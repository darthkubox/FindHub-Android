// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import SwiftUI
import WebKit
import SwiftProtobuf

/// Builds the `finder_hw` security-domain unlock URL (mirrors shared_key_request.py).
enum Vault {
    static func unlockURL() -> URL {
        var extras = EncryptionUnlockRequestExtras()
        extras.operation = 1
        extras.securityDomain.name = "finder_hw"
        extras.securityDomain.unknown = 0
        extras.sessionID = UUID().uuidString
        let serialized = (try? extras.serializedData()) ?? Data()
        var comps = URLComponents(string: "https://accounts.google.com/encryption/unlock/android")!
        comps.queryItems = [URLQueryItem(name: "kdi", value: serialized.base64EncodedString())]
        return comps.url!
    }
}

/// Signs into Google, then opens the E2EE key-unlock page and captures the
/// `finder_hw` vault keys via the `mm.setVaultSharedKeys` JS bridge — mirrors
/// KeyBackup/shared_key_flow.py. Returns the raw vaultKeys JSON string.
struct VaultUnlockWebView: UIViewRepresentable {
    let onVaultKeys: (String) -> Void
    let onError: (String) -> Void

    private static let bridge = """
    if (location.origin === 'https://accounts.google.com') {
        let result = null;
        window.mm = {
            setVaultSharedKeys: function(unused, vaultKeys) {
                result = {method: 'setVaultSharedKeys', vaultKeys: vaultKeys};
            },
            closeView: function() { if (result === null) result = {method: 'closeView'}; }
        };
        window.__findhubTakeResult = function() { const v = result; result = null; return v; };
    }
    """

    func makeCoordinator() -> Coordinator { Coordinator(onVaultKeys: onVaultKeys, onError: onError) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let userScript = WKUserScript(source: Self.bridge, injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: URL(string: "https://accounts.google.com/")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onVaultKeys: (String) -> Void
        private let onError: (String) -> Void
        private var navigatedToUnlock = false
        private var finished = false
        private var pollTimer: Timer?
        weak var webView: WKWebView?

        init(onVaultKeys: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onVaultKeys = onVaultKeys
            self.onError = onError
        }

        deinit { pollTimer?.invalidate() }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let host = webView.url?.host ?? ""
            // Signed in → move on to the key-unlock page.
            if !navigatedToUnlock, host == "myaccount.google.com" {
                navigatedToUnlock = true
                webView.load(URLRequest(url: Vault.unlockURL()))
                return
            }
            if navigatedToUnlock { startPolling(webView) }
        }

        private func startPolling(_ webView: WKWebView) {
            guard pollTimer == nil else { return }
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView, !self.finished else { return }
                guard webView.url?.host == "accounts.google.com" else { return }
                webView.evaluateJavaScript(
                    "window.__findhubTakeResult ? window.__findhubTakeResult() : null"
                ) { value, _ in
                    guard let dict = value as? [String: Any],
                          dict["method"] as? String == "setVaultSharedKeys",
                          let vaultKeys = dict["vaultKeys"] as? String else { return }
                    self.finish(vaultKeys)
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
        }

        private func finish(_ vaultKeys: String) {
            guard !finished else { return }
            finished = true
            pollTimer?.invalidate(); pollTimer = nil
            onVaultKeys(vaultKeys)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error as NSError)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error as NSError)
        }
        private func report(_ error: NSError) {
            guard !finished, error.code != NSURLErrorCancelled else { return }
            finished = true
            pollTimer?.invalidate()
            onError("Odblokowanie skarbca nie powiodło się (\(error.code)).")
        }
    }
}

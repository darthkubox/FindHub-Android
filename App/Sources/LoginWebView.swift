// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WebKit

/// Loads Google's EmbeddedSetup sign-in page in a WKWebView and reports back the
/// `oauth_token` cookie once Google sets it. iOS Password AutoFill offers the
/// account/passkey saved in the system Keychain right on this page, so the user
/// signs in without typing the password. Nothing is persisted here; the cookie
/// value is handed to the caller in memory.
struct LoginWebView: UIViewRepresentable {
    /// Called once with the captured oauth_token value.
    let onToken: (String) -> Void
    /// Called on navigation to a non-Google origin (safety) or on hard failure.
    let onError: (String) -> Void

    private static let setupURL = URL(string: "https://accounts.google.com/EmbeddedSetup")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Ephemeral store: no cookies/site data survive this sign-in on disk.
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: Self.setupURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onToken: (String) -> Void
        private let onError: (String) -> Void
        private var finished = false
        weak var webView: WKWebView?
        private var pollTimer: Timer?

        init(onToken: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onToken = onToken
            self.onError = onError
        }

        deinit { pollTimer?.invalidate() }

        private static func isGoogleOrigin(_ url: URL?) -> Bool {
            guard let url, url.scheme == "https", let host = url.host else { return false }
            return host == "accounts.google.com"
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPollingForToken(in: webView)
        }

        /// The oauth_token cookie can be set without a full navigation, so poll the
        /// cookie store on an interval while we remain on a Google origin.
        private func startPollingForToken(in webView: WKWebView) {
            guard pollTimer == nil else { return }
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView else { return }
                guard !self.finished else { return }
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    guard let cookie = cookies.first(where: {
                        $0.name == "oauth_token" && $0.domain.contains("google.com")
                    }), !cookie.value.isEmpty else { return }
                    self.finish(with: cookie.value)
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            pollTimer = timer
        }

        private func finish(with token: String) {
            guard !finished else { return }
            finished = true
            pollTimer?.invalidate()
            pollTimer = nil
            onToken(token)
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            reportFailureIfNeeded((error as NSError))
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            reportFailureIfNeeded((error as NSError))
        }

        private func reportFailureIfNeeded(_ error: NSError) {
            // Ignore cancellations (e.g. redirects superseding a load).
            guard !finished, error.code != NSURLErrorCancelled else { return }
            finished = true
            pollTimer?.invalidate()
            onError(String(localized: "Logowanie nie powiodło się (\(error.code))."))
        }
    }
}

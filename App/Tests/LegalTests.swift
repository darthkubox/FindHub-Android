// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
@testable import FindHubAndroid

/// The legal documents and licences must ship inside the app, name the
/// publisher, and render; sign-in stays gated until they are accepted.
final class LegalTests: XCTestCase {

    @MainActor
    func testLegalDocumentsAndLicencesShipAndRender() async throws {
        for document in LegalDocument.allCases {
            let text = document.text
            XCTAssertFalse(text.hasPrefix("Nie znaleziono"), "\(document.rawValue) missing from bundle")
            XCTAssertTrue(text.contains("mintstudio Jakub Koncewicz"), "\(document.rawValue) names the publisher")
            XCTAssertTrue(text.contains("kontakt@mintstudio.pl"))
        }
        XCTAssertTrue(LegalDocument.privacy.text.contains("policies.google.com/privacy"))
        XCTAssertTrue(LegalDocument.terms.text.contains("GNU General Public License"))

        for resource in ["ACKNOWLEDGEMENTS", "GPL-3.0"] {
            XCTAssertNotNil(Bundle.main.url(forResource: resource, withExtension: "txt"), "\(resource).txt missing")
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        XCTAssertEqual(LicensesView.publisher, "mintstudio")
        XCTAssertEqual(LicensesView.sourceCodeURL?.host, "github.com")

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        for document in LegalDocument.allCases {
            window.rootViewController = UIHostingController(rootView: NavigationStack { LegalDocumentView(document: document) })
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(300))
            let size = window.rootViewController!.view.sizeThatFits(window.bounds.size)
            XCTAssertGreaterThan(size.height, 0)
        }
    }

    func testConsentIsVersioned() {
        let key = "legal_accepted_version"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(LegalConsent.isAccepted)
        LegalConsent.accept()
        XCTAssertTrue(LegalConsent.isAccepted)
        UserDefaults.standard.set(LegalDocument.currentVersion - 1, forKey: key)
        XCTAssertFalse(LegalConsent.isAccepted, "an older acceptance must be renewed")
    }
}

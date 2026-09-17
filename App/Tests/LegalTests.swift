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
            for language in ["pl", "en"] {
                let text = document.text(language: language)
                XCTAssertFalse(text.hasPrefix("Nie znaleziono"), "\(document.resource(language: language)) missing from bundle")
                XCTAssertTrue(text.contains("mintstudio Jakub Koncewicz"), "\(document.resource(language: language)) names the publisher")
                XCTAssertTrue(text.contains("kontakt@mintstudio.pl"))
                XCTAssertTrue(text.contains("Version 1") || text.contains("Wersja 1"), "both languages carry the same version")
            }
            // Both language versions have the same numbered sections.
            let sections = { (lang: String) in document.text(language: lang).components(separatedBy: "\n").filter { $0.hasPrefix("## ") }.count }
            XCTAssertEqual(sections("pl"), sections("en"), "\(document.rawValue) sections differ between languages")
        }
        XCTAssertTrue(LegalDocument.privacy.text(language: "en").contains("policies.google.com/privacy"))
        XCTAssertTrue(LegalDocument.terms.text(language: "pl").contains("GNU General Public License"))

        for resource in ["ACKNOWLEDGEMENTS-pl", "ACKNOWLEDGEMENTS-en", "GPL-3.0"] {
            XCTAssertNotNil(Bundle.main.url(forResource: resource, withExtension: "txt"), "\(resource).txt missing")
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))

        // Every upstream project shown in Settings is credited, with its link, in both licence files.
        XCTAssertEqual(UpstreamProject.all.count, 7)
        for language in ["pl", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "ACKNOWLEDGEMENTS-\(language)", withExtension: "txt"))
            let acknowledgements = try String(contentsOf: url, encoding: .utf8)
            for project in UpstreamProject.all {
                XCTAssertEqual(project.url.scheme, "https")
                XCTAssertTrue(acknowledgements.contains(project.name.components(separatedBy: " (").first!), "\(language): \(project.name)")
                XCTAssertTrue(acknowledgements.contains(project.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                              "\(language): link for \(project.name)")
            }
        }
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

/// The account menu, legal screen and licences screen render; captures are kept
/// as attachments (and written to MOTOHUB_SNAPSHOT_DIR when set) for review.
final class LegalScreensTests: XCTestCase {
    @MainActor
    func testAccountMenuLegalAndLicenceScreens() async throws {
        let model = AppModel()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        let outputDirectory = ProcessInfo.processInfo.environment["MOTOHUB_SNAPSHOT_DIR"]
        let screens: [(String, AnyView)] = [
            ("login", AnyView(ContentView())),
            ("account-menu", AnyView(AccountSheet(model: model, onAddAccount: {}, onSettings: {}))),
            ("legal-info", AnyView(NavigationStack { LegalInfoView() })),
            ("licences", AnyView(NavigationStack { LicensesView() })),
            ("settings", AnyView(SettingsView(model: model, onAddAccount: {}))),
        ]
        for (name, view) in screens {
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(900))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            XCTAssertGreaterThan(image.size.height, 0)
            if name == "login" { XCTAssertNotNil(UIImage(named: "AppLogo"), "app logo asset is bundled") }
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            if let outputDirectory, let png = image.pngData() {
                try? png.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(name).png"))
            }
        }
    }
}

/// Every supported language ships with a complete interface translation.
final class LocalizationTests: XCTestCase {
    func testAllLanguagesAreBundledAndTranslated() throws {
        let expected: Set<String> = ["pl", "en", "de", "fr", "es", "it"]
        XCTAssertTrue(expected.isSubset(of: Set(Bundle.main.localizations)), "bundled: \(Bundle.main.localizations)")
        for language in expected.subtracting(["pl"]) {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in ["Zaloguj się przez Google", "Usuń dane tego konta z telefonu", "Polityka prywatności"] {
                let value = bundle.localizedString(forKey: key, value: "__missing__", table: nil)
                XCTAssertNotEqual(value, "__missing__", "\(language): \(key)")
                XCTAssertNotEqual(value, key, "\(language) not translated: \(key)")
            }
            let plural = String(format: bundle.localizedString(forKey: "%lld urządzeń", value: nil, table: nil), 2)
            XCTAssertFalse(plural.contains("urządz"), "\(language) plural: \(plural)")
        }
        let polish = try XCTUnwrap(Bundle(path: try XCTUnwrap(Bundle.main.path(forResource: "pl", ofType: "lproj"))))
        let format = polish.localizedString(forKey: "%lld urządzeń", value: nil, table: nil)
        XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 urządzenie")
        XCTAssertEqual(String.localizedStringWithFormat(format, 3), "3 urządzenia")
        XCTAssertEqual(String.localizedStringWithFormat(format, 5), "5 urządzeń")
        XCTAssertEqual(Bundle.main.infoDictionary?["CFBundleDevelopmentRegion"] as? String, "en",
                       "untranslated languages must fall back to English")
    }
}

/// Alert wording respects the lock-screen privacy switch.
final class NotificationSettingsTests: XCTestCase {
    func testAlertTextHidesNamesWhenRequested() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let detailed = NotificationText.placeExit(deviceName: "Portfel", placeName: "Dom", reportedAt: date, showDetails: true)
        XCTAssertTrue(detailed.title.contains("Portfel") && detailed.title.contains("Dom"))
        let hidden = NotificationText.placeExit(deviceName: "Portfel", placeName: "Dom", reportedAt: date, showDetails: false)
        XCTAssertFalse(hidden.title.contains("Portfel") || hidden.title.contains("Dom") || hidden.body.contains("Portfel"))
        XCTAssertTrue(NotificationText.separation(deviceName: "Klucze", showDetails: true).title.contains("Klucze"))
        XCTAssertFalse(NotificationText.separation(deviceName: "Klucze", showDetails: false).title.contains("Klucze"))
    }
}

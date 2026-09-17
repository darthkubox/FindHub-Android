// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
@testable import Tagpin

final class AppearanceTests: XCTestCase {
    @MainActor
    func testThemeChangesReachRootAndOpenSettingsAndRestoreSystem() async throws {
        let settings = AppSettings.shared
        let originalTheme = settings.theme
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let originalSystemStyle = scene.traitCollection.userInterfaceStyle
        let window = UIWindow(windowScene: scene)
        let observations = Observations()
        let root = UIHostingController(rootView: Harness(observations: observations))
        window.rootViewController = root
        defer {
            window.isHidden = true
            window.rootViewController = nil
            scene.traitOverrides.userInterfaceStyle = originalSystemStyle
            settings.theme = originalTheme
        }
        scene.traitOverrides.userInterfaceStyle = .dark
        settings.theme = .light
        window.makeKeyAndVisible()

        // Exercise the reported sequence repeatedly while the actual settings
        // sheet stays presented; both SwiftUI environments must update.
        for theme in [AppTheme.light, .dark, .system, .light, .system, .dark, .light, .dark, .system] {
            settings.theme = theme
            let expected: ColorScheme = theme == .light ? .light : .dark
            let expectedOverride: UIUserInterfaceStyle = theme == .system ? .unspecified : (theme == .light ? .light : .dark)
            try await eventually {
                observations.root == expected && observations.sheet == expected
                    && root.presentedViewController != nil
                    && window.overrideUserInterfaceStyle == expectedOverride
            }
            XCTAssertEqual(window.overrideUserInterfaceStyle, expectedOverride)
            XCTAssertEqual(UserDefaults.standard.string(forKey: AppSettings.K.theme), theme.rawValue)
        }

        // System mode must keep following system changes after clearing override.
        scene.traitOverrides.userInterfaceStyle = .light
        try await eventually { observations.root == .light && observations.sheet == .light }
        scene.traitOverrides.userInterfaceStyle = .dark
        try await eventually { observations.root == .dark && observations.sheet == .dark }

        // Recreating the view should apply the persisted theme on first attachment.
        window.isHidden = true
        window.rootViewController = nil
        settings.theme = .dark
        let reopened = UIHostingController(rootView: Harness(observations: observations))
        window.rootViewController = reopened
        window.makeKeyAndVisible()
        try await eventually { window.overrideUserInterfaceStyle == .dark && observations.root == .dark }
    }

    @MainActor
    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<60 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(condition(), "Appearance did not propagate to the window and open settings")
    }

    @MainActor
    private final class Observations {
        var root: ColorScheme?
        var sheet: ColorScheme?
    }

    private struct Probe: View {
        @Environment(\.colorScheme) private var scheme
        let record: (ColorScheme) -> Void
        var body: some View {
            Color.clear.onChange(of: scheme, initial: true) { _, value in record(value) }
        }
    }

    private struct Harness: View {
        @ObservedObject private var settings = AppSettings.shared
        @StateObject private var model = AppModel()
        @State private var showingSettings = true
        let observations: Observations

        var body: some View {
            Probe { observations.root = $0 }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(model: model, onAddAccount: {})
                        .background(Probe { observations.sheet = $0 })
                }
                .background(AppWindowAppearance(theme: settings.theme))
        }
    }
}

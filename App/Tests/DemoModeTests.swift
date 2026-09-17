// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
@testable import Tagpin

/// The demo shows every feature on sample data, never touches the network or a
/// tracker, and leaves nothing behind when it ends.
final class DemoModeTests: XCTestCase {
    @MainActor
    func testDemoSeedsSampleDataAndCleansUp() async throws {
        let model = AppModel()
        let journal = TrackerJournal.shared
        model.startDemo()
        defer { if model.isDemo { model.exitDemo() } }

        XCTAssertTrue(model.isDemo)
        XCTAssertTrue(model.loggedIn)
        XCTAssertTrue(model.hasE2EE)
        XCTAssertEqual(model.devices.count, 4)
        XCTAssertEqual(model.locations.count, 4)
        XCTAssertEqual(journal.account, DemoData.account)
        XCTAssertEqual(journal.document.places.count, 2)
        XCTAssertGreaterThan(journal.device("demo-backpack").history.count, 10)
        XCTAssertFalse(journal.device("demo-wallet").note.isEmpty)
        XCTAssertNil(Session.shared.masterToken.flatMap { _ in model.activeAccount == DemoData.account ? "" : nil },
                     "the demo never becomes a real session account")

        // Refresh is simulated locally and ringing never reaches Bluetooth.
        await model.locateAll(force: true)
        XCTAssertEqual(model.locationMessages["demo-keys"], String(localized: "Pozycja na mapie"))
        await model.ringNearby()
        XCTAssertEqual(model.issue?.kind, .demoRing)
        XCTAssertFalse(model.isRingingNearby)

        NameStore.set("Moje klucze", for: "demo-keys")
        model.exitDemo()
        XCTAssertFalse(model.isDemo)
        XCTAssertNil(NameStore.name(for: "demo-keys"), "demo customisation is removed")
        journal.activate(DemoData.account)
        XCTAssertTrue(journal.document.places.isEmpty && journal.document.devices.isEmpty, "demo journal is deleted")
        journal.activate(Session.shared.activeAccountID)
    }

    @MainActor
    func testDemoScreens() async throws {
        let model = AppModel()
        model.startDemo()
        defer { model.exitDemo() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        window.overrideUserInterfaceStyle = .dark
        let outputDirectory = ProcessInfo.processInfo.environment["MOTOHUB_SNAPSHOT_DIR"]
        let device = try XCTUnwrap(model.devices.first { $0.id == "demo-backpack" })
        let screens: [(String, AnyView)] = [
            ("demo-map", AnyView(DemoShell(model: model, tab: .devices))),
            ("demo-places", AnyView(DemoShell(model: model, tab: .places))),
            ("demo-detail", AnyView(NavigationStack { DeviceDetailView(model: model, device: device) })),
            ("demo-history", AnyView(NavigationStack { DeviceHistoryView(model: model, device: device) })),
        ]
        for (name, view) in screens {
            TrackerJournal.shared.activate(DemoData.account)
            window.rootViewController = UIHostingController(rootView: view)
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(1500))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            if let outputDirectory, let png = image.pngData() {
                try? png.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(name).png"))
            }
        }
    }
}

private struct DemoShell: View {
    @ObservedObject var model: AppModel
    @State var tab: MainTab
    var body: some View {
        MainTabsView(model: model, selection: $tab) {
            ToolbarItem(placement: .topBarTrailing) {
                Text("DEMO").font(.caption.weight(.bold)).padding(.horizontal, 10).frame(height: 28)
                    .background(Color.blue, in: Capsule())
            }
        }
    }
}

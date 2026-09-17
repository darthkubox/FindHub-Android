// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
import MapKit
@testable import Tagpin

/// Renders the rebuilt places tab and the Material navigation bar from synthetic
/// fixtures, in both appearances. No account, network or Bluetooth is involved.
final class PlacesViewTests: XCTestCase {
    @MainActor
    func testPlacesTabInBothAppearances() async throws {
        // AppModel's initialiser activates the journal for the signed-in account,
        // so the fixture account has to be selected *after* the model exists —
        // otherwise every fixture write lands with no active account and is lost.
        let model = AppModel()
        let journal = TrackerJournal.shared
        let originalAccount = journal.account
        let fixtureAccount = "places-ui-fixture@example.invalid"
        journal.activate(fixtureAccount)
        let wallet = TrackerDevice(id: "fixture-wallet", name: "Portfel")
        let car = TrackerDevice(id: "fixture-car", name: "Kia")
        let buds = TrackerDevice(id: "fixture-buds", name: "WF-1000XM5")
        model.devices = [wallet, car, buds]
        let now = Date()
        model.locations = [
            wallet.id: DecryptedLocation(coordinate: .init(latitude: 52.2297, longitude: 21.0122),
                                         time: now.addingTimeInterval(-300), accuracy: 18),
            car.id: DecryptedLocation(coordinate: .init(latitude: 52.2410, longitude: 21.0290),
                                      time: now.addingTimeInterval(-900), accuracy: 32),
        ]

        let home = SavedPlace(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                              name: "Dom", latitude: 52.2297, longitude: 21.0122, radius: 200)
        let work = SavedPlace(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                              name: "Praca", latitude: 52.2450, longitude: 21.0350, radius: 150)
        XCTAssertTrue(journal.savePlace(home))
        XCTAssertTrue(journal.savePlace(work))
        PlaceAssignment.set(true, device: wallet, place: home.id)
        PlaceAssignment.set(true, device: car, place: home.id)
        PlaceAssignment.set(true, device: buds, place: work.id)

        XCTAssertTrue(journal.device(wallet.id).placeIDs.contains(home.id))
        XCTAssertTrue(journal.device(wallet.id).placeAlerts)

        // Removing the only assignment disarms the alerts again.
        PlaceAssignment.set(false, device: buds, place: work.id)
        XCTAssertFalse(journal.device(buds.id).placeIDs.contains(work.id))
        XCTAssertFalse(journal.device(buds.id).placeAlerts)
        PlaceAssignment.set(true, device: buds, place: work.id)

        XCTAssertEqual(PlaceAssignment.symbol(for: home), "house.fill")
        XCTAssertEqual(PlaceAssignment.symbol(for: work), "briefcase.fill")

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil; journal.activate(originalAccount) }

        let outputDirectory = ProcessInfo.processInfo.environment["MOTOHUB_SNAPSHOT_DIR"]
        for style in [UIUserInterfaceStyle.light, .dark] {
            window.overrideUserInterfaceStyle = style
            let suffix = style == .light ? "light" : "dark"
            let views: [(String, AnyView)] = [
                ("tabs", AnyView(tabs(model: model, selected: .places))),
                ("devices", AnyView(tabs(model: model, selected: .devices))),
                ("detail", AnyView(NavigationStack { PlaceDetailView(model: model, placeID: home.id) })),
            ]
            for (name, view) in views {
                // The host app keeps re-activating the signed-out account; restore
                // the fixture before each capture so the screens have data.
                journal.activate(fixtureAccount)
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                try await Task.sleep(for: .milliseconds(900))
                window.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "places-\(name)-\(suffix)"
                attachment.lifetime = .keepAlways
                add(attachment)
                if let outputDirectory, let png = image.pngData() {
                    try? png.write(to: URL(fileURLWithPath: outputDirectory)
                        .appendingPathComponent("places-\(name)-\(suffix).png"))
                }
            }
        }
    }

    /// The signed-in shell with one tab selected, wired to a throwaway binding.
    @MainActor
    private func tabs(model: AppModel, selected: MainTab) -> some View {
        var selection = selected
        return MainTabsView(model: model,
                            selection: Binding(get: { selection }, set: { selection = $0 })) {
            ToolbarItem(placement: .topBarTrailing) { Image(systemName: "person.crop.circle") }
        }
    }
}

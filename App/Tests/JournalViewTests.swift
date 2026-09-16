// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import SwiftUI
import MapKit
@testable import FindHubAndroid

final class JournalViewTests: XCTestCase {
    @MainActor
    func testJournalScreensInBothAppearances() async throws {
        // AppModel's initialiser activates the journal for the signed-in account,
        // so the fixture account has to be selected *after* the model exists —
        // otherwise every fixture write lands with no active account and is lost.
        let model = AppModel()
        let journal = TrackerJournal.shared
        let originalAccount = journal.account
        let fixtureAccount = "journal-ui-fixture@example.invalid"
        journal.activate(fixtureAccount)
        let device = TrackerDevice(id: "fixture-wallet", name: "Portfel")
        model.devices = [device]
        journal.clearHistory(device.id)
        _ = journal.updateDevice(device.id, name: device.name) {
            $0.note = "W małej kieszeni plecaka. Parking: poziom −2, sektor C4."
        }
        let now = Date()
        var reports: [DecryptedLocation] = []
        for index in 0..<8 {
            let coordinate = CLLocationCoordinate2D(latitude: 52.2297 + Double(index) * 0.001,
                                                    longitude: 21.0122 + Double(index) * 0.0015)
            let time = now.addingTimeInterval(Double(index - 8) * 120)
            reports.append(DecryptedLocation(coordinate: coordinate, time: time, accuracy: 15))
        }
        _ = journal.ingest(reports, deviceID: device.id, name: device.name)
        model.locations[device.id] = reports.last
        let home = SavedPlace(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                              name: "Dom", latitude: 52.2297, longitude: 21.0122, radius: 200)
        XCTAssertTrue(journal.savePlace(home))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil; journal.activate(originalAccount) }
        for style in [UIUserInterfaceStyle.light, .dark] {
            window.overrideUserInterfaceStyle = style
            let suffix = style == .light ? "light" : "dark"
            let views: [(String, AnyView)] = [
                ("history", AnyView(NavigationStack { DeviceHistoryView(model: model, device: device) })),
                ("protection", AnyView(NavigationStack { DeviceProtectionView(model: model, device: device) })),
                ("places", AnyView(NavigationStack { SavedPlacesView() })),
                ("place-editor", AnyView(PlaceEditor(place: home))),
                ("note", AnyView(NavigationStack { ScrollView { DeviceNoteCard(deviceID: device.id, name: device.name).padding() }.navigationTitle("Portfel") }))
            ]
            for (name, view) in views {
                // The host app keeps re-activating the signed-out account; restore
                // the fixture before each capture so the screens have data.
                journal.activate(fixtureAccount)
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                try await Task.sleep(for: .milliseconds(600))
                window.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "journal-\(name)-\(suffix)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCTAssertEqual(journal.device(device.id).points(in: .day).count, 8)
    }
}

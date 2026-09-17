// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreLocation

@main
struct JournalRegressionTests {
    @MainActor static var count = 0
    @MainActor static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError("FAIL: \(message)") }
        count += 1; print("PASS: \(message)")
    }

    @MainActor static func main() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func location(_ age: Double, lat: Double = 52, accuracy: Double = 10) -> DecryptedLocation {
            .init(coordinate: .init(latitude: lat, longitude: 21), time: now.addingTimeInterval(-age), accuracy: accuracy)
        }
        func point(_ age: Double, lat: Double = 52, accuracy: Double = 10) -> HistoryPoint {
            HistoryPoint(location(age, lat: lat, accuracy: accuracy), now: now)!
        }
        check(HistoryPoint(location(-3600), now: now) == nil, "future report is rejected")
        check(HistoryPoint(location(8 * 86400), now: now) == nil, "older than seven days is rejected")
        check(HistoryPoint(location(0, lat: 91), now: now) == nil, "invalid coordinate is rejected")
        var record = DeviceJournal()
        record.merge([point(100), point(100), point(26 * 3600), point(50 * 3600), point(6 * 86400)], now: now)
        check(record.history.count == 4, "duplicate reports do not duplicate history")
        check(record.points(in: .day, now: now).count == 1, "24-hour range")
        check(record.points(in: .twoDays, now: now).count == 2, "48-hour range")
        check(record.points(in: .week, now: now).count == 4, "seven-day range")
        record.merge([point(100, accuracy: 5)], now: now)
        check(record.history.last?.accuracy == 5, "more accurate same-time report replaces old fix")
        record.merge([], now: now.addingTimeInterval(8 * 86400))
        check(record.history.isEmpty, "expired history is pruned")
        let segments = HistoryPath.segments([point(0), point(8000), point(7000)])
        check(segments.count == 2 && segments[0].count == 2, "route sorts points and leaves a gap after one hour")

        let home = SavedPlace(name: "Dom", latitude: 52, longitude: 21, radius: 150)
        check(home.isValid, "valid saved area")
        check(!SavedPlace(name: " ", latitude: 52, longitude: 21).isValid, "blank area name rejected")
        check(!SavedPlace(name: "Dom", latitude: 52, longitude: 21, radius: -1).isValid, "invalid radius rejected")
        let enabled = now.addingTimeInterval(-600)
        var boundary = BoundaryState()
        check(!boundary.accept(point(590, lat: 52.01), place: home, enabledAt: enabled, now: now), "outside initial state does not trigger departure")
        check(!boundary.accept(point(500), place: home, enabledAt: enabled, now: now), "inside arms without notifying")
        check(!boundary.accept(point(400, lat: 52.01), place: home, enabledAt: enabled, now: now), "first outside fix waits for confirmation")
        check(!boundary.accept(point(400, lat: 52.01), place: home, enabledAt: enabled, now: now), "duplicate outside fix is not confirmation")
        check(boundary.accept(point(300, lat: 52.01), place: home, enabledAt: enabled, now: now), "second distinct outside fix notifies")
        check(!boundary.accept(point(200, lat: 52.01), place: home, enabledAt: enabled, now: now), "remaining outside does not spam alerts")
        _ = boundary.accept(point(150), place: home, enabledAt: enabled, now: now)
        _ = boundary.accept(point(100, lat: 52.01), place: home, enabledAt: enabled, now: now)
        check(boundary.accept(point(50, lat: 52.01), place: home, enabledAt: enabled, now: now), "returning inside rearms next departure")
        var uncertain = BoundaryState()
        _ = uncertain.accept(point(500), place: home, enabledAt: enabled, now: now)
        _ = uncertain.accept(point(400, lat: 52.01), place: home, enabledAt: enabled, now: now)
        check(!uncertain.accept(point(300, lat: 52.01, accuracy: 1000), place: home, enabledAt: enabled, now: now), "inaccurate location never triggers exit")
        check(!uncertain.accept(point(200, lat: 52.01), place: home, enabledAt: enabled, now: now), "uncertain fix breaks outside sequence")
        var stale = BoundaryState()
        check(!stale.accept(point(1200), place: home, enabledAt: .distantPast, now: now) && !stale.wasInside, "stale report cannot arm rule")
        check(!stale.accept(point(700), place: home, enabledAt: enabled, now: now) && !stale.wasInside, "pre-enablement report cannot arm rule")

        var watch = SeparationWatch()
        check(!watch.disconnected(bluetoothAvailable: true), "unconfirmed tag never triggers separation")
        watch.connected()
        check(watch.disconnected(bluetoothAvailable: true), "confirmed connection loss triggers separation")
        check(!watch.disconnected(bluetoothAvailable: true), "duplicate disconnect cannot trigger another alarm")
        watch.connected()
        check(!watch.disconnected(bluetoothAvailable: false), "Bluetooth disabled is not separation")
        watch.connected(); watch.pause()
        check(!watch.disconnected(bluetoothAvailable: true), "paused or disabled watch cannot alert")
        watch.connected()
        check(watch.isConnected, "reconnection rearms protection")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("journal-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackerJournal(directory: directory)
        store.activate("first@example.com")
        check(store.updateDevice("same-id", name: "Portfel") { $0.note = "Kieszeń plecaka" }, "note saved")
        check(store.savePlace(home), "area saved")
        _ = store.updateDevice("same-id", name: "Portfel") {
            $0.placeIDs.insert(home.id); $0.placeAlerts = true; $0.alertEnabledAt = enabled; $0.closeDevice = true
        }
        check(store.ingest([location(500), location(400, lat: 52.01), location(300, lat: 52.01)], deviceID: "same-id", name: "Portfel", now: now).count == 1,
              "ingestion saves reports and generates one confirmed exit")
        check(store.ingest([location(300, lat: 52.01)], deviceID: "same-id", name: "Portfel", now: now).isEmpty, "replayed response does not notify")
        store.activate("second@example.com")
        check(store.device("same-id").note.isEmpty && store.document.places.isEmpty, "accounts isolate same device ID and areas")
        _ = store.updateDevice("same-id", name: "Klucze") { $0.note = "Druga notatka" }
        let restored = TrackerJournal(directory: directory)
        restored.activate("first@example.com")
        check(restored.device("same-id").note == "Kieszeń plecaka", "notes survive reload and account switch")
        check(restored.document.places == [home], "area survives reload")
        check(restored.device("same-id").history.count == 3, "history survives reload")
        restored.deletePlace(home)
        check(restored.device("same-id").placeIDs.isEmpty && restored.device("same-id").boundaries.isEmpty, "deleting area cleans assignments and boundary state")
        restored.stopProtectionForLogout()
        restored.activate("first@example.com")
        check(!restored.device("same-id").closeDevice && !restored.device("same-id").placeAlerts, "logout disables persisted protection")
        check(restored.device("same-id").note == "Kieszeń plecaka", "logout preserves note for future login")
        restored.clearHistory("same-id")
        check(restored.device("same-id").history.isEmpty, "history can be cleared")
        _ = restored.updateDevice("only-first", name: "Rower") { $0.note = "Tylko A" }
        check(restored.deviceIDsInOtherAccounts() == ["same-id"], "other accounts' device IDs are known before deletion")
        let removedIDs = try restored.deleteActiveAccountData()
        check(removedIDs == ["same-id", "only-first"], "deletion reports the account's device IDs")
        check(restored.account == nil && restored.document.devices.isEmpty, "deletion deactivates the store")
        check(!restored.updateDevice("same-id", name: "Portfel") { $0.note = "Po usunięciu" }, "deleted account cannot be written without activation")
        let afterDeletion = TrackerJournal(directory: directory)
        afterDeletion.activate("first@example.com")
        check(afterDeletion.device("same-id").note.isEmpty && afterDeletion.document.places.isEmpty, "deleted account data does not return after reload")
        afterDeletion.activate("second@example.com")
        check(afterDeletion.device("same-id").note == "Druga notatka", "deleting one account keeps another account's data")
        // A corrupted account file must remain intact instead of being overwritten
        // by an empty document on the next edit.
        let corruptDir = directory.appendingPathComponent("corrupt")
        let corrupt = TrackerJournal(directory: corruptDir)
        corrupt.activate("broken@example.com")
        _ = corrupt.updateDevice("id", name: "Tag") { $0.note = "Before corruption" }
        let file = try FileManager.default.contentsOfDirectory(at: corruptDir, includingPropertiesForKeys: nil).first!
        try Data("broken".utf8).write(to: file)
        let reader = TrackerJournal(directory: corruptDir)
        reader.activate("broken@example.com")
        check(!reader.updateDevice("id", name: "Tag") { $0.note = "New" }, "unreadable storage blocks writes")
        check(try Data(contentsOf: file) == Data("broken".utf8), "corrupt storage is not silently overwritten")
        print("\(count) journal checks passed")
    }
}

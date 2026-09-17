// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import CryptoKit

@MainActor
final class TrackerJournal: ObservableObject {
    static let shared = TrackerJournal()
    @Published private(set) var document = JournalDocument()
    @Published private(set) var account: String?
    @Published private(set) var storageError: String?
    var configurationChanged: (() -> Void)?
    private let directory: URL
    private var readable = true

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrackerJournal", isDirectory: true)
    }

    private func url(for account: String) -> URL {
        let hash = SHA256.hash(data: Data(account.lowercased().utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash + ".json")
    }

    func activate(_ account: String?) {
        guard self.account != account || !readable else { return }
        self.account = account
        document = JournalDocument(); storageError = nil; readable = true
        if let account, FileManager.default.fileExists(atPath: url(for: account).path) {
            do {
                document = try JSONDecoder().decode(JournalDocument.self, from: Data(contentsOf: url(for: account)))
                var trimmed = document
                for id in trimmed.devices.keys { trimmed.devices[id]?.merge([], now: .now) }
                _ = commit(trimmed)
            } catch {
                readable = false
                storageError = String(localized: "Nie udało się odczytać zapisanych notatek i historii. Dane nie zostały nadpisane.")
            }
        }
        configurationChanged?()
    }

    @discardableResult
    private func commit(_ next: JournalDocument) -> Bool {
        guard let account, readable else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var folder = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try folder.setResourceValues(values)
            let data = try JSONEncoder().encode(next)
            #if os(iOS)
            try data.write(to: url(for: account), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: url(for: account), options: .atomic)
            #endif
            document = next; storageError = nil
            return true
        } catch {
            storageError = String(localized: "Nie udało się zapisać zmian na telefonie. Spróbuj ponownie.")
            return false
        }
    }

    func device(_ id: String) -> DeviceJournal { document.devices[id] ?? DeviceJournal() }

    @discardableResult
    func updateDevice(_ id: String, name: String, _ change: (inout DeviceJournal) -> Void) -> Bool {
        var next = document
        var record = next.devices[id] ?? DeviceJournal()
        record.name = name
        change(&record)
        record.disconnectDelay = min(300, max(30, record.disconnectDelay))
        record.note = String(record.note.prefix(4000))
        next.devices[id] = record
        let saved = commit(next)
        if saved { configurationChanged?() }
        return saved
    }

    @discardableResult
    func savePlace(_ place: SavedPlace) -> Bool {
        guard place.isValid else { return false }
        var next = document
        if let index = next.places.firstIndex(where: { $0.id == place.id }) { next.places[index] = place }
        else { next.places.append(place) }
        // Moving/resizing a zone is configuration, never a device departure.
        for id in next.devices.keys where next.devices[id]?.placeIDs.contains(place.id) == true {
            next.devices[id]?.boundaries = [:]
            next.devices[id]?.alertEnabledAt = .now
        }
        let saved = commit(next)
        if saved { configurationChanged?() }
        return saved
    }

    func deletePlace(_ place: SavedPlace) {
        var next = document
        next.places.removeAll { $0.id == place.id }
        for id in next.devices.keys {
            next.devices[id]?.placeIDs.remove(place.id)
            next.devices[id]?.boundaries.removeValue(forKey: place.id.uuidString)
        }
        if commit(next) { configurationChanged?() }
    }

    func ingest(_ locations: [DecryptedLocation], deviceID: String, name: String, now: Date = .now) -> [PlaceExitEvent] {
        let points = locations.compactMap { HistoryPoint($0, now: now) }.sorted { $0.time < $1.time }
        guard !points.isEmpty else { return [] }
        var next = document
        var record = next.devices[deviceID] ?? DeviceJournal()
        record.name = name; record.merge(points, now: now)
        var events: [PlaceExitEvent] = []
        if record.placeAlerts {
            for place in next.places where record.placeIDs.contains(place.id) {
                var boundary = record.boundaries[place.id.uuidString] ?? BoundaryState()
                for point in points {
                    if boundary.accept(point, place: place, enabledAt: record.alertEnabledAt, now: now) {
                        events.append(.init(deviceID: deviceID, deviceName: name, placeID: place.id,
                                            placeName: place.name, reportedAt: point.time))
                    }
                }
                record.boundaries[place.id.uuidString] = boundary
            }
        }
        next.devices[deviceID] = record
        guard next != document else { return [] }
        return commit(next) ? events : []
    }

    func clearHistory(_ id: String) {
        var next = document; next.devices[id]?.history = []; _ = commit(next)
    }

    /// Device IDs recorded in other accounts' files, so shared per-device stores
    /// (names, icons, photos) keep entries another account still uses.
    /// Unreadable files are skipped.
    func deviceIDsInOtherAccounts() -> Set<String> {
        let own = account.map { url(for: $0).lastPathComponent }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var ids = Set<String>()
        for file in files where file.pathExtension == "json" && file.lastPathComponent != own {
            guard let data = try? Data(contentsOf: file),
                  let other = try? JSONDecoder().decode(JournalDocument.self, from: data) else { continue }
            ids.formUnion(other.devices.keys)
        }
        return ids
    }

    /// Permanently removes the active account's history, notes and places, then
    /// deactivates the store. Returns the device IDs the file held. Throws and
    /// keeps everything unchanged when the file cannot be removed.
    func deleteActiveAccountData() throws -> Set<String> {
        guard let account else { return [] }
        let ids = Set(document.devices.keys)
        let file = url(for: account)
        if FileManager.default.fileExists(atPath: file.path) {
            do { try FileManager.default.removeItem(at: file) }
            catch {
                storageError = String(localized: "Nie udało się usunąć danych konta z telefonu. Spróbuj ponownie.")
                throw error
            }
        }
        self.account = nil
        document = JournalDocument(); storageError = nil; readable = true
        configurationChanged?()
        return ids
    }

    func stopProtectionForLogout() {
        var next = document
        for id in next.devices.keys {
            next.devices[id]?.closeDevice = false
            next.devices[id]?.connectionArmed = false
            next.devices[id]?.placeAlerts = false
            next.devices[id]?.boundaries = [:]
        }
        _ = commit(next)
        activate(nil)
    }
}

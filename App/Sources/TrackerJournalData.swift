// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreLocation

enum HistoryRange: Int, CaseIterable, Identifiable {
    case day = 24, twoDays = 48, week = 168
    var id: Int { rawValue }
    var label: String { self == .week ? String(localized: "7 dni") : String(localized: "\(rawValue) h") }
    var seconds: TimeInterval { Double(rawValue) * 3600 }
}

struct HistoryPoint: Codable, Identifiable, Equatable {
    var id: String { "\(time.timeIntervalSince1970):\(latitude):\(longitude)" }
    let latitude: Double
    let longitude: Double
    let time: Date
    let accuracy: Double?
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    init?(_ location: DecryptedLocation, now: Date = .now) {
        guard CLLocationCoordinate2DIsValid(location.coordinate), let date = location.reportedAt,
              date <= now.addingTimeInterval(60), date >= now.addingTimeInterval(-HistoryRange.week.seconds) else { return nil }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        time = date
        accuracy = location.accuracyMeters
    }
}

struct SavedPlace: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 150
    /// SF Symbol the user picked; nil falls back to a guess from the name.
    var symbol: String?
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CLLocationCoordinate2DIsValid(coordinate) && radius.isFinite && (50...5000).contains(radius)
    }
}

struct DeviceJournal: Codable, Equatable {
    var name = String(localized: "Urządzenie")
    var note = ""
    var history: [HistoryPoint] = []
    var closeDevice = false
    var disconnectDelay: Double = 90
    var peripheralID: UUID?
    var encryptedIdentityKey: Data?
    var connectionArmed: Bool?
    var placeIDs: Set<UUID> = []
    var placeAlerts = false
    var alertEnabledAt = Date.distantFuture
    var boundaries: [String: BoundaryState] = [:]

    func points(in range: HistoryRange, now: Date = .now) -> [HistoryPoint] {
        history.filter { $0.time >= now.addingTimeInterval(-range.seconds) && $0.time <= now }
            .sorted { $0.time < $1.time }
    }

    mutating func merge(_ points: [HistoryPoint], now: Date) {
        // A report can be delivered repeatedly or out of order. Keep a single fix
        // per timestamp; prefer its more accurate version without inventing a path.
        var byTime: [Date: HistoryPoint] = [:]
        for point in history + points where point.time >= now.addingTimeInterval(-HistoryRange.week.seconds) {
            if let old = byTime[point.time], (old.accuracy ?? .infinity) <= (point.accuracy ?? .infinity) { continue }
            byTime[point.time] = point
        }
        history = Array(byTime.values.sorted { $0.time < $1.time }.suffix(12_000))
    }
}

struct BoundaryState: Codable, Equatable {
    var lastReport = Date.distantPast
    var wasInside = false
    var firstOutside: Date?

    /// Only fresh, accurate reports received after enabling the rule can arm it.
    /// Two distinct outside fixes confirm departure; uncertain fixes break that sequence.
    mutating func accept(_ point: HistoryPoint, place: SavedPlace, enabledAt: Date, now: Date) -> Bool {
        guard point.time > lastReport, point.time >= enabledAt,
              point.time <= now, now.timeIntervalSince(point.time) <= 15 * 60 else { return false }
        lastReport = point.time
        guard let accuracy = point.accuracy, accuracy > 0, accuracy <= place.radius else {
            firstOutside = nil; return false
        }
        let distance = CLLocation(latitude: point.latitude, longitude: point.longitude)
            .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
        if distance + accuracy <= place.radius {
            wasInside = true; firstOutside = nil; return false
        }
        guard distance - accuracy > place.radius + 20 else { firstOutside = nil; return false }
        guard wasInside else { return false }
        guard let firstOutside else { self.firstOutside = point.time; return false }
        guard point.time.timeIntervalSince(firstOutside) >= 30 else { return false }
        wasInside = false; self.firstOutside = nil
        return true
    }
}

struct PlaceExitEvent {
    let deviceID: String
    let deviceName: String
    let placeID: UUID
    let placeName: String
    let reportedAt: Date
}

struct JournalDocument: Codable, Equatable {
    var startedAt = Date()
    var devices: [String: DeviceJournal] = [:]
    var places: [SavedPlace] = []
}

enum HistoryPath {
    /// An hour without a report creates a visible gap instead of a fictitious route.
    static func segments(_ points: [HistoryPoint]) -> [[HistoryPoint]] {
        var result: [[HistoryPoint]] = []
        for point in points.sorted(by: { $0.time < $1.time }) {
            if let last = result.last?.last, point.time.timeIntervalSince(last.time) <= 3600 {
                result[result.count - 1].append(point)
            } else { result.append([point]) }
        }
        return result
    }
}

struct SeparationWatch {
    private(set) var isConnected = false
    mutating func connected() { isConnected = true }
    mutating func pause() { isConnected = false }
    mutating func disconnected(bluetoothAvailable: Bool) -> Bool {
        let shouldAlert = isConnected && bluetoothAvailable
        isConnected = false
        return shouldAlert
    }
}

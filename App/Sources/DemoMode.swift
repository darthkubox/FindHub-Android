// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import CoreLocation

/// Sample account for the demonstration mode offered on the sign-in screen.
/// Everything is synthetic: no Google account, no network requests, no Bluetooth
/// commands. It lets anyone (including App Review) see every screen without a
/// paired tracker.
enum DemoData {
    /// Reserved `.invalid` domain: can never be a real Google account.
    static let account = "demo@findhub-android.invalid"

    private static let home = CLLocationCoordinate2D(latitude: 52.1935, longitude: 21.0213)
    private static let work = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
    private static let park = CLLocationCoordinate2D(latitude: 52.2125, longitude: 21.0000)
    private static let wilanow = CLLocationCoordinate2D(latitude: 52.1650, longitude: 21.0890)

    static func devices(now: Date = .now) -> [TrackerDevice] {
        let paired = now.addingTimeInterval(-120 * 86_400)
        return [
            TrackerDevice(id: "demo-keys", name: String(localized: "Klucze"), categorySymbol: "key.fill",
                          manufacturer: "Motorola", modelName: "moto tag", pairedAt: paired),
            TrackerDevice(id: "demo-wallet", name: String(localized: "Portfel"), categorySymbol: "creditcard.fill",
                          manufacturer: "Motorola", modelName: "moto tag", pairedAt: paired),
            TrackerDevice(id: "demo-backpack", name: String(localized: "Plecak"), categorySymbol: "backpack.fill",
                          manufacturer: "Motorola", modelName: "moto tag", pairedAt: paired),
            TrackerDevice(id: "demo-bike", name: String(localized: "Rower"), categorySymbol: "bicycle",
                          manufacturer: "Motorola", modelName: "moto tag", pairedAt: paired,
                          sharedWithMe: true, ownerEmail: "ola@example.com"),
        ]
    }

    static func locations(now: Date = .now) -> [String: DecryptedLocation] {
        [
            "demo-keys": DecryptedLocation(coordinate: home, time: now.addingTimeInterval(-4 * 60), accuracy: 12),
            "demo-wallet": DecryptedLocation(coordinate: work, time: now.addingTimeInterval(-18 * 60), accuracy: 25),
            "demo-backpack": DecryptedLocation(coordinate: park, time: now.addingTimeInterval(-7 * 60), accuracy: 35),
            "demo-bike": DecryptedLocation(coordinate: wilanow, time: now.addingTimeInterval(-2 * 3600), accuracy: 60),
        ]
    }

    /// Places, assignments, a note and a day of history, written to the demo
    /// account's journal file (deleted again when the demo ends).
    @MainActor static func seed(_ journal: TrackerJournal, now: Date = .now) {
        let homePlace = SavedPlace(name: String(localized: "Dom"), latitude: home.latitude, longitude: home.longitude,
                                   radius: 150, symbol: "house.fill")
        let workPlace = SavedPlace(name: String(localized: "Praca"), latitude: work.latitude, longitude: work.longitude,
                                   radius: 200, symbol: "briefcase.fill")
        journal.savePlace(homePlace)
        journal.savePlace(workPlace)

        // Backpack: morning at home, commute through the park, afternoon at work,
        // with a gap over lunch so the route shows how missing reports look.
        var route: [DecryptedLocation] = []
        let legs: [(CLLocationCoordinate2D, CLLocationCoordinate2D, Double, Double)] = [
            (home, home, 10, 8), (home, park, 8, 7), (park, work, 7, 5.5), (work, work, 3.5, 0.2),
        ]
        for (from, to, startHours, endHours) in legs {
            let steps = max(2, Int((startHours - endHours) * 2))
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let hoursAgo = startHours - (startHours - endHours) * t
                let coordinate = CLLocationCoordinate2D(latitude: from.latitude + (to.latitude - from.latitude) * t,
                                                        longitude: from.longitude + (to.longitude - from.longitude) * t)
                route.append(DecryptedLocation(coordinate: coordinate, time: now.addingTimeInterval(-hoursAgo * 3600),
                                               accuracy: 30))
            }
        }
        _ = journal.ingest(route, deviceID: "demo-backpack", name: String(localized: "Plecak"), now: now)
        _ = journal.ingest((0..<6).map { index in
            DecryptedLocation(coordinate: home, time: now.addingTimeInterval(-Double(index) * 3600 - 240), accuracy: 12)
        }, deviceID: "demo-keys", name: String(localized: "Klucze"), now: now)

        journal.updateDevice("demo-keys", name: String(localized: "Klucze")) {
            $0.placeIDs = [homePlace.id]; $0.placeAlerts = true; $0.alertEnabledAt = now.addingTimeInterval(-86_400)
        }
        journal.updateDevice("demo-wallet", name: String(localized: "Portfel")) {
            $0.placeIDs = [workPlace.id]; $0.placeAlerts = true; $0.alertEnabledAt = now.addingTimeInterval(-86_400)
            $0.note = String(localized: "Zwykle w wewnętrznej kieszeni kurtki.")
        }
    }
}

/// Always-visible marker that the app shows sample data, with the way out.
struct DemoBanner: View {
    let onExit: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "play.rectangle.fill").font(.system(size: 20, weight: .semibold))
                .foregroundStyle(M3.primary(scheme)).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text("Tryb demonstracyjny").font(.subheadline.weight(.semibold)).foregroundStyle(M3.onSurface(scheme))
                Text("Przykładowe dane. Aplikacja nie łączy się z Google ani z tagami.")
                    .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Zakończ demo i zaloguj się", action: onExit)
                    .buttonStyle(M3TonalButtonStyle())
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.background(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.primary(scheme).opacity(0.4), lineWidth: 1))
    }
}

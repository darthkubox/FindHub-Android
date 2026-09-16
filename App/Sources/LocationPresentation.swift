// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreLocation

enum MapsProvider: String, CaseIterable, Identifiable {
    case google, apple

    var id: String { rawValue }
    var name: String {
        switch self {
        case .google: return "Google Maps"
        case .apple: return String(localized: "Mapy Apple")
        }
    }
}

enum LocationPresentation {
    /// The app's resolved UI language with the user's region, so dates match the
    /// language the interface is shown in.
    static var appLocale: Locale { Locale.autoupdatingCurrent }

    /// Relative age in full words (e.g. "2 hours ago", "2 godziny temu").
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = appLocale
        f.unitsStyle = .full
        return f
    }()

    static func relativeAge(_ date: Date, relativeTo now: Date = Date()) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    /// Full date + time in the app's language.
    static func fullDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard).locale(appLocale))
    }

    static func coordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", locale: Locale(identifier: "en_US_POSIX"),
               coordinate.latitude, coordinate.longitude)
    }

    static func distance(_ meters: Double) -> String {
        guard meters.isFinite, meters >= 0 else { return String(localized: "Brak danych") }
        if UserDefaults.standard.bool(forKey: "set_useImperial") {   // AppSettings.K.imperial
            let feet = meters * 3.28084
            if feet < 5280 { return "\(Int(feet.rounded())) ft" }
            return (feet / 5280).formatted(.number.precision(.fractionLength(1))) + " mi"
        }
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        return (meters / 1000).formatted(.number.precision(.fractionLength(1))) + " km"
    }

    static func mapsURL(coordinate: CLLocationCoordinate2D, name: String, directions: Bool,
                        provider: MapsProvider) -> URL? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        var parts = URLComponents()
        parts.scheme = "https"
        let point = coordinates(coordinate)
        switch provider {
        case .google:
            // Universal URLs open the installed app, with a browser fallback.
            parts.host = "www.google.com"
            parts.path = directions ? "/maps/dir/" : "/maps/search/"
            parts.queryItems = [URLQueryItem(name: "api", value: "1"),
                                URLQueryItem(name: directions ? "destination" : "query", value: point)]
        case .apple:
            parts.host = "maps.apple.com"
            parts.queryItems = directions
                ? [URLQueryItem(name: "daddr", value: point)]
                : [URLQueryItem(name: "ll", value: point), URLQueryItem(name: "q", value: name)]
        }
        return parts.url
    }
}

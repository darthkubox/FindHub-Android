// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return String(localized: "Systemowy")
        case .light: return String(localized: "Jasny")
        case .dark: return String(localized: "Ciemny")
        }
    }
}

/// User-tunable display settings, persisted in UserDefaults. Toggles let the user
/// hide details they don't care about; units switch between metric and imperial;
/// theme overrides the system light/dark appearance.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    enum K {
        static let imperial = "set_useImperial"
        static let accuracy = "set_showAccuracy"
        static let coordinates = "set_showCoordinates"
        static let distance = "set_showDistance"
        static let seenTime = "set_showSeenTime"
        static let diagnostics = "set_showDiagnostics"
        static let namedPlaces = "set_showNamedPlaces"
        static let theme = "set_theme"
    }

    /// Defaults new display flags to on; returns stored value otherwise.
    private static func flag(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? true : UserDefaults.standard.bool(forKey: key)
    }

    @Published var useImperial: Bool { didSet { d.set(useImperial, forKey: K.imperial) } }
    @Published var showAccuracy: Bool { didSet { d.set(showAccuracy, forKey: K.accuracy) } }
    @Published var showCoordinates: Bool { didSet { d.set(showCoordinates, forKey: K.coordinates) } }
    @Published var showDistance: Bool { didSet { d.set(showDistance, forKey: K.distance) } }
    @Published var showSeenTime: Bool { didSet { d.set(showSeenTime, forKey: K.seenTime) } }
    @Published var showDiagnostics: Bool { didSet { d.set(showDiagnostics, forKey: K.diagnostics) } }
    @Published var showNamedPlaces: Bool { didSet { d.set(showNamedPlaces, forKey: K.namedPlaces) } }
    @Published var theme: AppTheme { didSet { d.set(theme.rawValue, forKey: K.theme) } }

    private init() {
        useImperial = d.bool(forKey: K.imperial)          // defaults false
        showAccuracy = Self.flag(K.accuracy)
        showCoordinates = Self.flag(K.coordinates)
        showDistance = Self.flag(K.distance)
        showSeenTime = Self.flag(K.seenTime)
        showDiagnostics = Self.flag(K.diagnostics)
        showNamedPlaces = Self.flag(K.namedPlaces)
        theme = AppTheme(rawValue: d.string(forKey: K.theme) ?? "") ?? .system
    }
}

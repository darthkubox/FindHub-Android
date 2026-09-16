// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Local per-device icon override: an SF Symbol name chosen by the user.
/// App-local only (does not change anything on the Google account).
enum IconStore {
    private static let key = "device_custom_symbol"

    /// Curated set of clean line icons to choose from (Apple SF Symbols).
    static let choices: [String] = [
        "bag.fill", "backpack.fill", "handbag.fill", "briefcase.fill", "suitcase.fill",
        "key.fill", "car.fill", "bicycle", "scooter", "airplane",
        "headphones", "airpods", "laptopcomputer", "camera.fill", "gamecontroller.fill",
        "pawprint.fill", "house.fill", "bed.double.fill", "cross.case.fill", "guitars.fill",
        "tag.fill", "creditcard.fill", "cart.fill", "figure.walk",
    ]

    static func symbol(for id: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        let v = map?[id]
        return (v?.isEmpty ?? true) ? nil : v
    }

    static func set(_ symbol: String, for id: String) {
        var map = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { map.removeValue(forKey: id) } else { map[id] = trimmed }
        UserDefaults.standard.set(map, forKey: key)
    }

    /// Removes the entries of devices whose local data is being deleted.
    static func remove(_ ids: Set<String>) {
        guard var map = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else { return }
        for id in ids { map.removeValue(forKey: id) }
        UserDefaults.standard.set(map, forKey: key)
    }
}

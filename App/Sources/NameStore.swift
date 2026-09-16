// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Local per-device custom names (aliases). Overrides the Google name in the app
/// only — does not rename the device on your Google account.
enum NameStore {
    private static let key = "device_custom_names"

    static func name(for id: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        let v = map?[id]
        return (v?.isEmpty ?? true) ? nil : v
    }

    static func set(_ name: String, for id: String) {
        var map = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
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

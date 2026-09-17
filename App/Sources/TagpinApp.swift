// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct TagpinApp: App {
    @UIApplicationDelegateAdaptor(GuardianAppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(AppWindowAppearance(theme: settings.theme))
        }
    }
}

// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct FindHubAndroidApp: App {
    @UIApplicationDelegateAdaptor(GuardianAppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .background(AppWindowAppearance(theme: settings.theme))
        }
    }
}

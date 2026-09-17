// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import BackgroundTasks

@MainActor
final class GuardianAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureAppearance()
        TrackerJournal.shared.activate(Session.shared.activeAccountID)
        DeviceProtection.shared.start()
        BGTaskScheduler.shared.register(forTaskWithIdentifier: GuardianBackground.identifier, using: .main) { task in
            Task { @MainActor in GuardianBackground.run(task) }
        }
        return true
    }

    /// Force a solid Material-style tab bar (Google look), overriding iOS 26's
    /// translucent "Liquid Glass" default. Colours track the M3 palette.
    private func configureAppearance() {
        func dyn(_ dark: UInt32, _ light: UInt32) -> UIColor {
            UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
        }
        let surface = dyn(0x1E2025, 0xFFFFFF)
        let unselected = dyn(0xC3C6CF, 0x43474E)
        let selected = dyn(0xA8C7FA, 0x0B57D1)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = surface
        tab.shadowColor = dyn(0x000000, 0xD9DDE5)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = unselected
            item.normal.titleTextAttributes = [.foregroundColor: unselected]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        // NOTE: do not set `isTranslucent = false` — with an opaque bar UIKit then adds
        // the bar's height to the safe area on top of SwiftUI's own inset, so the
        // drawer gets pushed up by twice the tab-bar height and leaves a black gap.
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = surface
        nav.shadowColor = dyn(0x000000, 0xD9DDE5)
        let title = dyn(0xE2E2E9, 0x1A1C1E)
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

@MainActor
enum GuardianBackground {
    static let identifier = "pl.mintstudio.tagpin.journal-refresh"

    static func schedule() {
        guard Session.shared.isLoggedIn else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier); return
        }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(15 * 60)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { /* Foreground refresh remains available if background refresh is disabled. */ }
    }

    static func run(_ task: BGTask) {
        schedule()
        let work = Task { @MainActor in
            await AppModel.shared.refreshJournalLocations()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
        task.expirationHandler = { work.cancel() }
    }
}

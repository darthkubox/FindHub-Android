// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// The app's two top-level destinations.
enum MainTab: Hashable, CaseIterable {
    case devices, places

    var title: String {
        switch self {
        case .devices: return String(localized: "Urządzenia")
        case .places: return String(localized: "Miejsca")
        }
    }
    /// Material navigation bars use an outlined glyph when idle and a filled one
    /// inside the active indicator.
    var icon: String {
        switch self {
        case .devices: return "location"
        case .places: return "mappin.and.ellipse"
        }
    }
    var selectedIcon: String {
        switch self {
        case .devices: return "location.fill"
        case .places: return "mappin.and.ellipse"
        }
    }
}

/// The window's own bottom safe-area inset. Read from the scene rather than from
/// a `GeometryReader`: the shell deliberately ignores that inset so the bar can
/// paint into it, which would make any reader nested inside it report zero.
enum ScreenInsets {
    @MainActor static var bottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }
            .map(\.safeAreaInsets.bottom)
            .max() ?? 0
    }
}

/// Material 3 navigation bar: a pill-shaped active indicator behind the selected
/// icon, the label underneath, and generous breathing room before the bottom edge
/// of the window — the system tab bar packed its icons far too close to it.
///
/// The bar paints its own home-indicator strip, so it must sit in a container
/// that ignores the bottom safe area, with `totalHeight(safeBottom:)` reserved
/// under the page. Neither a `safeAreaInset` nor `.ignoresSafeArea` on the bar
/// itself does that job — both leave it resting on the safe-area boundary, which
/// is what left the handle floating a full inset too high.
struct M3TabBar: View {
    @Binding var selection: MainTab
    let safeBottom: CGFloat

    @Environment(\.colorScheme) private var scheme
    @Namespace private var indicator

    /// Height of the row of items, above the home-indicator strip.
    static let contentHeight: CGFloat = 80
    /// Room the handle needs when the window reserves none of its own.
    static let minimumHandleStrip: CGFloat = 24

    static func handleStrip(safeBottom: CGFloat) -> CGFloat { max(safeBottom, minimumHandleStrip) }
    /// Full painted height, and what the page underneath has to reserve.
    static func totalHeight(safeBottom: CGFloat) -> CGFloat {
        contentHeight + handleStrip(safeBottom: safeBottom)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.self) { tab in item(tab) }
            }
            .frame(height: 54)
            .padding(.top, 12)
            .padding(.bottom, 14)

            // The strip the system keeps for the home indicator, painted by the bar
            // so the surface reaches the very bottom of the window.
            Color.clear.frame(height: Self.handleStrip(safeBottom: safeBottom))
        }
        .frame(maxWidth: .infinity)
        .background(M3.surface(scheme))
        .overlay(alignment: .top) {
            Rectangle().fill(M3.outline(scheme).opacity(scheme == .dark ? 0.25 : 0.2))
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) { handle }
    }

    /// The home-indicator handle, drawn by the app so it is always present and
    /// always sits on the bar's surface, at the metrics the system uses.
    private var handle: some View {
        Capsule()
            .fill(M3.onSurface(scheme).opacity(scheme == .dark ? 0.55 : 0.35))
            .frame(width: 140, height: 5)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }

    private func item(_ tab: MainTab) -> some View {
        let active = selection == tab
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { selection = tab }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if active {
                        Capsule()
                            .fill(M3.primaryContainer(scheme))
                            .frame(width: 64, height: 32)
                            .matchedGeometryEffect(id: "indicator", in: indicator)
                    }
                    Image(systemName: active ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? M3.onPrimaryContainer(scheme) : M3.onSurfaceVariant(scheme))
                }
                .frame(height: 32)

                Text(tab.title)
                    .font(.caption.weight(active ? .semibold : .medium))
                    .foregroundStyle(active ? M3.onSurface(scheme) : M3.onSurfaceVariant(scheme))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

private struct TabBarReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Height the navigation bar covers at the bottom of a tab page; zero outside
    /// the tab shell (sheets, full-screen covers).
    var tabBarReserve: CGFloat {
        get { self[TabBarReserveKey.self] }
        set { self[TabBarReserveKey.self] = newValue }
    }
}

/// Screens pushed inside a tab's NavigationStack do not inherit the shell's
/// `safeAreaInset`, so their last rows ended under the navigation bar. Each
/// pushed screen reserves the bar's height itself.
private struct ClearsTabBar: ViewModifier {
    @Environment(\.tabBarReserve) private var reserve
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: reserve).allowsHitTesting(false)
        }
    }
}

extension View {
    func clearsTabBar() -> some View { modifier(ClearsTabBar()) }
}

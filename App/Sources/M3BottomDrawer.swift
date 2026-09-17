// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The three resting positions the home drawers snap between. Heights are what
/// stays visible above the navigation bar: the drawer extends behind the bar by
/// the page's bottom inset, which `height` adds back on top.
enum DrawerDetents {
    /// Peek shows the grab handle and the drawer header, never less.
    static let peekHeight: CGFloat = 124
    static let collapsedFraction = 0.52
    static let fullFraction = 0.92

    static func base(available: CGFloat, expanded: Bool, minimized: Bool) -> CGFloat {
        if minimized { return min(peekHeight, available * collapsedFraction) }
        return available * (expanded ? fullFraction : collapsedFraction)
    }

    static func height(available: CGFloat, expanded: Bool, minimized: Bool, drag: CGFloat,
                       bottomInset: CGFloat) -> CGFloat {
        let peek = base(available: available, expanded: false, minimized: true)
        let full = available * fullFraction
        let visible = min(max(base(available: available, expanded: expanded, minimized: minimized) - drag,
                              peek * 0.9), full)
        return visible + bottomInset
    }
}

/// The Material bottom sheet used by both home tabs: a grab handle, a pinned
/// header and a scrolling body, resting at a peek / half / full detent.
struct M3BottomDrawer<Header: View, Content: View>: View {
    @Binding var expanded: Bool
    @Binding var minimized: Bool
    let availableHeight: CGFloat
    let bottomInset: CGFloat
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            grabHandle
            header
            ScrollView {
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomInset + 24)
            }
        }
        .frame(height: DrawerDetents.height(available: availableHeight, expanded: expanded,
                                            minimized: minimized, drag: dragOffset,
                                            bottomInset: bottomInset),
               alignment: .top)
        .frame(maxWidth: .infinity)
        .background(M3.surface(scheme))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .background(alignment: .bottom) {
            M3.surface(scheme).frame(height: bottomInset + 60).ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: -2)
    }

    private var grabHandle: some View {
        Capsule().fill(M3.outline(scheme).opacity(0.5))
            .frame(width: 40, height: 5).padding(.top, 10).padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                // Global coordinate space: the handle lives inside the panel whose
                // height we change, so a local-space translation would chase itself
                // and jitter. Global translation is measured against the screen.
                DragGesture(coordinateSpace: .global)
                    .onChanged { dragOffset = $0.translation.height }
                    .onEnded { value in
                        let dy = value.translation.height
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            if dy < -40 {            // dragged up: peek → collapsed → expanded
                                if minimized { minimized = false } else { expanded = true }
                            } else if dy > 40 {      // dragged down: expanded → collapsed → peek
                                if expanded { expanded = false } else { minimized = true }
                            }
                            dragOffset = 0
                        }
                    })
    }
}

/// Header for every modal drawer, copied from the home drawer: grab handle,
/// bold title on the left and a round action on the right. Sheets use it in
/// place of a navigation bar so they look like the drawer on the map.
struct M3SheetHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    var closeIcon = "xmark"
    let onClose: () -> Void
    @ViewBuilder var trailing: Trailing
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(M3.outline(scheme).opacity(0.5))
                .frame(width: 40, height: 5).padding(.top, 10).padding(.bottom, 8)
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Text(title).font(.title3.bold()).foregroundStyle(M3.onSurface(scheme))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                trailing
                Button(action: onClose) {
                    Image(systemName: closeIcon).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(M3.onPrimaryContainer(scheme))
                        .frame(width: 36, height: 36).background(M3.primaryContainer(scheme)).clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(closeIcon == "checkmark" ? "Gotowe" : "Zamknij"))
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(M3.surface(scheme))
    }
}

extension M3SheetHeader where Trailing == EmptyView {
    init(title: LocalizedStringKey, closeIcon: String = "xmark", onClose: @escaping () -> Void) {
        self.init(title: title, closeIcon: closeIcon, onClose: onClose) { EmptyView() }
    }
}

/// Presentation of a modal drawer: the home drawer's surface colour and 28 pt
/// corners, with the grab handle drawn by `M3SheetHeader` instead of the system.
private struct M3SheetStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .presentationBackground(M3.surface(scheme))
            .presentationCornerRadius(28)
            .presentationDragIndicator(.hidden)
    }
}

/// Root of a sheet's NavigationStack: hides the system bar and pins the drawer
/// header on top. Pushed screens keep their own navigation bar with a back button.
private struct M3SheetRoot: ViewModifier {
    let title: LocalizedStringKey
    let closeIcon: String
    let onClose: () -> Void
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                M3SheetHeader(title: title, closeIcon: closeIcon, onClose: onClose)
            }
            .background(M3.surface(scheme).ignoresSafeArea())
    }
}

extension View {
    func m3Sheet() -> some View { modifier(M3SheetStyle()) }
    func m3SheetRoot(_ title: LocalizedStringKey, closeIcon: String = "xmark", onClose: @escaping () -> Void) -> some View {
        modifier(M3SheetRoot(title: title, closeIcon: closeIcon, onClose: onClose))
    }
    /// Lists inside drawers: drawer surface behind, darker cards like the home rows.
    func m3SheetList(_ scheme: ColorScheme) -> some View {
        scrollContentBackground(.hidden).background(M3.surface(scheme))
            // Material list items are 56 pt; 52 keeps iOS proportions without cramping.
            .environment(\.defaultMinListRowHeight, 52)
            .listSectionSpacing(24)
            .contentMargins(.top, 8, for: .scrollContent)
    }
}

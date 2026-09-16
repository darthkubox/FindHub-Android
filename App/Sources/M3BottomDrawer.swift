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
                    .padding(.horizontal, 12)
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

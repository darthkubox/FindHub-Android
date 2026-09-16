// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// Apply appearance to this scene's window so already-presented sheets inherit
/// changes too. Explicitly clear the override when returning to system mode.
struct AppWindowAppearance: UIViewRepresentable {
    let theme: AppTheme

    func makeUIView(context: Context) -> AppearanceView {
        let view = AppearanceView()
        view.isUserInteractionEnabled = false
        view.theme = theme
        return view
    }

    func updateUIView(_ uiView: AppearanceView, context: Context) {
        uiView.theme = theme
    }

    final class AppearanceView: UIView {
        var theme: AppTheme = .system { didSet { applyAppearance() } }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyAppearance()
        }

        private func applyAppearance() {
            let style: UIUserInterfaceStyle
            switch theme {
            case .system: style = .unspecified
            case .light: style = .light
            case .dark: style = .dark
            }
            guard let window, window.overrideUserInterfaceStyle != style else { return }
            window.overrideUserInterfaceStyle = style
        }
    }
}

/// Lightweight Material 3 palette + surfaces, adapting to light/dark.
enum M3 {
    // Google Find Hub blue (Material 3 dynamic blue tokens).
    static func primary(_ s: ColorScheme) -> Color { s == .dark ? hex(0xA8C7FA) : hex(0x0B57D1) }
    static func onPrimary(_ s: ColorScheme) -> Color { s == .dark ? hex(0x0A305F) : .white }
    static func primaryContainer(_ s: ColorScheme) -> Color { s == .dark ? hex(0x284777) : hex(0xD3E3FD) }
    static func onPrimaryContainer(_ s: ColorScheme) -> Color { s == .dark ? hex(0xD7E3FF) : hex(0x041E49) }
    static func secondary(_ s: ColorScheme) -> Color { s == .dark ? hex(0xBEC6DC) : hex(0x565F71) }
    static func background(_ s: ColorScheme) -> Color { s == .dark ? hex(0x111318) : hex(0xF8FAFF) }
    static func surface(_ s: ColorScheme) -> Color { s == .dark ? hex(0x1E2025) : .white }
    static func surfaceVariant(_ s: ColorScheme) -> Color { s == .dark ? hex(0x43474E) : hex(0xDFE2EB) }
    static func onSurface(_ s: ColorScheme) -> Color { s == .dark ? hex(0xE2E2E9) : hex(0x1A1C1E) }
    static func onSurfaceVariant(_ s: ColorScheme) -> Color { s == .dark ? hex(0xC3C6CF) : hex(0x43474E) }
    static func outline(_ s: ColorScheme) -> Color { s == .dark ? hex(0x8D9199) : hex(0x73777F) }

    static func hex(_ v: UInt32) -> Color {
        Color(.sRGB,
              red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255)
    }
}

/// Material "elevated card" container.
struct M3Card<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(M3.surface(scheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.08), radius: 8, x: 0, y: 2)
    }
}

/// Material filled button style.
struct M3FilledButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(M3.onPrimary(scheme))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(M3.primary(scheme).opacity(isEnabled ? 1 : 0.4))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Material tonal (secondary) button style.
struct M3TonalButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(M3.onPrimaryContainer(scheme))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(M3.primaryContainer(scheme))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Round Material icon button on a tonal background.
struct M3IconButton: View {
    @Environment(\.colorScheme) private var scheme
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(M3.onPrimaryContainer(scheme))
                .frame(width: 40, height: 40)
                .background(M3.primaryContainer(scheme))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Floating round button over a full-bleed map (my location, overview). Shared by
/// every map screen so the controls look the same everywhere.
struct M3MapButton: View {
    @Environment(\.colorScheme) private var scheme
    let system: String
    let label: LocalizedStringKey
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(M3.primary(scheme))
                .frame(width: 44, height: 44)
                .background(M3.surface(scheme), in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
        }
        .accessibilityLabel(label)
    }
}

/// DisclosureGroup style whose chevron points DOWN when collapsed and rotates UP
/// when expanded (top/bottom motion), instead of the default right→down flip.
struct UpDownDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { configuration.isExpanded.toggle() }
            } label: {
                HStack {
                    configuration.label
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if configuration.isExpanded { configuration.content }
        }
    }
}

/// Material-style text field container: filled tonal surface, soft rounded corners,
/// hairline outline — replaces the default black `.roundedBorder` look.
struct M3FieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .foregroundStyle(M3.onSurface(scheme))
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(M3.surfaceVariant(scheme).opacity(scheme == .dark ? 0.45 : 0.55),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(M3.outline(scheme).opacity(0.25), lineWidth: 1))
    }
}

extension View {
    func m3Field() -> some View { modifier(M3FieldStyle()) }
}

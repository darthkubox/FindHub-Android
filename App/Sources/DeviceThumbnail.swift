// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Shared device thumbnail. Main image priority: custom photo → custom icon →
/// Google render → category glyph. When a custom photo/icon is set, the original
/// (render or category glyph) is shown as a small badge in the bottom-left.
struct DeviceThumbnail: View {
    @Environment(\.colorScheme) private var scheme
    let device: TrackerDevice
    var size: CGFloat = 56
    var version: Int = 0   // bump to force a refresh after editing
    var iconOnly = false   // map markers never use photos or product-render badges

    private var customPhoto: UIImage? { DeviceImageStore.image(for: device.id) }
    private var customSymbol: String? { IconStore.symbol(for: device.id) }
    private var renderURL: URL? { device.imageURL.flatMap { URL(string: $0) } }

    var body: some View {
        let _ = version
        main
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                // Small original Google render in the corner (the actual device image).
                if !iconOnly, let url = renderURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit().padding(size * 0.05)
                        } else { Color.clear }
                    }
                    .frame(width: size * 0.4, height: size * 0.4)
                    .background(M3.surface(scheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(M3.background(scheme), lineWidth: size * 0.03))
                    .offset(x: -size * 0.06, y: size * 0.06)
                }
            }
    }

    /// Main image: custom photo → custom icon → auto category icon (by name).
    @ViewBuilder private var main: some View {
        if !iconOnly, let img = customPhoto {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                M3.primaryContainer(scheme)
                Image(systemName: customSymbol ?? device.categorySymbol ?? Self.iconFor(device.name))
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(M3.onPrimaryContainer(scheme))
            }
        }
    }

    static func iconFor(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("wf-") || n.contains("bud") || n.contains("sony") { return "airpods" }
        if n.contains("watch") { return "applewatch" }
        if n.contains("s22") || n.contains("phone") || n.contains("galaxy") { return "iphone" }
        if n.contains("kia") || n.contains("car") || n.contains("auto") { return "car.fill" }
        if n.contains("portfel") || n.contains("wallet") { return "wallet.pass.fill" }
        return "dot.radiowaves.left.and.right"
    }
}

// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct MapClusterMarker: View {
    let cluster: MapCluster
    let devices: [TrackerDevice]
    let selectedDeviceID: String?
    let select: (MapMarkerID) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(MapClusters.tileWidth), spacing: MapClusters.spacing),
                                     count: min(3, cluster.members.count)), spacing: MapClusters.spacing) {
                ForEach(cluster.members, id: \.self) { member in
                    Button { select(member) } label: {
                        tile(member)
                            .frame(width: MapClusters.tileWidth, height: MapClusters.tileHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MapClusters.padding)
            .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.primary(scheme).opacity(0.6), lineWidth: 1))
            MapPinTip()
                .fill(M3.primary(scheme))
                .frame(width: 16, height: MapClusters.tipHeight)
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
    }

    @ViewBuilder private func tile(_ member: MapMarkerID) -> some View {
        switch member {
        case .user:
            VStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue, in: Circle())
                Text("Ty").font(.caption2.weight(.semibold)).foregroundStyle(M3.onSurface(scheme))
            }
            .accessibilityLabel("Twoja lokalizacja")
        case .device(let id):
            if let device = devices.first(where: { $0.id == id }) {
                let name = NameStore.name(for: id) ?? device.name
                VStack(spacing: 4) {
                    DeviceThumbnail(device: device, size: 32, iconOnly: true)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedDeviceID == id ? M3.primary(scheme) : .clear, lineWidth: 2))
                    Text(name.isEmpty ? String(localized: "Urządzenie") : name)
                        .font(.caption2).lineLimit(1)
                        .foregroundStyle(M3.onSurface(scheme))
                }
                .accessibilityLabel(name)
            }
        }
    }
}

/// Downward tip shared by the map markers, so a pin points at its coordinate.
struct MapPinTip: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

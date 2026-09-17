// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// "Hot/cold" Bluetooth proximity finder for a single tag. Grows and warms as the
/// signal gets stronger; confirms identity when the tag's EID matches the device.
struct FinderView: View {
    @ObservedObject var model: AppModel
    let device: TrackerDevice
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var finder = BleFinder()

    private var displayName: String {
        NameStore.name(for: device.id) ?? (device.name.isEmpty ? String(localized: "(bez nazwy)") : device.name)
    }

    private var ringColor: Color {
        // Cold (blue) → warm (orange/red) with proximity.
        Color(hue: 0.6 - 0.6 * finder.level, saturation: 0.85, brightness: 0.95)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 8)

                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(ringColor.opacity(0.12))
                            .frame(width: 140 + CGFloat(i) * 90 * finder.level,
                                   height: 140 + CGFloat(i) * 90 * finder.level)
                    }
                    Circle()
                        .fill(ringColor.opacity(0.9))
                        .frame(width: 120 + 90 * finder.level, height: 120 + 90 * finder.level)
                        .shadow(color: ringColor.opacity(0.5), radius: 18)
                    VStack(spacing: 4) {
                        Image(systemName: finder.locked ? "dot.radiowaves.left.and.right" : "wave.3.right")
                            .font(.system(size: 34, weight: .bold))
                        if let rssi = finder.rssi {
                            Text("\(rssi) dBm").font(.headline.monospacedDigit())
                        }
                    }
                    .foregroundStyle(.white)
                }
                .frame(height: 380)
                .animation(.easeOut(duration: 0.4), value: finder.level)

                VStack(spacing: 6) {
                    if finder.locked {
                        Label(displayName, systemImage: "checkmark.seal.fill")
                            .font(.title3.bold()).foregroundStyle(M3.primary(scheme))
                    } else {
                        Text(displayName).font(.title3.bold()).foregroundStyle(M3.onSurface(scheme))
                    }
                    Text(finder.status)
                        .font(.subheadline).foregroundStyle(M3.onSurfaceVariant(scheme))
                        .multilineTextAlignment(.center)
                    if !finder.locked && finder.nearbyCount > 0 {
                        Text("Tagów w pobliżu: \(finder.nearbyCount)")
                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                Button {
                    Task { await model.ringNearby() }
                } label: {
                    Label(model.isRingingNearby ? "Dzwonię…" : "Zadzwoń w najbliższym tagu",
                          systemImage: "bell.and.waves.left.and.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(M3TonalButtonStyle())
                .disabled(model.isRingingNearby || !finder.available)
                .padding(.horizontal, 24)

                Text("Wskaźnik rośnie i się ociepla, gdy jesteś bliżej. Idź w stronę, w której sygnał jest najsilniejszy.")
                    .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .m3SheetRoot("Namierz w pobliżu") { dismiss() }
        }
        .onAppear { finder.start(expectedEIDPrefixes: model.expectedEIDPrefixes(for: device)) }
        .onDisappear { finder.stop() }
    }
}

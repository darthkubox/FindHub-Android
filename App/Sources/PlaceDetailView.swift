// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit

/// A single saved place: its zone on the map, and the devices it watches. Devices
/// are added to and removed from the zone here.
struct PlaceDetailView: View {
    @ObservedObject var model: AppModel
    let placeID: UUID

    @ObservedObject private var journal = TrackerJournal.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var editing = false
    @State private var picking = false
    @State private var confirmDelete = false
    @State private var camera: MapCameraPosition = .automatic

    private var place: SavedPlace? { journal.document.places.first { $0.id == placeID } }
    private var assigned: [TrackerDevice] {
        model.devices.filter { journal.device($0.id).placeIDs.contains(placeID) }
    }
    private var unassigned: [TrackerDevice] {
        model.devices.filter { !journal.device($0.id).placeIDs.contains(placeID) }
    }

    var body: some View {
        Group {
            if let place { content(place) } else { removed }
        }
        .background(M3.background(scheme).ignoresSafeArea())
        .navigationTitle(place?.name ?? "Miejsce")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edytuj obszar", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Usuń miejsce", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Opcje miejsca")
            }
        }
        .sheet(isPresented: $editing) { if let place { PlaceEditor(place: place) } }
        .sheet(isPresented: $picking) { devicePicker }
        .alert("Usunąć miejsce?", isPresented: $confirmDelete) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive) {
                if let place { journal.deletePlace(place) }
                dismiss()
            }
        } message: {
            Text("Przypisane urządzenia przestaną być pilnowane w tym obszarze. Historia i notatki zostają.")
        }
    }

    // MARK: - Content

    private func content(_ place: SavedPlace) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                mapCard(place)
                zoneCard(place)
                devicesCard(place)
                Text("Alert wysyłamy, gdy świeży raport Find Hub pokaże urządzenie poza tym obszarem — nie na podstawie pozycji telefonu.")
                    .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let error = journal.storageError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private func mapCard(_ place: SavedPlace) -> some View {
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            MapCircle(center: place.coordinate, radius: place.radius)
                .foregroundStyle(M3.primary(scheme).opacity(0.18))
                .stroke(M3.primary(scheme).opacity(0.8), lineWidth: 2)
            Annotation("", coordinate: place.coordinate, anchor: .center) {
                ZStack {
                    Circle().fill(M3.primary(scheme)).frame(width: 34, height: 34)
                    Image(systemName: PlaceAssignment.symbol(for: place))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(M3.onPrimary(scheme))
                }
            }
            ForEach(assigned) { device in
                if let loc = model.locations[device.id] {
                    Annotation("", coordinate: loc.coordinate, anchor: .center) {
                        DeviceThumbnail(device: device, size: 28, iconOnly: true)
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(M3.surface(scheme), lineWidth: 2))
                    }
                }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear { frame(place) }
        .onChange(of: place) { frame(place) }
    }

    private func frame(_ place: SavedPlace) {
        let span = max(place.radius * 3, 300)
        camera = .region(MKCoordinateRegion(center: place.coordinate,
            latitudinalMeters: span, longitudinalMeters: span))
    }

    private func zoneCard(_ place: SavedPlace) -> some View {
        M3Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(M3.primaryContainer(scheme)).frame(width: 44, height: 44)
                        Image(systemName: PlaceAssignment.symbol(for: place))
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(M3.onPrimaryContainer(scheme))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.headline).foregroundStyle(M3.onSurface(scheme))
                        Text("Promień \(Int(place.radius)) m")
                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                    Spacer()
                }
                Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                    .font(.caption.monospaced()).foregroundStyle(M3.onSurfaceVariant(scheme))
                Button { editing = true } label: {
                    Label("Edytuj obszar", systemImage: "pencil").frame(maxWidth: .infinity)
                }
                .buttonStyle(M3TonalButtonStyle())
            }
            .padding(16)
        }
    }

    private func devicesCard(_ place: SavedPlace) -> some View {
        M3Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pilnowane urządzenia").font(.subheadline.weight(.semibold))
                        .foregroundStyle(M3.onSurface(scheme))
                    Spacer()
                    Text("\(assigned.count)").font(.subheadline.weight(.semibold))
                        .foregroundStyle(M3.onSurfaceVariant(scheme))
                }

                if assigned.isEmpty {
                    Text("Żadne urządzenie nie jest jeszcze przypisane do tego miejsca.")
                        .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                } else {
                    VStack(spacing: 8) {
                        ForEach(assigned) { device in assignedRow(device) }
                    }
                }

                Button { picking = true } label: {
                    Label("Dodaj urządzenie", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(M3TonalButtonStyle())
                .disabled(unassigned.isEmpty)

                if unassigned.isEmpty && !model.devices.isEmpty {
                    Text("Wszystkie urządzenia są już przypisane do tego miejsca.")
                        .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                }
                if model.devices.isEmpty {
                    Text("Brak urządzeń na koncie.")
                        .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                }
            }
            .padding(16)
        }
    }

    private func assignedRow(_ device: TrackerDevice) -> some View {
        HStack(spacing: 12) {
            DeviceThumbnail(device: device, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(PlaceAssignment.name(of: device))
                    .font(.subheadline.weight(.medium)).foregroundStyle(M3.onSurface(scheme))
                Text(statusText(device))
                    .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
            Spacer()
            Button {
                PlaceAssignment.set(false, device: device, place: placeID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Usuń \(PlaceAssignment.name(of: device)) z tego miejsca")
        }
        .padding(8)
        .background(M3.background(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    /// Where the device's newest fix sits relative to this zone, when we have one.
    private func statusText(_ device: TrackerDevice) -> String {
        guard let place, let location = model.locations[device.id] else { return "Brak odebranej pozycji" }
        let distance = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude))
        guard distance.isFinite else { return "Pozycja niedostępna" }
        if distance <= place.radius { return "W obszarze" }
        return "Poza obszarem · \(LocationPresentation.distance(distance))"
    }

    private var removed: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash").font(.system(size: 44))
                .foregroundStyle(M3.onSurfaceVariant(scheme))
            Text("To miejsce zostało usunięte.").font(.headline).foregroundStyle(M3.onSurface(scheme))
            Button("Wróć") { dismiss() }.buttonStyle(M3TonalButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Device picker

    private var devicePicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if unassigned.isEmpty {
                        Text("Nie ma już urządzeń do dodania.")
                            .font(.subheadline).foregroundStyle(M3.onSurfaceVariant(scheme))
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(unassigned) { device in
                        Button {
                            PlaceAssignment.set(true, device: device, place: placeID)
                        } label: {
                            HStack(spacing: 12) {
                                DeviceThumbnail(device: device, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(PlaceAssignment.name(of: device))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(M3.onSurface(scheme))
                                    if device.sharedWithMe, let owner = device.ownerEmail {
                                        Text("Udostępnione przez \(owner)")
                                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22)).foregroundStyle(M3.primary(scheme))
                            }
                            .padding(10)
                            .background(M3.surface(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(M3.background(scheme).ignoresSafeArea())
            .navigationTitle("Dodaj urządzenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { picking = false } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(M3.primary(scheme))
    }
}

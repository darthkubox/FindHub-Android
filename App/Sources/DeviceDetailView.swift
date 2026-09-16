// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import PhotosUI
import CoreLocation

/// Per-device screen: locate, ring, and personalize (name / icon / photo).
struct DeviceDetailView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings = AppSettings.shared
    let device: TrackerDevice
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var version = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var showRename = false
    @State private var nameField = ""
    @State private var showIconPicker = false
    @State private var showFinder = false
    @State private var copiedCoordinates = false
    @StateObject private var userLocation = LocationManager()

    private var currentDevice: TrackerDevice { model.devices.first { $0.id == device.id } ?? device }
    private var position: DecryptedLocation? { model.locations[device.id] }

    private var displayName: String {
        NameStore.name(for: device.id) ?? (currentDevice.name.isEmpty ? "(bez nazwy)" : currentDevice.name)
    }
    private var hasCustom: Bool {
        DeviceImageStore.image(for: device.id) != nil || IconStore.symbol(for: device.id) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                actionsRow
                locationCard
                detailCard("Historia i pilnowanie", icon: "clock.arrow.circlepath") {
                    NavigationLink {
                        DeviceHistoryView(model: model, device: currentDevice)
                    } label: { Label("Ostatnie zmiany lokalizacji", systemImage: "map") }
                    Divider()
                    NavigationLink {
                        DeviceProtectionView(model: model, device: currentDevice)
                    } label: { Label("Bliskie urządzenie i alerty miejsc", systemImage: "bell.badge") }
                }
                informationCard
                DeviceNoteCard(deviceID: device.id, name: displayName)
                personalizationCard
                diagnosticsCard
                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(M3.background(scheme).ignoresSafeArea())
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem, applyPickedPhoto)
        .alert("Zmień nazwę", isPresented: $showRename) {
            TextField("Nazwa", text: $nameField)
            Button("Zapisz") { NameStore.set(nameField, for: device.id); version += 1 }
            Button("Anuluj", role: .cancel) {}
        } message: { Text("Nazwa lokalna w aplikacji (nie zmienia nazwy na koncie Google).") }
        .sheet(isPresented: $showIconPicker) { iconPickerSheet }
        .sheet(isPresented: $showFinder) { FinderView(model: model, device: currentDevice) }
        .onAppear { userLocation.request() }
        .onDisappear { userLocation.stop() }
        .onChange(of: position?.time) { copiedCoordinates = false }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            DeviceThumbnail(device: currentDevice, size: 120, version: version)
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.1), radius: 8, y: 3)
            Text(displayName).font(.title2.bold()).foregroundStyle(M3.onSurface(scheme))
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton("Pokaż na mapie", "location.fill") {
                model.focusOnMap(device.id)
                dismiss()
            }
            actionButton("Namierz w pobliżu", "dot.radiowaves.left.and.right") { showFinder = true }
            actionButton(model.ringingDeviceID == device.id ? "Wysyłam…" : "Zadzwoń przez sieć", "bell.and.waves.left.and.right.fill") { Task { await model.ring(currentDevice) } }
                .disabled(model.ringingDeviceID != nil)
        }
    }

    private var locationCard: some View {
        detailCard("Ostatnia lokalizacja", icon: "location.fill") {
            if let position {
                if let date = position.reportedAt {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocationPresentation.relativeAge(date))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(M3.onSurface(scheme))
                            Text(LocationPresentation.fullDate(date))
                                .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                        }
                    }
                } else {
                    infoLine("Czas raportu", value: "Brak danych")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { mapsLinks(position) }
                    VStack(alignment: .leading, spacing: 10) { mapsLinks(position) }
                }
                locationDetails(position)
            } else {
                if settings.showNamedPlaces, let named = model.namedLocations[device.id] {
                    Label(named.name, systemImage: "mappin.and.ellipse")
                        .font(.headline).foregroundStyle(M3.onSurface(scheme))
                    if named.time.timeIntervalSince1970 > 0 {
                        Text(LocationPresentation.fullDate(named.time))
                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                }
                Text(model.locationMessages[device.id] ?? "Nie odebrano jeszcze pozycji tego urządzenia.")
                    .font(.subheadline).foregroundStyle(M3.onSurfaceVariant(scheme))
                Button("Pobierz lokalizację") { Task { await model.locate(currentDevice) } }
                    .buttonStyle(M3TonalButtonStyle())
            }
        }
    }

    @ViewBuilder private var diagnosticsCard: some View {
        if settings.showDiagnostics, let diagnostics = model.locationDiagnostics[device.id] {
            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup {
                    Text(diagnostics).font(.caption).textSelection(.enabled)
                        .foregroundStyle(M3.onSurfaceVariant(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                } label: {
                    Label("Diagnostyka odczytu", systemImage: "stethoscope")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(M3.primary(scheme))
                }
                .tint(M3.primary(scheme))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
        }
    }

    @ViewBuilder private func mapsLinks(_ position: DecryptedLocation) -> some View {
        mapsMenu(position, directions: false)
        mapsMenu(position, directions: true)
    }

    /// Secondary location facts (accuracy, distance, coordinates) tucked away in an
    /// expandable section — main info stays visible, details on demand.
    @ViewBuilder private func locationDetails(_ position: DecryptedLocation) -> some View {
        if settings.showAccuracy || settings.showDistance || settings.showCoordinates {
            DisclosureGroup("Więcej szczegółów") {
                VStack(alignment: .leading, spacing: 12) {
                    if settings.showAccuracy {
                        infoLine("Dokładność", value: position.accuracyMeters.map { "około " + LocationPresentation.distance($0) } ?? "Brak danych")
                    }
                    if settings.showDistance {
                        if let me = userLocation.location {
                            let target = CLLocation(latitude: position.coordinate.latitude, longitude: position.coordinate.longitude)
                            infoLine("Od Ciebie w linii prostej", value: "około " + LocationPresentation.distance(me.distance(from: target)))
                        } else {
                            Text(userLocation.message ?? "Odległość pojawi się po ustaleniu Twojej pozycji.")
                                .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                        }
                    }
                    if settings.showCoordinates {
                        infoLine("Współrzędne", value: LocationPresentation.coordinates(position.coordinate))
                        Button {
                            UIPasteboard.general.string = LocationPresentation.coordinates(position.coordinate)
                            copiedCoordinates = true
                        } label: {
                            Label(copiedCoordinates ? "Skopiowano współrzędne" : "Kopiuj współrzędne",
                                  systemImage: copiedCoordinates ? "checkmark" : "doc.on.doc")
                                .font(.footnote)
                        }
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.footnote)
            .tint(M3.primary(scheme))
        }
    }

    private func mapsMenu(_ position: DecryptedLocation, directions: Bool) -> some View {
        Menu {
            ForEach(MapsProvider.allCases) { provider in
                if let url = LocationPresentation.mapsURL(coordinate: position.coordinate,
                                                         name: displayName, directions: directions,
                                                         provider: provider) {
                    Link(provider.name, destination: url)
                }
            }
        } label: {
            Label(directions ? "Trasa" : "Otwórz w mapach",
                  systemImage: directions ? "arrow.turn.up.right" : "map")
        }
        .menuOrder(.fixed)
        .buttonStyle(M3TonalButtonStyle())
    }

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    infoLine("Nazwa w Google", value: currentDevice.name.isEmpty ? "Brak danych" : currentDevice.name)
                    infoLine("Producent", value: currentDevice.manufacturer ?? "Brak danych")
                    infoLine("Model", value: currentDevice.modelName ?? "Brak danych")
                    if let paired = currentDevice.pairedAt {
                        infoLine("Sparowano", value: paired.formatted(date: .abbreviated, time: .omitted))
                    }
                    infoLine("Pozycja", value: model.locationMessages[device.id] ?? (position == nil ? "Brak danych" : "Dostępna na mapie"))
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Informacje o urządzeniu", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(M3.primary(scheme))
            }
            .tint(M3.primary(scheme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
    }

    private func detailCard<Content: View>(_ title: String, icon: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold)).foregroundStyle(M3.primary(scheme))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
    }

    private func infoLine(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).foregroundStyle(M3.onSurfaceVariant(scheme))
                Spacer(minLength: 8)
                Text(value).foregroundStyle(M3.onSurface(scheme)).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(M3.onSurfaceVariant(scheme))
                Text(value).foregroundStyle(M3.onSurface(scheme))
            }
        }
        .font(.footnote)
    }

    private var personalizationCard: some View {
        VStack(spacing: 0) {
            editRow("Zmień nazwę", "pencil") {
                nameField = NameStore.name(for: device.id) ?? device.name; showRename = true
            }
            Divider().padding(.leading, 52)
            PhotosPicker(selection: $photoItem, matching: .images) {
                rowLabel("Dodaj / zmień zdjęcie", "photo")
            }
            Divider().padding(.leading, 52)
            editRow("Wybierz ikonę", "square.grid.2x2.fill") { showIconPicker = true }
            if hasCustom {
                Divider().padding(.leading, 52)
                editRow("Przywróć domyślny wygląd", "arrow.uturn.backward", destructive: true) {
                    DeviceImageStore.remove(device.id); IconStore.set("", for: device.id); version += 1
                }
            }
        }
        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
    }

    private var iconPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(IconStore.choices, id: \.self) { sym in
                        Button {
                            DeviceImageStore.remove(device.id)
                            IconStore.set(sym, for: device.id)
                            version += 1
                            showIconPicker = false
                        } label: {
                            Image(systemName: sym)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(M3.onPrimaryContainer(scheme))
                                .frame(width: 64, height: 64)
                                .background(M3.primaryContainer(scheme))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Wybierz ikonę")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { showIconPicker = false } } }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Helpers

    private func applyPickedPhoto(_ old: PhotosPickerItem?, _ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                DeviceImageStore.save(img, for: device.id)
                IconStore.set("", for: device.id)
                await MainActor.run { version += 1; photoItem = nil }
            }
        }
    }

    private func actionButton(_ title: String, _ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: system).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(M3.onPrimaryContainer(scheme))
                    .frame(width: 48, height: 48)
                    .background(M3.primaryContainer(scheme)).clipShape(Circle())
                Text(title).font(.caption2).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .multilineTextAlignment(.center).lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12).padding(.horizontal, 6)
            .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func editRow(_ title: String, _ system: String, destructive: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, system, destructive: destructive) }.buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, _ system: String, destructive: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: system).frame(width: 24)
                .foregroundStyle(destructive ? Color.red : M3.primary(scheme))
            Text(title).foregroundStyle(destructive ? Color.red : M3.onSurface(scheme))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

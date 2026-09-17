// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit

/// Assigning a device to a place also arms its place alerts; clearing the last
/// place disarms them again. Shared by the place detail screen and its picker.
@MainActor
enum PlaceAssignment {
    static func name(of device: TrackerDevice) -> String {
        NameStore.name(for: device.id) ?? (device.name.isEmpty ? String(localized: "(bez nazwy)") : device.name)
    }

    static func set(_ assigned: Bool, device: TrackerDevice, place: UUID) {
        if assigned {
            // Assigning arms place alerts, which are useless without permission.
            Task { _ = await DeviceProtection.shared.requestNotifications() }
        }
        TrackerJournal.shared.updateDevice(device.id, name: name(of: device)) { rec in
            if assigned {
                rec.placeIDs.insert(place)
                rec.placeAlerts = true
                if rec.alertEnabledAt == .distantFuture { rec.alertEnabledAt = .now }
            } else {
                rec.placeIDs.remove(place)
                rec.boundaries.removeValue(forKey: place.uuidString)
                if rec.placeIDs.isEmpty { rec.placeAlerts = false }
            }
        }
    }

    /// A glyph that matches what the place is called, so the list reads at a glance.
    /// The user's own choice wins; otherwise guess from the name.
    static func symbol(for place: SavedPlace) -> String {
        if let chosen = place.symbol, !chosen.isEmpty { return chosen }
        return suggestedSymbol(named: place.name)
    }

    static func suggestedSymbol(named name: String) -> String {
        let n = name.lowercased()
        // Keywords cover every app language, since names are typed in the user's own.
        func has(_ words: [String]) -> Bool { words.contains { n.contains($0) } }
        if has(["dom", "home", "chata", "haus", "zuhause", "maison", "casa", "hogar"]) { return "house.fill" }
        if has(["prac", "biur", "work", "office", "arbeit", "büro", "buero", "travail", "bureau",
                "trabajo", "oficina", "lavoro", "ufficio"]) { return "briefcase.fill" }
        if has(["szkoł", "szkol", "uczel", "school", "schule", "universit", "école", "ecole", "lycée",
                "escuela", "colegio", "scuola"]) { return "graduationcap.fill" }
        if has(["garaż", "garaz", "garage", "parking", "auto", "coche", "parcheggio"]) { return "car.fill" }
        if has(["dzia", "ogró", "ogrod", "las", "garden", "garten", "wald", "jardin", "jardín", "forêt",
                "bosque", "giardino", "bosco", "park", "parc", "parque", "parco"]) { return "tree.fill" }
        return "mappin.and.ellipse"
    }
}

/// "Moje miejsca" tab, built like the devices tab: a full-bleed map of every
/// saved zone with a Material drawer over it. A place opens its own screen where
/// devices are added to or removed from that zone.
struct PlacesHomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var journal = TrackerJournal.shared
    @Environment(\.colorScheme) private var scheme

    private static let fallback = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),  // Warsaw
        span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6))

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(PlacesHomeView.fallback))
    @State private var followsOverview = true
    @State private var adding = false
    @State private var openedPlaceID: UUID?
    @State private var focusedPlaceID: UUID?
    @State private var expanded = false
    @State private var minimized = false
    @State private var mapSize: CGSize = .zero
    @State private var mapTopInset: CGFloat = 0
    @StateObject private var locationManager = LocationManager()

    private var places: [SavedPlace] { journal.document.places }

    private func devices(in place: SavedPlace) -> [TrackerDevice] {
        model.devices.filter { journal.device($0.id).placeIDs.contains(place.id) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                map
                    .ignoresSafeArea()
                    .onAppear { mapSize = geo.size; mapTopInset = geo.safeAreaInsets.top }
                    .onChange(of: geo.size) { mapSize = geo.size; mapTopInset = geo.safeAreaInsets.top }
                    .overlay(alignment: .topTrailing) { mapButtons }

                // The drawer runs to the screen edge behind the navigation bar; its
                // content is already padded by `bottomInset`, so nothing is hidden.
                drawer(available: geo.size.height, bottomInset: geo.safeAreaInsets.bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(M3.background(scheme).ignoresSafeArea())
        .navigationDestination(item: $openedPlaceID) { id in
            PlaceDetailView(model: model, placeID: id)
        }
        .sheet(isPresented: $adding) { PlaceEditor(place: nil) }
        .onAppear { locationManager.request() }
        .onDisappear { locationManager.stop() }
        .onChange(of: locationManager.location) { if followsOverview { showOverview() } }
        .onChange(of: places) { if followsOverview { showOverview() } }
        // The first frame arrives before the map knows its size; fit the zones as
        // soon as it does, otherwise the camera stays on the country-wide fallback.
        .onChange(of: mapSize) { if followsOverview { showOverview() } }
        .onChange(of: camera.positionedByUser) {
            if camera.positionedByUser { followsOverview = false; focusedPlaceID = nil }
        }
        .task { await model.loadDevices() }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera) {
            // Devices first, places on top: a tag parked inside its own zone must
            // not hide the pin that names the zone.
            ForEach(model.devices) { device in
                if let loc = model.locations[device.id] {
                    Annotation("", coordinate: loc.coordinate, anchor: .center) {
                        DeviceThumbnail(device: device, size: 28, iconOnly: true)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(M3.surface(scheme), lineWidth: 2))
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                }
            }
            ForEach(places) { place in
                MapCircle(center: place.coordinate, radius: place.radius)
                    .foregroundStyle(M3.primary(scheme).opacity(isFocused(place) ? 0.26 : 0.16))
                    .stroke(M3.primary(scheme).opacity(isFocused(place) ? 1 : 0.85),
                            lineWidth: isFocused(place) ? 3 : 2)
                // The marker stays small: a zone is often only a couple of hundred
                // metres across, and a large pin would swallow its circle.
                Annotation("", coordinate: place.coordinate, anchor: .bottom) {
                    placeMarker(place, active: isFocused(place))
                }
            }
        }
    }

    private func isFocused(_ place: SavedPlace) -> Bool { focusedPlaceID == place.id }

    /// A labelled pin whose tip sits on the zone centre, matching the cluster
    /// markers on the devices tab — and leaving the zone circle itself visible.
    private func placeMarker(_ place: SavedPlace, active: Bool) -> some View {
        let surface = active ? M3.primary(scheme) : M3.surface(scheme)
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: PlaceAssignment.symbol(for: place))
                    .font(.system(size: 12, weight: .semibold))
                Text(place.name).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(active ? M3.onPrimary(scheme) : M3.primary(scheme))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(surface, in: Capsule())
            .overlay(Capsule().stroke(M3.primary(scheme).opacity(active ? 0 : 0.5), lineWidth: 1))
            MapPinTip().fill(surface).frame(width: 12, height: 6)
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .onTapGesture { openedPlaceID = place.id }
        .accessibilityLabel("Miejsce \(place.name)")
    }

    private var mapButtons: some View {
        VStack(spacing: 10) {
            M3MapButton(system: "location.fill", label: "Pokaż moją lokalizację") {
                focusedPlaceID = nil
                followsOverview = false
                locationManager.request()
                if let fix = locationManager.location { centerInBand(fix.coordinate, meters: 700) }
            }
            M3MapButton(system: "viewfinder", label: "Pokaż wszystkie miejsca") {
                focusedPlaceID = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { minimized = true }
                showOverview()
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    private func focus(on place: SavedPlace) {
        followsOverview = false
        focusedPlaceID = place.id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded = false; minimized = true }
        // Frame the whole zone, with a margin so the circle is not cropped.
        centerInBand(place.coordinate, meters: max(place.radius * 3, 300))
    }

    /// Centre a close-up in the free band between the top bar and the drawer.
    private func centerInBand(_ coordinate: CLLocationCoordinate2D, meters: Double) {
        let size = mapSize == .zero ? CGSize(width: 400, height: 800) : mapSize
        let drawer = DrawerDetents.base(available: size.height, expanded: expanded, minimized: minimized)
        guard let rect = MapViewport.focusRect(on: coordinate, meters: meters, viewSize: size,
                                               topInset: mapTopInset + 52, bottomInset: drawer) else { return }
        withAnimation { camera = .rect(rect) }
    }

    /// Fit every saved zone (and the phone) into the band between the top bar and
    /// the drawer, exactly like the devices tab does for its markers.
    private func showOverview() {
        followsOverview = true
        var coordinates = places.map(\.coordinate)
        if let fix = locationManager.location { coordinates.append(fix.coordinate) }
        let size = mapSize == .zero ? CGSize(width: 400, height: 800) : mapSize
        let drawerHeight = DrawerDetents.base(available: size.height, expanded: false, minimized: minimized)
        guard let rect = MapViewport.overviewRect(for: coordinates, viewSize: size,
                            topInset: mapTopInset + 52, bottomInset: drawerHeight)
                ?? MapViewport.bounds(for: coordinates) else { return }
        withAnimation { camera = .rect(rect) }
    }

    // MARK: - Drawer

    private func drawer(available: CGFloat, bottomInset: CGFloat) -> some View {
        M3BottomDrawer(expanded: $expanded, minimized: $minimized,
                       availableHeight: available, bottomInset: bottomInset) {
            drawerHeader
        } content: {
            VStack(spacing: 8) {
                if places.isEmpty {
                    emptyState
                } else {
                    notificationStatus
                    ForEach(places) { place in placeCard(place) }
                    addButton.padding(.top, 4)
                }
                if let error = journal.storageError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }
            }
        }
    }

    private var drawerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Moje miejsca").font(.title3.bold()).foregroundStyle(M3.onSurface(scheme))
                Text(places.isEmpty ? String(localized: "Brak zapisanych obszarów")
                                    : String(localized: "\(places.count) miejsc"))
                    .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private func placeCard(_ place: SavedPlace) -> some View {
        let assigned = devices(in: place)
        return HStack(spacing: 14) {
            Button { openedPlaceID = place.id } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(M3.primaryContainer(scheme)).frame(width: 52, height: 52)
                        Image(systemName: PlaceAssignment.symbol(for: place))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(M3.onPrimaryContainer(scheme))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.body.weight(.medium)).foregroundStyle(M3.onSurface(scheme))
                        (Text("Promień \(Int(place.radius)) m") + Text(verbatim: " · ") + Text("\(assigned.count) urządzeń"))
                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                        if !assigned.isEmpty {
                            HStack(spacing: -6) {
                                ForEach(assigned.prefix(5)) { device in
                                    DeviceThumbnail(device: device, size: 22, iconOnly: true)
                                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(M3.background(scheme), lineWidth: 1.5))
                                }
                                if assigned.count > 5 {
                                    Text("+\(assigned.count - 5)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(M3.onSurfaceVariant(scheme))
                                        .padding(.leading, 10)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(M3.onSurfaceVariant(scheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            M3IconButton(system: "location.fill") { focus(on: place) }
                .accessibilityLabel("Pokaż \(place.name) na mapie")
        }
        .padding(10)
        .background(M3.background(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Only when alerts cannot reach the user; nothing is shown once allowed.
    private var notificationStatus: some View {
        NotificationPermissionCard()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.bottom, 4)
    }

    private var addButton: some View {
        Button { adding = true } label: {
            Label("Dodaj miejsce", systemImage: "plus")
        }
        .buttonStyle(M3FilledButtonStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 44)).foregroundStyle(M3.primary(scheme))
                .padding(.top, 12)
            Text("Brak zapisanych miejsc").font(.headline).foregroundStyle(M3.onSurface(scheme))
            Text("Zaznacz obszar domu, pracy lub innego miejsca, a potem przypisz do niego urządzenia — dostaniesz alert, gdy je opuszczą.")
                .font(.subheadline).foregroundStyle(M3.onSurfaceVariant(scheme))
                .multilineTextAlignment(.center).padding(.horizontal, 16)
            addButton.padding(.top, 4).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

}

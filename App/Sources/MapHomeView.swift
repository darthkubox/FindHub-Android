// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit

/// Find Hub–style home: a full map with a bottom panel listing your devices.
/// Map icons zoom to a device; at close range they open its details.
struct MapHomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journal = TrackerJournal.shared
    @Environment(\.colorScheme) private var scheme

    private static let fallback = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),  // Warsaw
        span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6))

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(MapHomeView.fallback))
    @State private var followsOverview = true
    @State private var pendingCenterOnUser = false
    @State private var mapDeviceID: String?
    @State private var visibleMapWidth = 5000.0
    @State private var visibleMapRect: MKMapRect?
    @State private var expanded = false
    @State private var minimized = false          // peek at the bottom, map exposed
    @State private var dragOffset: CGFloat = 0
    @State private var selectedDevice: TrackerDevice?
    @State private var mapSize: CGSize = .zero    // latest map view size, for overview framing
    @State private var mapTopInset: CGFloat = 0   // top safe area (status + nav bar), reserved when framing
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        GeometryReader { geo in
            let height = DrawerDetents.height(available: geo.size.height, expanded: expanded,
                                              minimized: minimized, drag: dragOffset,
                                              bottomInset: geo.safeAreaInsets.bottom)

            ZStack(alignment: .bottom) {
            Map(position: $camera) {
                ForEach(journal.document.places) { place in
                    MapCircle(center: place.coordinate, radius: place.radius)
                        .foregroundStyle(.green.opacity(0.08)).stroke(.green.opacity(0.5), lineWidth: 1)
                    Annotation(place.name, coordinate: place.coordinate) {
                        Text(place.name).font(.caption2.weight(.medium))
                            .padding(5).background(.regularMaterial, in: Capsule())
                    }
                }
                if settings.showAccuracy, let id = mapDeviceID, let loc = model.locations[id],
                   let accuracy = loc.accuracyMeters, accuracy > 0 {
                    MapCircle(center: loc.coordinate, radius: accuracy)
                        .foregroundStyle(M3.primary(scheme).opacity(0.15))
                        .stroke(M3.primary(scheme).opacity(0.45), lineWidth: 1)
                }
                ForEach(mapClusters(screenWidth: geo.size.width)) { cluster in
                    Annotation("", coordinate: cluster.coordinate, anchor: .bottom) {
                        MapClusterMarker(cluster: cluster, devices: model.devices, selectedDeviceID: mapDeviceID) { member in
                            switch member {
                            case .user:
                                mapDeviceID = nil
                                centerOnUser()
                            case .device(let id):
                                if let device = model.devices.first(where: { $0.id == id }) { selectMapDevice(device) }
                            }
                        }
                    }
                }
            }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleMapWidth = context.rect.width
                    visibleMapRect = context.rect
                }
                .ignoresSafeArea()
                .onAppear { mapSize = geo.size; mapTopInset = geo.safeAreaInsets.top }
                .onChange(of: geo.size) { mapSize = geo.size; mapTopInset = geo.safeAreaInsets.top }
                .overlay(alignment: .topTrailing) { mapButtons }

                // The panel itself ignores the bottom safe area so its surface runs all
                // the way to the screen edge (behind the opaque tab bar) — otherwise the
                // tab-bar inset is applied twice and leaves a black gap. Its content is
                // already padded by `bottomInset`, so nothing hides behind the tab bar.
                panel(height: height, bottomInset: geo.safeAreaInsets.bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .onChange(of: model.focusToken) {
            if followsOverview { showOverview() }
        }
        .onChange(of: model.mapFocusToken) {
            guard let id = model.pendingMapFocusID,
                  let device = model.devices.first(where: { $0.id == id }) else { return }
            showDeviceOnMap(device)
        }
        .onReceive(model.$locations) { locations in
            if let id = mapDeviceID, let position = locations[id] {
                centerOnDevice(position)
            } else if followsOverview {
                showOverview(locations: locations)
            }
        }
        .onChange(of: locationManager.location) {
            if pendingCenterOnUser { centerOnUser() }
            else if followsOverview { showOverview() }
        }
        .onChange(of: camera.positionedByUser) {
            if camera.positionedByUser {
                followsOverview = false
                pendingCenterOnUser = false
                mapDeviceID = nil
            }
        }
        .navigationDestination(item: $selectedDevice) { device in
            DeviceDetailView(model: model, device: device)
        }
        .task(id: model.hasE2EE) { await model.loadDevices(); await model.locateAll() }   // auto-load + auto-locate on launch
        .onAppear { locationManager.request() }
        .onDisappear { locationManager.stop() }
    }

    private func mapClusters(screenWidth: Double) -> [MapCluster] {
        var positions: [MapMarkerID: CLLocationCoordinate2D] = [:]
        for device in model.devices {
            if let location = model.locations[device.id] { positions[.device(device.id)] = location.coordinate }
        }
        if let user = locationManager.location { positions[.user] = user.coordinate }
        return MapClusters.make(positions: positions, visibleMapWidth: visibleMapWidth, screenWidth: screenWidth)
    }

    private var mapButtons: some View {
        VStack(spacing: 10) {
            M3MapButton(system: "location.fill", label: "Pokaż moją lokalizację") {
                mapDeviceID = nil
                followsOverview = false
                locationManager.request()
                pendingCenterOnUser = true
                centerOnUser()
            }
            M3MapButton(system: "viewfinder", label: "Pokaż mnie i wszystkie urządzenia") {
                mapDeviceID = nil
                pendingCenterOnUser = false
                locationManager.request()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { minimized = true }
                showOverview()
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    private func centerOnUser() {
        guard let position = locationManager.location else { return }
        pendingCenterOnUser = false
        followsOverview = false
        focus(on: position.coordinate, meters: 500)
    }

    private func selectMapDevice(_ device: TrackerDevice) {
        if let position = model.locations[device.id],
           MapViewport.isDeviceCloseUp(visibleMapRect, at: position.coordinate) {
            selectedDevice = device
        } else {
            showDeviceOnMap(device)
        }
    }

    private func showDeviceOnMap(_ device: TrackerDevice) {
        followsOverview = false
        pendingCenterOnUser = false
        mapDeviceID = device.id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            expanded = false
            minimized = true          // drop the drawer to a peek so the map is exposed
            dragOffset = 0
        }
        if let position = model.locations[device.id] {
            centerOnDevice(position)
        } else {
            Task { await model.locate(device) }
        }
    }

    private func centerOnDevice(_ position: DecryptedLocation) {
        focus(on: position.coordinate, meters: MapViewport.deviceFocusMeters)
    }

    /// Centre a close-up in the free band between the top bar and the drawer.
    private func focus(on coordinate: CLLocationCoordinate2D, meters: Double) {
        let size = mapSize == .zero ? CGSize(width: 400, height: 800) : mapSize
        let drawer = DrawerDetents.base(available: size.height, expanded: expanded, minimized: minimized)
        guard let rect = MapViewport.focusRect(on: coordinate, meters: meters, viewSize: size,
                                               topInset: mapTopInset + 52, bottomInset: drawer) else { return }
        withAnimation { camera = .rect(rect) }
    }

    private func showOverview(locations: [String: DecryptedLocation]? = nil) {
        followsOverview = true
        let positions = locations ?? model.locations
        var coordinates = model.devices.compactMap { positions[$0.id]?.coordinate }
        if let position = locationManager.location { coordinates.append(position.coordinate) }
        // Reserve the top bar and the visible drawer so devices land in the band
        // between them — never clipped at the top nor hidden behind the drawer.
        let size = mapSize == .zero ? CGSize(width: 400, height: 800) : mapSize
        let drawer = DrawerDetents.base(available: size.height, expanded: false, minimized: minimized)
        let top = mapTopInset + 52   // status bar + navigation bar
        guard let rect = MapViewport.overviewRect(for: coordinates, viewSize: size,
                            topInset: top, bottomInset: drawer)
                ?? MapViewport.bounds(for: coordinates) else { return }
        withAnimation { camera = .rect(rect) }
    }

    private func panel(height: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
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
                                    if minimized { minimized = false }
                                    else { expanded = true }
                                } else if dy > 40 {      // dragged down: expanded → collapsed → peek
                                    if expanded { expanded = false }
                                    else { minimized = true }
                                }
                                dragOffset = 0
                            }
                        }
                )

            HStack {
                Text("Twoje urządzenia").font(.title3.bold()).foregroundStyle(M3.onSurface(scheme))
                Spacer()
                Button { Task { await model.loadDevices(); await model.locateAll(force: true) } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(M3.onPrimaryContainer(scheme))
                        .frame(width: 36, height: 36).background(M3.primaryContainer(scheme)).clipShape(Circle())
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 8)

            nearbyRingButton
                .padding(.horizontal, 12).padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 8) {
                    if let message = locationManager.message {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(message, systemImage: "location.circle")
                                .font(.footnote)
                                .foregroundStyle(M3.onSurfaceVariant(scheme))
                            if locationManager.permissionDenied {
                                Button("Ustawienia lokalizacji") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .buttonStyle(M3TonalButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    }
                    if !model.hasE2EE { unlockBanner }
                    let close = model.devices.filter { journal.device($0.id).closeDevice }
                    if !close.isEmpty {
                        sectionHeader("Bliskie urządzenia")
                        ForEach(close) { device in row(device) }
                    }
                    let owned = model.devices.filter { !$0.sharedWithMe && !journal.device($0.id).closeDevice }
                    let shared = model.devices.filter { $0.sharedWithMe && !journal.device($0.id).closeDevice }
                    if !close.isEmpty && !owned.isEmpty { sectionHeader("Pozostałe urządzenia") }
                    ForEach(owned) { device in row(device) }
                    if !shared.isEmpty {
                        sectionHeader("Udostępnione Tobie")
                        ForEach(shared) { device in row(device) }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, bottomInset + 24)
            }
        }
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(M3.surface(scheme))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .background(alignment: .bottom) {
            M3.surface(scheme).frame(height: bottomInset + 60).ignoresSafeArea(edges: .bottom)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: -2)
    }

    private var nearbyRingButton: some View {
        Button { Task { await model.ringNearby() } } label: {
            HStack(spacing: 10) {
                if model.isRingingNearby {
                    ProgressView().tint(M3.onPrimaryContainer(scheme))
                } else {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                }
                Text(model.isRingingNearby ? "Szukam urządzenia…" : "Zadzwoń do najbliższego")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(M3TonalButtonStyle())
        .disabled(model.isRingingNearby)
        .accessibilityHint("Wysyła dźwięk do najbliższego lokalizatora przez Bluetooth.")
    }

    private var unlockBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Klucze E2EE zablokowane", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(M3.onSurface(scheme))
            Text("Odblokuj raz, by widzieć lokalizacje urządzeń.")
                .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
            Button("Odblokuj klucze E2EE") { model.showingVaultUnlock = true }
                .buttonStyle(M3TonalButtonStyle())
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.primaryContainer(scheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ device: TrackerDevice) -> some View {
        let display = NameStore.name(for: device.id) ?? (device.name.isEmpty ? "(bez nazwy)" : device.name)
        return HStack(spacing: 14) {
            Button { selectedDevice = device } label: {
                HStack(spacing: 14) {
                    DeviceThumbnail(device: device, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(display)
                            .font(.body.weight(.medium)).foregroundStyle(M3.onSurface(scheme))
                        rowSubtitle(device)
                            .font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            M3IconButton(system: "location.fill") {
                showDeviceOnMap(device)
            }
            .accessibilityLabel("Pokaż \(display) na mapie")
        }
        .padding(10)
        .background(M3.background(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(M3.onSurfaceVariant(scheme))
            Spacer()
        }
        .padding(.horizontal, 6).padding(.top, 10).padding(.bottom, 2)
    }

    /// Row subtitle: relative "seen" time when a fix exists, else the status message.
    @ViewBuilder private func rowSubtitle(_ device: TrackerDevice) -> some View {
        if device.sharedWithMe, let owner = device.ownerEmail {
            Text("Udostępnione przez \(owner)")
        } else if settings.showSeenTime, let location = model.locations[device.id], let seen = location.reportedAt {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text("Widziano " + LocationPresentation.relativeAge(seen))
            }
        } else {
            Text(model.locationMessages[device.id] ?? (model.locations[device.id] == nil ? "Brak odebranej pozycji" : "Pozycja na mapie"))
        }
    }
}

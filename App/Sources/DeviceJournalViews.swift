// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import MapKit
import CoreLocation

struct DeviceNoteCard: View {
    @ObservedObject private var journal = TrackerJournal.shared
    @Environment(\.colorScheme) private var scheme
    let deviceID: String
    let name: String
    @State private var text = ""
    @State private var dirty = false
    @State private var noteAccount: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notatka", systemImage: "note.text")
                .font(.subheadline.weight(.semibold)).foregroundStyle(M3.primary(scheme))
            TextField("Np. parking −2, sektor C4", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .foregroundStyle(M3.onSurface(scheme))
                .onChange(of: text) { dirty = text != journal.device(deviceID).note }
            HStack {
                Text("\(text.count)/4000").font(.caption).foregroundStyle(M3.onSurfaceVariant(scheme))
                Spacer()
                Button("Zapisz") { save() }.disabled(!dirty || text.count > 4000)
                    .tint(M3.primary(scheme))
            }
            if let error = journal.storageError { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(M3.outline(scheme).opacity(0.18), lineWidth: 1))
        .onAppear { noteAccount = journal.account; text = journal.device(deviceID).note }
        .onDisappear { if dirty && text.count <= 4000 { save() } }
    }

    private func save() {
        guard noteAccount == journal.account else { return }
        if journal.updateDevice(deviceID, name: name, { $0.note = text }) { dirty = false }
    }
}

struct DeviceHistoryView: View {
    @ObservedObject private var journal = TrackerJournal.shared
    @ObservedObject var model: AppModel
    let device: TrackerDevice
    @State private var range: HistoryRange = .day
    @State private var camera: MapCameraPosition = .automatic
    @State private var confirmClear = false

    private var points: [HistoryPoint] { journal.device(device.id).points(in: range) }
    private var segments: [[HistoryPoint]] { HistoryPath.segments(points) }
    private var visiblePoints: [HistoryPoint] {
        let all = points
        let stride = max(1, Int(ceil(Double(all.count) / 200)))
        return all.enumerated().compactMap { index, point in index % stride == 0 ? point : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Zakres historii", selection: $range) {
                ForEach(HistoryRange.allCases) { Text($0.label).tag($0) }
            }.pickerStyle(.segmented).padding()
            Map(position: $camera) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if segment.count > 1 {
                        MapPolyline(coordinates: segment.map(\.coordinate))
                            .stroke(.blue, style: StrokeStyle(lineWidth: 4, dash: [7, 4]))
                    }
                }
                ForEach(visiblePoints) { point in
                    Annotation("", coordinate: point.coordinate) {
                        Circle().fill(.blue).frame(width: 7, height: 7)
                            .accessibilityLabel(LocationPresentation.fullDate(point.time))
                    }
                }
                if let first = points.first {
                    Marker("Początek", systemImage: "flag", coordinate: first.coordinate).tint(.green)
                }
                if let last = points.last, points.count > 1 {
                    Marker("Ostatnio", systemImage: "mappin", coordinate: last.coordinate).tint(.blue)
                }
            }
            .overlay {
                if points.isEmpty {
                    ContentUnavailableView("Brak historii w tym okresie", systemImage: "clock.arrow.circlepath",
                        description: Text("Historia powstaje z odebranych lokalizacji. Otwórz aplikację lub odśwież pozycję, aby zapisać kolejne odczyty."))
                        .background(.regularMaterial)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(points.count) odczytów").font(.headline)
                    Spacer()
                    Button { Task { await model.locate(device) } } label: { Label("Odśwież", systemImage: "arrow.clockwise") }
                        .disabled(model.isLocating)
                }
                if let first = points.first, let last = points.last {
                    Text("\(LocationPresentation.fullDate(first.time)) — \(LocationPresentation.fullDate(last.time))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Linie łączą otrzymane pozycje, nie odtwarzają dokładnej drogi. Przerwy dłuższe niż godzinę są rozdzielone. Zapis obejmuje maksymalnie 7 dni; wcześniejsze odczyty nie są dostępne.")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = journal.storageError { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding().background(.background)
        }
        .navigationTitle("Historia i trasa")
        .clearsTabBar()
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: range) { frameHistory() }
        .onChange(of: points) { frameHistory() }
        .onAppear { frameHistory() }
        .toolbar {
            Button("Wyczyść", role: .destructive) { confirmClear = true }.disabled(points.isEmpty)
        }
        .confirmationDialog("Usunąć zapisaną historię tego urządzenia?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Usuń historię", role: .destructive) { journal.clearHistory(device.id) }
        }
    }

    private func frameHistory() {
        if let bounds = MapViewport.bounds(for: points.map(\.coordinate)) { camera = .rect(bounds) }
        else if let coordinate = model.locations[device.id]?.coordinate {
            camera = .region(.init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000))
        }
    }
}

struct DeviceProtectionView: View {
    @ObservedObject private var journal = TrackerJournal.shared
    @ObservedObject private var protection = DeviceProtection.shared
    @ObservedObject var model: AppModel
    let device: TrackerDevice
    @State private var requesting = false
    private var record: DeviceJournal { journal.device(device.id) }
    private var name: String { NameStore.name(for: device.id) ?? device.name }

    var body: some View {
        Form {
            Section {
                Toggle("Moje bliskie urządzenie", isOn: Binding(get: { record.closeDevice }, set: setClose))
                    .disabled(requesting || (device.encryptedIdentityKey == nil && !record.closeDevice))
                if device.encryptedIdentityKey == nil {
                    Text("Brak danych pozwalających potwierdzić tożsamość tego urządzenia przez Bluetooth.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if record.closeDevice {
                    Picker("Powiadom po utracie kontaktu", selection: Binding(get: { record.disconnectDelay }, set: { delay in
                        _ = journal.updateDevice(device.id, name: name) { $0.disconnectDelay = delay }
                    })) {
                        Text("30 sekund").tag(30.0)
                        Text("90 sekund").tag(90.0)
                        Text("3 minuty").tag(180.0)
                        Text("5 minut").tag(300.0)
                    }
                    Text(protection.deviceStatus[device.id] ?? String(localized: "Podejdź do urządzenia, aby rozpocząć pilnowanie."))
                        .font(.footnote)
                    Text(protection.bluetoothStatus).font(.caption).foregroundStyle(.secondary)
                }
            } header: { Text("Pilnowanie w pobliżu") } footer: {
                Text("Alert pojawi się po utracie potwierdzonego połączenia Bluetooth. Zasięg zależy od otoczenia — nie da się ustawić dokładnej odległości w metrach. Pierwsze połączenie wykonaj przy tagu. Nie wszystkie urządzenia obsługują stałe połączenie.")
            }

            Section {
                ForEach(journal.document.places) { place in
                    Toggle(place.name, isOn: Binding(get: { record.placeIDs.contains(place.id) }, set: { enabled in
                        _ = journal.updateDevice(device.id, name: name) {
                            if enabled { $0.placeIDs.insert(place.id) } else { $0.placeIDs.remove(place.id) }
                            $0.boundaries = [:]
                            $0.alertEnabledAt = .now
                        }
                    }))
                }
                NavigationLink("Dodaj lub edytuj miejsca") { SavedPlacesView() }
                Toggle("Powiadom po opuszczeniu miejsca", isOn: Binding(get: { record.placeAlerts }, set: setPlaceAlerts))
                    .disabled(record.placeIDs.isEmpty || requesting)
                if record.placeAlerts {
                    Text("Najpierw potrzebny jest nowy odczyt wewnątrz miejsca. Alert wyślę po dwóch kolejnych odczytach wyraźnie poza obszarem.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Miejsca tego urządzenia") } footer: {
                Text("Sprawdzam położenie przedmiotu z Google Find Hub. Odczyty mogą przychodzić z opóźnieniem; aplikacja nie uznaje wyjścia telefonu z domu za wyjście przedmiotu.")
            }

            Section("Powiadomienia i działanie w tle") {
                NotificationPermissionCard(showWhenAllowed: true)
                if let message = protection.notificationMessage, protection.notificationsAllowed {
                    Text(message).font(.footnote)
                }
                Text("Pilnowanie dotyczy aktywnego konta. iOS decyduje, kiedy odświeżyć pozycje w tle, więc alert miejsca może być opóźniony. Ręczne zamknięcie aplikacji może zatrzymać pilnowanie do ponownego otwarcia.")
                    .font(.footnote).foregroundStyle(.secondary)
                if UIApplication.shared.backgroundRefreshStatus != .available {
                    Text("Odświeżanie aplikacji w tle jest niedostępne. Pozycje będą sprawdzane po otwarciu aplikacji.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if let error = journal.storageError { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Pilnowanie urządzenia")
        .clearsTabBar()
        .navigationBarTitleDisplayMode(.inline)
        .task { await protection.refreshNotificationPermission() }
    }

    private func setClose(_ enabled: Bool) {
        guard enabled else {
            _ = journal.updateDevice(device.id, name: name) { $0.closeDevice = false; $0.connectionArmed = false }; return
        }
        guard model.hasE2EE else { model.showingVaultUnlock = true; return }
        requesting = true
        let account = journal.account
        Task {
            defer { requesting = false }
            guard await protection.requestNotifications(), journal.account == account else { return }
            _ = journal.updateDevice(device.id, name: name) {
                $0.closeDevice = true; $0.encryptedIdentityKey = device.encryptedIdentityKey
            }
        }
    }

    private func setPlaceAlerts(_ enabled: Bool) {
        guard enabled else {
            _ = journal.updateDevice(device.id, name: name) { $0.placeAlerts = false; $0.boundaries = [:] }; return
        }
        requesting = true
        let account = journal.account
        Task {
            defer { requesting = false }
            guard await protection.requestNotifications(), journal.account == account else { return }
            _ = journal.updateDevice(device.id, name: name) {
                $0.placeAlerts = true; $0.alertEnabledAt = .now; $0.boundaries = [:]
            }
            await model.locate(device)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

struct SavedPlacesView: View {
    @ObservedObject private var journal = TrackerJournal.shared
    @State private var editor: SavedPlace?
    @State private var adding = false
    var body: some View {
        List {
            Section {
                ForEach(journal.document.places) { place in
                    Button { editor = place } label: {
                        HStack {
                            Label(place.name, systemImage: "mappin.and.ellipse")
                            Spacer()
                            Text("\(Int(place.radius)) m").foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexes in
                    let places = indexes.map { journal.document.places[$0] }
                    for place in places { journal.deletePlace(place) }
                }
                Button { adding = true } label: { Label("Dodaj miejsce", systemImage: "plus") }
            } footer: { Text("Zaznacz obszar domu, pracy lub innego miejsca. Urządzenia przypiszesz w ich ustawieniach pilnowania.") }
            if let error = journal.storageError { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Dom i inne miejsca")
        .clearsTabBar()
        .sheet(item: $editor) { PlaceEditor(place: $0) }
        .sheet(isPresented: $adding) { PlaceEditor(place: nil) }
    }
}

struct PlaceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var journal = TrackerJournal.shared
    @StateObject private var location = LocationManager()
    @State private var draft: SavedPlace
    @State private var camera: MapCameraPosition
    @State private var pickedCenter: Bool
    @State private var address = ""
    @State private var resolvedAddress: String?
    @State private var searching = false
    @State private var searchError: String?
    private let geocoder = CLGeocoder()

    init(place: SavedPlace?) {
        let initial = place ?? SavedPlace(name: String(localized: "Dom"), latitude: 52.2297, longitude: 21.0122)
        _draft = State(initialValue: initial)
        _camera = State(initialValue: .region(.init(center: initial.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)))
        _pickedCenter = State(initialValue: place != nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                fieldLabel("Nazwa lokalizacji")
                TextField("np. Dom lub Praca", text: $draft.name).m3Field()

                fieldLabel("Ikona")
                symbolPicker

                fieldLabel("Adres")
                HStack(spacing: 8) {
                    TextField("Wpisz adres, np. Marszałkowska 1, Warszawa", text: $address)
                        .m3Field().submitLabel(.search)
                        .autocorrectionDisabled().onSubmit { search() }
                    Button { search() } label: {
                        if searching { ProgressView() } else { Image(systemName: "magnifyingglass") }
                    }
                    .buttonStyle(M3TonalButtonStyle())
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                }
                if let searchError { Text(searchError).font(.caption).foregroundStyle(.red) }

                Map(position: $camera) {
                    MapCircle(center: draft.coordinate, radius: draft.radius).foregroundStyle(.blue.opacity(0.15)).stroke(.blue, lineWidth: 2)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    draft.latitude = context.region.center.latitude; draft.longitude = context.region.center.longitude
                    reverseGeocode(context.region.center)
                }
                .overlay { Image(systemName: "plus").font(.title2.bold()).allowsHitTesting(false) }
                .overlay(alignment: .topTrailing) {
                    M3MapButton(system: "location.fill", label: "Pokaż moją lokalizację") {
                        location.request()
                        if let fix = location.location { center(on: fix.coordinate) }
                    }
                    .padding(12)
                }
                .overlay(alignment: .bottom) {
                    Button("Ustaw środek tutaj") { pickedCenter = true }.buttonStyle(M3TonalButtonStyle()).padding()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Label(resolvedAddress ?? String(localized: "Przesuń mapę i ustaw środek obszaru pod krzyżykiem."),
                          systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Promień: \(Int(draft.radius)) m")
                    Slider(value: $draft.radius, in: 50...2000, step: 50)
                    if let message = location.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    if let error = journal.storageError { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                M3SheetHeader(title: "Obszar miejsca", onClose: { dismiss() }) {
                    let canSave = draft.isValid && pickedCenter
                    Button {
                        if journal.savePlace(draft) {
                            // Places exist to raise alerts; ask while the intent is fresh.
                            Task { _ = await DeviceProtection.shared.requestNotifications() }
                            dismiss()
                        }
                    } label: {
                        Text("Zapisz").font(.subheadline.weight(.semibold))
                            .foregroundStyle(canSave ? M3.onPrimary(scheme) : M3.onSurfaceVariant(scheme))
                            .padding(.horizontal, 18).frame(height: 36)
                            .background(canSave ? M3.primary(scheme) : M3.surfaceVariant(scheme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
            }
            .background(M3.surface(scheme).ignoresSafeArea())
            .onChange(of: location.location) { if let fix = location.location { center(on: fix.coordinate) } }
            .onDisappear { location.stop(); geocoder.cancelGeocode() }
        }
        .presentationDetents([.large])
        .m3Sheet()
        .interactiveDismissDisabled()
        .tint(M3.primary(scheme))
    }

    /// Glyphs a place can wear. Until the user picks one, the guess from the name
    /// stays highlighted and keeps following the name as it is typed.
    static let symbolChoices: [String] = [
        "house.fill", "briefcase.fill", "building.2.fill", "graduationcap.fill", "car.fill",
        "tree.fill", "tent.fill", "mountain.2.fill", "beach.umbrella.fill", "cart.fill",
        "dumbbell.fill", "cross.case.fill", "fork.knife", "cup.and.saucer.fill", "figure.and.child.holdinghands",
        "pawprint.fill", "sailboat.fill", "airplane", "heart.fill", "star.fill", "mappin.and.ellipse",
    ]

    private var symbolPicker: some View {
        let current = PlaceAssignment.symbol(for: draft)
        return ScrollViewReader { proxy in ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.symbolChoices, id: \.self) { symbol in
                    let selected = symbol == current
                    Button { draft.symbol = symbol } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected ? M3.onPrimary(scheme) : M3.onPrimaryContainer(scheme))
                            .frame(width: 44, height: 44)
                            .background(selected ? M3.primary(scheme) : M3.primaryContainer(scheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .id(symbol)
                }
            }
            .padding(.vertical, 2)
        }
        .onAppear { proxy.scrollTo(current, anchor: .center) }
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func center(on coordinate: CLLocationCoordinate2D) {
        draft.latitude = coordinate.latitude; draft.longitude = coordinate.longitude; pickedCenter = true
        camera = .region(.init(center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
        location.stop()
        reverseGeocode(coordinate)
    }

    /// Geocode the typed address and centre the map there.
    private func search() {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searching = true; searchError = nil
        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(query) { placemarks, _ in
            Task { @MainActor in
                searching = false
                guard let placemark = placemarks?.first, let loc = placemark.location else {
                    searchError = String(localized: "Nie znaleziono adresu."); return
                }
                center(on: loc.coordinate)
                resolvedAddress = Self.format(placemark)
            }
        }
    }

    /// Show the address under the crosshair.
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) { placemarks, _ in
            Task { @MainActor in resolvedAddress = placemarks?.first.map(Self.format) }
        }
    }

    private static func format(_ p: CLPlacemark) -> String {
        var parts: [String] = []
        if let street = p.thoroughfare {
            parts.append(p.subThoroughfare.map { "\(street) \($0)" } ?? street)
        }
        if let city = p.locality { parts.append(city) }
        else if let area = p.administrativeArea { parts.append(area) }
        if parts.isEmpty, let name = p.name { parts.append(name) }
        return parts.joined(separator: ", ")
    }
}

/// Notification permission state with the one action that fixes it: ask when
/// iOS has not asked yet, or open the app's notification settings when denied.
struct NotificationPermissionCard: View {
    @ObservedObject private var protection = DeviceProtection.shared
    /// Also show a short confirmation when notifications are allowed.
    var showWhenAllowed = false
    /// Draw its own card (drawers); inside lists and cards it stays plain.
    var inCard = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            switch protection.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                if showWhenAllowed {
                    Label("Powiadomienia włączone", systemImage: "bell.badge.fill").foregroundStyle(.green)
                }
            case .denied:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Powiadomienia są wyłączone w ustawieniach iPhone’a — alerty nie przyjdą.",
                          systemImage: "bell.slash.fill").foregroundStyle(.orange)
                    Button("Otwórz ustawienia powiadomień") { Self.openSettings() }
                }
            default:
                VStack(alignment: .leading, spacing: 10) {
                    Label("Aby dostawać alerty, włącz powiadomienia.", systemImage: "bell.fill")
                    Button("Włącz powiadomienia") { Task { _ = await protection.requestNotifications() } }
                }
            }
        }
        .font(.footnote)
        .padding(.vertical, inCard ? 0 : 4)
        .modifier(CardIf(enabled: inCard && !allowed, scheme: scheme))
        .task { await protection.refreshNotificationPermission() }
    }

    private var allowed: Bool { [.authorized, .provisional, .ephemeral].contains(protection.authorizationStatus) }

    private struct CardIf: ViewModifier {
        let enabled: Bool
        let scheme: ColorScheme
        func body(content: Content) -> some View {
            if enabled {
                content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(M3.background(scheme), in: RoundedRectangle(cornerRadius: 16))
            } else { content }
        }
    }

    static func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }
}

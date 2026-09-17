// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Google profile photo with a monogram fallback when no photo is available.
struct AccountAvatar: View {
    let email: String?
    let scheme: ColorScheme
    var size: CGFloat = 32
    var photo: UIImage? = nil

    private var initial: String {
        guard let c = email?.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(c).uppercased()
    }
    private var tint: Color {
        let hue = Double(abs((email ?? "?").hashValue) % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: scheme == .dark ? 0.7 : 0.85)
    }

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Text(initial)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
            .accessibilityLabel("Konto: \(email ?? "brak")")
    }
}

/// Google-style account switcher sheet: big avatar + email up top, a card listing
/// the other signed-in accounts, then add-account / settings / sign-out actions.
struct AccountSheet: View {
    @ObservedObject var model: AppModel
    var onAddAccount: () -> Void
    var onSettings: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingLogout = false

    private var active: String { model.activeAccount ?? model.email ?? "—" }
    private var others: [String] { model.accounts.filter { $0 != active } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AccountAvatar(email: active, scheme: scheme, size: 76, photo: model.accountPhotos[active])
                    VStack(spacing: 2) {
                        Text(active).font(.headline).foregroundStyle(M3.onSurface(scheme))
                    }

                    Button { onSettings() } label: {
                        Text("Zarządzaj kontem")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 20).padding(.vertical, 9)
                            .overlay(Capsule().stroke(M3.outline(scheme), lineWidth: 1))
                    }
                    .tint(M3.primary(scheme))

                    if !others.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(others, id: \.self) { acc in
                                Button { Task { await model.switchAccount(acc); dismiss() } } label: {
                                    HStack(spacing: 14) {
                                        AccountAvatar(email: acc, scheme: scheme, size: 36, photo: model.accountPhotos[acc])
                                        Text(acc).foregroundStyle(M3.onSurface(scheme)).lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if acc != others.last { Divider().padding(.leading, 66) }
                            }
                        }
                        .background(M3.background(scheme), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 0) {
                        if !model.isDemo {
                            actionRow("Dodaj kolejne konto", "person.badge.plus") { onAddAccount() }
                            Divider().padding(.leading, 52)
                        }
                        actionRow("Ustawienia", "gearshape") { onSettings() }
                        Divider().padding(.leading, 52)
                        NavigationLink { LegalInfoView() } label: {
                            rowLabel("Informacje prawne i licencje", "doc.text", chevron: true)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        if model.isDemo {
                            actionRow("Zakończ tryb demo", "xmark.rectangle", destructive: true) {
                                model.exitDemo(); dismiss()
                            }
                        } else {
                            actionRow("Wyloguj się", "rectangle.portrait.and.arrow.right", destructive: true) {
                                confirmingLogout = true
                            }
                        }
                    }
                    .background(M3.background(scheme), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8).padding(.bottom, 24)
            }
            .m3SheetRoot("Konto Google") { dismiss() }
        }
        // Tall enough for every menu row, including sign-out, without scrolling.
        .presentationDetents([.fraction(0.72), .large])
        .alert("Czy na pewno chcesz się wylogować?", isPresented: $confirmingLogout) {
            Button("Wyloguj się", role: .destructive) { model.logout(); dismiss() }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Konto \(active) zostanie wylogowane z tego iPhone’a. Historia, notatki i miejsca zostaną zachowane.")
        }
    }

    private func actionRow(_ title: LocalizedStringKey, _ icon: String, destructive: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title, icon, destructive: destructive) }
            .buttonStyle(.plain)
    }

    private func rowLabel(_ title: LocalizedStringKey, _ icon: String, destructive: Bool = false, chevron: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 24)
                .foregroundStyle(destructive ? Color.red : M3.primary(scheme))
            Text(title).foregroundStyle(destructive ? Color.red : M3.onSurface(scheme))
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold)).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
    }
}

/// Privacy policy, terms of use, licences and publisher details in one place,
/// reachable from the account menu and from Settings.
struct LegalInfoView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        List {
            Group {
            Section {
                ForEach(LegalDocument.allCases) { document in
                    NavigationLink { LegalDocumentView(document: document) } label: {
                        Label(document.title, systemImage: document == .privacy ? "hand.raised" : "doc.plaintext")
                    }
                }
                NavigationLink { LicensesView() } label: {
                    Label("Licencje i kod źródłowy", systemImage: "doc.text")
                }
            } footer: {
                Text("FindHub Android to niezależna, nieoficjalna aplikacja wydawana przez mintstudio. Nie jest powiązana z Google, Motorola ani Apple. Find Hub i Android są znakami towarowymi Google LLC; nazwy służą wyłącznie opisaniu zgodności.")
            }
            Section("O aplikacji") {
                LabeledContent("Wydawca", value: LicensesView.publisher)
                if let contact = LicensesView.contactURL {
                    Link(destination: contact) {
                        Label(contact.absoluteString.replacingOccurrences(of: "mailto:", with: ""), systemImage: "envelope")
                    }
                }
                if let source = LicensesView.sourceCodeURL {
                    Link(destination: source) {
                        Label("Kod źródłowy na GitHubie", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            }
            .listRowBackground(M3.background(scheme))
        }
        .m3SheetList(scheme)
        .navigationTitle("Informacje prawne i licencje")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Basic settings: accounts, E2EE status, on-device privacy note, app version.
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings = AppSettings.shared
    var onAddAccount: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDeletion = false
    @State private var deleting = false
    @State private var testScheduled = false
    @State private var confirmingLogout = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Group {
                Section("Konta") {
                    ForEach(model.accounts, id: \.self) { acc in
                        Button {
                            Task { await model.switchAccount(acc); dismiss() }
                        } label: {
                            HStack(spacing: 12) {
                                AccountAvatar(email: acc, scheme: scheme, size: 30, photo: model.accountPhotos[acc])
                                Text(acc).foregroundStyle(M3.onSurface(scheme))
                                Spacer()
                                if acc == model.activeAccount {
                                    Image(systemName: "checkmark").foregroundStyle(M3.primary(scheme))
                                }
                            }
                        }
                    }
                    if model.isDemo {
                        Label("Tryb demonstracyjny — przykładowe dane", systemImage: "play.rectangle")
                    } else {
                        Button { onAddAccount() } label: {
                            Label("Dodaj konto", systemImage: "person.badge.plus")
                        }
                    }
                }

                Section {
                    NotificationPermissionCard(showWhenAllowed: true)
                    Toggle("Opuszczenie miejsca", isOn: $settings.notifyPlaceExit)
                    Toggle("Utrata kontaktu Bluetooth", isOn: $settings.notifySeparation)
                    Toggle("Nazwy urządzeń i miejsc w treści", isOn: $settings.notificationDetails)
                    Button {
                        Task { testScheduled = await DeviceProtection.shared.sendTestNotification() }
                    } label: {
                        Label("Wyślij powiadomienie testowe", systemImage: "paperplane")
                    }
                    if testScheduled {
                        Text("Powiadomienie pojawi się za 5 sekund — możesz zablokować telefon.")
                            .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                } header: {
                    Text("Powiadomienia")
                } footer: {
                    Text("Alert o opuszczeniu miejsca wysyłamy po dwóch świeżych raportach poza obszarem. Gdy aplikacja jest w tle, iOS sam decyduje, kiedy odświeżyć pozycje — zwykle nie częściej niż co kilkanaście minut. Nazwy w treści są widoczne na zablokowanym ekranie.")
                }

                Section("Miejsca") {
                    NavigationLink { SavedPlacesView() } label: {
                        Label("Dom, praca i inne obszary", systemImage: "mappin.and.ellipse")
                    }
                }

                // Settings lists use menu pickers (label left, value right), as iOS
                // Settings does; segmented controls are for switching views.
                Section("Wygląd") {
                    Picker(selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                    } label: {
                        Label("Motyw", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                    Picker(selection: $settings.useImperial) {
                        Text("Metryczne (km, m)").tag(false)
                        Text("Imperialne (mi, ft)").tag(true)
                    } label: {
                        Label("Jednostki", systemImage: "ruler")
                    }
                    .pickerStyle(.menu)
                }

                Section("Wyświetlanie") {
                    Toggle("Czas ostatniego raportu", isOn: $settings.showSeenTime)
                    Toggle("Dokładność i okrąg na mapie", isOn: $settings.showAccuracy)
                    Toggle("Odległość od Ciebie", isOn: $settings.showDistance)
                    Toggle("Współrzędne", isOn: $settings.showCoordinates)
                    Toggle("Nazwane miejsca", isOn: $settings.showNamedPlaces)
                    Toggle("Diagnostyka odczytu", isOn: $settings.showDiagnostics)
                }

                Section("Szyfrowanie (E2EE)") {
                    HStack {
                        Label("Klucze lokalizacji", systemImage: model.hasE2EE ? "lock.open.fill" : "lock.fill")
                        Spacer()
                        Text(model.hasE2EE ? "Odblokowane" : "Zablokowane")
                            .foregroundStyle(M3.onSurfaceVariant(scheme))
                    }
                    if !model.hasE2EE {
                        Button("Odblokuj klucze E2EE") {
                            dismiss(); model.showingVaultUnlock = true
                        }
                    }
                }

                Section("Prywatność") {
                    Label("Tokeny i klucze są w Keychain iPhone’a. mintstudio nie otrzymuje żadnych Twoich danych.",
                          systemImage: "iphone.gen3")
                        .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                }

                Section("Informacje prawne") {
                    ForEach(LegalDocument.allCases) { document in
                        NavigationLink { LegalDocumentView(document: document) } label: {
                            Label(document.title, systemImage: document == .privacy ? "hand.raised" : "doc.plaintext")
                        }
                    }
                    NavigationLink { LicensesView() } label: {
                        Label("Licencje i kod źródłowy", systemImage: "doc.text")
                    }
                }

                Section("O aplikacji") {
                    LabeledContent("Nazwa", value: "FindHub Android")
                    LabeledContent("Wersja", value: appVersion)
                    LabeledContent("Wydawca", value: LicensesView.publisher)
                    if let contact = LicensesView.contactURL {
                        Link(destination: contact) {
                            Label(contact.absoluteString.replacingOccurrences(of: "mailto:", with: ""), systemImage: "envelope")
                        }
                    }
                    if let source = LicensesView.sourceCodeURL {
                        Link(destination: source) {
                            Label("Kod źródłowy na GitHubie", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                }

                Section {
                    if model.isDemo {
                        Button(role: .destructive) { model.exitDemo(); dismiss() } label: {
                            Label { Text("Zakończ tryb demo") } icon: { Image(systemName: "xmark.rectangle") }
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button(role: .destructive) { confirmingLogout = true } label: {
                            Label { Text("Wyloguj bieżące konto") } icon: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                                .foregroundStyle(.red)
                        }
                        Button(role: .destructive) { confirmingDeletion = true } label: {
                            Label { Text("Usuń dane tego konta z telefonu") } icon: { Image(systemName: "trash") }
                                .foregroundStyle(.red)
                        }
                        .disabled(model.activeAccount == nil || deleting)
                    }
                } footer: {
                    Text("Wylogowanie zachowuje historię, notatki i miejsca na wypadek ponownego logowania. Usunięcie kasuje je trwale razem z nazwami, ikonami, zdjęciami, alertami i kluczami tego konta. Konto Google i dane na serwerach Google pozostają bez zmian.")
                }
                }
                .listRowBackground(M3.background(scheme))
            }
            .m3SheetList(scheme)
            .m3SheetRoot("Ustawienia") { dismiss() }
            .alert("Czy na pewno chcesz się wylogować?", isPresented: $confirmingLogout) {
                Button("Wyloguj się", role: .destructive) { model.logout(); dismiss() }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Konto \(model.activeAccount ?? "") zostanie wylogowane z tego iPhone’a. Historia, notatki i miejsca zostaną zachowane.")
            }
            .alert("Czy na pewno chcesz usunąć dane tego konta?", isPresented: $confirmingDeletion) {
                Button("Usuń trwale", role: .destructive) {
                    deleting = true
                    Task {
                        let removed = await model.deleteActiveAccountLocalData()
                        deleting = false
                        if removed { dismiss() }
                    }
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Z iPhone’a zostaną usunięte historia, notatki, miejsca, własne nazwy, ikony i zdjęcia urządzeń oraz klucze konta \(model.activeAccount ?? ""). Tej operacji nie można cofnąć.")
            }
        }
    }
}

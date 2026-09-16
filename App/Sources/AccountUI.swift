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

    private var active: String { model.activeAccount ?? model.email ?? "—" }
    private var others: [String] { model.accounts.filter { $0 != active } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("FindHub Android").font(.footnote.weight(.semibold))
                        .foregroundStyle(M3.onSurfaceVariant(scheme)).padding(.top, 6)

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
                        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }

                    VStack(spacing: 0) {
                        actionRow("Dodaj kolejne konto", "person.badge.plus") { onAddAccount() }
                        Divider().padding(.leading, 52)
                        actionRow("Ustawienia", "gearshape") { onSettings() }
                        Divider().padding(.leading, 52)
                        NavigationLink { LegalInfoView() } label: {
                            rowLabel("Informacje prawne i licencje", "doc.text", chevron: true)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        actionRow("Wyloguj się", "rectangle.portrait.and.arrow.right", destructive: true) {
                            model.logout(); dismiss()
                        }
                    }
                    .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                }
                .frame(maxWidth: .infinity)
            }
            .background(M3.background(scheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
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

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
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
                    Button { onAddAccount() } label: {
                        Label("Dodaj konto", systemImage: "person.badge.plus")
                    }
                }

                Section("Miejsca") {
                    NavigationLink { SavedPlacesView() } label: {
                        Label("Dom, praca i inne obszary", systemImage: "mappin.and.ellipse")
                    }
                }

                Section("Wygląd") {
                    Picker("Motyw", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Jednostki") {
                    Picker("Jednostki odległości", selection: $settings.useImperial) {
                        Text("Metryczne (km, m)").tag(false)
                        Text("Imperialne (mi, ft)").tag(true)
                    }
                    .pickerStyle(.segmented)
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
                    Button(role: .destructive) { model.logout(); dismiss() } label: {
                        Label("Wyloguj bieżące konto", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) { confirmingDeletion = true } label: {
                        Label("Usuń dane tego konta z telefonu", systemImage: "trash")
                    }
                    .disabled(model.activeAccount == nil || deleting)
                } footer: {
                    Text("Wylogowanie zachowuje historię, notatki i miejsca na wypadek ponownego logowania. Usunięcie kasuje je trwale razem z nazwami, ikonami, zdjęciami, alertami i kluczami tego konta. Konto Google i dane na serwerach Google pozostają bez zmian.")
                }
            }
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Usunąć dane konta \(model.activeAccount ?? "")?",
                                isPresented: $confirmingDeletion, titleVisibility: .visible) {
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
                Text("Historia, notatki, miejsca, własne nazwy, ikony i zdjęcia urządzeń oraz klucze tego konta zostaną usunięte z iPhone’a. Tej operacji nie można cofnąć.")
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } } }
        }
    }
}

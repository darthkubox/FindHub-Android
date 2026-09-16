// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingLogin = false
    @State private var showingSettings = false
    @State private var showingAccounts = false
    @State private var legalAccepted = LegalConsent.isAccepted
    @State private var tab: MainTab = .devices
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if model.loggedIn { mainTabs } else { loginStack }
        }
        .tint(M3.primary(scheme))
        .disclosureGroupStyle(UpDownDisclosureStyle())
        .sheet(isPresented: $showingAccounts) {
            AccountSheet(model: model,
                         onAddAccount: { showingAccounts = false; showingLogin = true },
                         onSettings: { showingAccounts = false; showingSettings = true })
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: model, onAddAccount: { showingSettings = false; showingLogin = true })
        }
        .sheet(isPresented: $showingLogin) {
            GoogleWebSheet(title: "Logowanie Google") {
                LoginWebView(
                    onToken: { token in
                        showingLogin = false
                        Task { await model.completeLogin(oauthToken: token) }
                    },
                    onError: { message in model.status = message; showingLogin = false })
            }
        }
        .sheet(isPresented: $model.showingVaultUnlock) {
            GoogleWebSheet(title: "Odblokowanie kluczy") {
                VaultUnlockWebView(
                    onVaultKeys: { keys in
                        model.showingVaultUnlock = false
                        Task { await model.unlockE2EE(vaultKeysJSON: keys) }
                    },
                    onError: { message in model.status = message; model.showingVaultUnlock = false })
            }
        }
        .fullScreenCover(isPresented: Binding(get: { model.loggedIn && !legalAccepted }, set: { _ in })) {
            // Signed-in users see updated terms again after a document version bump.
            NavigationStack {
                ZStack {
                    M3.background(scheme).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Spacer()
                        Text("Zaktualizowane dokumenty").font(.title2.bold()).foregroundStyle(M3.onSurface(scheme))
                        Text("Aby dalej korzystać z aplikacji, zapoznaj się z warunkami korzystania i polityką prywatności.")
                            .font(.subheadline).multilineTextAlignment(.center)
                            .foregroundStyle(M3.onSurfaceVariant(scheme)).padding(.horizontal, 24)
                        unofficialNotice
                        Spacer()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .interactiveDismissDisabled()
        }
        .task(id: model.activeAccount) { await model.refreshAccountPhotos() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            TrackerJournal.shared.activate(Session.shared.activeAccountID)
            await DeviceProtection.shared.refreshNotificationPermission()
            DeviceProtection.shared.configure()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(120)) } catch { return }
                await model.refreshJournalLocations()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background { GuardianBackground.schedule() }
        }
    }

    private var mainTabs: some View {
        MainTabsView(model: model, selection: $tab) { avatarToolbar }
    }

    private var loginStack: some View {
        NavigationStack {
            ZStack {
                M3.background(scheme).ignoresSafeArea()
                loginScreen
            }
            .navigationTitle("FindHub Android")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(M3.surface(scheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ToolbarContentBuilder private var avatarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingAccounts = true } label: {
                AccountAvatar(email: model.activeAccount ?? model.email, scheme: scheme,
                              photo: model.accountPhotos[model.activeAccount ?? ""])
            }
            .accessibilityLabel("Konto Google")
        }
    }

    private var loginScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(M3.primaryContainer(scheme)).frame(width: 112, height: 112)
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(M3.primary(scheme))
            }
            VStack(spacing: 6) {
                Text("FindHub Android").font(.largeTitle.bold()).foregroundStyle(M3.onSurface(scheme))
                Text("Odczyt lokalizatorów Find Hub")
                    .font(.subheadline).foregroundStyle(M3.onSurfaceVariant(scheme))
            }
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.footnote).foregroundStyle(M3.onSurfaceVariant(scheme))
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            if model.isBusy { ProgressView().tint(M3.primary(scheme)) }
            Spacer()
            unofficialNotice
            Button {
                showingLogin = true
            } label: {
                Label("Zaloguj się przez Google", systemImage: "person.badge.key.fill")
            }
            .buttonStyle(M3FilledButtonStyle())
            .disabled(model.isBusy || !legalAccepted)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    /// Shown before sign-in: the app is an unofficial client, and the terms and
    /// privacy policy must be accepted before any request reaches Google.
    private var unofficialNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Nieoficjalna aplikacja, niepowiązana z Google. Google może zmienić lub zablokować dostęp w każdej chwili, a korzystanie z nieoficjalnego klienta może naruszać warunki Google.")
            } icon: {
                Image(systemName: "exclamationmark.shield")
            }
            .font(.footnote)
            .foregroundStyle(M3.onSurfaceVariant(scheme))

            HStack(spacing: 16) {
                ForEach(LegalDocument.allCases) { document in
                    NavigationLink(document.title) { LegalDocumentView(document: document) }
                        .font(.footnote.weight(.medium))
                }
            }

            Toggle(isOn: Binding(get: { legalAccepted }, set: { accepted in
                if accepted { LegalConsent.accept() }
                legalAccepted = accepted && LegalConsent.isAccepted
            })) {
                Text("Akceptuję warunki korzystania i politykę prywatności")
                    .font(.footnote).foregroundStyle(M3.onSurface(scheme))
            }
            .disabled(legalAccepted)
        }
        .padding(16)
        .background(M3.surface(scheme), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }
}

/// The signed-in shell: the two home tabs under a Material navigation bar.
///
/// Deliberately not a `TabView`. With the system tab bar hidden, TabView stopped
/// following the selection binding — the bar highlighted one tab while the page
/// underneath stayed on the other, and tapping could not recover. Here `selection`
/// is the only source of truth. Both pages stay alive once visited, exactly as
/// TabView kept them, so navigation state and loaded devices survive a switch.
struct MainTabsView<Account: ToolbarContent>: View {
    @ObservedObject var model: AppModel
    @Binding var selection: MainTab
    @ToolbarContentBuilder var account: () -> Account
    @Environment(\.colorScheme) private var scheme

    @State private var visited: Set<MainTab> = []
    @State private var safeBottom: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                page(.devices)
                page(.places)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: M3TabBar.totalHeight(safeBottom: safeBottom))
            }

            M3TabBar(selection: $selection, safeBottom: safeBottom)
        }
        // The shell owns the bottom strip so the bar can paint the home-indicator
        // area; the pages get it back as the reserved inset above.
        .ignoresSafeArea(edges: .bottom)
        .onAppear { visited.insert(selection); safeBottom = ScreenInsets.bottom }
        .onChange(of: selection) { visited.insert(selection) }
        .tint(M3.primary(scheme))
    }

    /// A page is built on its first visit and then kept, hidden but intact.
    @ViewBuilder private func page(_ tab: MainTab) -> some View {
        if visited.contains(tab) {
            destination(tab)
                .opacity(selection == tab ? 1 : 0)
                .allowsHitTesting(selection == tab)
                .accessibilityHidden(selection != tab)
        }
    }

    @ViewBuilder private func destination(_ tab: MainTab) -> some View {
        switch tab {
        case .devices:
            NavigationStack {
                MapHomeView(model: model)
                    .navigationTitle("FindHub Android")
                    .modifier(HomeChrome(scheme: scheme))
                    .toolbar { account() }
            }
        case .places:
            NavigationStack {
                PlacesHomeView(model: model)
                    .navigationTitle("Moje miejsca")
                    .modifier(HomeChrome(scheme: scheme))
                    .toolbar { account() }
            }
        }
    }
}

/// Shared navigation-bar chrome for both home tabs.
private struct HomeChrome: ViewModifier {
    let scheme: ColorScheme
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(M3.surface(scheme), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// Reusable sheet wrapper for the Google WKWebView flows.
struct GoogleWebSheet<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            content
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anuluj") { dismiss() }
                    }
                }
        }
    }
}

#Preview { ContentView() }

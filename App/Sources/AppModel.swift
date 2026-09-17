// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import OSLog
import CoreLocation
import Network

private let locLog = Logger(subsystem: "pl.mintstudio.tagpin", category: "locate")

@MainActor
final class AppModel: ObservableObject {
    /// Per-device placeholder while a location request is in flight; compared by value.
    private static let waitingForPosition = String(localized: "Czekam na pozycję…")
    static let shared = AppModel()
    @Published var loggedIn: Bool
    @Published var email: String?
    @Published var accounts: [String] = []
    @Published private(set) var accountPhotos: [String: UIImage] = [:]
    @Published var devices: [TrackerDevice] = []
    @Published var status: String = ""
    @Published var isBusy = false
    @Published private(set) var isLocating = false
    @Published var isRingingNearby = false
    @Published var hasE2EE: Bool
    @Published var showingVaultUnlock = false
    /// Problem or confirmation shown on the signed-in screens.
    @Published var issue: AppIssue?
    /// True once the device list was fetched for the active account.
    @Published private(set) var devicesLoaded = false
    /// Incremented to ask the shell to present Google sign-in again.
    @Published private(set) var signInRequest = 0
    @Published private(set) var isOnline = true
    /// Sample data from `DemoData`; nothing reaches Google or a tracker.
    @Published private(set) var isDemo = false
    /// Decrypted positions by device id, and the coordinate to center the map on.
    @Published var locations: [String: DecryptedLocation] = [:]
    @Published private(set) var locationMessages: [String: String] = [:]
    @Published private(set) var namedLocations: [String: NamedLocationReport] = [:]
    @Published private(set) var locationDiagnostics: [String: String] = [:]
    @Published var focus: CLLocationCoordinate2D?
    @Published var focusToken = 0
    /// Set by the detail screen's "Zlokalizuj" to ask the map to pop to front,
    /// collapse the device drawer and show this device. MapHomeView observes the token.
    @Published var pendingMapFocusID: String?
    @Published var mapFocusToken = 0

    func focusOnMap(_ id: String) {
        pendingMapFocusID = id
        mapFocusToken += 1
    }

    private var locationTask: Task<Void, Never>?
    private var nearbyTask: Task<Data, Error>?
    private var lookupID = UUID()
    private var sessionID = UUID()
    private var didAutoLocate = false
    private let pathMonitor = NWPathMonitor()
    private var issueDismissal: Task<Void, Never>?

    init() {
        loggedIn = Session.shared.isLoggedIn
        email = Session.shared.email
        hasE2EE = Session.shared.hasE2EE
        accounts = Session.shared.accounts
        reloadAccountPhotos()
        // A demo interrupted by quitting the app leaves its sample file behind.
        TrackerJournal.shared.activate(DemoData.account)
        _ = try? TrackerJournal.shared.deleteActiveAccountData()
        TrackerJournal.shared.activate(Session.shared.activeAccountID)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "pl.mintstudio.tagpin.network"))
    }

    // MARK: - Issues

    func show(_ newIssue: AppIssue) {
        issueDismissal?.cancel()
        issue = newIssue
        if newIssue.isConfirmation {
            issueDismissal = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, self?.issue == newIssue else { return }
                self?.issue = nil
            }
        }
    }

    func dismissIssue() { issueDismissal?.cancel(); issue = nil }

    /// Runs the action offered with the current issue.
    func resolveIssue() {
        guard let current = issue else { return }
        dismissIssue()
        switch current.action {
        case .signInAgain: signInRequest += 1
        case .unlockKeys: showingVaultUnlock = true
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .retry:
            Task {
                switch current.context {
                case .devices: await loadDevices(); await locateAll(force: true)
                case .locations: await locateAll(force: true)
                case .unlock: showingVaultUnlock = true
                case .ring: await ringNearby()
                }
            }
        case .none: break
        }
    }

    private func clearIssue(for contexts: Set<AppIssue.Context>) {
        if let current = issue, !current.isConfirmation, contexts.contains(current.context) { dismissIssue() }
    }

    /// The journal account the app should use right now (demo or signed-in).
    var journalAccount: String? { isDemo ? DemoData.account : Session.shared.activeAccountID }

    // MARK: - Demo mode

    func startDemo() {
        cancelAccountWork()
        isDemo = true
        let journal = TrackerJournal.shared
        journal.activate(DemoData.account)
        _ = try? journal.deleteActiveAccountData()          // start from a clean sample
        journal.activate(DemoData.account)
        DemoData.seed(journal)
        email = String(localized: "Konto demonstracyjne")
        accounts = []
        hasE2EE = true
        devices = DemoData.devices()
        devicesLoaded = true
        locations = DemoData.locations()
        locationMessages = [:]; namedLocations = [:]; locationDiagnostics = [:]
        dismissIssue()
        status = ""
        loggedIn = true
        focus = nil; focusToken += 1
    }

    /// Leaves the demo and removes everything it stored on the phone.
    func exitDemo() {
        guard isDemo else { return }
        cancelAccountWork()
        let ids = Set(DemoData.devices().map(\.id))
        let journal = TrackerJournal.shared
        journal.activate(DemoData.account)
        _ = try? journal.deleteActiveAccountData()
        NameStore.remove(ids); IconStore.remove(ids); ids.forEach(DeviceImageStore.remove)
        Task { await DeviceProtection.shared.removeNotifications(for: DemoData.account) }
        isDemo = false
        resetAccountState()
        loggedIn = Session.shared.isLoggedIn
        hasE2EE = Session.shared.hasE2EE
    }

    /// A pretend refresh: fresh timestamps after a short wait, no network.
    private func refreshDemo(_ requested: [TrackerDevice]) async {
        isLocating = true
        for device in requested { locationMessages[device.id] = Self.waitingForPosition }
        try? await Task.sleep(for: .milliseconds(1200))
        guard isDemo else { return }
        let fresh = DemoData.locations()
        for device in requested {
            locations[device.id] = fresh[device.id]
            locationMessages[device.id] = String(localized: "Pozycja na mapie")
        }
        isLocating = false
        focusToken += 1
    }

    private func networkChanged(online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        guard loggedIn, !isDemo else { return }
        if !online {
            show(.offline())
        } else if issue?.kind == .offline || issue?.kind == .googleUnreachable {
            dismissIssue()
            Task { await loadDevices(); await locateAll(force: true) }
        }
    }

    private func reloadAccountPhotos() {
        accountPhotos = Dictionary(uniqueKeysWithValues: accounts.compactMap { account in
            guard let data = Session.shared.avatar(for: account), let image = UIImage(data: data) else { return nil }
            return (account, image)
        })
    }

    /// Independent of device loading; existing accounts need no new web login.
    func refreshAccountPhotos() async {
        guard !isDemo else { return }
        let session = sessionID
        let ordered = accounts.sorted { $0 == activeAccount && $1 != activeAccount }
        for account in ordered {
            guard !Task.isCancelled, session == sessionID else { return }
            guard let credentials = Session.shared.profileCredentials(for: account) else { continue }
            do {
                let data = try await GoogleAuth.accountPhoto(email: account, masterToken: credentials.master,
                                                            androidID: credentials.androidID)
                guard !Task.isCancelled, session == sessionID,
                      Session.shared.profileCredentials(for: account)?.master == credentials.master else { return }
                if let data {
                    guard let image = UIImage(data: data),
                          let thumbnail = image.preparingThumbnail(of: CGSize(width: 192, height: 192)),
                          let jpeg = thumbnail.jpegData(compressionQuality: 0.85) else { continue }
                    Session.shared.storeAvatar(jpeg, for: account)
                    accountPhotos[account] = thumbnail
                } else {
                    Session.shared.storeAvatar(nil, for: account)
                    accountPhotos.removeValue(forKey: account)
                }
            } catch {
                // Keep the cached photo (or monogram) on temporary network/auth failure.
                // Never expose profile responses or credentials in device status/logs.
            }
        }
    }

    /// The currently active account email.
    var activeAccount: String? { Session.shared.activeAccountID }

    /// Switch to another already-signed-in account: reset per-account UI state,
    /// then reload its devices and positions.
    func switchAccount(_ accountEmail: String) async {
        guard accountEmail.lowercased() != Session.shared.activeAccountID else { return }
        sessionID = UUID()
        lookupID = UUID()
        locationTask?.cancel(); locationTask = nil
        nearbyTask?.cancel(); nearbyTask = nil
        Session.shared.switchTo(accountEmail)
        resetAccountState()
        loggedIn = Session.shared.isLoggedIn
        await loadDevices()
        await locateAll()
    }

    /// Clear all in-memory per-account UI state (positions, messages, flags).
    private func resetAccountState() {
        email = Session.shared.email
        accounts = Session.shared.accounts
        reloadAccountPhotos()
        TrackerJournal.shared.activate(journalAccount)
        hasE2EE = Session.shared.hasE2EE
        devices = []
        locations = [:]
        locationMessages = [:]
        namedLocations = [:]
        locationDiagnostics = [:]
        focus = nil; focusToken += 1
        didAutoLocate = false
        devicesLoaded = false
        dismissIssue()
        isRingingNearby = false
        isLocating = false
        isBusy = false
        status = ""
    }

    /// Full M1+M2 flow: checkin → exchange oauth_token → store → list devices.
    func completeLogin(oauthToken: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            status = String(localized: "Rejestracja urządzenia (checkin)…")
            let (aid, stok) = try await GoogleAuth.checkin()

            status = String(localized: "Wymiana tokenu konta…")
            let (master, mail) = try await GoogleAuth.exchangeToken(oauthToken: oauthToken, androidID: aid)
            Session.shared.store(masterToken: master, email: mail, androidID: aid, securityToken: stok)

            resetAccountState()          // clear any previous account's positions/state
            loggedIn = true
            await loadDevices()
            await locateAll()
        } catch {
            status = String(localized: "Błąd logowania: \(error.localizedDescription)")
        }
    }

    func loadDevices() async {
        if isDemo { devicesLoaded = true; return }
        guard Session.shared.masterToken != nil else { status = String(localized: "Niezalogowano."); return }
        let session = sessionID
        isBusy = true
        defer { if session == sessionID { isBusy = false } }
        do {
            let adm = try await currentAdmToken()
            guard session == sessionID else { return }
            status = String(localized: "Pobieranie listy urządzeń…")
            let list = try await Nova.listDevices(admToken: adm)
            guard session == sessionID else { return }
            devices = list
            devicesLoaded = true
            clearIssue(for: [.devices])
            status = list.isEmpty ? String(localized: "Brak urządzeń na koncie.") : String(localized: "Znaleziono \(list.count) urządzeń.")
        } catch {
            guard session == sessionID else { return }
            status = String(localized: "Błąd listy: \(error.localizedDescription)")
            show(.from(error, context: .devices))
        }
    }

    /// Periodic history collection yields to explicit user operations.
    func refreshJournalLocations() async {
        guard !isDemo else { return }
        guard loggedIn, hasE2EE, !isBusy, !isLocating else { return }
        let session = sessionID
        if devices.isEmpty { await loadDevices() }
        guard !Task.isCancelled, session == sessionID, !isBusy, !isLocating else { return }
        await locateAll(force: true)
    }

    // MARK: - E2EE (M4)

    /// Turn captured vault keys into the account owner key for location decryption.
    func unlockE2EE(vaultKeysJSON: String) async {
        let session = sessionID
        isBusy = true
        defer { if session == sessionID { isBusy = false } }
        do {
            status = String(localized: "Przetwarzanie kluczy skarbca…")
            let shared = try FMDNCrypto.fmdnSharedKey(fromVaultKeysJSON: vaultKeysJSON)
            Session.shared.sharedKey = shared

            guard let master = Session.shared.masterToken else { throw NovaError.http(401) }
            let androidID = try await ensureAndroidID()
            status = String(localized: "Autoryzacja Spot…")
            let spot = try await GoogleAuth.spotToken(
                email: Session.shared.email ?? "", masterToken: master, androidID: androidID)

            guard session == sessionID else { return }
            status = String(localized: "Pobieranie owner key…")
            let encOwner = try await SpotClient.encryptedOwnerKey(spotToken: spot)
            guard session == sessionID else { return }
            let owner = try FMDNCrypto.decryptOwnerKey(sharedKey: shared, encryptedOwnerKey: encOwner)
            Session.shared.ownerKey = owner
            hasE2EE = true
            status = String(localized: "Klucze E2EE odblokowane ✅")
            clearIssue(for: [.unlock])
        } catch {
            guard session == sessionID else { return }
            status = String(localized: "Błąd odblokowania: \(error.localizedDescription)")
            show(.from(error, context: .unlock))
        }
    }

    /// Ring the nearest tracker over Bluetooth via the unauthenticated DULT sound
    /// command (no owner keys, no E2EE needed). Hold the tag you want near the phone.
    func ringNearby() async {
        if isDemo { show(.demoRing()); return }
        guard !isRingingNearby else { return }
        let session = sessionID
        isRingingNearby = true
        defer {
            if session == sessionID { isRingingNearby = false; nearbyTask = nil }
        }
        let task = Task {
            try await BleRing.ring(onProgress: { [weak self] msg in
                guard let self, self.sessionID == session else { return }
                self.status = msg
            })
        }
        nearbyTask = task
        do {
            status = String(localized: "Szukam najbliższego tagu po Bluetooth…")
            _ = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            guard session == sessionID else { return }
            status = String(localized: "Wysłano komendę dźwięku do najbliższego tagu.")
            show(.ringSent())
        } catch is CancellationError {
        } catch {
            guard session == sessionID else { return }
            status = String(localized: "BLE: \(error.localizedDescription)")
            show(.from(error, context: .ring))
        }
    }

    /// Manual requests replace the current batch, keeping one MCS connection active.
    func locate(_ device: TrackerDevice) async {
        if isDemo { await refreshDemo([device]); return }
        guard Session.shared.masterToken != nil else { status = String(localized: "Niezalogowano."); return }
        guard Session.shared.ownerKey != nil else {
            status = String(localized: "Najpierw odblokuj klucze E2EE.")
            showingVaultUnlock = true
            return
        }
        await startLocationLookup([device], focusDeviceID: device.id)
    }

    func locateAll(force: Bool = false) async {
        if isDemo { if force { await refreshDemo(devices) }; return }
        guard force || !didAutoLocate else { return }
        guard !isLocating || force, !devices.isEmpty,
              Session.shared.masterToken != nil, Session.shared.ownerKey != nil else { return }
        await startLocationLookup(devices, focusDeviceID: nil)
    }

    private func startLocationLookup(_ requested: [TrackerDevice], focusDeviceID: String?) async {
        let previous = locationTask
        previous?.cancel()
        for device in devices where locationMessages[device.id] == Self.waitingForPosition {
            locationMessages[device.id] = locations[device.id] == nil ? String(localized: "Pobieranie przerwane") : String(localized: "Ostatnia pozycja na mapie")
        }
        let id = UUID()
        lookupID = id
        await previous?.value
        guard lookupID == id else { return }
        guard !Task.isCancelled else {
            isLocating = false
            locationTask = nil
            return
        }
        if focusDeviceID == nil { didAutoLocate = false }
        isLocating = true
        let task = Task { await self.lookupLocations(requested, focusDeviceID: focusDeviceID, id: id) }
        locationTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if lookupID == id {
            isLocating = false
            locationTask = nil
        }
    }

    private func lookupLocations(_ requested: [TrackerDevice], focusDeviceID: String?, id: UUID) async {
        guard let ownerKey = Session.shared.ownerKey else { return }
        let account = Session.shared.activeAccountID
        let sharedKey = Session.shared.sharedKey
        let requests = Dictionary(requested.map { ($0.id, UUID().uuidString) }, uniquingKeysWith: { first, _ in first })
        for device in requested { locationMessages[device.id] = Self.waitingForPosition }
        var received = Set<String>()
        var sendFailures = Set<String>()
        var lastSendError: Error?
        var decodeFailures = 0
        do {
            let creds = try await FcmRegister.ensureRegistered()
            try Task.checkCancellation()
            let adm = try await currentAdmToken()
            try Task.checkCancellation()
            guard lookupID == id else { return }
            let mcs = McsClient(androidID: creds.androidID, securityToken: creds.securityToken)
            let waiter = CallbackWaiter<Void>()
            var sender: Task<Void, Never>?
            defer { sender?.cancel(); mcs.stop() }
            mcs.onError = { waiter.resolve(.failure($0)) }
            mcs.onDataMessage = { [weak self] stanza in
                guard let self, self.lookupID == id, !waiter.isFinished,
                      Session.shared.activeAccountID == account, TrackerJournal.shared.account == account else { return }
                do {
                    let update = try LocationDecrypt.decodeUpdate(stanza: stanza, creds: creds)
                    guard let deviceID = requests.first(where: { $0.value == update.fcmMetadata.requestUuid })?.key,
                          LocationDecrypt.deviceIDs(in: update).contains(deviceID) else { return }
                    do {
                        let report = try LocationDecrypt.decrypt(update: update, ownerKey: ownerKey, sharedKey: sharedKey)
                        guard report.matches(deviceID: deviceID, requestID: requests[deviceID]!) else { return }
                        let name = NameStore.name(for: deviceID) ?? requested.first(where: { $0.id == deviceID })?.name ?? String(localized: "Urządzenie")
                        let events = TrackerJournal.shared.ingest(report.locations, deviceID: deviceID, name: name)
                        DeviceProtection.shared.deliver(events)
                        self.locationDiagnostics[deviceID] = report.diagnosticSummary
                        self.saveRedactedLocationDiagnostics()
                        if let named = report.semanticLocations.first,
                           self.namedLocations[deviceID].map({ $0.time <= named.time }) ?? true {
                            self.namedLocations[deviceID] = named
                        }
                        guard let best = report.locations.first else {
                            if !received.contains(deviceID) {
                                self.locationMessages[deviceID] = report.locationIssue ?? String(localized: "Raport bez współrzędnych")
                            }
                            return // Metadata-only responses may be followed by an actual fix.
                        }
                        received.insert(deviceID)
                        if self.locations[deviceID].map({ $0.time <= best.time }) ?? true {
                            self.locations[deviceID] = best
                        }
                        self.locationMessages[deviceID] = String(localized: "Pozycja na mapie")
                        if focusDeviceID == deviceID || self.focus == nil {
                            self.focus = self.locations[deviceID]?.coordinate
                            self.focusToken += 1
                        }
                        if received.union(sendFailures).count == requests.count { waiter.resolve(.success(())) }
                    } catch {
                        decodeFailures += 1
                        self.locationMessages[deviceID] = String(localized: "Błąd pozycji: \(error.localizedDescription)")
                    }
                } catch {
                    // Cannot attribute an undecodable push to any device.
                    decodeFailures += 1
                }
            }

            try await waiter.wait(timeout: 45, timeoutError: McsError.timeout) {
                sender = Task {
                    do {
                        self.status = String(localized: "Łączę z kanałem lokalizacji…")
                        try await mcs.connectAndLogin()
                        try Task.checkCancellation()
                        guard self.lookupID == id, !waiter.isFinished else { return }
                        self.status = String(localized: "Pobieram lokalizacje urządzeń…")
                        for device in requested {
                            try Task.checkCancellation()
                            guard !waiter.isFinished else { return }
                            do {
                                try await Nova.sendLocate(canonicId: device.id, fcmToken: creds.fcmToken,
                                                          requestUuid: requests[device.id]!, admToken: adm)
                            } catch {
                                try Task.checkCancellation()
                                sendFailures.insert(device.id)
                                lastSendError = error
                                self.locationMessages[device.id] = String(localized: "Nie udało się wysłać żądania pozycji")
                            }
                            if received.union(sendFailures).count == requests.count {
                                waiter.resolve(.success(()))
                                return
                            }
                            try await Task.sleep(nanoseconds: 300_000_000)
                        }
                    } catch { waiter.resolve(.failure(error)) }
                }
            }
            try Task.checkCancellation()
            guard lookupID == id else { return }
            if focusDeviceID == nil { didAutoLocate = received.count == requests.count }
            status = String(localized: "Odebrano lokalizacje: \(received.count)/\(requests.count).")
            if !sendFailures.isEmpty { status += " " + String(localized: "Nie wysłano żądań: \(sendFailures.count).") }
            if received.isEmpty, let lastSendError {
                show(.from(lastSendError, context: .locations))
            } else {
                clearIssue(for: [.locations, .devices])
            }
        } catch is CancellationError {
            if lookupID == id {
                for device in requested where locationMessages[device.id] == Self.waitingForPosition {
                    locationMessages[device.id] = locations[device.id] == nil ? String(localized: "Pobieranie przerwane") : String(localized: "Ostatnia pozycja na mapie")
                }
            }
        } catch {
            guard lookupID == id, !Task.isCancelled else { return }
            for device in requested where locationMessages[device.id] == Self.waitingForPosition {
                locationMessages[device.id] = locations[device.id] == nil ? String(localized: "Brak odpowiedzi z pozycją") : String(localized: "Ostatnia pozycja na mapie")
            }
            status = String(localized: "Odebrano lokalizacje: \(received.count)/\(requests.count). \(error.localizedDescription)")
            if received.isEmpty {
                if case McsError.timeout = error {
                    // Silence from Google usually means no fresh reports, not a broken link.
                    show(AppIssue(kind: .failed(.locations), context: .locations,
                                  title: String(localized: "Brak nowych raportów lokalizacji"),
                                  message: String(localized: "Google nie przesłał pozycji na czas. Tag mógł nie być ostatnio w pobliżu innych urządzeń — pokazuję ostatnie znane pozycje."),
                                  action: .retry))
                } else {
                    show(.from(error, context: .locations))
                }
            }
            if decodeFailures > 0 { status += " " + String(localized: "Część raportów nie dała się odczytać.") }
        }
    }

    /// Expected 10-byte EID prefixes a tag would advertise now, so the BLE finder
    /// can recognize *this* device. Covers a ±2 h window (clock skew) plus the
    /// static EID (DIY beacons). Empty if E2EE keys are missing → finder falls
    /// back to "nearest tag".
    func expectedEIDPrefixes(for device: TrackerDevice) -> Set<Data> {
        guard let ownerKey = Session.shared.ownerKey,
              let encEIK = device.encryptedIdentityKey else { return [] }
        let keys = FMDNCrypto.identityKeyCandidates(
            ownerKey: ownerKey, sharedKey: Session.shared.sharedKey,
            encryptedEIK: encEIK, deviceIDs: [device.id], isMCU: false)
        guard !keys.isEmpty else { return [] }
        let now = UInt32(Date().timeIntervalSince1970)
        let period: UInt32 = 1024
        let base = now - (now % period)
        var counters: [UInt32] = [0]   // static EID (DIY firmware)
        for step in -7...7 {
            let c = Int64(base) + Int64(step) * Int64(period)
            if c >= 0 { counters.append(UInt32(c)) }
        }
        var prefixes = Set<Data>()
        for key in keys {
            for c in counters {
                if let eid = ForeignTrackerCryptor.eid(identityKey: key, timeCounter: c) {
                    prefixes.insert(eid.prefix(10))
                }
            }
        }
        return prefixes
    }

    /// Sign out the active account. If another account remains, switch to it and
    /// stay signed in; otherwise return to the login screen.
    func logout() {
        if isDemo { exitDemo(); return }
        cancelAccountWork()
        saveRedactedLocationDiagnostics()
        TrackerJournal.shared.stopProtectionForLogout()
        finishSignOut(status: String(localized: "Wylogowano."))
    }

    /// Signs out the active account and permanently removes what the app keeps
    /// for it on this iPhone: history, notes, places, custom names, icons and
    /// photos, alerts and Keychain secrets. Does not touch the Google account.
    /// Returns false (and keeps the account signed in) when the data cannot be removed.
    @discardableResult
    func deleteActiveAccountLocalData() async -> Bool {
        if isDemo { exitDemo(); return true }
        guard let account = Session.shared.activeAccountID else { return false }
        cancelAccountWork()
        let journal = TrackerJournal.shared
        let shared = journal.deviceIDsInOtherAccounts()
        let listed = Set(devices.map(\.id))
        let recorded: Set<String>
        do { recorded = try journal.deleteActiveAccountData() }
        catch {
            status = journal.storageError ?? String(localized: "Nie udało się usunąć danych konta.")
            return false
        }
        let owned = recorded.union(listed).subtracting(shared)
        NameStore.remove(owned)
        IconStore.remove(owned)
        for id in owned { DeviceImageStore.remove(id) }
        await DeviceProtection.shared.removeNotifications(for: account)
        finishSignOut(status: String(localized: "Usunięto dane konta z telefonu."))
        return true
    }

    private func cancelAccountWork() {
        sessionID = UUID()
        lookupID = UUID()
        locationTask?.cancel(); locationTask = nil
        nearbyTask?.cancel(); nearbyTask = nil
        showingVaultUnlock = false
    }

    private func finishSignOut(status message: String) {
        let next = Session.shared.signOut(Session.shared.activeAccountID ?? "")
        resetAccountState()
        if next != nil {
            loggedIn = Session.shared.isLoggedIn
            Task { await loadDevices(); await locateAll() }
        } else {
            loggedIn = false
            email = nil
            status = message
        }
    }

    private func ensureAndroidID() async throws -> UInt64 {
        if let existing = Session.shared.androidID { return existing }
        guard let master = Session.shared.masterToken else { throw NovaError.http(401) }
        let session = sessionID
        let (aid, stok) = try await GoogleAuth.checkin()
        guard session == sessionID else { throw CancellationError() }
        Session.shared.store(masterToken: master, email: Session.shared.email,
                             androidID: aid, securityToken: stok)
        return aid
    }

    /// Debug build support: export only structural counts, never device IDs,
    /// names, keys, locations or the original reports.
    private func saveRedactedLocationDiagnostics() {
        #if DEBUG
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let text = locationDiagnostics.values.sorted().joined(separator: "\n\n")
        try? text.write(to: directory.appendingPathComponent("LocationDiagnostics.txt"), atomically: true, encoding: .utf8)
        #endif
    }

    /// Cached ADM bearer, deriving a fresh one (and android id if needed) on demand.
    private func currentAdmToken() async throws -> String {
        if let adm = Session.shared.admToken { return adm }
        guard let master = Session.shared.masterToken else { throw NovaError.http(401) }
        let session = sessionID
        let androidID = try await ensureAndroidID()
        guard session == sessionID else { throw CancellationError() }
        status = String(localized: "Autoryzacja Find Hub…")
        let adm = try await GoogleAuth.admToken(
            email: Session.shared.email ?? "", masterToken: master, androidID: androidID)
        guard session == sessionID else { throw CancellationError() }
        Session.shared.admToken = adm
        return adm
    }
}

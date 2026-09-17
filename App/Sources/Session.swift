// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Multi-account session store. Every account's secrets (master/AAS token, checkin
/// identity, E2EE keys, FCM credentials) live in this app's Keychain under keys
/// namespaced by the account email. A small registry tracks the known accounts and
/// which one is active. Short-lived derived tokens (ADM bearer) stay in memory.
@MainActor
final class Session {
    static let shared = Session()
    private init() {
        migrateLegacyIfNeeded()
        accounts = Self.loadRegistry()
        activeAccountID = Keychain.string(for: kActive) ?? accounts.first
        reloadCached()
    }

    // MARK: Registry (not namespaced)
    private let kRegistry = "accounts_registry"     // JSON [String] of emails
    private let kActive = "active_account"          // active email

    private(set) var accounts: [String] = []
    /// Active account email; nil when no account is signed in.
    private(set) var activeAccountID: String?

    private static func loadRegistry() -> [String] {
        guard let data = Keychain.data(for: "accounts_registry"),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return list
    }
    private func saveRegistry() {
        if let data = try? JSONEncoder().encode(accounts) { Keychain.set(data, for: kRegistry) }
    }

    // MARK: Per-account keys
    private let kMaster = "aas_master_token"
    private let kEmail = "account_email"
    private let kAndroidID = "checkin_android_id"
    private let kSecurityToken = "checkin_security_token"
    private let kSharedKey = "e2ee_shared_key"
    private let kOwnerKey = "e2ee_owner_key"
    private let kFcm = "fcm_credentials"
    private let kAvatar = "account_avatar"

    func profileCredentials(for account: String) -> (master: String, androidID: UInt64)? {
        guard accounts.contains(account),
              let master = Keychain.string(for: k(kMaster, for: account)),
              let rawID = Keychain.string(for: k(kAndroidID, for: account)),
              let androidID = UInt64(rawID) else { return nil }
        return (master, androidID)
    }

    func avatar(for account: String) -> Data? {
        guard accounts.contains(account) else { return nil }
        return Keychain.data(for: k(kAvatar, for: account))
    }

    func storeAvatar(_ data: Data?, for account: String) {
        guard accounts.contains(account) else { return }
        if let data { Keychain.set(data, for: k(kAvatar, for: account)) }
        else { Keychain.remove(k(kAvatar, for: account)) }
    }

    /// Namespace a base key under the active account.
    private func k(_ base: String) -> String { "\(activeAccountID ?? "default").\(base)" }
    private func k(_ base: String, for account: String) -> String { "\(account).\(base)" }

    // MARK: Cached in-memory (for the active account)
    var email: String?
    var androidID: UInt64?
    var securityToken: UInt64?
    /// Derived per launch, never persisted.
    var admToken: String?
    private var _fcmCache: FcmCredentials?

    private func reloadCached() {
        email = Keychain.string(for: k(kEmail)) ?? activeAccountID
        androidID = Keychain.string(for: k(kAndroidID)).flatMap { UInt64($0) }
        securityToken = Keychain.string(for: k(kSecurityToken)).flatMap { UInt64($0) }
        admToken = nil
        _fcmCache = nil
    }

    var masterToken: String? { activeAccountID == nil ? nil : Keychain.string(for: k(kMaster)) }
    var isLoggedIn: Bool { masterToken != nil }

    var sharedKey: Data? {
        get { Keychain.string(for: k(kSharedKey)).flatMap { Data(base64Encoded: $0) } }
        set {
            if let d = newValue { Keychain.set(d.base64EncodedString(), for: k(kSharedKey)) }
            else { Keychain.remove(k(kSharedKey)) }
        }
    }

    var ownerKey: Data? {
        get { Keychain.string(for: k(kOwnerKey)).flatMap { Data(base64Encoded: $0) } }
        set {
            if let d = newValue { Keychain.set(d.base64EncodedString(), for: k(kOwnerKey)) }
            else { Keychain.remove(k(kOwnerKey)) }
        }
    }
    var hasE2EE: Bool { ownerKey != nil }

    var fcmCredentials: FcmCredentials? {
        get {
            if let c = _fcmCache { return c }
            guard let data = Keychain.data(for: k(kFcm)) else { return nil }
            _fcmCache = try? JSONDecoder().decode(FcmCredentials.self, from: data)
            return _fcmCache
        }
        set {
            _fcmCache = newValue
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                Keychain.set(data, for: k(kFcm))
            } else {
                Keychain.remove(k(kFcm))
            }
        }
    }

    // MARK: Account lifecycle

    /// Persist a freshly logged-in account and make it active.
    func store(masterToken: String, email: String?, androidID: UInt64, securityToken: UInt64) {
        let id = (email?.isEmpty == false ? email! : (self.activeAccountID ?? "default")).lowercased()
        activeAccountID = id
        if !accounts.contains(id) { accounts.append(id); saveRegistry() }
        Keychain.set(id, for: kActive)

        Keychain.set(masterToken, for: k(kMaster))
        self.androidID = androidID
        self.securityToken = securityToken
        Keychain.set(String(androidID), for: k(kAndroidID))
        Keychain.set(String(securityToken), for: k(kSecurityToken))
        if let email, !email.isEmpty {
            self.email = email
            Keychain.set(email, for: k(kEmail))
        } else {
            self.email = id
        }
        admToken = nil
        _fcmCache = nil
    }

    /// Switch the active account to an already-known email.
    func switchTo(_ accountEmail: String) {
        let id = accountEmail.lowercased()
        guard accounts.contains(id) else { return }
        activeAccountID = id
        Keychain.set(id, for: kActive)
        reloadCached()
    }

    /// Remove one account's secrets. Returns the new active account (or nil).
    @discardableResult
    func signOut(_ accountEmail: String) -> String? {
        let id = accountEmail.lowercased()
        for base in [kMaster, kEmail, kAndroidID, kSecurityToken, kSharedKey, kOwnerKey, kFcm, kAvatar] {
            Keychain.remove(k(base, for: id))
        }
        accounts.removeAll { $0 == id }
        saveRegistry()
        if activeAccountID == id {
            activeAccountID = accounts.first
            if let next = activeAccountID { Keychain.set(next, for: kActive) } else { Keychain.remove(kActive) }
            reloadCached()
        }
        return activeAccountID
    }

    /// Sign out the currently active account.
    func logout() { if let id = activeAccountID { signOut(id) } }

    // MARK: Legacy migration (single-account → namespaced)

    private func migrateLegacyIfNeeded() {
        // If a registry already exists, nothing to migrate.
        if Keychain.data(for: kRegistry) != nil { return }
        guard let legacyMaster = Keychain.string(for: kMaster) else { return }
        let legacyEmail = (Keychain.string(for: kEmail) ?? "konto").lowercased()
        func move(_ base: String) {
            if let s = Keychain.string(for: base) {
                Keychain.set(s, for: k(base, for: legacyEmail))
                Keychain.remove(base)
            } else if let d = Keychain.data(for: base) {
                Keychain.set(d, for: k(base, for: legacyEmail))
                Keychain.remove(base)
            }
        }
        Keychain.set(legacyMaster, for: k(kMaster, for: legacyEmail))
        Keychain.remove(kMaster)
        for base in [kEmail, kAndroidID, kSecurityToken, kSharedKey, kOwnerKey, kFcm] { move(base) }
        if let data = try? JSONEncoder().encode([legacyEmail]) { Keychain.set(data, for: kRegistry) }
        Keychain.set(legacyEmail, for: kActive)
    }
}

// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   firebase-messaging, Copyright (c) 2017 Matthieu Lemoine, (c) 2023 Steven Beth, MIT, https://github.com/sdb9696/firebase-messaging
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import CryptoKit

/// Persisted FCM identity. Reused across launches so the registration token
/// (used to route Find Hub push responses) stays stable.
struct FcmCredentials: Codable {
    var androidID: UInt64
    var securityToken: UInt64
    var gcmToken: String        // c2dm registration
    var fcmToken: String        // FCM registration token (goes into Nova actions)
    var privateKeyB64: String   // PKCS8 DER, urlsafe b64 — for http_ece (M3b)
    var publicKeyB64: String    // raw P-256 point, urlsafe b64
    var authSecretB64: String   // 16 bytes, urlsafe b64
}

enum FcmError: LocalizedError {
    case http(String, Int)
    case parse(String)
    var errorDescription: String? {
        switch self {
        case .http(let step, let code): return "FCM \(step) HTTP \(code)"
        case .parse(let step): return "FCM \(step): zła odpowiedź"
        }
    }
}

/// Swift port of the FCM registration flow (firebase-messaging) that FindHub Android needs:
/// checkin → c2dm register → firebase installation → fcm registration.
/// Config values are the Google Find Hub (com.google.android.apps.adm) app's.
struct FcmRegister {
    static let projectID = "google.com:api-project-289722593072"
    static let appID = "1:289722593072:android:3cfcf5bc359f0308"
    static let apiKey = "AIzaSyD_gko3P392v6how2H7UpdeXQ0v2HLettc"
    static let bundleID = "com.google.android.apps.adm"
    static let certSHA1 = "38918a453d07199354f8b19af05ec6562ced5788"
    static let gcmServerKeyB64 =
        "BDOU99-h67HcA6JeFXHbSNMu7e2yNNu3RzoMj8TM4W88jITfq7ZmPvIM1Iv-4_l2LxQcYwhqby2xGpWwzjfAnG4"

    /// Reuse stored credentials or run a full registration.
    @MainActor
    static func ensureRegistered() async throws -> FcmCredentials {
        try Task.checkCancellation()
        guard let accountToken = Session.shared.masterToken else { throw CancellationError() }
        if let existing = Session.shared.fcmCredentials { return existing }
        let creds = try await register()
        try Task.checkCancellation()
        guard Session.shared.masterToken == accountToken else { throw CancellationError() }
        Session.shared.fcmCredentials = creds
        return creds
    }

    static func register() async throws -> FcmCredentials {
        let (androidID, securityToken) = try await GoogleAuth.checkin()
        let keys = generateKeys()
        let gcmToken = try await gcmRegister(androidID: androidID, securityToken: securityToken)
        let installToken = try await fcmInstall()
        let fcmToken = try await fcmRegister(gcmToken: gcmToken, installToken: installToken, keys: keys)
        return FcmCredentials(
            androidID: androidID, securityToken: securityToken,
            gcmToken: gcmToken, fcmToken: fcmToken,
            privateKeyB64: keys.privateKeyB64, publicKeyB64: keys.publicKeyB64,
            authSecretB64: keys.authSecretB64)
    }

    // MARK: - Keys (P-256 keypair + auth secret) for Web Push / http_ece

    struct Keys { let privateKeyB64, publicKeyB64, authSecretB64: String }

    static func generateKeys() -> Keys {
        let priv = P256.KeyAgreement.PrivateKey()
        let pubPoint = priv.publicKey.x963Representation           // 0x04 || X || Y (65 bytes)
        let privDER = priv.derRepresentation                       // PKCS#8 DER
        var secret = Data(count: 16)
        _ = secret.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        return Keys(privateKeyB64: b64url(privDER),
                    publicKeyB64: b64url(pubPoint),
                    authSecretB64: b64url(secret))
    }

    // MARK: - c2dm register → gcm token

    private static func gcmRegister(androidID: UInt64, securityToken: UInt64) async throws -> String {
        var request = URLRequest(url: URL(string: "https://android.clients.google.com/c2dm/register3")!)
        request.httpMethod = "POST"
        request.setValue("AidLogin \(androidID):\(securityToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "app": "org.chromium.linux",
            "X-subtype": "wp:\(bundleID)#\(UUID().uuidString)",
            "device": String(androidID),
            "sender": gcmServerKeyB64,
        ]
        request.httpBody = formEncode(body).data(using: .utf8)

        // c2dm returns HTTP 200 with "Error=PHONE_REGISTRATION_ERROR" transiently
        // right after a fresh checkin; the reference client retries. Do the same.
        var lastError = "?"
        for attempt in 0..<20 {
            let (data, resp) = try await URLSession.shared.data(for: request)
            let text = String(data: data, encoding: .utf8) ?? ""
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw FcmError.http("c2dm", (resp as? HTTPURLResponse)?.statusCode ?? -1)
            }
            if text.contains("Error") {
                lastError = text.trimmingCharacters(in: .whitespacesAndNewlines)
                try await Task.sleep(nanoseconds: 1_500_000_000)
                continue
            }
            guard let eq = text.firstIndex(of: "=") else { throw FcmError.parse("c2dm") }
            let token = String(text[text.index(after: eq)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { return token }
            _ = attempt
        }
        throw FcmError.http("c2dm(\(lastError.prefix(60)))", 200)
    }

    // MARK: - firebase installation → install auth token

    private static func fcmInstall() async throws -> String {
        var fid = Data((0..<17).map { _ in UInt8.random(in: 0...255) })
        fid[0] = 0x70 + (fid[0] % 0x10)  // FID header 0b0111
        let hbHeader = Data("{\"heartbeats\":[],\"version\":2}".utf8).base64EncodedString()

        var request = URLRequest(url: URL(string:
            "https://firebaseinstallations.googleapis.com/v1/projects/\(projectID)/installations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(hbHeader, forHTTPHeaderField: "x-firebase-client")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue(bundleID, forHTTPHeaderField: "X-Android-Package")
        request.setValue(certSHA1, forHTTPHeaderField: "X-Android-Cert")
        let payload: [String: Any] = [
            "appId": appID,
            "authVersion": "FIS_v2",
            "fid": fid.base64EncodedString(),
            "sdkVersion": "w:0.6.6",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw FcmError.http("install", (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authToken = json["authToken"] as? [String: Any],
              let token = authToken["token"] as? String else {
            throw FcmError.parse("install")
        }
        return token
    }

    // MARK: - fcm registration → FCM token

    private static func fcmRegister(gcmToken: String, installToken: String, keys: Keys) async throws -> String {
        var request = URLRequest(url: URL(string:
            "https://fcmregistrations.googleapis.com/v1/projects/\(projectID)/registrations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue(installToken, forHTTPHeaderField: "x-goog-firebase-installations-auth")
        request.setValue(bundleID, forHTTPHeaderField: "X-Android-Package")
        request.setValue(certSHA1, forHTTPHeaderField: "X-Android-Cert")
        let payload: [String: Any] = [
            "web": [
                "auth": keys.authSecretB64,
                "endpoint": "https://fcm.googleapis.com/fcm/send/\(gcmToken)",
                "p256dh": keys.publicKeyB64,
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw FcmError.http("register(\(text.prefix(60)))", (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String else {
            throw FcmError.parse("register")
        }
        return token
    }

    // MARK: - helpers

    private static func b64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private static func formEncode(_ form: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
    }
}

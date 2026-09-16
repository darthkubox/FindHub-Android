// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   gpsoauth, Copyright (c) 2015 Simon Weber, MIT, https://github.com/simon-weber/gpsoauth
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import SwiftProtobuf

enum GoogleAuthError: LocalizedError {
    case http(Int)
    case missingField(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .http(let code): return "HTTP \(code)"
        case .missingField(let f): return "brak pola '\(f)' w odpowiedzi Google"
        case .badResponse: return "nieczytelna odpowiedź serwera"
        }
    }
}

/// Swift port of the pieces of gpsoauth + GCM checkin that FindHub Android needs.
/// Endpoints, form fields and parsing mirror the reference implementation exactly.
struct GoogleAuth {
    static let authURL = URL(string: "https://android.clients.google.com/auth")!
    static let checkinURL = URL(string: "https://android.clients.google.com/checkin")!
    static let clientSig = "38918a453d07199354f8b19af05ec6562ced5788"
    static let gmsVersion = "240913000"

    // MARK: - GCM checkin → (androidID, securityToken)

    static func checkin() async throws -> (androidID: UInt64, securityToken: UInt64) {
        var chrome = CheckinProto_ChromeBuildProto()
        chrome.platform = .linux
        chrome.chromeVersion = "94.0.4606.51"
        chrome.channel = .stable

        var checkin = CheckinProto_AndroidCheckinProto()
        checkin.type = .deviceChromeBrowser
        checkin.chromeBuild = chrome

        var payload = CheckinProto_AndroidCheckinRequest()
        payload.version = 3
        payload.userSerialNumber = 0
        payload.checkin = checkin

        var request = URLRequest(url: checkinURL)
        request.httpMethod = "POST"
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.httpBody = try payload.serializedData()

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw GoogleAuthError.badResponse }
        guard http.statusCode == 200 else { throw GoogleAuthError.http(http.statusCode) }

        let out = try CheckinProto_AndroidCheckinResponse(serializedBytes: data)
        return (out.androidID, out.securityToken)
    }

    // MARK: - Exchange web oauth_token → master (AAS) token

    static func exchangeToken(oauthToken: String,
                              androidID: UInt64) async throws -> (token: String, email: String) {
        let form: [String: String] = [
            "accountType": "HOSTED_OR_GOOGLE",
            "Email": "",
            "has_permission": "1",
            "add_account": "1",
            "ACCESS_TOKEN": "1",
            "Token": oauthToken,
            "service": "ac2dm",
            "source": "android",
            "androidId": String(androidID),
            "device_country": "us",
            "operatorCountry": "us",
            "lang": "en",
            "sdk_version": "17",
            "google_play_services_version": gmsVersion,
            "client_sig": clientSig,
            "callerSig": clientSig,
            "droidguard_results": "dummy123",
        ]
        let dict = try await post(form)
        guard let token = dict["Token"] else { throw GoogleAuthError.missingField("Token") }
        return (token, dict["Email"] ?? "")
    }

    // MARK: - Master token → per-service token

    static func performOAuth(email: String, masterToken: String, androidID: UInt64,
                             service: String, app: String) async throws -> String {
        let form: [String: String] = [
            "accountType": "HOSTED_OR_GOOGLE",
            "Email": email,
            "has_permission": "1",
            "EncryptedPasswd": masterToken,
            "service": service,
            "source": "android",
            "androidId": String(androidID),
            "app": app,
            "client_sig": clientSig,
            "device_country": "us",
            "operatorCountry": "us",
            "lang": "en",
            "sdk_version": "17",
            "google_play_services_version": gmsVersion,
        ]
        let dict = try await post(form)
        guard let auth = dict["Auth"] else { throw GoogleAuthError.missingField("Auth") }
        return auth
    }

    /// ADM (Android Device Manager) bearer token used by the Nova/Find Hub API.
    static func admToken(email: String, masterToken: String, androidID: UInt64) async throws -> String {
        try await performOAuth(
            email: email, masterToken: masterToken, androidID: androidID,
            service: "oauth2:https://www.googleapis.com/auth/android_device_manager",
            app: "com.google.android.apps.adm")
    }

    /// Spot bearer token used by the Spot (E2EE key) gRPC API. Uses the GMS app id.
    static func spotToken(email: String, masterToken: String, androidID: UInt64) async throws -> String {
        try await performOAuth(
            email: email, masterToken: masterToken, androidID: androidID,
            service: "oauth2:https://www.googleapis.com/auth/spot",
            app: "com.google.android.gms")
    }

    /// Request basic profile access separately from Find Hub's bearer token.
    /// A failure here must never prevent listing or locating devices.
    static func accountPhoto(email: String, masterToken: String, androidID: UInt64) async throws -> Data? {
        let token = try await performOAuth(
            email: email, masterToken: masterToken, androidID: androidID,
            service: "oauth2:https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email",
            app: "com.google.android.gms")
        try Task.checkCancellation()
        let transport = URLSession(configuration: .ephemeral)
        defer { transport.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleAuthError.badResponse }
        guard http.statusCode == 200 else { throw GoogleAuthError.http(http.statusCode) }
        let profile = try JSONDecoder().decode(AccountProfile.self, from: data)
        guard let url = try profile.avatarURL(for: email) else { return nil }
        try Task.checkCancellation()
        // The public photo request contains no Google credentials.
        var photoRequest = URLRequest(url: url)
        photoRequest.timeoutInterval = 20
        let (photo, photoResponse) = try await transport.data(for: photoRequest)
        guard let http = photoResponse as? HTTPURLResponse else { throw GoogleAuthError.badResponse }
        guard http.statusCode == 200 else { throw GoogleAuthError.http(http.statusCode) }
        guard photo.count <= 5_000_000, http.mimeType?.hasPrefix("image/") == true else {
            throw GoogleAuthError.badResponse
        }
        return photo
    }

    // MARK: - Shared form POST + key=value parsing

    private static func post(_ form: [String: String]) async throws -> [String: String] {
        var request = URLRequest(url: authURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("GoogleAuth/1.4", forHTTPHeaderField: "User-Agent")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = formEncode(form).data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw GoogleAuthError.badResponse }
        let text = String(data: data, encoding: .utf8) ?? ""
        var dict: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let eq = line.firstIndex(of: "=") else { continue }
            dict[String(line[..<eq])] = String(line[line.index(after: eq)...])
        }
        // Google returns useful fields even on non-200 (e.g. Error=BadAuthentication).
        if http.statusCode != 200, dict["Auth"] == nil, dict["Token"] == nil {
            throw GoogleAuthError.http(http.statusCode)
        }
        return dict
    }

    private static func formEncode(_ form: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return form.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }
}

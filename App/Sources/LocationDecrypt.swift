// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import CoreLocation
import SwiftProtobuf

enum LocationDecryptError: LocalizedError {
    case headers, payload, noLocation, networkDecryption
    var errorDescription: String? {
        switch self {
        case .headers: return String(localized: "Brak nagłówków szyfrowania w raporcie")
        case .payload: return String(localized: "Nie udało się odczytać payloadu raportu")
        case .noLocation: return String(localized: "Raport nie zawiera odczytywalnej pozycji")
        case .networkDecryption: return String(localized: "Nie udało się odszyfrować raportów sieciowych")
        }
    }
}

/// Turns a pushed FMDN report (MCS DataMessageStanza) into coordinates.
/// Own reports use AES-GCM; network reports use SECP160r1 + AES-EAX.
enum LocationDecrypt {
    static func decrypt(stanza: McsProto_DataMessageStanza,
                        creds: FcmCredentials, ownerKey: Data) throws -> LocationResponse {
        let update = try decodeUpdate(stanza: stanza, creds: creds)
        return try decrypt(update: update, ownerKey: ownerKey)
    }

    static func decodeUpdate(stanza: McsProto_DataMessageStanza, creds: FcmCredentials) throws -> DeviceUpdate {
        func appData(_ key: String) -> String? { stanza.appData.first { $0.key == key }?.value }

        guard let dhRaw = appData("crypto-key")?.replacingOccurrences(of: "dh=", with: ""),
              let saltRaw = appData("encryption")?.replacingOccurrences(of: "salt=", with: ""),
              let dh = HttpEce.b64urlDecode(dhRaw), let salt = HttpEce.b64urlDecode(saltRaw),
              let priv = HttpEce.b64urlDecode(creds.privateKeyB64),
              let secret = HttpEce.b64urlDecode(creds.authSecretB64) else {
            throw LocationDecryptError.headers
        }

        let plain = try HttpEce.decryptAesgcm(content: stanza.rawData, salt: salt, dh: dh,
                                              privateKeyDER: priv, authSecret: secret)

        guard let obj = try? JSONSerialization.jsonObject(with: plain),
              let payloadB64 = findFcmPayload(obj),
              let duBytes = Data(base64Encoded: payloadB64) else {
            throw LocationDecryptError.payload
        }

        return try DeviceUpdate(serializedBytes: duBytes)
    }

    static func deviceIDs(in update: DeviceUpdate) -> [String] {
        LocationReportDecoder.deviceIDs(in: update)
    }

    static func decrypt(update: DeviceUpdate, ownerKey: Data, sharedKey: Data? = nil) throws -> LocationResponse {
        LocationReportDecoder.decode(update, ownerKey: ownerKey, sharedKey: sharedKey)
    }

    /// Find the FMDN payload (base64) inside the decrypted FCM JSON, top-level or under "data".
    private static func findFcmPayload(_ obj: Any) -> String? {
        let key = "com.google.android.apps.adm.FCM_PAYLOAD"
        if let dict = obj as? [String: Any] {
            if let v = dict[key] as? String { return v }
            if let data = dict["data"], let found = findFcmPayload(data) { return found }
        }
        return nil
    }
}

// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   encrypted-content-encoding (http_ece), Martin Thomson, MIT, https://github.com/martinthomson/encrypted-content-encoding

import Foundation
import CryptoKit

enum EceError: LocalizedError {
    case badKey, decrypt
    var errorDescription: String? {
        switch self {
        case .badKey: return "ECE: zły klucz"
        case .decrypt: return "ECE: odszyfrowanie nie powiodło się"
        }
    }
}

/// Web Push "aesgcm" (draft-01) decryption, as used by FCM data messages.
/// Ported from the http_ece library (version="aesgcm", single record).
enum HttpEce {
    static func decryptAesgcm(content: Data, salt: Data, dh: Data,
                              privateKeyDER: Data, authSecret: Data) throws -> Data {
        guard let priv = try? P256.KeyAgreement.PrivateKey(derRepresentation: privateKeyDER),
              let senderPub = try? P256.KeyAgreement.PublicKey(x963Representation: dh) else {
            throw EceError.badKey
        }
        let receiverPub = priv.publicKey.x963Representation           // 65 bytes
        let shared = try priv.sharedSecretFromKeyAgreement(with: senderPub)
        let sharedData = shared.withUnsafeBytes { Data($0) }          // ECDH x (32 bytes)

        // context = "P-256\0" || len16(receiverPub) || receiverPub || len16(senderPub) || senderPub
        var context = Data("P-256".utf8); context.append(0)
        context.append(contentsOf: be16(receiverPub.count)); context.append(receiverPub)
        context.append(contentsOf: be16(dh.count)); context.append(dh)

        // PRK = HKDF(salt=authSecret, ikm=shared, info="Content-Encoding: auth\0", 32)
        let prk = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: sharedData),
            salt: authSecret, info: Data("Content-Encoding: auth\0".utf8), outputByteCount: 32)

        let cek = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: prk, salt: salt,
            info: info("aesgcm", context), outputByteCount: 16)
        let nonce = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: prk, salt: salt,
            info: info("nonce", context), outputByteCount: 12)
        let nonceData = nonce.withUnsafeBytes { Data($0) }

        guard content.count > 16 else { throw EceError.decrypt }
        let ciphertext = content.prefix(content.count - 16)
        let tag = content.suffix(16)
        guard let box = try? AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: nonceData),
                                               ciphertext: ciphertext, tag: tag),
              let plain = try? AES.GCM.open(box, using: cek) else {
            throw EceError.decrypt
        }
        // aesgcm padding: [padLen: 2 bytes BE][padding][data]
        guard plain.count >= 2 else { throw EceError.decrypt }
        let padLen = Int(plain[plain.startIndex]) << 8 | Int(plain[plain.startIndex + 1])
        let start = plain.startIndex + 2 + padLen
        guard start <= plain.endIndex else { throw EceError.decrypt }
        return Data(plain[start...])
    }

    private static func info(_ base: String, _ context: Data) -> Data {
        var d = Data("Content-Encoding: \(base)\0".utf8)
        d.append(context)
        return d
    }

    private static func be16(_ n: Int) -> [UInt8] { [UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)] }

    /// urlsafe base64 decode with padding restored (for stored keys / headers).
    static func b64urlDecode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t.append("=") }
        return Data(base64Encoded: t)
    }
}

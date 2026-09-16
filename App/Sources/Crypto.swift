// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import CryptoKit
import CommonCrypto

enum CryptoError: LocalizedError {
    case aesCBC
    case badLength(String)
    case vaultParse
    var errorDescription: String? {
        switch self {
        case .aesCBC: return "AES-CBC nie powiodło się"
        case .badLength(let w): return "zła długość danych (\(w))"
        case .vaultParse: return "nie udało się odczytać kluczy skarbca"
        }
    }
}

/// E2EE crypto for Find Hub, ported from KeyBackup/cloud_key_decryptor.py and
/// FMDNCrypto/. Only the primitives on the real runtime path are here:
/// shared key (from the vault-unlock bridge) → owner key → per-tag identity key
/// → ring key. SECP160r1 location decryption is added later (needs a C lib).
enum FMDNCrypto {

    /// AES-GCM with a 12-byte IV prepended and the 16-byte tag appended.
    static func decryptAESGCM(key: Data, ivAndCiphertext: Data,
                              aad: Data? = nil, ivLen: Int = 12) throws -> Data {
        guard ivAndCiphertext.count >= ivLen + 16 else { throw CryptoError.badLength("gcm") }
        let iv = ivAndCiphertext.prefix(ivLen)
        let body = ivAndCiphertext.dropFirst(ivLen)
        let tag = body.suffix(16)
        let ciphertext = body.dropLast(16)
        let box = try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: iv),
                                        ciphertext: ciphertext, tag: tag)
        let symKey = SymmetricKey(data: key)
        if let aad {
            return try AES.GCM.open(box, using: symKey, authenticating: aad)
        }
        return try AES.GCM.open(box, using: symKey)
    }

    /// AES-CBC, no padding, with a 16-byte IV prepended (CryptoKit lacks CBC).
    static func decryptAESCBCNoPadding(key: Data, ivAndCiphertext: Data, ivLen: Int = 16) throws -> Data {
        guard ivAndCiphertext.count > ivLen else { throw CryptoError.badLength("cbc") }
        let iv = Data(ivAndCiphertext.prefix(ivLen))
        let ct = Data(ivAndCiphertext.dropFirst(ivLen))
        var out = Data(count: ct.count + kCCBlockSizeAES128)
        var moved = 0
        let outCount = out.count
        let status = out.withUnsafeMutableBytes { outPtr in
            ct.withUnsafeBytes { ctPtr in
                iv.withUnsafeBytes { ivPtr in
                    key.withUnsafeBytes { keyPtr in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(0),  // no padding
                                keyPtr.baseAddress, key.count,
                                ivPtr.baseAddress,
                                ctPtr.baseAddress, ct.count,
                                outPtr.baseAddress, outCount, &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw CryptoError.aesCBC }
        return out.prefix(moved)
    }

    /// Owner key = AES-GCM(shared_key, encryptedOwnerKey). Valid for all trackers.
    static func decryptOwnerKey(sharedKey: Data, encryptedOwnerKey: Data) throws -> Data {
        try decryptAESGCM(key: sharedKey, ivAndCiphertext: encryptedOwnerKey)
    }

    /// Per-tag Ephemeral Identity Key. Length selects the cipher (CBC 48 / GCM 60).
    static func decryptEIK(ownerKey: Data, encryptedEIK: Data) throws -> Data {
        switch encryptedEIK.count {
        case 48: return try decryptAESCBCNoPadding(key: ownerKey, ivAndCiphertext: encryptedEIK)
        case 60: return try decryptAESGCM(key: ownerKey, ivAndCiphertext: encryptedEIK)
        default: throw CryptoError.badLength("eik \(encryptedEIK.count)")
        }
    }

    /// Compatibility variants used by the current reference client. CBC unwrap
    /// alone is not proof: every candidate must authenticate the location report.
    static func identityKeyCandidates(ownerKey: Data, sharedKey: Data?, encryptedEIK: Data,
                                      deviceIDs: [String], isMCU: Bool) -> [Data] {
        var candidates: [Data] = []
        var wrappingKeys = [ownerKey]
        if let sharedKey, sharedKey != ownerKey { wrappingKeys.append(sharedKey) }
        let flipped = Data(encryptedEIK.map { $0 ^ 0xFF })
        let envelopes = isMCU ? [flipped, encryptedEIK] : [encryptedEIK, flipped]
        func append(_ candidate: Data?) {
            if let candidate, candidate.count == 32, !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }
        for wrappingKey in wrappingKeys {
            for envelope in envelopes {
                append(try? decryptEIK(ownerKey: wrappingKey, encryptedEIK: envelope))
                if envelope.count == 60 {
                    for id in deviceIDs where !id.isEmpty {
                        append(try? decryptAESGCM(key: wrappingKey, ivAndCiphertext: envelope, aad: Data(id.utf8)))
                    }
                }
            }
        }
        return candidates
    }

    /// Ring key = first 8 bytes of SHA-256(identityKey ‖ 0x02). Used to authenticate
    /// the BLE ring command (FMDNCrypto/key_derivation.py, operation 0x02).
    static func ringKey(identityKey: Data) -> Data {
        var d = identityKey
        d.append(0x02)
        return Data(SHA256.hash(data: d).prefix(8))
    }

    /// Own-report location key = SHA-256(identityKey); report is AES-GCM under it.
    static func ownReportKey(identityKey: Data) -> Data {
        Data(SHA256.hash(data: identityKey))
    }

    /// Extract the finder_hw shared key from the vault-unlock bridge JSON.
    /// Shape: {"finder_hw":[{"epoch":N,"key":{"0":b,"1":b,...}}, ...]}
    static func fmdnSharedKey(fromVaultKeysJSON json: String) throws -> Data {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let arr = obj["finder_hw"] as? [[String: Any]],
              let keyObj = arr.first?["key"] as? [String: Any] else {
            throw CryptoError.vaultParse
        }
        var bytes = [UInt8](repeating: 0, count: keyObj.count)
        for i in 0..<keyObj.count {
            guard let v = keyObj[String(i)] as? Int else { throw CryptoError.vaultParse }
            bytes[i] = UInt8(truncatingIfNeeded: v)
        }
        return Data(bytes)
    }
}

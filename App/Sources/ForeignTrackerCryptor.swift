// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import CommonCrypto
import CryptoKit

/// Decrypts FMDN *network* (crowdsourced) location reports for BLE tags.
/// These use SECP160r1 ECDH + AES-EAX-256 (CryptoKit lacks secp160r1, so we
/// use micro-ecc via the bridging header). Ported from GoogleFindMyTools'
/// foreign_tracker_cryptor.py + eid_generator.py.
enum ForeignTrackerCryptor {
    private static let K: UInt8 = 10   // rotation exponent (period 2^10 = 1024 s)

    /// SECP160r1 curve order n (161 bits → 21 bytes big-endian).
    private static let order: [UInt8] = [
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0xF4, 0xC8, 0xF9, 0x27, 0xAE, 0xD3, 0xCA, 0x75, 0x22, 0x57]

    enum Err: Error { case ecc, eax }

    /// - identityKey: per-tag 32-byte ephemeral identity key (from decryptEIK)
    /// - encryptedAndTag: EncryptedReport.encryptedLocation (m' || 16-byte tag)
    /// - sx: EncryptedReport.publicKeyRandom (20-byte S.x)
    /// - timeCounter: GeoLocation.deviceTimeOffset (0 for MCU trackers)
    static func decrypt(identityKey: Data, encryptedAndTag: Data, sx: Data,
                        timeCounter: UInt32) throws -> Data {
        guard encryptedAndTag.count > 16 else { throw Err.eax }
        let mDash = encryptedAndTag.prefix(encryptedAndTag.count - 16)
        let tag = encryptedAndTag.suffix(16)

        let curve = uECC_secp160r1()
        // r = AES-256-ECB(identityKey, structured block) mod n  → 21-byte private key
        let r = try calculateR(identityKey: identityKey, timeCounter: timeCounter)

        // R = r * G ; Rx = R[0..<20]
        var rPub = [UInt8](repeating: 0, count: 40)
        guard r.withUnsafeBytes({ rp in
            uECC_compute_public_key(rp.bindMemory(to: UInt8.self).baseAddress, &rPub, curve)
        }) == 1 else { throw Err.ecc }
        let rx = Array(rPub[0..<20])

        // S = decompress(Sx) with even y (prefix 0x02) → 40-byte public key
        var compressed = [UInt8]([0x02]); compressed.append(contentsOf: sx)
        guard compressed.count == 21 else { throw Err.ecc }
        var sPub = [UInt8](repeating: 0, count: 40)
        uECC_decompress(compressed, &sPub, curve)
        guard uECC_valid_public_key(sPub, curve) == 1 else { throw Err.ecc }

        // shared = (r * S).x  (20 bytes)
        var shared = [UInt8](repeating: 0, count: 20)
        guard r.withUnsafeBytes({ rp in
            uECC_shared_secret(sPub, rp.bindMemory(to: UInt8.self).baseAddress, &shared, curve)
        }) == 1 else { throw Err.ecc }

        // k = HKDF-SHA256(ikm = shared, salt = nil, info = "", 32 bytes)
        let k = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(shared)),
            info: Data(), outputByteCount: 32)
        let keyData = k.withUnsafeBytes { Data($0) }

        // nonce = LRx || LSx = R.x[12..<20] || S.x[12..<20]  (16 bytes)
        // The legacy client uses 8-byte halves; Google's current published
        // specification describes 80-bit halves. Accept only authenticated data.
        for halfLength in [8, 10] {
            var nonce = Data(rx.suffix(halfLength)); nonce.append(sx.suffix(halfLength))
            if let plain = AesEax.decrypt(key: keyData, nonce: nonce,
                                        ciphertext: Data(mDash), tag: Data(tag)) {
                return plain
            }
        }
        throw Err.eax
    }

    /// The 20-byte Ephemeral Identifier (EID) a provisioned FMDN tag advertises
    /// at the given beacon time counter: EID = (r·G).x, r from calculateR.
    /// Used to recognize *which* tag an advertisement belongs to. Ported from
    /// eid_generator.generate_eid.
    static func eid(identityKey: Data, timeCounter: UInt32) -> Data? {
        guard let r = try? calculateR(identityKey: identityKey, timeCounter: timeCounter) else { return nil }
        var pub = [UInt8](repeating: 0, count: 40)
        guard r.withUnsafeBytes({ rp in
            uECC_compute_public_key(rp.bindMemory(to: UInt8.self).baseAddress, &pub, uECC_secp160r1())
        }) == 1 else { return nil }
        return Data(pub[0..<20])
    }

    /// r = ( AES-256-ECB(identityKey, block)  as big-endian int )  mod n
    private static func calculateR(identityKey: Data, timeCounter: UInt32) throws -> [UInt8] {
        let masked = timeCounter & ~UInt32((1 << Int(K)) - 1)
        let ts: [UInt8] = [UInt8(masked >> 24 & 0xFF), UInt8(masked >> 16 & 0xFF),
                           UInt8(masked >> 8 & 0xFF), UInt8(masked & 0xFF)]
        var block = [UInt8](repeating: 0, count: 32)
        for i in 0..<11 { block[i] = 0xFF }
        block[11] = K
        block[12] = ts[0]; block[13] = ts[1]; block[14] = ts[2]; block[15] = ts[3]
        // 16..<27 already 0x00
        block[27] = K
        block[28] = ts[0]; block[29] = ts[1]; block[30] = ts[2]; block[31] = ts[3]

        let rPrime = try aes256ECB(key: identityKey, block: Data(block))  // 32 bytes
        return modOrder([UInt8](rPrime))
    }

    private static func aes256ECB(key: Data, block: Data) throws -> Data {
        guard key.count == 32 else { throw Err.eax }
        var out = Data(count: block.count); var moved = 0
        let outCap = out.count
        let ok = out.withUnsafeMutableBytes { o in block.withUnsafeBytes { b in key.withUnsafeBytes { k in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                    k.baseAddress, key.count, nil, b.baseAddress, block.count, o.baseAddress, outCap, &moved)
        }}}
        guard ok == kCCSuccess else { throw Err.eax }
        return out.prefix(moved)
    }

    /// 256-bit big-endian value mod the 21-byte order n, bit-by-bit.
    private static func modOrder(_ value: [UInt8]) -> [UInt8] {
        var rem = [UInt8](repeating: 0, count: order.count)   // 21 bytes
        for byte in value {
            for bit in stride(from: 7, through: 0, by: -1) {
                // rem = (rem << 1) | nextBit
                var carry: UInt8 = (byte >> bit) & 1
                for i in stride(from: rem.count - 1, through: 0, by: -1) {
                    let v = (UInt16(rem[i]) << 1) | UInt16(carry)
                    rem[i] = UInt8(v & 0xFF)
                    carry = UInt8(v >> 8)
                }
                if !lessThan(rem, order) { subtract(&rem, order) }  // rem >= n → rem -= n
            }
        }
        return rem
    }

    private static func lessThan(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        for i in 0..<a.count { if a[i] != b[i] { return a[i] < b[i] } }
        return false
    }

    private static func subtract(_ a: inout [UInt8], _ b: [UInt8]) {
        var borrow: Int = 0
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            let d = Int(a[i]) - Int(b[i]) - borrow
            if d < 0 { a[i] = UInt8(d + 256); borrow = 1 } else { a[i] = UInt8(d); borrow = 0 }
        }
    }
}

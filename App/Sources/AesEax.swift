// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CommonCrypto

/// AES-EAX (authenticated encryption) — needed for FMDN network location reports.
/// Implements CMAC (OMAC1) + AES-CTR per the EAX construction. Decrypt only.
enum AesEax {
    private static func ecbBlock(_ key: Data, _ block: Data) -> Data {
        var out = Data(count: 16); var moved = 0
        _ = out.withUnsafeMutableBytes { o in block.withUnsafeBytes { b in key.withUnsafeBytes { k in
            CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                    k.baseAddress, key.count, nil, b.baseAddress, 16, o.baseAddress, 16, &moved)
        }}}
        return out
    }

    private static func xor(_ a: Data, _ b: Data) -> Data { Data(zip(a, b).map { $0 ^ $1 }) }

    private static func dbl(_ x: Data) -> Data {
        let bytes = [UInt8](x)
        var r = [UInt8](repeating: 0, count: 16)
        var carry: UInt8 = 0
        for i in stride(from: 15, through: 0, by: -1) {
            r[i] = (bytes[i] << 1) | carry
            carry = (bytes[i] & 0x80) >> 7
        }
        if (bytes[0] & 0x80) != 0 { r[15] ^= 0x87 }
        return Data(r)
    }

    private static func cmac(_ key: Data, _ msg: Data) -> Data {
        let k1 = dbl(ecbBlock(key, Data(count: 16)))
        let k2 = dbl(k1)
        var blocks: [Data] = []
        var i = msg.startIndex
        while i < msg.endIndex { let e = min(i + 16, msg.endIndex); blocks.append(Data(msg[i..<e])); i = e }

        let last: Data
        if !msg.isEmpty && msg.count % 16 == 0 {
            last = xor(blocks.removeLast(), k1)
        } else {
            var b = blocks.isEmpty ? Data() : blocks.removeLast()
            b.append(0x80); while b.count < 16 { b.append(0) }
            last = xor(b, k2)
        }
        var x = Data(count: 16)
        for blk in blocks { x = ecbBlock(key, xor(x, blk)) }
        return ecbBlock(key, xor(x, last))
    }

    private static func omac(_ key: Data, _ t: UInt8, _ msg: Data) -> Data {
        var b = Data(count: 15); b.append(t); b.append(msg)
        return cmac(key, b)
    }

    private static func ctr(_ key: Data, _ iv: Data, _ data: Data) -> Data {
        var cryptor: CCCryptorRef?
        key.withUnsafeBytes { k in iv.withUnsafeBytes { ivp in
            _ = CCCryptorCreateWithMode(CCOperation(kCCEncrypt), CCMode(kCCModeCTR), CCAlgorithm(kCCAlgorithmAES),
                                        CCPadding(ccNoPadding), ivp.baseAddress, k.baseAddress, key.count,
                                        nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &cryptor)
        }}
        guard let cryptor else { return Data() }
        defer { CCCryptorRelease(cryptor) }
        var out = Data(count: data.count + 16); var moved = 0
        let outCap = out.count
        _ = out.withUnsafeMutableBytes { o in data.withUnsafeBytes { d in
            CCCryptorUpdate(cryptor, d.baseAddress, data.count, o.baseAddress, outCap, &moved)
        }}
        return out.prefix(moved)
    }

    /// EAX decrypt with empty header. Returns plaintext or nil if the tag mismatches.
    static func decrypt(key: Data, nonce: Data, ciphertext: Data, tag: Data) -> Data? {
        let n = omac(key, 0, nonce)
        let h = omac(key, 1, Data())
        let c = omac(key, 2, ciphertext)
        let computed = xor(xor(n, h), c)
        guard computed == tag else { return nil }
        return ctr(key, n, ciphertext)
    }
}

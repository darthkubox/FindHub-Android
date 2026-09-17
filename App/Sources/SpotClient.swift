// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import SwiftProtobuf

enum SpotError: LocalizedError {
    case http(Int)
    case grpc(String)
    var errorDescription: String? {
        switch self {
        case .http(let c): return "Spot HTTP \(c)"
        case .grpc(let m): return "Spot gRPC: \(m)"
        }
    }
}

/// Spot (E2EE key) API over gRPC/HTTP-2. Mirrors SpotApi/spot_request.py.
struct SpotClient {
    /// Returns the account-wide encrypted owner key blob.
    static func encryptedOwnerKey(spotToken: String) async throws -> Data {
        var reqProto = GetEidInfoForE2eeDevicesRequest()
        reqProto.ownerKeyVersion = -1
        reqProto.hasOwnerKeyVersion_p = true
        let payload = try reqProto.serializedData()

        let data = try await call(method: "GetEidInfoForE2eeDevices", payload: payload, spotToken: spotToken)
        let out = try GetEidInfoForE2eeDevicesResponse(serializedBytes: data)
        return out.encryptedOwnerKeyAndMetadata.encryptedOwnerKey
    }

    private static func call(method: String, payload: Data, spotToken: String) async throws -> Data {
        let url = URL(string: "https://spot-pa.googleapis.com/google.internal.spot.v1.SpotService/\(method)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("com.google.android.gms/244433022 grpc-java-cronet/1.69.0-SNAPSHOT",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/grpc", forHTTPHeaderField: "Content-Type")
        request.setValue("trailers", forHTTPHeaderField: "TE")
        request.setValue("Bearer \(spotToken)", forHTTPHeaderField: "Authorization")
        request.setValue("gzip", forHTTPHeaderField: "Grpc-Accept-Encoding")
        request.httpBody = frame(payload)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpotError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try unframe(data)
    }

    /// gRPC length-prefixed framing: 1 flag byte (0 = uncompressed) + big-endian uint32 length.
    private static func frame(_ payload: Data) -> Data {
        var out = Data([0])
        var len = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &len) { out.append(contentsOf: $0) }
        out.append(payload)
        return out
    }

    private static func unframe(_ grpc: Data) throws -> Data {
        guard grpc.count >= 5 else { throw SpotError.grpc(String(localized: "krótka ramka")) }
        let lengthBytes = grpc.subdata(in: 1..<5)
        let length = lengthBytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let start = 5
        let end = start + Int(length)
        guard grpc.count >= end else { throw SpotError.grpc(String(localized: "zła długość")) }
        return grpc.subdata(in: start..<end)
    }
}

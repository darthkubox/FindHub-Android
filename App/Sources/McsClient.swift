// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   firebase-messaging, Copyright (c) 2017 Matthieu Lemoine, (c) 2023 Steven Beth, MIT, https://github.com/sdb9696/firebase-messaging
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import Network
import SwiftProtobuf
import OSLog

private let mcsLog = Logger(subsystem: "pl.mintstudio.findhubandroid", category: "mcs")

/// Minimal MCS (Mobile Connection Server) client — the persistent TLS channel
/// over which Find Hub delivers encrypted location reports as push messages.
/// Ported from Auth/firebase_messaging/fcmpushclient.py (wire framing + login).
@MainActor
final class McsClient {
    static let host = "mtalk.google.com"
    static let port: UInt16 = 5228
    static let version: UInt8 = 41
    // Tag numbers of MCS message types on the wire.
    enum Tag: UInt8 { case heartbeatPing = 0, heartbeatAck = 1, loginRequest = 2,
                           loginResponse = 3, close = 4, iqStanza = 7, dataMessageStanza = 8 }

    private let androidID: UInt64
    private let securityToken: UInt64
    var onDataMessage: ((McsProto_DataMessageStanza) -> Void)?
    var onEvent: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private var conn: NWConnection?
    private var recvBuffer = Data()
    private var firstSend = true
    private var firstRecv = true
    private var lastStreamId: Int32 = 0
    private let loginWaiter = CallbackWaiter<Void>()
    private var loggedIn = false

    init(androidID: UInt64, securityToken: UInt64) {
        self.androidID = androidID
        self.securityToken = securityToken
    }

    /// Connect, send LoginRequest and resume when the server accepts the login.
    func connectAndLogin(timeout: TimeInterval = 30) async throws {
        do {
            try await loginWaiter.wait(timeout: timeout, timeoutError: McsError.timeout) {
                self.doConnect()
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        onDataMessage = nil
        onError = nil
        onEvent = nil
        loginWaiter.resolve(.failure(CancellationError()))
        conn?.stateUpdateHandler = nil
        conn?.cancel()
        conn = nil
    }

    private func doConnect() {
        let params = NWParameters(tls: NWProtocolTLS.Options())
        let c = NWConnection(host: .init(Self.host), port: .init(rawValue: Self.port)!, using: params)
        conn = c
        c.stateUpdateHandler = { [weak self, weak c] state in
            Task { @MainActor in
                guard let self, let c, self.conn === c else { return }
                switch state {
                case .ready:
                    self.sendLogin()
                    self.receiveLoop()
                case .failed(let err): self.failLogin(McsError.transport(err.localizedDescription))
                case .cancelled: self.failLogin(CancellationError())
                default: break
                }
            }
        }
        c.start(queue: .main)
    }

    private func failLogin(_ error: Error) {
        loginWaiter.resolve(.failure(error))
        onError?(error)
    }

    private func succeedLogin() {
        guard !loggedIn else { return }
        loggedIn = true
        loginWaiter.resolve(.success(()))
    }

    // MARK: - Sending

    private func sendLogin() {
        var req = McsProto_LoginRequest()
        req.adaptiveHeartbeat = false
        req.authService = .androidID
        req.authToken = String(securityToken)
        req.id = "94.0.4606.51"
        req.domain = "mcs.android.com"
        req.deviceID = "android-" + String(androidID, radix: 16)
        req.networkType = 1
        req.resource = String(androidID)
        req.user = String(androidID)
        req.useRmq2 = true
        var setting = McsProto_Setting()
        setting.name = "new_vc"; setting.value = "1"
        req.setting = [setting]
        sendMessage(tag: .loginRequest, message: req)
    }

    private func sendHeartbeatAck() {
        var ack = McsProto_HeartbeatAck()
        ack.lastStreamIDReceived = lastStreamId
        sendMessage(tag: .heartbeatAck, message: ack)
    }

    private func sendMessage(tag: Tag, message: SwiftProtobuf.Message) {
        guard let payload = try? message.serializedData() else { return }
        var packet = Data()
        if firstSend { packet.append(Self.version); firstSend = false }
        packet.append(tag.rawValue)
        packet.append(Self.encodeVarint(UInt32(payload.count)))
        packet.append(payload)
        conn?.send(content: packet, completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.failLogin(McsError.transport(error.localizedDescription)) }
        })
    }

    // MARK: - Receiving

    private func receiveLoop() {
        guard let connection = conn else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self, self.conn === connection else { return }
                if let data, !data.isEmpty {
                    self.recvBuffer.append(data)
                    self.drainBuffer()
                }
                if let error { self.failLogin(McsError.transport(error.localizedDescription)); return }
                if isComplete { self.failLogin(McsError.transport(String(localized: "Połączenie zostało zamknięte"))); return }
                self.receiveLoop()
            }
        }
    }

    /// Extract as many complete MCS messages as the buffer holds.
    private func drainBuffer() {
        while true {
            var offset = 0
            // header: [version?][tag]
            if firstRecv {
                guard recvBuffer.count >= 2 else { return }
                offset = 2                    // skip version + tag
            } else {
                guard recvBuffer.count >= 1 else { return }
                offset = 1                    // skip tag
            }
            let tagByte = recvBuffer[firstRecv ? 1 : 0]
            guard let (length, varintLen) = Self.decodeVarint(recvBuffer, at: offset) else { return }
            let headerEnd = offset + varintLen
            let total = headerEnd + Int(length)
            guard recvBuffer.count >= total else { return }   // wait for more bytes
            let payload = recvBuffer.subdata(in: headerEnd..<total)
            recvBuffer.removeSubrange(0..<total)
            firstRecv = false
            handle(tag: tagByte, payload: payload)
        }
    }

    private func handle(tag: UInt8, payload: Data) {
        onEvent?("odebrano tag=\(tag) (\(payload.count) B)")
        mcsLog.notice("recv tag=\(tag, privacy: .public) size=\(payload.count, privacy: .public)")
        switch Tag(rawValue: tag) {
        case .loginResponse:
            guard let response = try? McsProto_LoginResponse(serializedBytes: payload), !response.hasError else {
                failLogin(McsError.transport(String(localized: "Serwer odrzucił logowanie")))
                return
            }
            mcsLog.notice("MCS login ok")
            succeedLogin()
        case .heartbeatPing:
            sendHeartbeatAck()
        case .dataMessageStanza:
            if let stanza = try? McsProto_DataMessageStanza(serializedBytes: payload) {
                lastStreamId = stanza.streamID
                mcsLog.notice("DATA raw=\(stanza.rawData.count, privacy: .public)B")
                onDataMessage?(stanza)
            } else {
                mcsLog.error("DATA parse failed")
            }
        case .close:
            mcsLog.error("MCS server closed")
            failLogin(McsError.transport("server closed"))
        default:
            break
        }
    }

    // MARK: - varint

    static func encodeVarint(_ value: UInt32) -> Data {
        var v = value, out = Data()
        repeat {
            var b = UInt8(v & 0x7F); v >>= 7
            if v != 0 { b |= 0x80 }
            out.append(b)
        } while v != 0
        return out
    }

    /// Returns (value, bytesConsumed) or nil if the buffer doesn't hold a full varint yet.
    static func decodeVarint(_ data: Data, at start: Int) -> (UInt32, Int)? {
        var result: UInt32 = 0, shift: UInt32 = 0, i = start
        while i < data.count {
            let b = data[i]
            result |= UInt32(b & 0x7F) << shift
            i += 1
            if b & 0x80 == 0 { return (result, i - start) }
            shift += 7
            if shift > 28 { return nil }
        }
        return nil
    }
}

enum McsError: LocalizedError {
    case timeout
    case transport(String)
    var errorDescription: String? {
        switch self {
        case .timeout: return String(localized: "MCS: przekroczono czas połączenia")
        case .transport(let m): return "MCS: \(m)"
        }
    }
}

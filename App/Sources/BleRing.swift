// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreBluetooth
import OSLog

private let bleLog = Logger(subsystem: "pl.mintstudio.findhubandroid", category: "ble")

enum BleError: LocalizedError {
    case unavailable
    case timeout
    case notFound
    var errorDescription: String? {
        switch self {
        case .unavailable: return String(localized: "Bluetooth niedostępny/wyłączony")
        case .timeout: return String(localized: "Nie znaleziono taga w pobliżu (limit czasu)")
        case .notFound: return String(localized: "Tag nie udostępnia usługi dzwonienia")
        }
    }
}

/// Rings a nearby tracker over Bluetooth using the standardized DULT
/// (Detecting Unwanted Location Trackers) Accessory Non-Owner Service — the same
/// unauthenticated "play sound" that iOS uses for unwanted-tracker alerts.
/// No owner keys required; connects to the strongest nearby tag (the one in hand).
@MainActor
final class BleRing: NSObject {
    // Advertisement service data seen from provisioned FMDN beacons.
    static let fmdnService = CBUUID(string: "FEAA")
    static let fastPairService = CBUUID(string: "FE2C")
    // DULT Accessory Non-Owner Service + non-owner control point.
    static let anosService = CBUUID(string: "15190001-12F4-C226-88ED-2AC5579F2A85")
    static let controlPoint = CBUUID(string: "8E0C0001-1D68-FB92-BF61-48377421680E")
    // DULT command opcodes (little-endian on the wire).
    static let soundStart: [UInt8] = [0x00, 0x03]   // 0x0300

    @discardableResult
    static func ring(timeout: TimeInterval = 20,
                     onProgress: @escaping (String) -> Void = { _ in }) async throws -> Data {
        let session = BleRing(onProgress: onProgress)
        defer { session.cleanup() }
        return try await session.waiter.wait(timeout: timeout, timeoutError: BleError.timeout) {
            session.central = CBCentralManager(delegate: session, queue: .main)
        }
    }

    private let progress: (String) -> Void
    private func p(_ s: String) { progress(s) }

    private var central: CBCentralManager!
    private var candidates: [(peripheral: CBPeripheral, rssi: Int)] = []
    private var active: CBPeripheral?
    private let waiter = CallbackWaiter<Data>()
    private var finished = false
    private var startedConnecting = false
    private var wroteCommand = false
    private var scanWindowElapsed = false

    private init(onProgress: @escaping (String) -> Void) {
        self.progress = onProgress
        super.init()
    }

    private func finish(_ result: Result<Data, Error>) {
        guard !finished else { return }
        cleanup()
        waiter.resolve(result)
    }

    private func cleanup() {
        finished = true
        central?.stopScan()
        central?.delegate = nil
        active?.delegate = nil
        if let active { central?.cancelPeripheralConnection(active) }
        candidates.removeAll()
        active = nil
    }

    private func skipCandidate() {
        if let active {
            active.delegate = nil
            central.cancelPeripheralConnection(active)
        }
        active = nil
        wroteCommand = false
        connectNext()
    }

    private func isTagCandidate(_ adv: [String: Any]) -> Bool {
        if let uuids = adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           uuids.contains(Self.fmdnService) || uuids.contains(Self.fastPairService) { return true }
        if let data = adv[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           data[Self.fmdnService] != nil || data[Self.fastPairService] != nil { return true }
        return false
    }
}

// CBCentralManager is explicitly configured with queue: .main above.
extension BleRing: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !finished else { return }
        bleLog.notice("central state = \(central.state.rawValue, privacy: .public)")
        switch central.state {
        case .poweredOn:
            p(String(localized: "BLE: skanuję w poszukiwaniu tagu…"))
            central.scanForPeripherals(withServices: nil,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        case .poweredOff, .unauthorized, .unsupported:
            finish(.failure(BleError.unavailable))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard !finished, RSSI.intValue != 127, isTagCandidate(advertisementData) else { return }
        guard active?.identifier != peripheral.identifier,
              !candidates.contains(where: { $0.peripheral.identifier == peripheral.identifier }) else { return }
        candidates.append((peripheral, RSSI.intValue))
        p(String(localized: "BLE: znaleziono \(candidates.count) tag(ów) w pobliżu…"))
        if !startedConnecting {
            startedConnecting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.scanWindowElapsed = true
                self?.connectNext()
            }
        } else if scanWindowElapsed {
            connectNext()
        }
    }

    private func connectNext() {
        guard !finished, active == nil else { return }
        guard let idx = candidates.indices.max(by: { candidates[$0].rssi < candidates[$1].rssi }) else { return }
        let c = candidates.remove(at: idx)
        wroteCommand = false
        active = c.peripheral
        c.peripheral.delegate = self
        p(String(localized: "BLE: łączę z najbliższym tagiem…"))
        central.connect(c.peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !finished, peripheral == active else { return }
        p(String(localized: "BLE: połączono, szukam usługi dzwonienia…"))
        peripheral.discoverServices([Self.anosService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard !finished, peripheral == active else { return }
        skipCandidate()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard !finished, peripheral == active else { return }
        if wroteCommand {
            finish(.failure(error ?? BleError.notFound))
        } else {
            skipCandidate()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard !finished, peripheral == active else { return }
        guard error == nil, let svc = peripheral.services?.first(where: { $0.uuid == Self.anosService }) else {
            bleLog.notice("no ANOS service")
            skipCandidate(); return
        }
        peripheral.discoverCharacteristics([Self.controlPoint], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard !finished, peripheral == active else { return }
        guard error == nil, let ch = service.characteristics?.first(where: { $0.uuid == Self.controlPoint }) else {
            bleLog.notice("no DULT control point")
            skipCandidate(); return
        }
        // Enable indications for the command response, then send the sound command.
        peripheral.setNotifyValue(true, for: ch)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard !finished, peripheral == active, !wroteCommand,
              characteristic.uuid == Self.controlPoint else { return }
        if let error { finish(.failure(error)); return }
        guard characteristic.isNotifying else { finish(.failure(BleError.notFound)); return }
        wroteCommand = true
        p(String(localized: "BLE: wysyłam komendę dzwonienia (DULT)…"))
        peripheral.writeValue(Data(Self.soundStart), for: characteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard !finished, peripheral == active, characteristic.uuid == Self.controlPoint else { return }
        if let error {
            bleLog.error("DULT write failed: \(error.localizedDescription, privacy: .public)")
            p(String(localized: "BLE: zapis odrzucony: \(error.localizedDescription)"))
            finish(.failure(error))
        } else {
            bleLog.notice("DULT sound command written")
            // ATT write acknowledgement confirms delivery, not an audible sound.
            finish(.success(Data()))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard !finished, peripheral == active, characteristic.uuid == Self.controlPoint else { return }
        if let error { finish(.failure(error)) }
        // An indication alone is not proof that the sound command succeeded.
        // Completion is based on the ATT write result above.
    }
}

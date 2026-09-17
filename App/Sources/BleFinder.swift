// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreBluetooth
import OSLog

private let finderLog = Logger(subsystem: "pl.mintstudio.tagpin", category: "finder")

/// Live BLE proximity finder ("hot/cold"). Continuously scans for FMDN tags and
/// reports a smoothed signal strength for the target. When the target device's
/// expected EID prefixes are known, it locks onto that exact tag; otherwise it
/// tracks the strongest nearby FMDN tag and marks the reading as unconfirmed.
@MainActor
final class BleFinder: NSObject, ObservableObject {
    /// 0 (far / no signal) … 1 (right next to the phone).
    @Published private(set) var level: Double = 0
    @Published private(set) var rssi: Int?
    /// True when the tracked tag's advertised EID matches the requested device.
    @Published private(set) var locked = false
    @Published private(set) var nearbyCount = 0
    @Published private(set) var status = String(localized: "Włącz Bluetooth i trzymaj tag w pobliżu.")
    @Published private(set) var available = true

    private var central: CBCentralManager?
    /// 10-byte EID prefixes we accept as "this is the device" (empty → any tag).
    private var expectedPrefixes: Set<Data> = []
    private struct Seen { var rssi: Double; var at: Date; var matches: Bool }
    private var seen: [UUID: Seen] = [:]
    private var ticker: Timer?

    /// RSSI (dBm) mapped to 0…1. -35 or stronger = 1, -95 or weaker = 0.
    private static func normalize(_ dbm: Double) -> Double {
        max(0, min(1, (dbm + 95) / 60))
    }

    func start(expectedEIDPrefixes: Set<Data>) {
        expectedPrefixes = expectedEIDPrefixes
        seen.removeAll()
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else if central?.state == .poweredOn { beginScan() }
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        ticker?.invalidate(); ticker = nil
        central?.stopScan()
        central?.delegate = nil
        central = nil
        seen.removeAll()
        level = 0; rssi = nil; locked = false; nearbyCount = 0
    }

    private func beginScan() {
        central?.scanForPeripherals(withServices: nil,
                                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        status = expectedPrefixes.isEmpty
            ? String(localized: "Szukam najbliższego tagu…")
            : String(localized: "Szukam tego urządzenia w pobliżu…")
    }

    /// Drop stale peripherals and recompute the tracked target + level.
    private func refresh() {
        let now = Date()
        seen = seen.filter { now.timeIntervalSince($0.value.at) < 4 }
        nearbyCount = seen.count

        // Prefer a peripheral whose EID matches the requested device.
        let matched = seen.filter { $0.value.matches }
        let pool = matched.isEmpty ? seen : matched
        guard let best = pool.max(by: { $0.value.rssi < $1.value.rssi }) else {
            rssi = nil
            level = max(0, level - 0.15)   // decay toward cold when nothing is seen
            locked = false
            status = expectedPrefixes.isEmpty ? String(localized: "Brak tagów w pobliżu.") : String(localized: "Nie widzę tego tagu. Podejdź bliżej.")
            return
        }
        locked = best.value.matches
        rssi = Int(best.value.rssi.rounded())
        // Smooth toward the new reading so the UI moves gently.
        level += (Self.normalize(best.value.rssi) - level) * 0.35
        status = locked ? String(localized: "To urządzenie jest w pobliżu.") :
            (expectedPrefixes.isEmpty ? String(localized: "Najbliższy tag.") : String(localized: "Widzę tag, ale nie potwierdzono, że to ten."))
    }

    private func matchesTarget(_ serviceData: [CBUUID: Data]) -> Bool {
        guard !expectedPrefixes.isEmpty,
              let fmdn = serviceData[BleRing.fmdnService], fmdn.count >= 21 else { return false }
        let eid = fmdn.subdata(in: 1..<21)          // [frameType][20-byte EID][flags]
        return expectedPrefixes.contains(eid.prefix(10))
    }

    private func isTag(_ adv: [String: Any]) -> Bool {
        if let data = adv[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           data[BleRing.fmdnService] != nil || data[BleRing.fastPairService] != nil { return true }
        if let uuids = adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           uuids.contains(BleRing.fmdnService) || uuids.contains(BleRing.fastPairService) { return true }
        return false
    }
}

extension BleFinder: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: available = true; beginScan()
        case .poweredOff, .unauthorized, .unsupported:
            available = false
            status = String(localized: "Bluetooth jest wyłączony lub niedostępny.")
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard RSSI.intValue != 127, isTag(advertisementData) else { return }
        let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        let matches = matchesTarget(serviceData)
        seen[peripheral.identifier] = Seen(rssi: Double(RSSI.intValue), at: Date(), matches: matches)
    }
}

// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Combine
import CoreBluetooth
import UserNotifications
import UIKit

/// Connection-based separation monitoring. Missing scan packets alone never
/// trigger an alarm: iOS coalesces those packets while the app is suspended.
@MainActor
final class DeviceProtection: NSObject, ObservableObject {
    static let shared = DeviceProtection()
    @Published private(set) var bluetoothStatus = String(localized: "Pilnowanie Bluetooth wyłączone")
    @Published private(set) var deviceStatus: [String: String] = [:]
    @Published private(set) var notificationsAllowed = false
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var notificationMessage: String?
    private let journal = TrackerJournal.shared
    private let notifications = UNUserNotificationCenter.current()
    private var central: CBCentralManager?
    private var monitoredAccount: String?
    private var peripherals: [String: CBPeripheral] = [:]
    private var watches: [String: SeparationWatch] = [:]
    private var restoredLosses = Set<String>()
    private var pendingAlerts: [String: String] = [:]
    private var eidCache: [String: Set<Data>] = [:]
    private var eidPeriod: UInt64 = 0
    private var started = false

    func start() {
        guard !started else { return }; started = true
        notifications.delegate = self
        journal.configurationChanged = { [weak self] in self?.configure() }
        configure()
        Task { await refreshNotificationPermission() }
    }

    func refreshNotificationPermission() async {
        let settings = await notifications.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        notificationsAllowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        notificationMessage = notificationsAllowed ? nil : String(localized: "Włącz powiadomienia, aby otrzymywać alerty.")
    }

    func requestNotifications() async -> Bool {
        do {
            let granted = try await notifications.requestAuthorization(options: [.alert, .sound])
            await refreshNotificationPermission()
            return granted
        } catch {
            notificationMessage = String(localized: "Nie udało się włączyć powiadomień. Spróbuj ponownie.")
            return false
        }
    }

    func configure() {
        let accountChanged = monitoredAccount != journal.account
        if accountChanged {
            for peripheral in peripherals.values { central?.cancelPeripheralConnection(peripheral) }
            for requestID in pendingAlerts.values { notifications.removePendingNotificationRequests(withIdentifiers: [requestID]) }
            peripherals = [:]; watches = [:]; restoredLosses = []; pendingAlerts = [:]; deviceStatus = [:]; eidCache = [:]
            monitoredAccount = journal.account
            // Clear outstanding requests from a previous launch/account as well.
            let expectedAccount = journal.account
            Task {
                let requests = await notifications.pendingNotificationRequests()
                guard journal.account == expectedAccount else { return }
                notifications.removePendingNotificationRequests(withIdentifiers: requests.filter {
                    $0.identifier.hasPrefix("guardian.") && ($0.content.userInfo["account"] as? String) != expectedAccount
                }.map(\.identifier))
            }
        }
        let enabled = journal.document.devices.filter { $0.value.closeDevice }
        let account = journal.account
        Task {
            let requests = await notifications.pendingNotificationRequests()
            guard journal.account == account else { return }
            notifications.removePendingNotificationRequests(withIdentifiers: requests.filter { request in
                guard request.content.userInfo["account"] as? String == account,
                      request.content.userInfo["kind"] as? String == "separation",
                      let id = request.content.userInfo["device"] as? String else { return false }
                return !journal.device(id).closeDevice
            }.map(\.identifier))
        }
        for id in Array(peripherals.keys) where enabled[id] == nil {
            cancelAlert(id)
            if let peripheral = peripherals.removeValue(forKey: id) { central?.cancelPeripheralConnection(peripheral) }
            watches.removeValue(forKey: id); deviceStatus.removeValue(forKey: id)
        }
        eidCache = [:]
        guard journal.account != nil, !enabled.isEmpty else {
            central?.stopScan(); bluetoothStatus = String(localized: "Pilnowanie Bluetooth wyłączone"); return
        }
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main, options: [
                CBCentralManagerOptionRestoreIdentifierKey: "pl.mintstudio.findhubandroid.protection",
                CBCentralManagerOptionShowPowerAlertKey: false
            ])
        } else if central?.state == .poweredOn { scanAndReconnect() }
    }

    private func scanAndReconnect() {
        guard let central, central.state == .poweredOn else { return }
        bluetoothStatus = String(localized: "Bluetooth włączony")
        for (id, record) in journal.document.devices where record.closeDevice {
            if let existing = peripherals[id], existing.state == .connected || existing.state == .connecting { continue }
            if let uuid = record.peripheralID, let peripheral = central.retrievePeripherals(withIdentifiers: [uuid]).first {
                peripherals[id] = peripheral
                if peripheral.state == .connected { didConnect(id) }
                else { deviceStatus[id] = String(localized: "Łączę z zapamiętanym tagiem…"); central.connect(peripheral) }
            } else { deviceStatus[id] = String(localized: "Podejdź do taga — oczekiwanie na potwierdzenie tożsamości") }
        }
        central.scanForPeripherals(withServices: [BleRing.fmdnService], options: nil)
    }

    private func expectedEIDs(_ id: String, record: DeviceJournal) -> Set<Data> {
        let period = UInt64(Date().timeIntervalSince1970) / 1024
        if eidPeriod != period { eidCache = [:]; eidPeriod = period }
        if let cached = eidCache[id] { return cached }
        guard let owner = Session.shared.ownerKey, let encrypted = record.encryptedIdentityKey else { return [] }
        let keys = FMDNCrypto.identityKeyCandidates(ownerKey: owner, sharedKey: Session.shared.sharedKey,
                                                   encryptedEIK: encrypted, deviceIDs: [id], isMCU: false)
        var result = Set<Data>()
        for key in keys {
            for step in -7...7 {
                let time = Int64(period * 1024) + Int64(step * 1024)
                if time >= 0, time <= UInt32.max, let eid = ForeignTrackerCryptor.eid(identityKey: key, timeCounter: UInt32(time)) {
                    result.insert(eid)
                }
            }
            if let eid = ForeignTrackerCryptor.eid(identityKey: key, timeCounter: 0) { result.insert(eid) }
        }
        eidCache[id] = result
        return result
    }

    private func deviceID(for peripheral: CBPeripheral) -> String? {
        peripherals.first { $0.value.identifier == peripheral.identifier }?.key
    }

    private func didConnect(_ id: String) {
        guard journal.device(id).closeDevice else { return }
        watches[id, default: SeparationWatch()].connected(); cancelAlert(id)
        deviceStatus[id] = String(localized: "Połączono — pilnuję utraty kontaktu")
        let record = journal.device(id)
        if record.connectionArmed != true {
            _ = journal.updateDevice(id, name: record.name) { $0.connectionArmed = true }
        }
    }

    private func cancelAlert(_ id: String) {
        if let requestID = pendingAlerts.removeValue(forKey: id) {
            notifications.removePendingNotificationRequests(withIdentifiers: [requestID])
        }
        // A pending alarm can survive process restoration. Remove only this
        // device's separation alarms, keeping unrelated place notifications.
        let account = journal.account
        Task {
            let requests = await notifications.pendingNotificationRequests()
            guard journal.account == account, watches[id]?.isConnected == true || !journal.device(id).closeDevice
                    || central?.state != .poweredOn else { return }
            notifications.removePendingNotificationRequests(withIdentifiers: requests.filter {
                $0.content.userInfo["kind"] as? String == "separation"
                    && $0.content.userInfo["device"] as? String == id
                    && $0.content.userInfo["account"] as? String == account
            }.map(\.identifier))
        }
    }

    private func separation(_ id: String) {
        guard let account = journal.account, journal.device(id).closeDevice,
              AppSettings.shared.notifySeparation, pendingAlerts[id] == nil else { return }
        let record = journal.device(id)
        let requestID = "guardian.separation." + UUID().uuidString
        pendingAlerts[id] = requestID
        deviceStatus[id] = String(localized: "Utracono kontakt — czekam \(Int(record.disconnectDelay)) s na ponowne połączenie")
        let content = UNMutableNotificationContent()
        let text = NotificationText.separation(deviceName: record.name, showDetails: AppSettings.shared.notificationDetails)
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = ["account": account, "device": id, "kind": "separation", "scheduledAt": Date().timeIntervalSince1970]
        let request = UNNotificationRequest(identifier: requestID, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: record.disconnectDelay, repeats: false))
        Task {
            do {
                try await notifications.add(request)
                if journal.account != account || pendingAlerts[id] != requestID || !journal.device(id).closeDevice {
                    notifications.removePendingNotificationRequests(withIdentifiers: [requestID])
                }
            } catch { notificationMessage = String(localized: "Nie udało się zaplanować alertu utraty kontaktu.") }
        }
    }

    func deliver(_ events: [PlaceExitEvent]) {
        guard let account = journal.account, AppSettings.shared.notifyPlaceExit else { return }
        for event in events {
            let content = UNMutableNotificationContent()
            let text = NotificationText.placeExit(deviceName: event.deviceName, placeName: event.placeName,
                                                  reportedAt: event.reportedAt, showDetails: AppSettings.shared.notificationDetails)
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.userInfo = ["account": account, "device": event.deviceID, "kind": "place"]
            let requestID = "guardian.place." + UUID().uuidString
            Task {
                guard journal.account == account, journal.device(event.deviceID).placeAlerts,
                      journal.device(event.deviceID).placeIDs.contains(event.placeID) else { return }
                do {
                    try await notifications.add(UNNotificationRequest(identifier: requestID, content: content, trigger: nil))
                    if journal.account != account {
                        notifications.removePendingNotificationRequests(withIdentifiers: [requestID])
                        notifications.removeDeliveredNotifications(withIdentifiers: [requestID])
                    }
                } catch { notificationMessage = String(localized: "Nie udało się wysłać powiadomienia o opuszczeniu miejsca.") }
            }
        }
    }

    /// Schedules a sample alert a few seconds ahead, so the user can lock the phone
    /// and check that banners, sound and the lock screen really work.
    func sendTestNotification(after seconds: TimeInterval = 5) async -> Bool {
        guard await requestNotifications() else { return false }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "FindHub Android — test")
        content.body = String(localized: "Powiadomienia działają. Tak będą wyglądać alerty o miejscach i utracie kontaktu.")
        content.sound = .default
        content.userInfo = ["kind": "test"]
        let request = UNNotificationRequest(identifier: "findhub.test." + UUID().uuidString, content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        do { try await notifications.add(request); return true }
        catch { notificationMessage = String(localized: "Nie udało się zaplanować powiadomienia testowego."); return false }
    }

    /// Withdraws pending and already delivered alerts of one account, which may
    /// show device and place names on the lock screen.
    func removeNotifications(for account: String) async {
        let belongs: (UNNotificationContent) -> Bool = { $0.userInfo["account"] as? String == account }
        let pending = await notifications.pendingNotificationRequests().filter { belongs($0.content) }
        notifications.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
        let delivered = await notifications.deliveredNotifications().filter { belongs($0.request.content) }
        notifications.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier))
    }
}

extension DeviceProtection: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            // Switching Bluetooth off is not evidence that the owner walked away.
            watches.removeAll()
            restoredLosses = []
            for id in Array(pendingAlerts.keys) { cancelAlert(id) }
            let account = journal.account
            let cutoff = Date().timeIntervalSince1970
            Task {
                let requests = await notifications.pendingNotificationRequests()
                guard journal.account == account else { return }
                notifications.removePendingNotificationRequests(withIdentifiers: requests.filter {
                    $0.content.userInfo["kind"] as? String == "separation"
                        && $0.content.userInfo["account"] as? String == account
                        && ($0.content.userInfo["scheduledAt"] as? Double ?? 0) <= cutoff
                }.map(\.identifier))
            }
            for (id, record) in journal.document.devices where record.connectionArmed == true {
                _ = journal.updateDevice(id, name: record.name) { $0.connectionArmed = false }
            }
            bluetoothStatus = central.state == .unauthorized ? String(localized: "Brak dostępu do Bluetooth — pilnowanie wstrzymane") : String(localized: "Bluetooth niedostępny — pilnowanie wstrzymane")
            for id in peripherals.keys { deviceStatus[id] = String(localized: "Pilnowanie wstrzymane") }
            return
        }
        let lost = restoredLosses; restoredLosses = []
        for id in lost where journal.device(id).closeDevice && peripherals[id]?.state != .connected {
            let record = journal.device(id)
            _ = journal.updateDevice(id, name: record.name) { $0.connectionArmed = false }
            separation(id)
        }
        if journal.document.devices.values.contains(where: \.closeDevice) { scanAndReconnect() }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard journal.account == monitoredAccount,
              let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
              let bytes = serviceData[BleRing.fmdnService], bytes.count >= 21 else { return }
        let eid = bytes.subdata(in: 1..<21)
        let matches = journal.document.devices.filter { $0.value.closeDevice && expectedEIDs($0.key, record: $0.value).contains(eid) }
        guard matches.count == 1, let (id, record) = matches.first else { return }
        if let current = peripherals[id], current.state == .connected || current.state == .connecting { return }
        peripherals[id] = peripheral
        if record.peripheralID != peripheral.identifier {
            _ = journal.updateDevice(id, name: record.name) { $0.peripheralID = peripheral.identifier }
        }
        deviceStatus[id] = String(localized: "Tag potwierdzony — nawiązuję połączenie…")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let id = deviceID(for: peripheral) else { central.cancelPeripheralConnection(peripheral); return }
        didConnect(id)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let id = deviceID(for: peripheral) else { return }
        deviceStatus[id] = String(localized: "Nie udało się połączyć. Ten tag może nie obsługiwać pilnowania w tle.")
        // No alarm: a first successful connection is required to arm protection.
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let id = deviceID(for: peripheral), journal.device(id).closeDevice else { return }
        let previouslyArmed = journal.device(id).connectionArmed == true
        let armed = watches[id, default: SeparationWatch()].disconnected(bluetoothAvailable: central.state == .poweredOn) || previouslyArmed
        if previouslyArmed {
            _ = journal.updateDevice(id, name: journal.device(id).name) { $0.connectionArmed = false }
        }
        guard central.state == .poweredOn else { cancelAlert(id); return }
        if armed { separation(id) }
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        for peripheral in restored {
            guard let id = journal.document.devices.first(where: { $0.value.closeDevice && $0.value.peripheralID == peripheral.identifier })?.key else {
                central.cancelPeripheralConnection(peripheral); continue
            }
            peripherals[id] = peripheral
            if peripheral.state == .connected { didConnect(id) }
            else if journal.device(id).connectionArmed == true { restoredLosses.insert(id) }
        }
    }
}

extension DeviceProtection: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

/// Alert wording, optionally without device and place names, which are otherwise
/// readable on the lock screen.
enum NotificationText {
    static func placeExit(deviceName: String, placeName: String, reportedAt: Date,
                          showDetails: Bool) -> (title: String, body: String) {
        guard showDetails else {
            return (String(localized: "Urządzenie opuściło miejsce"),
                    String(localized: "Otwórz aplikację, aby zobaczyć szczegóły."))
        }
        return (String(localized: "\(deviceName) poza miejscem: \(placeName)"),
                String(localized: "Dwa raporty potwierdziły pozycję poza obszarem. Ostatni: \(LocationPresentation.fullDate(reportedAt))."))
    }

    static func separation(deviceName: String, showDetails: Bool) -> (title: String, body: String) {
        (showDetails ? String(localized: "Czy masz przy sobie \(deviceName)?")
                     : String(localized: "Utracono kontakt z urządzeniem"),
         String(localized: "Utracono połączenie Bluetooth. Przedmiot może być poza zasięgiem."))
    }
}

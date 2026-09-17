// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Portions ported from:
//   GoogleFindMyTools, Copyright (c) 2024 Leon Böttger, GPL-3.0, https://github.com/leonboe1/GoogleFindMyTools

import Foundation
import SwiftProtobuf
import OSLog

private let novaLog = Logger(subsystem: "pl.mintstudio.findhubandroid", category: "nova")

struct TrackerDevice: Identifiable, Hashable {
    let id: String     // canonic id
    let name: String
    /// Per-tag encrypted identity key from device metadata (nil if not present).
    /// Decrypted with the owner key → identity key → ring key (BLE).
    var encryptedIdentityKey: Data?
    /// Google-hosted product render URL from device metadata (as Find Hub uses).
    var imageURL: String?
    /// SF Symbol matching the category the user assigned in Find Hub (nil if unknown).
    var categorySymbol: String?
    var manufacturer: String?
    var modelName: String?
    var pairedAt: Date?
    /// True when the current account has access but is not the owner (shared with me).
    var sharedWithMe: Bool = false
    /// Owner's email, shown on devices shared with me.
    var ownerEmail: String?
}

/// Map the Find Hub device category to a clean SF Symbol (Apple's own icons).
func categorySymbol(for type: SpotDeviceType) -> String? {
    switch type {
    case .deviceTypeHeadphones: return "headphones"
    case .deviceTypeEarbuds: return "airpods"
    case .deviceTypeKeys: return "key.fill"
    case .deviceTypeWatch: return "applewatch"
    case .deviceTypeWallet: return "wallet.pass.fill"
    case .deviceTypeBag: return "bag.fill"
    case .deviceTypeLaptop: return "laptopcomputer"
    case .deviceTypeCar: return "car.fill"
    case .deviceTypeBike: return "bicycle"
    case .deviceTypeCamera: return "camera.fill"
    case .deviceTypeCat, .deviceTypeDog: return "pawprint.fill"
    case .deviceTypeCharger: return "powerplug.fill"
    case .deviceTypeClothing: return "tshirt.fill"
    case .deviceTypeNotebook, .deviceTypePassport: return "book.closed.fill"
    case .deviceTypePhone: return "iphone"
    case .deviceTypeSpeaker: return "hifispeaker.fill"
    case .deviceTypeTablet: return "ipad"
    case .deviceTypeToy: return "teddybear.fill"
    case .deviceTypeUmbrella: return "umbrella.fill"
    case .deviceTypeStylus: return "pencil.tip"
    case .deviceTypeBadge: return "person.text.rectangle.fill"
    case .deviceTypeBeacon: return "dot.radiowaves.left.and.right"
    default: return nil
    }
}

enum NovaError: LocalizedError {
    case http(Int)
    var errorDescription: String? {
        switch self {
        case .http(let code): return "Nova HTTP \(code)"
        }
    }
}

/// Find Hub / Nova device listing. Mirrors NovaApi/ListDevices in the reference.
struct Nova {
    static func listDevices(admToken: String) async throws -> [TrackerDevice] {
        var payload = DevicesListRequest()
        payload.deviceListRequestPayload.type = .spotDevice
        payload.deviceListRequestPayload.id = UUID().uuidString

        var request = URLRequest(url: URL(string: "https://android.googleapis.com/nova/nbe_list_devices")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(admToken)", forHTTPHeaderField: "Authorization")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue("fmd/20006320; gzip", forHTTPHeaderField: "User-Agent")
        request.httpBody = try payload.serializedData()

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NovaError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let list = try DevicesList(serializedBytes: data)
        novaLog.notice("nbe_list_devices returned \(list.deviceMetadata.count, privacy: .public) devices")
        var result: [TrackerDevice] = []
        for device in list.deviceMetadata {
            // Collect canonic ids from BOTH fields (some device types populate one or
            // the other), keeping order and dropping empties/duplicates.
            var seen = Set<String>()
            let ids: [CanonicId] = (device.identifierInformation.canonicIds.canonicID
                + device.identifierInformation.phoneInformation.canonicIds.canonicID)
                .filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
            let idType = device.identifierInformation.type
            novaLog.notice("device name=\(device.userDefinedDeviceName, privacy: .private) type=\(String(describing: idType), privacy: .public) spotType=\(String(describing: device.information.deviceRegistration.deviceTypeInformation.deviceType), privacy: .public) ids=\(ids.count, privacy: .public)")
            let reg = device.information.deviceRegistration
            let encIdentity = reg.encryptedUserSecrets.encryptedIdentityKey
            let imageURL = device.imageInformation.imageURL
            let catSymbol = categorySymbol(for: reg.deviceTypeInformation.deviceType)
            // Ownership: the entry for the current account tells us owner vs. shared.
            let access = device.information.accessInformation
            let mine = access.first { $0.thisAccount }
            let sharedWithMe = mine != nil && !mine!.isOwner
            let ownerEmail = access.first { $0.isOwner }?.email
            // Skip companion devices Google returns without a canonic id (e.g. a Wear OS
            // watch tied to a phone): they can't be located or rung, so we don't list them.
            for cid in ids {
                result.append(TrackerDevice(
                    id: cid.id,
                    name: device.userDefinedDeviceName,
                    encryptedIdentityKey: encIdentity.isEmpty ? nil : encIdentity,
                    imageURL: imageURL.isEmpty ? nil : imageURL,
                    categorySymbol: catSymbol,
                    manufacturer: reg.manufacturer.isEmpty ? nil : reg.manufacturer,
                    modelName: reg.model.isEmpty ? nil : reg.model,
                    pairedAt: reg.pairDate > 0 ? Date(timeIntervalSince1970: TimeInterval(reg.pairDate)) : nil,
                    sharedWithMe: sharedWithMe,
                    ownerEmail: (ownerEmail?.isEmpty == false) ? ownerEmail : nil))
            }
        }
        return result
    }

    /// Fixed per app run, mirrors the reference client's fmdClientUuid.
    private static let clientID = UUID().uuidString

    /// Request a location update for a device. The encrypted report is delivered
    /// asynchronously via FCM/MCS push (not in this HTTP response).
    static func sendLocate(canonicId: String, fcmToken: String, requestUuid: String,
                           admToken: String) async throws {
        var req = ExecuteActionRequest()
        req.scope.type = .spotDevice
        req.scope.device.canonicID.id = canonicId
        req.requestMetadata.type = .spotDevice
        req.requestMetadata.requestUuid = requestUuid
        req.requestMetadata.fmdClientUuid = clientID
        req.requestMetadata.gcmRegistrationID.id = fcmToken
        req.requestMetadata.unknown = true
        req.action.locateTracker.lastHighTrafficEnablingTime.seconds = 1732120060
        req.action.locateTracker.contributorType = .fmdnAllLocations

        var request = URLRequest(url: URL(string: "https://android.googleapis.com/nova/nbe_execute_action")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(admToken)", forHTTPHeaderField: "Authorization")
        request.setValue("en-US", forHTTPHeaderField: "Accept-Language")
        request.setValue("fmd/20006320; gzip", forHTTPHeaderField: "User-Agent")
        request.httpBody = try req.serializedData()

        let (_, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NovaError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

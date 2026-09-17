// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreLocation
import SwiftProtobuf

/// Pure report decoding, separate from FCM transport so real protobuf messages
/// and authenticated crypto paths can be tested without an account or network.
enum LocationReportDecoder {
    static func deviceIDs(in update: DeviceUpdate) -> [String] {
        let info = update.deviceMetadata.identifierInformation
        return Array(Set((info.canonicIds.canonicID + info.phoneInformation.canonicIds.canonicID)
            .map(\.id).filter { !$0.isEmpty })).sorted()
    }

    static func decode(_ update: DeviceUpdate, ownerKey: Data, sharedKey: Data? = nil) -> LocationResponse {
        let ids = deviceIDs(in: update)
        let info = update.deviceMetadata.information
        let reg = info.deviceRegistration
        let wrap = info.locationInformation.reports.recentLocationAndNetworkLocations
        // Missing timestamps must not silently truncate the reports via zip().
        var pairs: [(LocationReport, Time)] = wrap.networkLocations.enumerated().map { index, report in
            (report, index < wrap.networkLocationTimestamps.count ? wrap.networkLocationTimestamps[index] : Time())
        }
        if wrap.hasRecentLocation { pairs.append((wrap.recentLocation, wrap.recentLocationTimestamp)) }

        var coordinates: [DecryptedLocation] = []
        var namedPlaces: [NamedLocationReport] = []
        var candidates: [Data]?
        var own = 0, network = 0, authFailures = 0, invalidPayloads = 0, missingGeo = 0
        var unsupportedKeySizes = Set<Int>()
        for (report, time) in pairs {
            let date = Date(timeIntervalSince1970: TimeInterval(time.seconds))
            let placeName = report.semanticLocation.locationName
            if report.hasSemanticLocation && !placeName.isEmpty {
                namedPlaces.append(NamedLocationReport(name: placeName, time: date))
            }
            let encrypted = report.geoLocation.encryptedReport
            guard report.hasGeoLocation, !encrypted.encryptedLocation.isEmpty else {
                if placeName.isEmpty { missingGeo += 1 }
                continue
            }
            // Status defaults to semantic in proto3; presence of encrypted geo
            // data is what determines whether there is a coordinate to decode.
            let foreign = !encrypted.publicKeyRandom.isEmpty
            if foreign { network += 1 } else { own += 1 }
            if foreign && encrypted.publicKeyRandom.count != 20 {
                unsupportedKeySizes.insert(encrypted.publicKeyRandom.count)
                continue
            }
            if candidates == nil {
                candidates = FMDNCrypto.identityKeyCandidates(ownerKey: ownerKey, sharedKey: sharedKey,
                    encryptedEIK: reg.encryptedUserSecrets.encryptedIdentityKey,
                    deviceIDs: ids, isMCU: reg.fastPairModelID == "003200")
            }
            var plaintext: Data?
            for key in candidates ?? [] {
                if foreign {
                    plaintext = try? ForeignTrackerCryptor.decrypt(identityKey: key,
                        encryptedAndTag: encrypted.encryptedLocation, sx: encrypted.publicKeyRandom,
                        timeCounter: reg.fastPairModelID == "003200" ? 0 : report.geoLocation.deviceTimeOffset)
                } else {
                    plaintext = try? FMDNCrypto.decryptAESGCM(key: FMDNCrypto.ownReportKey(identityKey: key),
                        ivAndCiphertext: encrypted.encryptedLocation)
                }
                if plaintext != nil { break }
            }
            guard let plaintext else { authFailures += 1; continue }
            guard let location = try? Location(serializedBytes: plaintext),
                  location.hasLatitude, location.hasLongitude else { invalidPayloads += 1; continue }
            let point = CLLocationCoordinate2D(latitude: Double(location.latitude) / 1e7,
                                              longitude: Double(location.longitude) / 1e7)
            guard CLLocationCoordinate2DIsValid(point) else { invalidPayloads += 1; continue }
            coordinates.append(DecryptedLocation(coordinate: point, time: date, accuracy: Double(report.geoLocation.accuracy)))
        }

        var issue: String?
        if coordinates.isEmpty {
            if !namedPlaces.isEmpty { issue = String(localized: "Google zwrócił nazwę miejsca, bez współrzędnych na mapę.") }
            else if pairs.isEmpty { issue = String(localized: "Google odpowiedział, ale nie dołączył raportu lokalizacji.") }
            else if !unsupportedKeySizes.isEmpty { issue = String(localized: "Ten raport używa nieobsługiwanego jeszcze formatu szyfrowania.") }
            else if candidates?.isEmpty == true { issue = String(localized: "Nie udało się odczytać klucza lokalizacji tego urządzenia.") }
            else if authFailures > 0 { issue = String(localized: "Odebrano raport, ale nie udało się potwierdzić jego odszyfrowania. Spróbuj pobrać świeżą pozycję.") }
            else if invalidPayloads > 0 { issue = String(localized: "Odszyfrowany raport nie zawiera prawidłowych współrzędnych.") }
            else { issue = String(localized: "Raport Google nie zawiera współrzędnych urządzenia.") }
        }
        // Structural counts only. Never include keys, payloads, IDs or coordinates.
        let keyBytes = reg.encryptedUserSecrets.encryptedIdentityKey.count
        let variants = candidates?.count ?? 0
        let keyVersion = reg.encryptedUserSecrets.ownerKeyVersion
        let unsupported = unsupportedKeySizes.sorted().map { String($0) }.joined(separator: ", ")
        let diagnostic = String(localized: "Raporty: \(pairs.count); własne: \(own); sieciowe: \(network); nazwane miejsca: \(namedPlaces.count).") + "\n" +
            String(localized: "Pozycje: \(coordinates.count); niepotwierdzone odszyfrowanie: \(authFailures); nieprawidłowe pozycje: \(invalidPayloads); bez geolokalizacji: \(missingGeo).") + "\n" +
            String(localized: "Klucz urządzenia: \(keyBytes) B; warianty: \(variants); wersja: \(keyVersion).") +
            (unsupportedKeySizes.isEmpty ? "" : "\n" + String(localized: "Nieobsługiwane klucze raportów: \(unsupported) B."))
        return LocationResponse(canonicId: ids.first ?? "", requestID: update.fcmMetadata.requestUuid,
            locations: coordinates.sorted { $0.time > $1.time }, alternateDeviceIDs: ids,
            semanticLocations: namedPlaces.sorted { $0.time > $1.time }, locationIssue: issue,
            diagnosticSummary: diagnostic)
    }
}

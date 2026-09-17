// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreLocation

struct DecryptedLocation {
    let coordinate: CLLocationCoordinate2D
    let time: Date
    let accuracy: Double

    /// Proto3 scalar defaults do not mean that a report is from 1970 or accurate to 0 m.
    var reportedAt: Date? { time.timeIntervalSince1970 > 0 ? time : nil }
    var accuracyMeters: Double? { accuracy.isFinite && accuracy > 0 ? accuracy : nil }
}

struct LocationResponse {
    let canonicId: String
    let requestID: String
    let locations: [DecryptedLocation]
    var alternateDeviceIDs: [String] = []
    var semanticLocations: [NamedLocationReport] = []
    var locationIssue: String?
    var diagnosticSummary: String = ""

    func matches(deviceID: String, requestID: String) -> Bool {
        !deviceID.isEmpty && !requestID.isEmpty &&
        (canonicId == deviceID || alternateDeviceIDs.contains(deviceID)) && self.requestID == requestID
    }
}

struct NamedLocationReport {
    let name: String
    let time: Date
}

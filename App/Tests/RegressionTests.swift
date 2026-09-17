// Tagpin — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MapKit

@main
struct RegressionTests {
    enum Failure: Error { case timeout, rejected }
    @MainActor static var checks = 0

    @MainActor static func check(_ condition: Bool, _ name: String) {
        guard condition else { fatalError("FAIL: \(name)") }
        checks += 1
        print("PASS: \(name)")
    }

    @MainActor static func main() async throws {
        let profile = try JSONDecoder().decode(AccountProfile.self, from: Data(
            #"{"email":"Owner@example.com","picture":"https://lh3.googleusercontent.com/a/photo=s192-c"}"#.utf8))
        let avatar = try profile.avatarURL(for: "owner@example.com")
        check(avatar?.host == "lh3.googleusercontent.com", "Google profile photo accepted for matching account")
        do {
            _ = try profile.avatarURL(for: "other@example.com")
            check(false, "another account's avatar must not be accepted")
        } catch { check(true, "another account's avatar rejected") }
        let noPhoto = try JSONDecoder().decode(AccountProfile.self, from: Data(#"{"email":"owner@example.com"}"#.utf8))
        let absentAvatar = try noPhoto.avatarURL(for: "owner@example.com")
        check(absentAvatar == nil, "missing Google photo allows monogram fallback")
        for url in ["http://lh3.googleusercontent.com/a/photo", "https://googleusercontent.com.evil.example/photo",
                    "file:///tmp/photo", "https://user:secret@lh3.googleusercontent.com/photo"] {
            do {
                _ = try AccountProfile(email: "owner@example.com", picture: url).avatarURL(for: "owner@example.com")
                check(false, "untrusted avatar URL must be rejected")
            } catch { check(true, "untrusted avatar URL rejected") }
        }
        // A silent peripheral/transport must finish even if its callback never arrives.
        let silent = CallbackWaiter<Int>()
        let began = Date()
        do {
            _ = try await silent.wait(timeout: 0.02, timeoutError: Failure.timeout) {}
            check(false, "missing callback must time out")
        } catch Failure.timeout {
            check(Date().timeIntervalSince(began) < 2, "missing callback times out promptly")
        }
        silent.resolve(.success(9)) // late callback after timeout must not double-resume
        check(silent.isFinished, "late callback after timeout is harmless")

        let success = CallbackWaiter<Int>()
        let value = try await success.wait(timeout: 0.02, timeoutError: Failure.timeout) {
            success.resolve(.success(7))
            success.resolve(.success(8))
        }
        check(value == 7, "first callback wins")
        try await Task.sleep(nanoseconds: 40_000_000)
        check(success.isFinished, "deadline after success does not resume twice")

        let rejected = CallbackWaiter<Int>()
        do {
            _ = try await rejected.wait(timeout: 1, timeoutError: Failure.timeout) {
                rejected.resolve(.failure(Failure.rejected))
            }
            check(false, "callback error must propagate")
        } catch Failure.rejected { check(true, "callback error is not converted to success") }

        let cancelled = CallbackWaiter<Int>()
        var didStart = false
        let task = Task { @MainActor in
            try await cancelled.wait(timeout: 5, timeoutError: Failure.timeout) { didStart = true }
        }
        while !didStart { await Task.yield() }
        task.cancel()
        do {
            _ = try await task.value
            check(false, "cancelled operation must fail")
        } catch is CancellationError { check(true, "in-flight cancellation resumes the waiter") }
        cancelled.resolve(.success(3))

        let preCancelled = CallbackWaiter<Int>()
        var unexpectedlyStarted = false
        let early = Task { @MainActor in
            try await preCancelled.wait(timeout: 5, timeoutError: Failure.timeout) { unexpectedlyStarted = true }
        }
        early.cancel()
        do {
            _ = try await early.value
            check(false, "pre-cancelled operation must fail")
        } catch is CancellationError { check(!unexpectedlyStarted, "pre-cancellation does not start hardware/network") }

        let report = LocationResponse(canonicId: "wallet", requestID: "current-request", locations: [])
        check(report.matches(deviceID: "wallet", requestID: "current-request"), "matching device and request accepted")
        check(!report.matches(deviceID: "car", requestID: "current-request"), "different device rejected")
        check(!report.matches(deviceID: "wallet", requestID: "old-request"), "stale request rejected")
        let empty = LocationResponse(canonicId: "", requestID: "", locations: [])
        check(!empty.matches(deviceID: "", requestID: ""), "missing identifiers rejected")
        let alias = LocationResponse(canonicId: "first-id", requestID: "current-request", locations: [],
                                     alternateDeviceIDs: ["first-id", "phone-id"])
        check(alias.matches(deviceID: "phone-id", requestID: "current-request"), "all reported canonical IDs are matched")
        check(!alias.matches(deviceID: "phone-id", requestID: "old-request"), "alias does not bypass request correlation")

        // Synthetic vector generated with the Python reference; contains no account data.
        let key = hex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let encrypted = hex("b82bdaabd469e653ea195a75b85ec738708663e1cc3e56c6709784c6280b6d02537b9a0b8cfcaa05ad21833c4595a96a")
        let sx = hex("abdc22b27bd612762dd26bb23a3cafe204508ed5")
        let output = try ForeignTrackerCryptor.decrypt(identityKey: key, encryptedAndTag: encrypted,
                                                       sx: sx, timeCounter: 0x0084D000)
        check(output == Data("HELLO_FMDN_LOCATION_TESTVECTOR!!".utf8), "network crypto matches Python vector")
        var corrupted = encrypted
        corrupted[corrupted.count - 1] ^= 1
        do {
            _ = try ForeignTrackerCryptor.decrypt(identityKey: key, encryptedAndTag: corrupted,
                                                  sx: sx, timeCounter: 0x0084D000)
            check(false, "modified authentication tag must fail")
        } catch { check(true, "modified authentication tag rejected") }
        let me = CLLocationCoordinate2D(latitude: 53.85, longitude: 23.0)
        let device = CLLocationCoordinate2D(latitude: 53.9, longitude: 23.1)
        let bounds = MapViewport.bounds(for: [me, device])!
        check(bounds.contains(MKMapPoint(me)) && bounds.contains(MKMapPoint(device)),
              "overview contains user and device")
        let samePlace = MapViewport.bounds(for: [me, me])!
        check(samePlace.width > 0 && samePlace.height > 0, "coincident positions retain a usable viewport")
        let units = MKMapPointsPerMeterAtLatitude(me.latitude)
        let focused = MKMapRect(x: 0, y: 0, width: 300 * units, height: 600 * units)
        check(MapViewport.isDeviceCloseUp(focused, at: me), "device focus scale allows opening details")
        let zoomedIn = MKMapRect(x: 0, y: 0, width: 200 * units, height: 100 * units)
        check(MapViewport.isDeviceCloseUp(zoomedIn, at: me), "manual closer zoom also allows details")
        let zoomedOut = MKMapRect(x: 0, y: 0, width: 900 * units, height: 600 * units)
        check(!MapViewport.isDeviceCloseUp(zoomedOut, at: me), "zooming out restores zoom-first behavior")
        check(!MapViewport.isDeviceCloseUp(nil, at: me) && !MapViewport.isDeviceCloseUp(.null, at: me),
              "unknown camera scale cannot skip zooming")
        // Close-up centred in the band between a 100 pt top bar and a 200 pt drawer
        // of an 800 pt view: the target sits at y = 100 + 500 / 2 = 350 pt.
        let banded = MapViewport.focusRect(on: me, meters: 300, viewSize: CGSize(width: 400, height: 800),
                                           topInset: 100, bottomInset: 200)!
        let targetY = (MKMapPoint(me).y - banded.minY) / banded.height * 800
        check(abs(targetY - 350) < 0.5 && abs(MKMapPoint(me).x - banded.midX) < 1e-6,
              "focus centres the target above the drawer, not in the middle of the view")
        check(MapViewport.isDeviceCloseUp(banded, at: me), "banded device focus still counts as a close-up")
        check(MapViewport.bounds(for: [CLLocationCoordinate2D(latitude: .nan, longitude: 0)]) == nil,
              "invalid coordinates do not move the map")
        let wrapped = MapViewport.bounds(for: [CLLocationCoordinate2D(latitude: 0, longitude: 179.9),
                                                CLLocationCoordinate2D(latitude: 0, longitude: -179.9)])!
        check(wrapped.width < MKMapSize.world.width / 10, "dateline neighbors do not zoom out to the world")
        let colocated: [MapMarkerID: CLLocationCoordinate2D] = [
            .device("phone"): me, .device("watch"): me, .device("headphones"): me, .user: me]
        let combined = MapClusters.make(positions: colocated, visibleMapWidth: 5000, screenWidth: 400)
        check(combined.count == 1 && combined[0].members.count == 4, "colocated phone watch headphones and user all remain visible")
        let nextDoor = CLLocationCoordinate2D(latitude: me.latitude, longitude: me.longitude + 0.0006)
        let nearby: [MapMarkerID: CLLocationCoordinate2D] = [.device("a"): me, .device("b"): nextDoor]
        check(MapClusters.make(positions: nearby, visibleMapWidth: 10000, screenWidth: 400).count == 1,
              "overlapping marker frames merge")
        check(MapClusters.make(positions: nearby, visibleMapWidth: 100, screenWidth: 400).count == 2,
              "zooming in separates nearby markers")
        var many = colocated
        for i in 0..<8 { many[.device("extra-\(i)")] = me }
        let all = MapClusters.make(positions: many, visibleMapWidth: 5000, screenWidth: 400)
        check(all.flatMap(\.members).count == many.count, "groups never drop icons beyond the first row")
        check(MapClusters.make(positions: [:], visibleMapWidth: 5000, screenWidth: 400).isEmpty,
              "no positions produce no invented markers")
        let unknown = DecryptedLocation(coordinate: me, time: Date(timeIntervalSince1970: 0), accuracy: 0)
        check(unknown.reportedAt == nil && unknown.accuracyMeters == nil,
              "missing report fields do not appear as 1970 or perfect accuracy")
        let known = DecryptedLocation(coordinate: me, time: Date(timeIntervalSince1970: 1_800_000_000), accuracy: 35)
        check(known.reportedAt == known.time && known.accuracyMeters == 35, "available report metadata is retained")
        let placeURL = LocationPresentation.mapsURL(coordinate: me, name: "Klucze & słuchawki #1", directions: false, provider: .apple)!
        let placeQuery = URLComponents(url: placeURL, resolvingAgainstBaseURL: false)!.queryItems!
        check(placeQuery.first { $0.name == "q" }?.value == "Klucze & słuchawki #1" && placeQuery.count == 2,
              "device names cannot corrupt map link parameters")
        let routeURL = LocationPresentation.mapsURL(coordinate: me, name: "test", directions: true, provider: .apple)!
        check(URLComponents(url: routeURL, resolvingAgainstBaseURL: false)!.queryItems ==
              [URLQueryItem(name: "daddr", value: "53.850000, 23.000000")], "directions target the reported coordinates")
        check(MapsProvider.allCases.allSatisfy {
            LocationPresentation.mapsURL(coordinate: .init(latitude: .nan, longitude: 0), name: "", directions: true, provider: $0) == nil
        },
              "invalid coordinates never produce a navigation link")
        for directions in [false, true] {
            let googleURL = LocationPresentation.mapsURL(coordinate: me, name: "Sklep & #1", directions: directions, provider: .google)!
            let components = URLComponents(url: googleURL, resolvingAgainstBaseURL: false)!
            check(components.scheme == "https" && components.host == "www.google.com" &&
                  components.path == (directions ? "/maps/dir/" : "/maps/search/") &&
                  components.queryItems == [URLQueryItem(name: "api", value: "1"),
                    URLQueryItem(name: directions ? "destination" : "query", value: "53.850000, 23.000000")],
                  "Google Maps \(directions ? "route" : "pin") uses coordinates and required API version")
        }
        check(LocationPresentation.distance(.nan) == "Brak danych" && LocationPresentation.distance(-1) == "Brak danych",
              "invalid distances are marked unavailable")
        print("\(checks) checks passed")
    }

    static func hex(_ text: String) -> Data {
        var data = Data()
        var i = text.startIndex
        while i < text.endIndex {
            let next = text.index(i, offsetBy: 2)
            data.append(UInt8(text[i..<next], radix: 16)!)
            i = next
        }
        return data
    }
}

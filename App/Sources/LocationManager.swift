// FindHub Android — Copyright (c) 2026 mintstudio Jakub Koncewicz
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreLocation

/// Foreground position used for the user's marker and the map's shared viewport.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    private var active = false
    @Published private(set) var authorized = false
    @Published private(set) var location: CLLocation?
    @Published private(set) var message: String?
    @Published private(set) var permissionDenied = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func request() {
        active = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        updateAuth()
    }

    private func updateAuth() {
        let s = manager.authorizationStatus
        authorized = (s == .authorizedWhenInUse || s == .authorizedAlways)
        permissionDenied = (s == .denied || s == .restricted)
        if authorized && active {
            message = location == nil ? String(localized: "Ustalam Twoją lokalizację…") : nil
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
            location = nil
            message = permissionDenied ? String(localized: "Włącz dostęp do lokalizacji, aby zobaczyć siebie na mapie.") : nil
        }
    }

    func stop() {
        active = false
        manager.stopUpdatingLocation()
    }
}

// The manager is created on MainActor; CoreLocation delivers delegates on its run loop.
extension LocationManager: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuth() }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard active, let fix = locations.last, fix.horizontalAccuracy >= 0,
              abs(fix.timestamp.timeIntervalSinceNow) < 120,
              CLLocationCoordinate2DIsValid(fix.coordinate) else { return }
        location = fix
        message = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard active else { return }
        if let error = error as? CLError, error.code == .denied {
            updateAuth()
        } else {
            message = String(localized: "Nie udało się ustalić Twojej pozycji. Spróbuj ponownie.")
        }
    }
}

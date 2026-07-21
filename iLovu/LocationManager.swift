// LocationManager.swift
// A tiny CoreLocation wrapper that gives the rest of the app a
// single answer to one question: "where are we, roughly?"
//
// Behaviour:
//   • On request, asks for When-In-Use location permission.
//   • If granted, updates `coordinate` once a fix arrives.
//   • If denied (or simulator has no location set), `coordinate`
//     stays on the London fallback so Places searches still work.
//
// The Info.plist key NSLocationWhenInUseUsageDescription must be
// present in the target's Info, or the system blocks the permission
// request with a runtime crash. (Step-by-step instructions in the
// chat alongside this file.)

import Foundation
import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

    /// Best-known location. Defaults to London so a fresh-launch
    /// search has something useful to bias against even before the
    /// permission prompt is answered.
    var coordinate: CLLocationCoordinate2D = .london

    /// True after the user grants When-In-Use permission. The UI
    /// can read this to know if it's safe to advertise location-
    /// dependent features.
    var hasPermission: Bool = false

    /// True once a REAL GPS fix has arrived (i.e. `coordinate` is no longer the
    /// London fallback). Callers that need genuine coordinates — like stamping a
    /// Memory's location — must gate on this, never store `coordinate` blindly.
    var hasFix: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // Hundred-meter accuracy is plenty for restaurant search
        // and uses way less battery than best-available GPS.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // Honour existing permission state on app launch — if the
        // user has already granted access in a previous session,
        // start updating immediately without re-prompting.
        applyCurrentAuthorization()
    }

    /// Call this once per session (e.g. on the first view that needs
    /// location) to kick off the permission flow.
    func requestPermissionIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            applyCurrentAuthorization()
        case .denied, .restricted:
            // User said no — keep London fallback, never nag again.
            hasPermission = false
        @unknown default:
            hasPermission = false
        }
    }

    private func applyCurrentAuthorization() {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        hasPermission = authorized
        if authorized {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        applyCurrentAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        coordinate = latest.coordinate
        hasFix = true
        // Stop updating after the first fix — we only need a rough
        // location for biasing Places searches, not live tracking.
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent fail. The London fallback in `coordinate` stays in
        // place so callers don't need to handle this.
    }
}

// MARK: - London fallback

extension CLLocationCoordinate2D {
    /// Used as the default location when the simulator has no
    /// location set or the user has denied permission. Roughly
    /// central London so the bias circle covers Soho and Shoreditch.
    static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
}

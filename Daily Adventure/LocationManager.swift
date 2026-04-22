//
//  LocationManager.swift
//  Daily Adventure
//
//  Created by Codex on 09/04/26.
//

import CoreLocation
import Foundation
import Combine

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    enum CheckInEligibility {
        case none
        case nearby
        case exact
    }

    enum Status {
        case idle
        case denied
        case authorized
    }

    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocation?
    @Published var status: Status = .idle
    @Published var lastErrorMessage: String?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20
        updateStatus(for: manager.authorizationStatus)
    }

    func requestAccess() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func refreshLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }

        manager.requestLocation()
        manager.startUpdatingLocation()
    }

    func distance(to challenge: DailyChallenge) -> CLLocationDistance? {
        guard let currentLocation else { return nil }
        let destination = CLLocation(latitude: challenge.latitude, longitude: challenge.longitude)
        return currentLocation.distance(from: destination)
    }

    func canCheckIn(for challenge: DailyChallenge) -> Bool {
        eligibility(for: challenge) != .none
    }

    func eligibility(for challenge: DailyChallenge) -> CheckInEligibility {
        guard let distance = distance(to: challenge) else { return .none }
        if distance <= challenge.exactRadiusMeters {
            return .exact
        }
        if distance <= challenge.nearbyRadiusMeters {
            return .nearby
        }
        return .none
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        updateStatus(for: manager.authorizationStatus)

        if status == .authorized {
            refreshLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        lastErrorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    private func updateStatus(for authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            status = .authorized
        case .denied, .restricted:
            status = .denied
        case .notDetermined:
            status = .idle
        @unknown default:
            status = .idle
        }
    }
}

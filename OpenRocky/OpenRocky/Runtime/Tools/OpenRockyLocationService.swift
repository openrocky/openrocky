//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import CoreLocation
import Foundation
@preconcurrency import MapKit

struct OpenRockyLocationSnapshot: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let locality: String?
    let administrativeArea: String?
    let country: String?
    let timeZoneIdentifier: String?

    var label: String {
        [locality, administrativeArea, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: ", ")
            .ifEmpty("Current location")
    }
}

@MainActor
final class OpenRockyLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func currentLocation() async throws -> CLLocation {
        try await ensureAuthorized()

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func currentSnapshot() async throws -> OpenRockyLocationSnapshot {
        let location = try await currentLocation()
        if #available(iOS 26, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return OpenRockyLocationSnapshot(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    locality: nil, administrativeArea: nil, country: nil, timeZoneIdentifier: nil
                )
            }
            let mapItems = try await request.mapItems
            let address = mapItems.first?.address
            return OpenRockyLocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locality: address?.fullAddress,
                administrativeArea: nil,
                country: nil,
                timeZoneIdentifier: nil
            )
        } else {
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            return OpenRockyLocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locality: placemark?.locality,
                administrativeArea: placemark?.administrativeArea,
                country: placemark?.country,
                timeZoneIdentifier: placemark?.timeZone?.identifier
            )
        }
    }

    func geocode(address: String) async throws -> OpenRockyLocationSnapshot {
        if #available(iOS 26, *) {
            guard let request = MKGeocodingRequest(addressString: address) else {
                throw OpenRockyLocationServiceError.geocodeFailed(address)
            }
            let mapItems = try await request.mapItems
            guard let item = mapItems.first else {
                throw OpenRockyLocationServiceError.geocodeFailed(address)
            }
            let location = item.location
            let mkAddress = item.address
            return OpenRockyLocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locality: mkAddress?.fullAddress,
                administrativeArea: nil,
                country: nil,
                timeZoneIdentifier: nil
            )
        } else {
            let placemarks = try await CLGeocoder().geocodeAddressString(address)
            guard let placemark = placemarks.first, let location = placemark.location else {
                throw OpenRockyLocationServiceError.geocodeFailed(address)
            }
            return OpenRockyLocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locality: placemark.locality,
                administrativeArea: placemark.administrativeArea,
                country: placemark.country,
                timeZoneIdentifier: placemark.timeZone?.identifier
            )
        }
    }

    private func ensureAuthorized() async throws {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
            }
        case .restricted, .denied:
            throw OpenRockyLocationServiceError.permissionDenied
        @unknown default:
            throw OpenRockyLocationServiceError.permissionDenied
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let authorizationContinuation else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self.authorizationContinuation = nil
            authorizationContinuation.resume()
        case .restricted, .denied:
            self.authorizationContinuation = nil
            authorizationContinuation.resume(throwing: OpenRockyLocationServiceError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            self.authorizationContinuation = nil
            authorizationContinuation.resume(throwing: OpenRockyLocationServiceError.permissionDenied)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil

        if let location = locations.last {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: OpenRockyLocationServiceError.locationUnavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }
}

enum OpenRockyLocationServiceError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case geocodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Location permission is required for `apple-location` and `apple-weather`."
        case .locationUnavailable:
            "OpenRocky could not determine the current location."
        case .geocodeFailed(let address):
            "OpenRocky could not find coordinates for '\(address)'."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

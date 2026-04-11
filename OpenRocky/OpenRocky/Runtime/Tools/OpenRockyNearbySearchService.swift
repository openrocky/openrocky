//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import MapKit

@MainActor
final class OpenRockyNearbySearchService {
    static let shared = OpenRockyNearbySearchService()

    func search(query: String, latitude: Double?, longitude: Double?) async throws -> [[String: String]] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let latitude, let longitude {
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 5000, longitudinalMeters: 5000)
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.prefix(10).map { item in
            var entry: [String: String] = [
                "name": item.name ?? "(Unknown)",
            ]

            if let phone = item.phoneNumber, !phone.isEmpty {
                entry["phone"] = phone
            }
            if let url = item.url {
                entry["url"] = url.absoluteString
            }

            if #available(iOS 26, *) {
                if let address = item.address?.fullAddress, !address.isEmpty {
                    entry["address"] = address
                }
                let loc = item.location
                entry["latitude"] = String(format: "%.6f", loc.coordinate.latitude)
                entry["longitude"] = String(format: "%.6f", loc.coordinate.longitude)
            } else {
                let placemark = item.placemark
                var addressParts: [String] = []
                if let street = placemark.thoroughfare { addressParts.append(street) }
                if let city = placemark.locality { addressParts.append(city) }
                if let state = placemark.administrativeArea { addressParts.append(state) }
                if !addressParts.isEmpty {
                    entry["address"] = addressParts.joined(separator: ", ")
                }
                entry["latitude"] = String(format: "%.6f", placemark.coordinate.latitude)
                entry["longitude"] = String(format: "%.6f", placemark.coordinate.longitude)
            }

            if let category = item.pointOfInterestCategory?.rawValue {
                entry["category"] = category
            }

            return entry
        }
    }
}

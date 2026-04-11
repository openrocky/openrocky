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

struct OpenRockyWeatherSnapshot: Codable, Sendable {
    struct Hour: Codable, Sendable {
        let time: String
        let condition: String
        let temperatureCelsius: Int
        let precipitationChance: Int
    }

    let summaryLocation: String
    let condition: String
    let temperatureCelsius: Int
    let apparentTemperatureCelsius: Int
    let hourly: [Hour]
}

@MainActor
final class OpenRockyWeatherService {
    private let session = URLSession.shared

    func currentWeather(for location: CLLocation, label: String) async throws -> OpenRockyWeatherSnapshot {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(lat)"),
            URLQueryItem(name: "longitude", value: "\(lon)"),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "forecast_hours", value: "6"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        guard let url = components.url else {
            throw OpenMeteoError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OpenMeteoError.requestFailed
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        let current = decoded.current
        let hourly = decoded.hourly

        let hourlySnapshots: [OpenRockyWeatherSnapshot.Hour] = zip(
            hourly.time.prefix(6),
            zip(
                hourly.temperature2m.prefix(6),
                zip(hourly.precipitationProbability.prefix(6), hourly.weatherCode.prefix(6))
            )
        ).map { time, rest in
            let (temp, (precip, code)) = rest
            return OpenRockyWeatherSnapshot.Hour(
                time: Self.formatHourlyTime(time),
                condition: Self.weatherCondition(for: code),
                temperatureCelsius: Int(temp.rounded()),
                precipitationChance: precip
            )
        }

        return OpenRockyWeatherSnapshot(
            summaryLocation: label,
            condition: Self.weatherCondition(for: current.weatherCode),
            temperatureCelsius: Int(current.temperature2m.rounded()),
            apparentTemperatureCelsius: Int(current.apparentTemperature.rounded()),
            hourly: hourlySnapshots
        )
    }

    // MARK: - WMO Weather Code Mapping

    private static func weatherCondition(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71: return "Slight snow"
        case 73: return "Moderate snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown (\(code))"
        }
    }

    private static func formatHourlyTime(_ isoTime: String) -> String {
        // Open-Meteo returns "2026-03-29T14:00" format
        if let tIndex = isoTime.firstIndex(of: "T") {
            return String(isoTime[isoTime.index(after: tIndex)...])
        }
        return isoTime
    }
}

// MARK: - Open-Meteo Response Types

private struct OpenMeteoResponse: Decodable {
    let current: Current
    let hourly: Hourly

    struct Current: Decodable {
        let temperature2m: Double
        let apparentTemperature: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature2m: [Double]
        let precipitationProbability: [Int]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case weatherCode = "weather_code"
        }
    }
}

private enum OpenMeteoError: LocalizedError {
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Failed to construct Open-Meteo API URL."
        case .requestFailed: "Open-Meteo weather request failed."
        }
    }
}

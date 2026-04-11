//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import UserNotifications

@MainActor
final class OpenRockyNotificationService {
    static let shared = OpenRockyNotificationService()

    private let center = UNUserNotificationCenter.current()

    private func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            throw OpenRockyNotificationError.permissionDenied
        }
    }

    func schedule(title: String, body: String?, triggerDate: String?, delaySeconds: Double?) async throws -> [String: String] {
        try await requestAuthorization()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? ""
        content.sound = .default

        let trigger: UNNotificationTrigger
        let id = UUID().uuidString

        if let triggerDate {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            let isoFrac = ISO8601DateFormatter()
            isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = isoFrac.date(from: triggerDate) ?? iso.date(from: triggerDate) else {
                throw OpenRockyNotificationError.invalidDate
            }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else if let delaySeconds, delaySeconds > 0 {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        } else {
            // Default: 5 seconds from now
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)

        return [
            "scheduled": "true",
            "id": id,
            "title": title,
        ]
    }
}

enum OpenRockyNotificationError: LocalizedError {
    case permissionDenied
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Notification permission was denied. Please enable it in Settings."
        case .invalidDate: "Could not parse the trigger date."
        }
    }
}

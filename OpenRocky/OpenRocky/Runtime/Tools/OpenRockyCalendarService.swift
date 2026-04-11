//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import EventKit
import Foundation

@MainActor
final class OpenRockyCalendarService {
    static let shared = OpenRockyCalendarService()

    private let store = EKEventStore()

    private func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            throw OpenRockyCalendarError.permissionDenied
        }
    }

    func listEvents(startDate: String, endDate: String) async throws -> [[String: String]] {
        try await requestAccess()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let start = formatter.date(from: startDate),
              let end = formatter.date(from: endDate)?.addingTimeInterval(86399) else {
            throw OpenRockyCalendarError.invalidDate
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        return events.map { event in
            var entry: [String: String] = [
                "title": event.title ?? "(No title)",
                "start": ISO8601DateFormatter().string(from: event.startDate),
                "end": ISO8601DateFormatter().string(from: event.endDate),
                "allDay": event.isAllDay ? "true" : "false",
            ]
            if let location = event.location, !location.isEmpty {
                entry["location"] = location
            }
            if let notes = event.notes, !notes.isEmpty {
                entry["notes"] = String(notes.prefix(200))
            }
            if let calendar = event.calendar {
                entry["calendar"] = calendar.title
            }
            return entry
        }
    }

    func createEvent(title: String, startDate: String, endDate: String?, allDay: Bool, location: String?, notes: String?) async throws -> [String: String] {
        try await requestAccess()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let start = isoFrac.date(from: startDate) ?? iso.date(from: startDate) else {
            throw OpenRockyCalendarError.invalidDate
        }

        let end: Date
        if let endDate, let d = isoFrac.date(from: endDate) ?? iso.date(from: endDate) {
            end = d
        } else {
            end = start.addingTimeInterval(3600)
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = allDay
        event.location = location
        event.notes = notes
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)

        return [
            "created": "true",
            "title": title,
            "start": iso.string(from: start),
            "end": iso.string(from: end),
            "eventIdentifier": event.eventIdentifier ?? ""
        ]
    }
}

enum OpenRockyCalendarError: LocalizedError {
    case permissionDenied
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Calendar access was denied. Please enable it in Settings."
        case .invalidDate: "Could not parse the provided date string."
        }
    }
}

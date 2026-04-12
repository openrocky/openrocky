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

        guard let start = Self.parseDate(startDate) else {
            throw OpenRockyCalendarError.invalidDate
        }

        let end: Date
        if let endDate, let d = Self.parseDate(endDate) {
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

        let outFormatter = ISO8601DateFormatter()
        outFormatter.formatOptions = [.withInternetDateTime]
        return [
            "created": "true",
            "title": title,
            "start": outFormatter.string(from: start),
            "end": outFormatter.string(from: end),
            "eventIdentifier": event.eventIdentifier ?? ""
        ]
    }

    /// Parse dates flexibly: ISO-8601 with timezone, without timezone, or date-only.
    nonisolated static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // ISO-8601 with fractional seconds
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: trimmed) { return d }

        // ISO-8601 standard
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }

        // Without timezone (e.g. "2026-09-26T09:00:00") — treat as local time
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = local.date(from: trimmed) { return d }

        // Date-only (e.g. "2026-09-26")
        local.dateFormat = "yyyy-MM-dd"
        if let d = local.date(from: trimmed) { return d }

        return nil
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

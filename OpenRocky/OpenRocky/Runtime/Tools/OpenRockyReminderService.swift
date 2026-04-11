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
final class OpenRockyReminderService {
    static let shared = OpenRockyReminderService()

    private let store = EKEventStore()

    private func requestAccess() async throws {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            throw OpenRockyReminderError.permissionDenied
        }
    }

    func listReminders(includeCompleted: Bool) async throws -> [[String: String]] {
        try await requestAccess()

        let predicate = store.predicateForReminders(in: nil)
        let eventStore = store

        let results: [[String: String]] = await withCheckedContinuation { (continuation: CheckedContinuation<[[String: String]], Never>) in
            eventStore.fetchReminders(matching: predicate) { @Sendable reminders in
                guard let reminders else {
                    continuation.resume(returning: [])
                    return
                }
                let filtered = includeCompleted ? reminders : reminders.filter { !$0.isCompleted }
                let result = filtered.prefix(50).map { reminder -> [String: String] in
                    var entry: [String: String] = [
                        "title": reminder.title ?? "(No title)",
                        "completed": reminder.isCompleted ? "true" : "false",
                    ]
                    if let dueDate = reminder.dueDateComponents?.date {
                        entry["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
                    }
                    if let notes = reminder.notes, !notes.isEmpty {
                        entry["notes"] = String(notes.prefix(200))
                    }
                    if let list = reminder.calendar {
                        entry["list"] = list.title
                    }
                    if let id = reminder.calendarItemIdentifier as String? {
                        entry["id"] = id
                    }
                    if reminder.priority > 0 {
                        entry["priority"] = "\(reminder.priority)"
                    }
                    return entry
                }
                continuation.resume(returning: Array(result))
            }
        }
        return results
    }

    func createReminder(title: String, dueDate: String?, notes: String?, priority: Int?) async throws -> [String: String] {
        try await requestAccess()

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        reminder.notes = notes

        if let priority {
            reminder.priority = min(max(priority, 0), 9)
        }

        if let dueDate {
            if let date = Self.parseDate(dueDate) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: date
                )
            } else {
                rlog.warning("Reminder date parse failed: \(dueDate)", category: "Tools")
            }
        }

        rlog.info("Reminder created: \(title)" + (dueDate.map { " due=\($0)" } ?? ""), category: "Tools")
        try store.save(reminder, commit: true)

        var result: [String: String] = [
            "created": "true",
            "title": title,
            "id": reminder.calendarItemIdentifier,
        ]
        if let dueDate { result["dueDate"] = dueDate }
        return result
    }
}

extension OpenRockyReminderService {
    /// Parse a date string in various formats LLMs may produce.
    static func parseDate(_ string: String) -> Date? {
        // ISO-8601 with timezone: 2025-04-05T14:00:00Z
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: string) { return d }

        // ISO-8601 with fractional seconds
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: string) { return d }

        // Datetime without timezone: 2025-04-05T14:00:00 or 2025-04-05 14:00:00
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        for fmt in formats {
            df.dateFormat = fmt
            if let d = df.date(from: string) { return d }
        }
        return nil
    }
}

enum OpenRockyReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Reminders access was denied. Please enable it in Settings."
        }
    }
}

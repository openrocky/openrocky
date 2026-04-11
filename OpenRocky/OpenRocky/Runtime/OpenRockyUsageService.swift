//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation

// MARK: - Data Models

enum OpenRockyUsageCategory: String, Codable, Sendable, CaseIterable {
    case chat
    case voice
}

struct OpenRockyUsageRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let category: OpenRockyUsageCategory
    let provider: String      // e.g. "OpenAI", "Anthropic"
    let model: String          // e.g. "gpt-5.2-codex"
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    var day: String {
        Self.dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

struct OpenRockyUsageDailySummary: Identifiable, Sendable {
    let day: String
    let date: Date
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let requestCount: Int

    var id: String { day }
}

struct OpenRockyUsageModelSummary: Identifiable, Sendable {
    let provider: String
    let model: String
    let totalTokens: Int
    let requestCount: Int

    var id: String { "\(provider)/\(model)" }
    var displayName: String { model }
}

// MARK: - Service

@MainActor
final class OpenRockyUsageService: ObservableObject {
    static let shared = OpenRockyUsageService()

    @Published private(set) var records: [OpenRockyUsageRecord] = []

    private let fileURL: URL
    private let fileManager = FileManager.default

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpenRockyUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("usage.json")
        load()
        pruneOldRecords()
    }

    // MARK: - Recording

    func recordChat(
        provider: String,
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int
    ) {
        let record = OpenRockyUsageRecord(
            id: UUID(),
            date: Date(),
            category: .chat,
            provider: provider,
            model: model,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
        records.append(record)
        save()
    }

    func recordVoice(
        provider: String,
        model: String,
        totalTokens: Int
    ) {
        let record = OpenRockyUsageRecord(
            id: UUID(),
            date: Date(),
            category: .voice,
            provider: provider,
            model: model,
            promptTokens: 0,
            completionTokens: 0,
            totalTokens: totalTokens
        )
        records.append(record)
        save()
    }

    // MARK: - Queries

    func dailySummaries(category: OpenRockyUsageCategory? = nil, days: Int = 30) -> [OpenRockyUsageDailySummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = records.filter { record in
            record.date >= cutoff && (category == nil || record.category == category)
        }

        let grouped = Dictionary(grouping: filtered, by: \.day)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return grouped.map { day, dayRecords in
            OpenRockyUsageDailySummary(
                day: day,
                date: formatter.date(from: day) ?? Date(),
                promptTokens: dayRecords.reduce(0) { $0 + $1.promptTokens },
                completionTokens: dayRecords.reduce(0) { $0 + $1.completionTokens },
                totalTokens: dayRecords.reduce(0) { $0 + $1.totalTokens },
                requestCount: dayRecords.count
            )
        }
        .sorted { $0.day < $1.day }
    }

    func modelSummaries(category: OpenRockyUsageCategory? = nil, days: Int = 30) -> [OpenRockyUsageModelSummary] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let filtered = records.filter { record in
            record.date >= cutoff && (category == nil || record.category == category)
        }

        let grouped = Dictionary(grouping: filtered) { "\($0.provider)/\($0.model)" }
        return grouped.map { _, modelRecords in
            let first = modelRecords[0]
            return OpenRockyUsageModelSummary(
                provider: first.provider,
                model: first.model,
                totalTokens: modelRecords.reduce(0) { $0 + $1.totalTokens },
                requestCount: modelRecords.count
            )
        }
        .sorted { $0.totalTokens > $1.totalTokens }
    }

    var totalTokensToday: Int {
        let today = OpenRockyUsageRecord(
            id: UUID(), date: Date(), category: .chat,
            provider: "", model: "", promptTokens: 0, completionTokens: 0, totalTokens: 0
        ).day

        return records.filter { $0.day == today }.reduce(0) { $0 + $1.totalTokens }
    }

    var totalRequestsToday: Int {
        let today = OpenRockyUsageRecord(
            id: UUID(), date: Date(), category: .chat,
            provider: "", model: "", promptTokens: 0, completionTokens: 0, totalTokens: 0
        ).day

        return records.filter { $0.day == today }.count
    }

    func clearAll() {
        records = []
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode([OpenRockyUsageRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Keep only the last 90 days of records to prevent unbounded growth.
    private func pruneOldRecords() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let before = records.count
        records.removeAll { $0.date < cutoff }
        if records.count != before { save() }
    }
}

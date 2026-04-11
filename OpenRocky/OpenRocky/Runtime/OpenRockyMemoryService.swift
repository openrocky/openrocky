//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyMemoryEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let key: String
    var value: String
    let createdAt: Date
    var updatedAt: Date
}

@MainActor
final class OpenRockyMemoryService {
    static let shared = OpenRockyMemoryService()

    private var entries: [String: OpenRockyMemoryEntry] = [:]
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpenRockyMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("memory.json")
        load()
    }

    func get(key: String) -> String? {
        entries[key.lowercased()]?.value
    }

    func write(key: String, value: String) {
        let normalizedKey = key.lowercased()
        let now = Date()
        if var existing = entries[normalizedKey] {
            existing.value = value
            existing.updatedAt = now
            entries[normalizedKey] = existing
        } else {
            entries[normalizedKey] = OpenRockyMemoryEntry(
                id: UUID(),
                key: normalizedKey,
                value: value,
                createdAt: now,
                updatedAt: now
            )
        }
        save()
    }

    func delete(key: String) {
        entries.removeValue(forKey: key.lowercased())
        save()
    }

    func allKeys() -> [String] {
        entries.keys.sorted()
    }

    func allEntries() -> [OpenRockyMemoryEntry] {
        entries.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: OpenRockyMemoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

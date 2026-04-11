//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

struct OpenRockyTodoItem: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var isComplete: Bool
    let createdAt: Date
    var updatedAt: Date
}

@MainActor
final class OpenRockyTodoService {
    static let shared = OpenRockyTodoService()

    private var items: [OpenRockyTodoItem] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OpenRockyTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("todos.json")
        load()
    }

    func list() -> [OpenRockyTodoItem] {
        items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(title: String) -> OpenRockyTodoItem {
        let now = Date()
        let item = OpenRockyTodoItem(
            id: UUID(),
            title: title,
            isComplete: false,
            createdAt: now,
            updatedAt: now
        )
        items.append(item)
        save()
        return item
    }

    func complete(id: String) -> Bool {
        guard let uuid = UUID(uuidString: id),
              let index = items.firstIndex(where: { $0.id == uuid }) else {
            return false
        }
        items[index].isComplete = true
        items[index].updatedAt = Date()
        save()
        return true
    }

    func delete(id: String) -> Bool {
        guard let uuid = UUID(uuidString: id) else { return false }
        let count = items.count
        items.removeAll { $0.id == uuid }
        if items.count != count {
            save()
            return true
        }
        return false
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([OpenRockyTodoItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

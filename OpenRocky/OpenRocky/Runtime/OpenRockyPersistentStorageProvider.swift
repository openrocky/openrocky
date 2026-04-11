//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import LanguageModelChatUI

final class OpenRockyPersistentStorageProvider: StorageProvider, @unchecked Sendable {
    static let shared = OpenRockyPersistentStorageProvider()

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var cache: [String: [ConversationMessage]] = [:]
    private var titles: [String: String] = [:]
    private var conversationIndex: [OpenRockyConversationMeta] = []

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyConversations", isDirectory: true)
    }

    private var indexURL: URL {
        baseDirectory.appendingPathComponent("index.json")
    }

    init() {
        ensureDirectoryExists()
        loadIndex()
        cleanupEmptyConversations()
    }

    // MARK: - StorageProvider

    func createMessage(in conversationID: String, role: MessageRole) -> ConversationMessage {
        let message = ConversationMessage(
            id: UUID().uuidString,
            conversationID: conversationID,
            role: role
        )
        lock.lock()
        ensureConversationExistsLocked(conversationID)
        lock.unlock()
        return message
    }

    func save(_ messages: [ConversationMessage]) {
        lock.lock()
        var affected = Set<String>()
        for message in messages {
            let cid = message.conversationID
            affected.insert(cid)
            ensureConversationExistsLocked(cid)
            if let idx = cache[cid]?.firstIndex(where: { $0.id == message.id }) {
                cache[cid]?[idx] = message
            } else {
                cache[cid]?.append(message)
            }
        }
        for cid in affected {
            persistMessagesLocked(for: cid)
            updateConversationTimestampLocked(cid)
        }
        lock.unlock()
    }

    func messages(in conversationID: String) -> [ConversationMessage] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[conversationID] {
            return cached
        }
        let loaded = loadMessages(for: conversationID)
        cache[conversationID] = loaded
        return loaded
    }

    func delete(_ messageIDs: [String]) {
        lock.lock()
        var affected = Set<String>()
        for (cid, msgs) in cache {
            let before = msgs.count
            cache[cid] = msgs.filter { !messageIDs.contains($0.id) }
            if cache[cid]!.count != before {
                affected.insert(cid)
            }
        }
        for cid in affected {
            persistMessagesLocked(for: cid)
        }
        lock.unlock()
    }

    func title(for id: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = titles[id] { return cached }
        if let meta = conversationIndex.first(where: { $0.id == id }) {
            return meta.title
        }
        return nil
    }

    func setTitle(_ title: String, for id: String) {
        lock.lock()
        titles[id] = title
        if let idx = conversationIndex.firstIndex(where: { $0.id == id }) {
            conversationIndex[idx].title = title
        }
        saveIndexLocked()
        lock.unlock()
    }

    // MARK: - Conversation Management (call from MainActor)

    var conversations: [OpenRockyConversationMeta] {
        lock.lock()
        defer { lock.unlock() }
        return conversationIndex.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createConversation() -> String {
        lock.lock()
        let id = UUID().uuidString
        cache[id] = []
        let meta = OpenRockyConversationMeta(id: id, title: nil, createdAt: Date(), updatedAt: Date())
        conversationIndex.append(meta)
        saveIndexLocked()
        lock.unlock()
        return id
    }

    func deleteConversation(_ id: String) {
        lock.lock()
        conversationIndex.removeAll { $0.id == id }
        cache.removeValue(forKey: id)
        titles.removeValue(forKey: id)
        let url = messagesURL(for: id)
        try? fileManager.removeItem(at: url)
        saveIndexLocked()
        lock.unlock()
    }

    // MARK: - Cleanup

    private func cleanupEmptyConversations() {
        lock.lock()
        let emptyIDs = conversationIndex
            .filter { meta in
                let msgs = cache[meta.id] ?? loadMessages(for: meta.id)
                return msgs.isEmpty
            }
            .map(\.id)
        for id in emptyIDs {
            conversationIndex.removeAll { $0.id == id }
            cache.removeValue(forKey: id)
            titles.removeValue(forKey: id)
            try? fileManager.removeItem(at: messagesURL(for: id))
        }
        if !emptyIDs.isEmpty { saveIndexLocked() }
        lock.unlock()
    }

    // MARK: - Persistence (must hold lock)

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func ensureConversationExistsLocked(_ id: String) {
        if cache[id] == nil {
            cache[id] = loadMessages(for: id)
        }
        if !conversationIndex.contains(where: { $0.id == id }) {
            let meta = OpenRockyConversationMeta(id: id, title: nil, createdAt: Date(), updatedAt: Date())
            conversationIndex.append(meta)
            saveIndexLocked()
        }
    }

    private func updateConversationTimestampLocked(_ id: String) {
        if let idx = conversationIndex.firstIndex(where: { $0.id == id }) {
            conversationIndex[idx].updatedAt = Date()
            saveIndexLocked()
        }
    }

    private func messagesURL(for conversationID: String) -> URL {
        baseDirectory.appendingPathComponent("\(conversationID).json")
    }

    private func persistMessagesLocked(for conversationID: String) {
        let msgs = cache[conversationID] ?? []
        let serializable = msgs.map { SerializableMessage(from: $0) }
        guard let data = try? JSONEncoder().encode(serializable) else { return }
        try? data.write(to: messagesURL(for: conversationID), options: .atomic)
    }

    private func loadMessages(for conversationID: String) -> [ConversationMessage] {
        let url = messagesURL(for: conversationID)
        guard let data = try? Data(contentsOf: url),
              let serializable = try? JSONDecoder().decode([SerializableMessage].self, from: data)
        else { return [] }
        return serializable.map { $0.toConversationMessage(conversationID: conversationID) }
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode([OpenRockyConversationMeta].self, from: data)
        else { return }
        conversationIndex = index
        for meta in index {
            if let t = meta.title { titles[meta.id] = t }
        }
    }

    private func saveIndexLocked() {
        guard let data = try? JSONEncoder().encode(conversationIndex) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

// MARK: - Models

struct OpenRockyConversationMeta: Codable, Identifiable, Sendable {
    let id: String
    var title: String?
    let createdAt: Date
    var updatedAt: Date

    var displayTitle: String {
        if let title,
           let metadata = ConversationTitleMetadata(storageValue: title) {
            return metadata.title
        }
        return "New conversation"
    }

    var displayDate: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Serializable message wrapper

private struct SerializableMessage: Codable, Sendable {
    let id: String
    let role: String
    let text: String
    let createdAt: Date

    nonisolated init(from message: ConversationMessage) {
        id = message.id
        role = message.role.rawValue
        text = message.textContent
        createdAt = message.createdAt
    }

    nonisolated func toConversationMessage(conversationID: String) -> ConversationMessage {
        let role: MessageRole = switch self.role {
        case "user": .user
        case "assistant": .assistant
        case "system": .system
        default: .user
        }
        let message = ConversationMessage(
            id: id,
            conversationID: conversationID,
            role: role
        )
        if !text.isEmpty {
            message.parts = [.text(.init(text: text))]
        }
        message.createdAt = createdAt
        return message
    }
}

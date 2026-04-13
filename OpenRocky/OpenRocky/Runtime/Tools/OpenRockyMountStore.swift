//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-13
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Observation

struct OpenRockyMount: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    /// Security-scoped bookmark data for the directory.
    var bookmarkData: Data
    var readWrite: Bool
    /// Cached display path (set at creation time for UI display).
    var displayPath: String

    /// Resolve the bookmark to a URL. Returns nil if the bookmark is stale.
    func resolvedURL() -> (url: URL, stale: Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }

    /// Access the directory with security scope. Call stopAccessing when done.
    func startAccessing() -> URL? {
        guard let (url, _) = resolvedURL() else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return url
    }

    static func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

@Observable
@MainActor
final class OpenRockyMountStore {
    static let shared = OpenRockyMountStore()

    private(set) var mounts: [OpenRockyMount] = []

    private let fileManager = FileManager.default
    private var storageURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyMounts", isDirectory: true)
    }
    private var dataURL: URL { storageURL.appendingPathComponent("mounts.json") }

    static let maxMounts = 10

    private init() {
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        load()
    }

    func add(_ mount: OpenRockyMount) {
        guard mounts.count < Self.maxMounts else { return }
        mounts.append(mount)
        save()
    }

    func update(_ mount: OpenRockyMount) {
        guard let idx = mounts.firstIndex(where: { $0.id == mount.id }) else { return }
        mounts[idx] = mount
        save()
    }

    func delete(id: String) {
        mounts.removeAll { $0.id == id }
        save()
    }

    func mount(named name: String) -> OpenRockyMount? {
        mounts.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Create a mount from a user-selected directory URL (security-scoped).
    static func createMount(name: String, url: URL, readWrite: Bool) -> OpenRockyMount? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let bookmarkData = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return nil }

        return OpenRockyMount(
            id: UUID().uuidString,
            name: name,
            bookmarkData: bookmarkData,
            readWrite: readWrite,
            displayPath: url.path
        )
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(mounts) else { return }
        try? data.write(to: dataURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: dataURL),
              let loaded = try? JSONDecoder().decode([OpenRockyMount].self, from: data) else { return }
        mounts = loaded
    }
}

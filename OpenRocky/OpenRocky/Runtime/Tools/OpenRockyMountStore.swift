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
    var containerIdentifier: String
    var subpath: String
    var readWrite: Bool

    var resolvedURL: URL? {
        let fm = FileManager.default
        let home = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let mobileDocs = home.appendingPathComponent("Library/Mobile Documents")

        // Resolve container identifier
        let containerName: String
        switch containerIdentifier.lowercased() {
        case "obsidian", "md.obsidian", "icloud~md~obsidian":
            containerName = "iCloud~md~obsidian"
        case "nssurge", "com.nssurge.surge-ios", "icloud~com~nssurge~surge-ios":
            containerName = "iCloud~com~nssurge~surge-ios"
        default:
            containerName = containerIdentifier.hasPrefix("iCloud~") ? containerIdentifier : "iCloud~\(containerIdentifier)"
        }

        var url = mobileDocs.appendingPathComponent(containerName)
        // Try Documents subfolder (common pattern)
        let docsURL = url.appendingPathComponent("Documents")
        if fm.fileExists(atPath: docsURL.path) {
            url = docsURL
        }
        if !subpath.isEmpty && subpath != "/" {
            url = url.appendingPathComponent(subpath)
        }
        guard fm.fileExists(atPath: url.path) else { return nil }
        return url
    }

    var displayPath: String {
        let containerName: String
        switch containerIdentifier.lowercased() {
        case "obsidian", "md.obsidian", "icloud~md~obsidian":
            containerName = "iCloud~md~obsidian"
        default:
            containerName = containerIdentifier.hasPrefix("iCloud~") ? containerIdentifier : "iCloud~\(containerIdentifier)"
        }
        if subpath.isEmpty || subpath == "/" {
            return "/Library/Mobile Documents/\(containerName)/Documents"
        }
        return "/Library/Mobile Documents/\(containerName)/Documents/\(subpath)"
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

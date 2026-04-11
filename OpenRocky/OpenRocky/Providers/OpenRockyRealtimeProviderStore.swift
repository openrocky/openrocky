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

@MainActor
final class OpenRockyRealtimeProviderStore: ObservableObject {
    @Published private(set) var instances: [OpenRockyRealtimeProviderInstance] = []
    @Published private(set) var activeInstanceID: String?

    private let keychain: OpenRockyKeychain
    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyRealtimeProviders", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    private static let configBackupKeychainKey = "rocky.realtime-provider-store.config-backup"

    init(keychain: OpenRockyKeychain = .live) {
        self.keychain = keychain
        ensureDirectoryExists()
        migrateIfNeeded()
        restoreFromKeychainIfNeeded()
        loadAll()
    }

    // MARK: - Computed (backwards-compatible)

    var configuration: OpenRockyRealtimeProviderConfiguration {
        guard let instance = activeInstance else {
            return OpenRockyRealtimeProviderConfiguration(provider: .openAI, modelID: OpenRockyRealtimeProviderKind.openAI.defaultModel)
        }
        let cred = keychain.value(for: instance.credentialKeychainKey)
        return instance.toConfiguration(credential: cred).normalized()
    }

    var status: ProviderStatus {
        let config = configuration
        return ProviderStatus(
            name: config.provider.displayName,
            model: config.modelID,
            isConnected: config.isConfigured
        )
    }

    var activeInstance: OpenRockyRealtimeProviderInstance? {
        instances.first(where: { $0.id == activeInstanceID })
    }

    // MARK: - CRUD

    func add(_ instance: OpenRockyRealtimeProviderInstance, credential: String?) {
        instances.append(instance)
        saveInstance(instance)
        if let credential, !credential.isEmpty {
            keychain.set(credential, for: instance.credentialKeychainKey)
        }
        saveManifest()
    }

    func update(_ instance: OpenRockyRealtimeProviderInstance, credential: String?) {
        guard let idx = instances.firstIndex(where: { $0.id == instance.id }) else { return }
        instances[idx] = instance
        saveInstance(instance)
        if let credential, !credential.isEmpty {
            keychain.set(credential, for: instance.credentialKeychainKey)
        } else if credential != nil {
            keychain.removeValue(for: instance.credentialKeychainKey)
        }
    }

    func delete(id: String) {
        guard let instance = instances.first(where: { $0.id == id }) else { return }
        instances.removeAll { $0.id == id }
        keychain.removeValue(for: instance.credentialKeychainKey)
        try? fileManager.removeItem(at: instanceURL(for: id))
        if activeInstanceID == id {
            activeInstanceID = instances.first?.id
        }
        saveManifest()
    }

    func setActive(id: String) {
        guard instances.contains(where: { $0.id == id }) else { return }
        activeInstanceID = id
        saveManifest()
    }

    func credential(for instance: OpenRockyRealtimeProviderInstance) -> String? {
        keychain.value(for: instance.credentialKeychainKey)
    }

    // MARK: - Legacy compatibility

    func update(configuration: OpenRockyRealtimeProviderConfiguration) {
        if let instance = activeInstance {
            var updated = instance
            updated.kind = configuration.provider
            updated.modelID = configuration.modelID
            updated.doubaoResourceID = configuration.doubaoResourceID
            update(updated, credential: configuration.credential)
        } else {
            let instance = OpenRockyRealtimeProviderInstance(
                id: UUID().uuidString,
                name: configuration.provider.displayName,
                kind: configuration.provider,
                modelID: configuration.modelID,
                doubaoResourceID: configuration.doubaoResourceID,
                isBuiltIn: false
            )
            add(instance, credential: configuration.credential)
            setActive(id: instance.id)
        }
    }

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func instanceURL(for id: String) -> URL {
        baseDirectory.appendingPathComponent("\(id).json")
    }

    private func saveInstance(_ instance: OpenRockyRealtimeProviderInstance) {
        guard let data = try? JSONEncoder().encode(instance) else { return }
        try? data.write(to: instanceURL(for: instance.id), options: .atomic)
    }

    private func loadAll() {
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(RealtimeProviderManifest.self, from: data) {
            activeInstanceID = manifest.activeInstanceID
        }

        var loaded: [OpenRockyRealtimeProviderInstance] = []
        if let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                if let data = try? Data(contentsOf: file),
                   let instance = try? JSONDecoder().decode(OpenRockyRealtimeProviderInstance.self, from: data) {
                    loaded.append(instance)
                }
            }
        }
        instances = loaded

        if let activeID = activeInstanceID, !instances.contains(where: { $0.id == activeID }) {
            activeInstanceID = instances.first?.id
            saveManifest()
        }
    }

    private func saveManifest() {
        let manifest = RealtimeProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id))
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
        backupToKeychain()
    }

    // MARK: - Keychain Backup/Restore (survives reinstall)

    private func backupToKeychain() {
        let backup = RealtimeProviderConfigBackup(
            manifest: RealtimeProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id)),
            instances: instances
        )
        guard let data = try? JSONEncoder().encode(backup),
              let json = String(data: data, encoding: .utf8) else { return }
        keychain.set(json, for: Self.configBackupKeychainKey)
    }

    private func restoreFromKeychainIfNeeded() {
        let files = (try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)) ?? []
        let hasInstanceFiles = files.contains { $0.pathExtension == "json" }
        guard !hasInstanceFiles else { return }

        guard let json = keychain.value(for: Self.configBackupKeychainKey),
              let data = json.data(using: .utf8),
              let backup = try? JSONDecoder().decode(RealtimeProviderConfigBackup.self, from: data) else { return }

        for instance in backup.instances {
            saveInstance(instance)
        }
        if let manifestData = try? JSONEncoder().encode(backup.manifest) {
            try? manifestData.write(to: manifestURL, options: .atomic)
        }
        rlog.info("Restored \(backup.instances.count) voice provider instance(s) from Keychain backup", category: "Provider")
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let migrationKey = "rocky.realtime-provider.migrated-to-multi"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let defaults = UserDefaults.standard
        let oldProviderRaw = defaults.string(forKey: "rocky.realtime-provider.kind") ?? ""
        let provider = OpenRockyRealtimeProviderKind(rawValue: oldProviderRaw) ?? .openAI
        let modelID = defaults.string(forKey: "rocky.realtime-provider.model-id") ?? provider.defaultModel

        let oldCredentialKey = "rocky.realtime-provider.credential"
        let credential = keychain.value(for: oldCredentialKey)

        if credential != nil || defaults.string(forKey: "rocky.realtime-provider.kind") != nil {
            let instance = OpenRockyRealtimeProviderInstance(
                id: UUID().uuidString,
                name: provider.displayName,
                kind: provider,
                modelID: modelID,
                doubaoResourceID: defaults.string(forKey: "rocky.realtime-provider.doubao.resource-id"),
                isBuiltIn: false
            )
            saveInstance(instance)
            if let credential {
                keychain.set(credential, for: instance.credentialKeychainKey)
            }
            let manifest = RealtimeProviderManifest(activeInstanceID: instance.id, instanceIDs: [instance.id])
            if let data = try? JSONEncoder().encode(manifest) {
                try? data.write(to: manifestURL, options: .atomic)
            }
        }

        defaults.set(true, forKey: migrationKey)
    }
}

private struct RealtimeProviderManifest: Codable {
    var activeInstanceID: String?
    var instanceIDs: [String]
}

private struct RealtimeProviderConfigBackup: Codable {
    var manifest: RealtimeProviderManifest
    var instances: [OpenRockyRealtimeProviderInstance]
}

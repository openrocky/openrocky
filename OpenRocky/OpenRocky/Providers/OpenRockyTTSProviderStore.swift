//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation

@MainActor
final class OpenRockyTTSProviderStore: ObservableObject {
    @Published private(set) var instances: [OpenRockyTTSProviderInstance] = []
    @Published private(set) var activeInstanceID: String?

    private let keychain: OpenRockyKeychain
    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyTTSProviders", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    private static let configBackupKeychainKey = "rocky.tts-provider-store.config-backup"

    init(keychain: OpenRockyKeychain = .live) {
        self.keychain = keychain
        ensureDirectoryExists()
        restoreFromKeychainIfNeeded()
        loadAll()
    }

    // MARK: - Computed

    var configuration: OpenRockyTTSProviderConfiguration {
        guard let instance = activeInstance else {
            return OpenRockyTTSProviderConfiguration(provider: .openAI, modelID: OpenRockyTTSProviderKind.openAI.defaultModel)
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

    var activeInstance: OpenRockyTTSProviderInstance? {
        instances.first(where: { $0.id == activeInstanceID })
    }

    // MARK: - CRUD

    func add(_ instance: OpenRockyTTSProviderInstance, credential: String?) {
        instances.append(instance)
        saveInstance(instance)
        if let credential, !credential.isEmpty {
            keychain.set(credential, for: instance.credentialKeychainKey)
        }
        saveManifest()
    }

    func update(_ instance: OpenRockyTTSProviderInstance, credential: String?) {
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

    func credential(for instance: OpenRockyTTSProviderInstance) -> String? {
        keychain.value(for: instance.credentialKeychainKey)
    }

    // MARK: - Persistence

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    private func instanceURL(for id: String) -> URL {
        baseDirectory.appendingPathComponent("\(id).json")
    }

    private func saveInstance(_ instance: OpenRockyTTSProviderInstance) {
        guard let data = try? JSONEncoder().encode(instance) else { return }
        try? data.write(to: instanceURL(for: instance.id), options: .atomic)
    }

    private func loadAll() {
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(TTSProviderManifest.self, from: data) {
            activeInstanceID = manifest.activeInstanceID
        }

        var loaded: [OpenRockyTTSProviderInstance] = []
        if let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                if let data = try? Data(contentsOf: file),
                   let instance = try? JSONDecoder().decode(OpenRockyTTSProviderInstance.self, from: data) {
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
        let manifest = TTSProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id))
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
        backupToKeychain()
    }

    // MARK: - Keychain Backup/Restore

    private func backupToKeychain() {
        let backup = TTSProviderConfigBackup(
            manifest: TTSProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id)),
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
              let backup = try? JSONDecoder().decode(TTSProviderConfigBackup.self, from: data) else { return }

        for instance in backup.instances {
            saveInstance(instance)
        }
        if let manifestData = try? JSONEncoder().encode(backup.manifest) {
            try? manifestData.write(to: manifestURL, options: .atomic)
        }
        rlog.info("Restored \(backup.instances.count) TTS provider instance(s) from Keychain backup", category: "Provider")
    }
}

private struct TTSProviderManifest: Codable {
    var activeInstanceID: String?
    var instanceIDs: [String]
}

private struct TTSProviderConfigBackup: Codable {
    var manifest: TTSProviderManifest
    var instances: [OpenRockyTTSProviderInstance]
}

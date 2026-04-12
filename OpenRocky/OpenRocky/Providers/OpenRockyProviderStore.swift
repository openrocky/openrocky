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
final class OpenRockyProviderStore: ObservableObject {
    @Published private(set) var instances: [OpenRockyProviderInstance] = []
    @Published private(set) var activeInstanceID: String?

    private let keychain: OpenRockyKeychain
    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OpenRockyProviders", isDirectory: true)
    }

    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }

    private static let configBackupKeychainKey = "rocky.provider-store.config-backup"

    init(keychain: OpenRockyKeychain = .live) {
        self.keychain = keychain
        keychain.migrateAccessibility()
        ensureDirectoryExists()
        migrateIfNeeded()
        restoreFromKeychainIfNeeded()
        loadAll()
    }

    // MARK: - Computed (backwards-compatible)

    var configuration: OpenRockyProviderConfiguration {
        guard let instance = activeInstance else {
            return OpenRockyProviderConfiguration(provider: .openAI, modelID: OpenRockyProviderKind.openAI.defaultModel)
        }
        let manualCredential = keychain.value(for: instance.credentialKeychainKey)
        let oauthCredential = openAIOAuthCredential(for: instance)
        let resolvedCredential: String?
        if instance.kind == .openAI, (manualCredential?.isEmpty ?? true), let oauthCredential {
            resolvedCredential = oauthCredential.accessToken
        } else {
            resolvedCredential = manualCredential
        }
        return instance.toConfiguration(credential: resolvedCredential).normalized()
    }

    var status: ProviderStatus {
        let config = configuration
        return ProviderStatus(
            name: config.provider.displayName,
            model: config.modelID,
            isConnected: config.isConfigured
        )
    }

    var activeInstance: OpenRockyProviderInstance? {
        instances.first(where: { $0.id == activeInstanceID })
    }

    // MARK: - CRUD

    func add(_ instance: OpenRockyProviderInstance, credential: String?) {
        instances.append(instance)
        saveInstance(instance)
        if let credential, !credential.isEmpty {
            keychain.set(credential, for: instance.credentialKeychainKey)
        }
        saveManifest()
    }

    func update(_ instance: OpenRockyProviderInstance, credential: String?) {
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
        keychain.removeValue(for: openAIOAuthKeychainKey(for: id))
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

    func credential(for instance: OpenRockyProviderInstance) -> String? {
        keychain.value(for: instance.credentialKeychainKey)
    }

    func openAIOAuthCredential(for instance: OpenRockyProviderInstance) -> OpenRockyOpenAIOAuthCredential? {
        guard let json = keychain.value(for: openAIOAuthKeychainKey(for: instance.id)),
              let data = json.data(using: .utf8),
              let credential = try? JSONDecoder().decode(OpenRockyOpenAIOAuthCredential.self, from: data) else {
            return nil
        }
        return credential
    }

    func setOpenAIOAuthCredential(_ credential: OpenRockyOpenAIOAuthCredential?, for instanceID: String) {
        let key = openAIOAuthKeychainKey(for: instanceID)
        guard let credential else {
            keychain.removeValue(for: key)
            objectWillChange.send()
            return
        }
        guard let data = try? JSONEncoder().encode(credential),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        keychain.set(json, for: key)
        OpenRockyOpenAIOAuthVault.save(credential)
        objectWillChange.send()
    }

    // MARK: - Legacy compatibility

    func update(configuration: OpenRockyProviderConfiguration) {
        if let instance = activeInstance {
            var updated = instance
            updated.kind = configuration.provider
            updated.modelID = configuration.modelID
            updated.azureResourceName = configuration.azureResourceName
            updated.azureAPIVersion = configuration.azureAPIVersion
            updated.aiProxyServiceURL = configuration.aiProxyServiceURL
            updated.openRouterReferer = configuration.openRouterReferer
            updated.openRouterTitle = configuration.openRouterTitle
            update(updated, credential: configuration.credential)
        } else {
            let instance = OpenRockyProviderInstance(
                id: UUID().uuidString,
                name: configuration.provider.displayName,
                kind: configuration.provider,
                modelID: configuration.modelID,
                azureResourceName: configuration.azureResourceName,
                azureAPIVersion: configuration.azureAPIVersion,
                aiProxyServiceURL: configuration.aiProxyServiceURL,
                openRouterReferer: configuration.openRouterReferer,
                openRouterTitle: configuration.openRouterTitle,
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

    private func openAIOAuthKeychainKey(for instanceID: String) -> String {
        "rocky.provider-instance.\(instanceID).openai-oauth"
    }

    private func saveInstance(_ instance: OpenRockyProviderInstance) {
        guard let data = try? JSONEncoder().encode(instance) else { return }
        try? data.write(to: instanceURL(for: instance.id), options: .atomic)
    }

    private func loadAll() {
        // Load manifest
        if let data = try? Data(contentsOf: manifestURL),
           let manifest = try? JSONDecoder().decode(ProviderManifest.self, from: data) {
            activeInstanceID = manifest.activeInstanceID
        }

        // Load instances from disk
        var loaded: [OpenRockyProviderInstance] = []
        if let files = try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" && file.lastPathComponent != "manifest.json" {
                if let data = try? Data(contentsOf: file),
                   let instance = try? JSONDecoder().decode(OpenRockyProviderInstance.self, from: data) {
                    loaded.append(instance)
                }
            }
        }
        instances = loaded

        // Validate active ID
        if let activeID = activeInstanceID, !instances.contains(where: { $0.id == activeID }) {
            activeInstanceID = instances.first?.id
            saveManifest()
        }
    }

    private func saveManifest() {
        let manifest = ProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id))
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
        backupToKeychain()
    }

    // MARK: - Keychain Backup/Restore (survives reinstall)

    private func backupToKeychain() {
        let backup = ProviderConfigBackup(
            manifest: ProviderManifest(activeInstanceID: activeInstanceID, instanceIDs: instances.map(\.id)),
            instances: instances
        )
        guard let data = try? JSONEncoder().encode(backup),
              let json = String(data: data, encoding: .utf8) else { return }
        keychain.set(json, for: Self.configBackupKeychainKey)
    }

    private func restoreFromKeychainIfNeeded() {
        // Only restore if disk is empty (fresh install)
        let files = (try? fileManager.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)) ?? []
        let hasInstanceFiles = files.contains { $0.pathExtension == "json" }
        guard !hasInstanceFiles else { return }

        guard let json = keychain.value(for: Self.configBackupKeychainKey),
              let data = json.data(using: .utf8),
              let backup = try? JSONDecoder().decode(ProviderConfigBackup.self, from: data) else { return }

        for instance in backup.instances {
            saveInstance(instance)
        }
        if let manifestData = try? JSONEncoder().encode(backup.manifest) {
            try? manifestData.write(to: manifestURL, options: .atomic)
        }
        rlog.info("Restored \(backup.instances.count) chat provider instance(s) from Keychain backup", category: "Provider")
    }

    // MARK: - Migration from UserDefaults

    private func migrateIfNeeded() {
        let migrationKey = "rocky.provider.migrated-to-multi"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let defaults = UserDefaults.standard
        let oldProviderRaw = defaults.string(forKey: "rocky.provider.kind") ?? ""
        let provider = OpenRockyProviderKind(rawValue: oldProviderRaw) ?? .openAI
        let modelID = defaults.string(forKey: "rocky.provider.model-id") ?? provider.defaultModel

        let oldCredentialKey = "rocky.provider.\(provider.rawValue).credential"
        let credential = keychain.value(for: oldCredentialKey)

        // Only migrate if there was actual configuration
        if credential != nil || defaults.string(forKey: "rocky.provider.kind") != nil {
            let instance = OpenRockyProviderInstance(
                id: UUID().uuidString,
                name: provider.displayName,
                kind: provider,
                modelID: modelID,
                azureResourceName: defaults.string(forKey: "rocky.provider.azure.resource-name"),
                azureAPIVersion: defaults.string(forKey: "rocky.provider.azure.api-version"),
                aiProxyServiceURL: defaults.string(forKey: "rocky.provider.aiproxy.service-url"),
                openRouterReferer: defaults.string(forKey: "rocky.provider.openrouter.referer"),
                openRouterTitle: defaults.string(forKey: "rocky.provider.openrouter.title"),
                isBuiltIn: false
            )
            saveInstance(instance)
            if let credential {
                keychain.set(credential, for: instance.credentialKeychainKey)
            }
            let manifest = ProviderManifest(activeInstanceID: instance.id, instanceIDs: [instance.id])
            if let data = try? JSONEncoder().encode(manifest) {
                try? data.write(to: manifestURL, options: .atomic)
            }
        }

        defaults.set(true, forKey: migrationKey)
    }
}

private struct ProviderManifest: Codable {
    var activeInstanceID: String?
    var instanceIDs: [String]
}

private struct ProviderConfigBackup: Codable {
    var manifest: ProviderManifest
    var instances: [OpenRockyProviderInstance]
}

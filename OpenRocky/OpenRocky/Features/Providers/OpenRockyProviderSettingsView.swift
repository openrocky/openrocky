//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyProviderSettingsView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore
    @ObservedObject var sttProviderStore: OpenRockySTTProviderStore
    @ObservedObject var ttsProviderStore: OpenRockyTTSProviderStore
    @ObservedObject var skillStore: OpenRockyBuiltInToolStore
    @ObservedObject var characterStore: OpenRockyCharacterStore
    @StateObject private var customSkillStore = OpenRockyCustomSkillStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Preferences at the top — voice mode switch is the most important entry point
                Section {
                    NavigationLink {
                        OpenRockyPreferencesView()
                    } label: {
                        settingsRow(
                            icon: "slider.horizontal.3",
                            tint: .indigo,
                            title: "Preferences",
                            subtitle: voiceModeSummary
                        )
                    }
                }

                // AI Model: the brain behind the assistant
                Section("AI Model") {
                    NavigationLink {
                        OpenRockyProviderInstanceListView(providerStore: providerStore)
                    } label: {
                        settingsRow(
                            icon: "bubble.left.and.text.bubble.right.fill",
                            tint: OpenRockyPalette.accent,
                            title: "Chat",
                            subtitle: chatStatusSummary
                        )
                    }
                }

                // Voice Pipeline: all voice-related providers grouped together
                Section {
                    NavigationLink {
                        OpenRockyRealtimeProviderInstanceListView(realtimeProviderStore: realtimeProviderStore)
                    } label: {
                        settingsRow(
                            icon: "bolt.circle.fill",
                            tint: OpenRockyPalette.secondary,
                            title: "Realtime Voice",
                            subtitle: voiceStatusSummary
                        )
                    }

                    NavigationLink {
                        OpenRockySTTProviderInstanceListView(sttProviderStore: sttProviderStore)
                    } label: {
                        settingsRow(
                            icon: "mic.badge.waveform",
                            tint: .teal,
                            title: "Speech-to-Text",
                            subtitle: sttStatusSummary
                        )
                    }

                    NavigationLink {
                        OpenRockyTTSProviderInstanceListView(ttsProviderStore: ttsProviderStore)
                    } label: {
                        settingsRow(
                            icon: "speaker.wave.2.fill",
                            tint: .mint,
                            title: "Text-to-Speech",
                            subtitle: ttsStatusSummary
                        )
                    }
                } header: {
                    Text("Voice Pipeline")
                } footer: {
                    Text("Realtime mode uses Voice (Realtime). Traditional mode uses STT + Chat + TTS.")
                }

                // Intelligence: character, tools, skills, memory
                Section("Intelligence") {
                    NavigationLink {
                        OpenRockyCharacterSettingsView(characterStore: characterStore)
                    } label: {
                        settingsRow(
                            icon: "person.crop.circle.fill",
                            tint: .pink,
                            title: "Character",
                            subtitle: characterStore.activeCharacter.name
                        )
                    }

                    NavigationLink {
                        OpenRockyBuiltInToolsSettingsView(toolStore: skillStore)
                    } label: {
                        settingsRow(
                            icon: "wrench.and.screwdriver.fill",
                            tint: OpenRockyPalette.accent,
                            title: "Tools",
                            subtitle: "\(skillStore.tools.count) tools available"
                        )
                    }

                    NavigationLink {
                        OpenRockyCustomSkillsListView(skillStore: customSkillStore)
                    } label: {
                        settingsRow(
                            icon: "sparkles",
                            tint: OpenRockyPalette.success,
                            title: "Skills",
                            subtitle: customSkillsSummary
                        )
                    }

                    NavigationLink {
                        OpenRockyMemorySettingsView()
                    } label: {
                        settingsRow(
                            icon: "brain.head.profile.fill",
                            tint: OpenRockyPalette.warning,
                            title: "Memory",
                            subtitle: "Persistent key-value store"
                        )
                    }
                }

                // Features & Data
                Section("Features & Data") {
                    NavigationLink {
                        OpenRockyFeaturesSettingsView(toolStore: skillStore)
                    } label: {
                        settingsRow(
                            icon: "star.circle.fill",
                            tint: .orange,
                            title: "Features",
                            subtitle: "Siri, Email & more"
                        )
                    }

                    NavigationLink {
                        OpenRockyWorkspaceFilesView(
                            rootURL: workspaceURL,
                            title: "Workspace"
                        )
                    } label: {
                        settingsRow(
                            icon: "folder.fill",
                            tint: .cyan,
                            title: "Workspace",
                            subtitle: "Files created by the assistant"
                        )
                    }

                    NavigationLink {
                        OpenRockyMountSettingsView()
                    } label: {
                        settingsRow(
                            icon: "externaldrive.fill.badge.icloud",
                            tint: .blue,
                            title: "External Folders",
                            subtitle: mountsSummary
                        )
                    }

                    NavigationLink {
                        OpenRockyUsageSettingsView()
                    } label: {
                        settingsRow(
                            icon: "chart.bar.fill",
                            tint: .purple,
                            title: "Usage",
                            subtitle: usageSummary
                        )
                    }
                }

                // System
                Section("System") {
                    NavigationLink {
                        OpenRockyFeedbackView()
                    } label: {
                        settingsRow(
                            icon: "exclamationmark.bubble.fill",
                            tint: .red,
                            title: "Feedback",
                            subtitle: "Report issues or suggestions"
                        )
                    }

                    NavigationLink {
                        OpenRockyAboutView(
                            providerStore: providerStore,
                            realtimeProviderStore: realtimeProviderStore
                        )
                    } label: {
                        settingsRow(
                            icon: "heart.fill",
                            tint: .pink,
                            title: "About",
                            subtitle: "Open source project & credits"
                        )
                    }

                    NavigationLink {
                        OpenRockyLogsView()
                    } label: {
                        settingsRow(
                            icon: "doc.text.fill",
                            tint: .gray,
                            title: "Logs",
                            subtitle: "View & share runtime logs"
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var workspaceURL: URL {
        if let path = OpenRockyShellRuntime.shared.workspacePath {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpenRockyWorkspace")
    }

    private var voiceModeSummary: String {
        let mode = UserDefaults.standard.string(forKey: "rocky.pref.voiceMode") ?? OpenRockyVoiceMode.realtime.rawValue
        let modeName = OpenRockyVoiceMode(rawValue: mode)?.displayName ?? "Realtime"
        return "Voice mode: \(modeName)"
    }

    private var chatStatusSummary: String {
        let config = providerStore.configuration
        if config.isConfigured {
            return "\(config.provider.displayName) · \(config.modelID)"
        }
        return "Not configured"
    }

    private var voiceStatusSummary: String {
        let config = realtimeProviderStore.configuration
        if config.isConfigured {
            return config.provider.displayName
        }
        return "Not configured"
    }

    private var sttStatusSummary: String {
        let config = sttProviderStore.configuration
        if config.isConfigured {
            return "\(config.provider.displayName) · \(config.modelID)"
        }
        return "Not configured"
    }

    private var ttsStatusSummary: String {
        let config = ttsProviderStore.configuration
        if config.isConfigured {
            return "\(config.provider.displayName) · \(config.modelID)"
        }
        return "Not configured"
    }

    private var usageSummary: String {
        let service = OpenRockyUsageService.shared
        let todayTokens = service.totalTokensToday
        let todayRequests = service.totalRequestsToday
        if todayTokens == 0 { return "Token usage & metrics" }
        return "Today: \(Self.formatTokens(todayTokens)) tokens, \(todayRequests) requests"
    }

    private static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private var mountsSummary: String {
        let count = OpenRockyMountStore.shared.mounts.count
        if count == 0 { return "Mount iCloud folders for AI access" }
        return "\(count) folder(s) mounted"
    }

    private var customSkillsSummary: String {
        let count = customSkillStore.skills.count
        if count == 0 { return "Add or import custom skills" }
        let enabled = customSkillStore.skills.filter(\.isEnabled).count
        return "\(enabled) of \(count) enabled"
    }

    private func settingsRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chat Provider Settings

struct OpenRockyChatProviderSettingsView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: OpenRockyProviderKind
    @State private var modelID: String
    @State private var credential: String
    @State private var azureResourceName: String
    @State private var azureAPIVersion: String
    @State private var aiProxyServiceURL: String
    @State private var previousProvider: OpenRockyProviderKind

    init(providerStore: OpenRockyProviderStore) {
        self.providerStore = providerStore
        let config = providerStore.configuration
        _selectedProvider = State(initialValue: config.provider)
        _modelID = State(initialValue: config.modelID)
        _credential = State(initialValue: config.credential ?? "")
        _azureResourceName = State(initialValue: config.azureResourceName ?? "")
        _azureAPIVersion = State(initialValue: config.azureAPIVersion ?? config.provider.defaultAzureAPIVersion ?? "")
        _aiProxyServiceURL = State(initialValue: config.aiProxyServiceURL ?? "")
        _previousProvider = State(initialValue: config.provider)
    }

    var body: some View {
        List {
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(OpenRockyProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Provider")
            }

            Section {
                statusRow(title: "Status", value: isConfigured ? "Ready" : "Needs setup",
                          tint: isConfigured ? .green : .orange)
                statusRow(title: "Provider", value: selectedProvider.displayName)
                statusRow(title: "Model", value: modelID.isEmpty ? "Not set" : modelID)
                statusRow(title: "Credential", value: maskedCredential)
            } header: {
                Text("Connection")
            }

            Section {
                SecureField(
                    "Credential",
                    text: $credential,
                    prompt: Text(selectedProvider.apiKeyPlaceholder)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.init(rawValue: ""))

                if !credential.isEmpty {
                    Button("Clear Credential", role: .destructive) {
                        credential = ""
                    }
                }
            } header: {
                Text(selectedProvider == .aiProxy ? "Partial Key" : "API Key")
            } footer: {
                Text("Stored in the iOS Keychain on this device.")
            }

            if selectedProvider == .azureOpenAI {
                Section {
                    TextField("my-resource", text: $azureResourceName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("2024-10-21", text: $azureAPIVersion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Azure")
                } footer: {
                    Text("Resource name and API version. Model should be your deployment name.")
                }
            }

            if selectedProvider == .aiProxy {
                Section {
                    TextField("https://api.aiproxy.pro/...", text: $aiProxyServiceURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("AIProxy")
                }
            }

            Section {
                TextField("Model ID", text: $modelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                ForEach(selectedProvider.suggestedModels, id: \.self) { model in
                    Button {
                        modelID = model
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: modelID == model ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(modelID == model ? Color.accentColor : Color.secondary)
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model)
                                    .foregroundStyle(.primary)
                                    .font(.system(.subheadline, design: .monospaced))
                                if model == selectedProvider.defaultModel {
                                    Text("Default")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Type any model identifier supported by the selected provider.")
            }
        }
        .navigationTitle("Chat Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedProvider) { _, newValue in
            if modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelID == previousProvider.defaultModel {
                modelID = newValue.defaultModel
            }
            if newValue == .azureOpenAI, azureAPIVersion.isEmpty {
                azureAPIVersion = newValue.defaultAzureAPIVersion ?? ""
            }
            previousProvider = newValue
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    providerStore.update(configuration: draftConfiguration)
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }

    private var draftConfiguration: OpenRockyProviderConfiguration {
        OpenRockyProviderConfiguration(
            provider: selectedProvider,
            modelID: modelID,
            credential: credential,
            azureResourceName: azureResourceName,
            azureAPIVersion: azureAPIVersion,
            aiProxyServiceURL: aiProxyServiceURL
        )
    }

    private var isConfigured: Bool { draftConfiguration.normalized().isConfigured }
    private var maskedCredential: String { draftConfiguration.normalized().maskedCredential }

    private func statusRow(title: String, value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                if let tint {
                    Circle().fill(tint).frame(width: 7, height: 7)
                }
                Text(value)
                    .foregroundStyle(tint != nil ? .primary : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Voice Provider Settings

struct OpenRockyVoiceProviderSettingsView: View {
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: OpenRockyRealtimeProviderKind
    @State private var modelID: String
    @State private var credential: String
    @State private var previousProvider: OpenRockyRealtimeProviderKind

    init(realtimeProviderStore: OpenRockyRealtimeProviderStore) {
        self.realtimeProviderStore = realtimeProviderStore
        let config = realtimeProviderStore.configuration
        _selectedProvider = State(initialValue: config.provider)
        _modelID = State(initialValue: config.modelID)
        _credential = State(initialValue: config.credential ?? "")
        _previousProvider = State(initialValue: config.provider)
    }

    var body: some View {
        List {
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(OpenRockyRealtimeProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Voice Provider")
            }

            Section {
                statusRow(title: "Status", value: isConfigured ? "Ready" : "Needs setup",
                          tint: isConfigured ? .green : .orange)
                statusRow(title: "Provider", value: selectedProvider.displayName)
                statusRow(title: "Model", value: modelID.isEmpty ? "Not set" : modelID)
                statusRow(title: "Credential", value: maskedCredential)
            } header: {
                Text("Connection")
            }

            Section {
                SecureField(
                    selectedProvider.credentialTitle,
                    text: $credential,
                    prompt: Text(selectedProvider.credentialPlaceholder)
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.init(rawValue: ""))
            } header: {
                Text(selectedProvider.credentialTitle)
            }

            Section {
                TextField("Model ID", text: $modelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                ForEach(selectedProvider.suggestedModels, id: \.self) { model in
                    Button {
                        modelID = model
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: modelID == model ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(modelID == model ? Color.accentColor : Color.secondary)
                                .font(.system(size: 18))
                            Text(model)
                                .foregroundStyle(.primary)
                                .font(.system(.subheadline, design: .monospaced))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Voice Model")
            } footer: {
                Text("OpenAI uses realtime models. GLM uses glm-realtime.")
            }
        }
        .navigationTitle("Voice Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedProvider) { _, newValue in
            if modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelID == previousProvider.defaultModel {
                modelID = newValue.defaultModel
            }
            previousProvider = newValue
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    realtimeProviderStore.update(configuration: draftConfiguration)
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }

    private var draftConfiguration: OpenRockyRealtimeProviderConfiguration {
        OpenRockyRealtimeProviderConfiguration(
            provider: selectedProvider,
            modelID: modelID,
            credential: credential
        )
    }

    private var isConfigured: Bool { draftConfiguration.normalized().isConfigured }
    private var maskedCredential: String { draftConfiguration.normalized().maskedCredential }

    private func statusRow(title: String, value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                if let tint {
                    Circle().fill(tint).frame(width: 7, height: 7)
                }
                Text(value)
                    .foregroundStyle(tint != nil ? .primary : .secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

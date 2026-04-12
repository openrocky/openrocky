//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import ChatClientKit
@preconcurrency import SwiftOpenAI

struct OpenRockyProviderInstanceEditorView: View {
    @ObservedObject var providerStore: OpenRockyProviderStore
    @Environment(\.dismiss) private var dismiss

    let editingInstanceID: String?

    @State private var name: String = ""
    @State private var selectedProvider: OpenRockyProviderKind = .openAI
    @State private var modelID: String = ""
    @State private var credential: String = ""
    @State private var openAIAuthMethod: OpenAIAuthMethod = .apiKey
    @State private var openAIOAuthCredential: OpenRockyOpenAIOAuthCredential?
    @State private var oauthState: OpenAIOAuthState = .idle
    @State private var azureResourceName: String = ""
    @State private var azureAPIVersion: String = ""
    @State private var aiProxyServiceURL: String = ""
    @State private var customHost: String = ""
    @State private var previousProvider: OpenRockyProviderKind = .openAI
    @State private var testState: TestConnectionState = .idle
    @State private var nameManuallyEdited: Bool = false
    @State private var appleModelReady: Bool = false

    private var isNew: Bool { editingInstanceID == nil }

    var body: some View {
        List {
            Section {
                TextField("Name (e.g. Personal OpenAI)", text: Binding(
                    get: { name },
                    set: { newValue in
                        name = newValue
                        nameManuallyEdited = true
                    }
                ))
            } header: {
                Text("Instance Name")
            }

            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(OpenRockyProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.menu)

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Provider")
            }

            if selectedProvider == .openAI {
                Section {
                    Picker("Auth Method", selection: $openAIAuthMethod) {
                        Text("API Key").tag(OpenAIAuthMethod.apiKey)
                        Text("OAuth").tag(OpenAIAuthMethod.oauth)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Use an API key, or sign in with your ChatGPT account for Codex-style OAuth.")
                }

                if openAIAuthMethod == .oauth {
                    Section {
                        if let oauthCredential = openAIOAuthCredential {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: oauthCredential.isExpired ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(oauthCredential.isExpired ? OpenRockyPalette.warning : OpenRockyPalette.success)
                                    Text(oauthCredential.isExpired ? "OAuth Expired" : "Authenticated")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("Token: \(oauthCredential.maskedAccessToken)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("Account: \(oauthCredential.accountID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Authorized: \(oauthCredential.authorizedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Expires: \(oauthCredential.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Sign Out", role: .destructive) {
                                openAIOAuthCredential = nil
                                oauthState = .idle
                            }
                        } else {
                            Button {
                                signInWithOpenAI()
                            } label: {
                                HStack {
                                    if oauthState == .authenticating {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("Signing in...")
                                    } else {
                                        Image(systemName: "person.badge.key.fill")
                                        Text("Sign in with OpenAI")
                                    }
                                }
                            }
                            .disabled(oauthState == .authenticating)
                        }

                        if case let .failed(message) = oauthState {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("OpenAI OAuth")
                    } footer: {
                        Text("OAuth tokens are stored per provider instance in iOS Keychain.")
                    }

                    Section {
                        SecureField(
                            "Bearer Token Override",
                            text: $credential,
                            prompt: Text("sk-...")
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.init(rawValue: ""))

                        if !credential.isEmpty {
                            Button("Clear Manual Token", role: .destructive) {
                                credential = ""
                            }
                        }
                    } header: {
                        Text("Manual Token")
                    } footer: {
                        Text("Optional. If provided, this token overrides OAuth for API calls.")
                    }
                } else {
                    apiKeySection(provider: selectedProvider)
                }
            } else if selectedProvider.requiresCredential {
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
                    if let guideURL = selectedProvider.apiKeyGuideURL, let url = URL(string: guideURL) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "arrow.up.forward.square")
                                Text("Get \(selectedProvider.displayName) API Key")
                            }
                            .font(.subheadline)
                        }
                    }
                } header: {
                    Text(selectedProvider == .aiProxy ? "Partial Key" : "API Key")
                } footer: {
                    Text("Stored in the iOS Keychain on this device.")
                }
            }

            if selectedProvider == .appleFoundationModels {
                Section {
                    HStack(spacing: 10) {
                        if appleModelReady {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OpenRockyPalette.success)
                            Text("Apple Intelligence is available on this device.")
                                .foregroundStyle(OpenRockyPalette.success)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Apple Intelligence is not available on this device.")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                } header: {
                    Text("Device Support")
                } footer: {
                    Text("Requires a supported iPhone with iOS 26 or later. No API key needed.")
                }
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

            if selectedProvider != .azureOpenAI && selectedProvider != .aiProxy && selectedProvider != .appleFoundationModels {
                Section {
                    TextField("https://your-proxy.example.com", text: $customHost)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("Custom Host")
                } footer: {
                    Text("Optional. Override the default API host for this provider.")
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
                if selectedProvider == .openRouter {
                    Link(destination: URL(string: "https://openrouter.ai/models")!) {
                        HStack {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Browse Models on OpenRouter")
                        }
                        .font(.subheadline)
                    }
                }
            } header: {
                Text("Model")
            } footer: {
                Text("Type any model identifier, or pick a suggested one above.")
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 10) {
                        switch testState {
                        case .idle:
                            Image(systemName: "bolt.circle.fill")
                                .foregroundStyle(OpenRockyPalette.accent)
                            Text("Test Connection")
                                .foregroundStyle(OpenRockyPalette.accent)
                        case .testing:
                            ProgressView()
                                .controlSize(.small)
                            Text("Testing...")
                                .foregroundStyle(.secondary)
                        case .success(let model):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OpenRockyPalette.success)
                            Text("Connected — \(model)")
                                .foregroundStyle(OpenRockyPalette.success)
                                .lineLimit(1)
                        case .failure(let message):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .foregroundStyle(.red)
                                .lineLimit(5)
                        }
                        Spacer()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .disabled(testState == .testing || !draftIsConfigured)
            } header: {
                Text("Connection Test")
            } footer: {
                Text("Sends a minimal request to verify your credentials and model are working.")
            }

            if let id = editingInstanceID, id != providerStore.activeInstanceID {
                Section {
                    Button {
                        providerStore.setActive(id: id)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Activate This Provider")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundStyle(OpenRockyPalette.accent)
                    }
                } footer: {
                    Text("Set this instance as the active chat provider.")
                }
            }
        }
        .navigationTitle(isNew ? "Add Provider" : "Edit Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .task { appleModelReady = OpenRockyAppleFoundationModelsChatClient.checkModelReady() }
        .onChange(of: selectedProvider) { _, newValue in
            if modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelID == previousProvider.defaultModel {
                modelID = newValue.defaultModel
            }
            if newValue == .azureOpenAI, azureAPIVersion.isEmpty {
                azureAPIVersion = newValue.defaultAzureAPIVersion ?? ""
            }
            if newValue != .openAI {
                openAIAuthMethod = .apiKey
            } else if openAIOAuthCredential != nil {
                openAIAuthMethod = .oauth
            }
            if !nameManuallyEdited {
                name = newValue.displayName
            }
            previousProvider = newValue
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveInstance()
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func loadExisting() {
        guard let id = editingInstanceID,
              let instance = providerStore.instances.first(where: { $0.id == id }) else {
            // New instance defaults
            name = selectedProvider.displayName
            modelID = selectedProvider.defaultModel
            credential = ""
            openAIOAuthCredential = nil
            openAIAuthMethod = .apiKey
            nameManuallyEdited = false
            return
        }
        name = instance.name
        nameManuallyEdited = true
        selectedProvider = instance.kind
        modelID = instance.modelID
        credential = providerStore.credential(for: instance) ?? ""
        openAIOAuthCredential = providerStore.openAIOAuthCredential(for: instance)
        openAIAuthMethod = openAIOAuthCredential != nil ? .oauth : .apiKey
        azureResourceName = instance.azureResourceName ?? ""
        azureAPIVersion = instance.azureAPIVersion ?? ""
        aiProxyServiceURL = instance.aiProxyServiceURL ?? ""
        customHost = instance.customHost ?? ""
        previousProvider = instance.kind
    }

    private var draftIsConfigured: Bool {
        if selectedProvider == .openAI && openAIAuthMethod == .oauth {
            let hasResolvedToken = resolvedCredential().isEmpty == false
            return hasResolvedToken && modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
        let config = OpenRockyProviderConfiguration(
            provider: selectedProvider,
            modelID: modelID,
            credential: resolvedCredential(),
            azureResourceName: azureResourceName,
            azureAPIVersion: azureAPIVersion,
            aiProxyServiceURL: aiProxyServiceURL,
            customHost: customHost
        ).normalized()
        return config.isConfigured
    }

    private func testConnection() {
        testState = .testing
        let config = OpenRockyProviderConfiguration(
            provider: selectedProvider,
            modelID: modelID,
            credential: resolvedCredential(),
            azureResourceName: azureResourceName,
            azureAPIVersion: azureAPIVersion,
            aiProxyServiceURL: aiProxyServiceURL,
            customHost: customHost
        ).normalized()

        rlog.info("Chat test: provider=\(config.provider.rawValue) model=\(config.modelID)", category: "Test")

        if config.provider == .appleFoundationModels {
            testAppleFoundationModelsConnection(config: config)
            return
        }

        Task {
            do {
                let service = try await OpenRockyOpenAIServiceFactory.makeService(configuration: config)
                var parameters = ChatCompletionParameters(
                    messages: [.init(role: .user, content: .text("Hi, I am OpenRocky. Now it is \(ISO8601DateFormatter().string(from: Date()))"))],
                    model: .custom(config.modelID)
                )
                parameters.maxCompletionTokens = 5
                let stream = try await service.startStreamedChat(parameters: parameters)
                var receivedAny = false
                for try await chunk in stream {
                    if chunk.choices?.first != nil {
                        receivedAny = true
                        break
                    }
                }
                if receivedAny {
                    rlog.info("Chat test passed: \(config.modelID)", category: "Test")
                    testState = .success(model: config.modelID)
                } else {
                    rlog.warning("Chat test: no response received", category: "Test")
                    testState = .failure(message: "No response received")
                }
            } catch {
                let nsError = error as NSError
                rlog.error("Chat test failed: [\(nsError.domain)/\(nsError.code)] \(error.localizedDescription)", category: "Test")
                testState = .failure(message: "[\(nsError.code)] \(error.localizedDescription)")
            }
        }
    }

    private func testAppleFoundationModelsConnection(config: OpenRockyProviderConfiguration) {
        Task {
            guard OpenRockyAppleFoundationModelsChatClient.checkModelReady() else {
                rlog.warning("Apple Foundation Models not available on this device", category: "Test")
                testState = .failure(message: "Apple Intelligence is not available on this device.")
                return
            }

            do {
                let client = OpenRockyAppleFoundationModelsChatClient()
                let body = ChatRequestBody(
                    messages: [.user(content: .text("Hi"), name: nil)],
                    maxCompletionTokens: 10
                )
                var receivedAny = false
                for try await chunk in try await client.streamingChat(body: body) {
                    if chunk.textValue != nil {
                        receivedAny = true
                        break
                    }
                }
                if receivedAny {
                    rlog.info("Apple Foundation Models test passed", category: "Test")
                    testState = .success(model: config.modelID)
                } else {
                    rlog.warning("Apple Foundation Models test: no response received", category: "Test")
                    testState = .failure(message: "No response received")
                }
            } catch {
                let nsError = error as NSError
                rlog.error("Apple FM test failed: [\(nsError.domain)/\(nsError.code)] \(error.localizedDescription)", category: "Test")
                testState = .failure(message: "[\(nsError.code)] \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder
    private func apiKeySection(provider: OpenRockyProviderKind) -> some View {
        Section {
            SecureField(
                "Credential",
                text: $credential,
                prompt: Text(provider.apiKeyPlaceholder)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.init(rawValue: ""))

            if !credential.isEmpty {
                Button("Clear Credential", role: .destructive) {
                    credential = ""
                }
            }
            if let guideURL = provider.apiKeyGuideURL, let url = URL(string: guideURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "arrow.up.forward.square")
                        Text("Get \(provider.displayName) API Key")
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text(provider == .aiProxy ? "Partial Key" : "API Key")
        } footer: {
            Text("Stored in the iOS Keychain on this device.")
        }
    }

    private func resolvedCredential() -> String {
        let manual = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty {
            return manual
        }
        if selectedProvider == .openAI, openAIAuthMethod == .oauth {
            return openAIOAuthCredential?.accessToken ?? ""
        }
        return manual
    }

    private func signInWithOpenAI() {
        oauthState = .authenticating
        Task {
            do {
                let oauthCredential = try await OpenRockyOpenAIOAuthService.signIn(originator: "openrocky")
                openAIOAuthCredential = oauthCredential
                openAIAuthMethod = .oauth
                oauthState = .authenticated
                rlog.info("OpenAI OAuth sign-in completed for account \(oauthCredential.accountID)", category: "Provider")
            } catch {
                let nsError = error as NSError
                let message = "[\(nsError.code)] \(error.localizedDescription)"
                oauthState = .failed(message: message)
                rlog.error("OpenAI OAuth sign-in failed: \(message)", category: "Provider")
            }
        }
    }

    private func saveInstance() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let manualCredential = credential.trimmingCharacters(in: .whitespacesAndNewlines)

        if let id = editingInstanceID {
            var instance = providerStore.instances.first(where: { $0.id == id })!
            instance.name = trimmedName
            instance.kind = selectedProvider
            instance.modelID = modelID
            instance.azureResourceName = azureResourceName.isEmpty ? nil : azureResourceName
            instance.azureAPIVersion = azureAPIVersion.isEmpty ? nil : azureAPIVersion
            instance.aiProxyServiceURL = aiProxyServiceURL.isEmpty ? nil : aiProxyServiceURL
            instance.customHost = customHost.isEmpty ? nil : customHost
            providerStore.update(instance, credential: manualCredential.isEmpty ? nil : manualCredential)
            if selectedProvider == .openAI {
                providerStore.setOpenAIOAuthCredential(openAIAuthMethod == .oauth ? openAIOAuthCredential : nil, for: id)
            } else {
                providerStore.setOpenAIOAuthCredential(nil, for: id)
            }
        } else {
            let instance = OpenRockyProviderInstance(
                id: UUID().uuidString,
                name: trimmedName,
                kind: selectedProvider,
                modelID: modelID,
                azureResourceName: azureResourceName.isEmpty ? nil : azureResourceName,
                azureAPIVersion: azureAPIVersion.isEmpty ? nil : azureAPIVersion,
                aiProxyServiceURL: aiProxyServiceURL.isEmpty ? nil : aiProxyServiceURL,
                openRouterReferer: nil,
                openRouterTitle: nil,
                customHost: customHost.isEmpty ? nil : customHost,
                isBuiltIn: false
            )
            providerStore.add(instance, credential: manualCredential.isEmpty ? nil : manualCredential)
            if selectedProvider == .openAI && openAIAuthMethod == .oauth {
                providerStore.setOpenAIOAuthCredential(openAIOAuthCredential, for: instance.id)
            } else {
                providerStore.setOpenAIOAuthCredential(nil, for: instance.id)
            }
            providerStore.setActive(id: instance.id)
        }
    }
}

// MARK: - Test Connection State

private enum TestConnectionState: Equatable {
    case idle
    case testing
    case success(model: String)
    case failure(message: String)
}

private enum OpenAIAuthMethod: String, Equatable {
    case apiKey
    case oauth
}

private enum OpenAIOAuthState: Equatable {
    case idle
    case authenticating
    case authenticated
    case failed(message: String)
}

//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyRealtimeProviderInstanceEditorView: View {
    @ObservedObject var realtimeProviderStore: OpenRockyRealtimeProviderStore
    @Environment(\.dismiss) private var dismiss

    let editingInstanceID: String?
    var initialProviderKind: OpenRockyRealtimeProviderKind? = nil

    @State private var name: String = ""
    @State private var selectedProvider: OpenRockyRealtimeProviderKind = .openAI
    @State private var credential: String = ""
    @State private var openaiVoice: String = OpenRockyOpenAIVoice.alloy.rawValue
    @State private var glmVoice: String = OpenRockyGLMVoice.tongtong.rawValue
    @State private var customHost: String = ""
    @State private var previousProvider: OpenRockyRealtimeProviderKind = .openAI
    @State private var testState: VoiceTestConnectionState = .idle
    @State private var nameManuallyEdited: Bool = false
    @StateObject private var openaiVoicePreview = OpenRockyOpenAIVoicePreview()
    @StateObject private var glmVoicePreview = OpenRockyGLMVoicePreview()

    private var isNew: Bool { editingInstanceID == nil }

    var body: some View {
        List {
            Section {
                TextField("Name (e.g. My OpenAI Voice)", text: Binding(
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
                if isNew && initialProviderKind != nil {
                    HStack {
                        Text("Provider")
                        Spacer()
                        Text(selectedProvider.displayName)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(OpenRockyRealtimeProviderKind.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Voice Provider")
            }

            if selectedProvider == .glm {
                Section {
                    SecureField(
                        "API Key",
                        text: $credential,
                        prompt: Text("your-api-key...")
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.init(rawValue: ""))

                    Link(destination: URL(string: "https://open.bigmodel.cn/usercenter/apikeys")!) {
                        HStack {
                            Image(systemName: "arrow.up.forward.square")
                            Text("Get Zhipu AI API Key")
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("Zhipu AI Open Platform")
                }

                Section {
                    ForEach(OpenRockyGLMVoice.allCases) { voice in
                        Button {
                            glmVoice = voice.rawValue
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: glmVoice == voice.rawValue ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(glmVoice == voice.rawValue ? Color.accentColor : .secondary)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.displayName)
                                        .foregroundStyle(.primary)
                                        .font(.subheadline.weight(.medium))
                                    Text(voice.subtitle)
                                        .foregroundStyle(.secondary)
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button {
                                    if glmVoicePreview.playingVoice == voice.rawValue {
                                        glmVoicePreview.stop()
                                    } else {
                                        glmVoicePreview.play(
                                            voice: voice.rawValue,
                                            credential: credential,
                                            customHost: customHost.isEmpty ? nil : customHost
                                        )
                                    }
                                } label: {
                                    if glmVoicePreview.playingVoice == voice.rawValue && glmVoicePreview.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: glmVoicePreview.playingVoice == voice.rawValue ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundStyle(glmVoicePreview.playingVoice == voice.rawValue ? .orange : .accentColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if let err = glmVoicePreview.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Voice")
                }
            } else {
                Section {
                    SecureField(
                        selectedProvider.credentialTitle,
                        text: $credential,
                        prompt: Text(selectedProvider.credentialPlaceholder)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.init(rawValue: ""))

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
                    Text(selectedProvider.credentialTitle)
                }

                Section {
                    ForEach(OpenRockyOpenAIVoice.allCases) { voice in
                        Button {
                            openaiVoice = voice.rawValue
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: openaiVoice == voice.rawValue ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(openaiVoice == voice.rawValue ? Color.accentColor : .secondary)
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.displayName)
                                        .foregroundStyle(.primary)
                                        .font(.subheadline.weight(.medium))
                                    Text(voice.subtitle)
                                        .foregroundStyle(.secondary)
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button {
                                    if openaiVoicePreview.playingVoice == voice.rawValue {
                                        openaiVoicePreview.stop()
                                    } else {
                                        openaiVoicePreview.play(
                                            voice: voice.rawValue,
                                            credential: credential,
                                            customHost: customHost.isEmpty ? nil : customHost
                                        )
                                    }
                                } label: {
                                    if openaiVoicePreview.playingVoice == voice.rawValue && openaiVoicePreview.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: openaiVoicePreview.playingVoice == voice.rawValue ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundStyle(openaiVoicePreview.playingVoice == voice.rawValue ? .orange : .accentColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if let err = openaiVoicePreview.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Voice")
                }
            }

            Section {
                    TextField("wss://your-proxy.example.com", text: $customHost)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("Custom Host")
                } footer: {
                    Text("Optional. Override the default WebSocket host for this voice provider.")
                }

            Section {
                Button {
                    testVoiceConnection()
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
                        case .success(let detail):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(OpenRockyPalette.success)
                            Text("Connected — \(detail)")
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
                Text("Opens a WebSocket to verify your credential and model are accepted.")
            }

            if let id = editingInstanceID, id != realtimeProviderStore.activeInstanceID {
                Section {
                    Button {
                        saveInstance()
                        realtimeProviderStore.setActive(id: id)
                        dismiss()
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
                    Text("Save and activate this provider, then return to the list.")
                }
            }
        }
        .navigationTitle(isNew ? "Add Voice Provider" : "Edit Voice Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .onChange(of: selectedProvider) { _, newValue in
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
              let instance = realtimeProviderStore.instances.first(where: { $0.id == id }) else {
            if let initial = initialProviderKind {
                selectedProvider = initial
                previousProvider = initial
            }
            name = selectedProvider.displayName
            nameManuallyEdited = false
            return
        }
        name = instance.name
        nameManuallyEdited = true
        selectedProvider = instance.kind
        credential = realtimeProviderStore.credential(for: instance) ?? ""
        openaiVoice = instance.openaiVoice ?? OpenRockyOpenAIVoice.alloy.rawValue
        customHost = instance.customHost ?? ""
        if instance.kind == .glm {
            glmVoice = instance.glmVoice ?? OpenRockyGLMVoice.tongtong.rawValue
        }
        previousProvider = instance.kind
    }

    private var draftModelID: String {
        selectedProvider.defaultModel
    }

    private var draftIsConfigured: Bool {
        let config = OpenRockyRealtimeProviderConfiguration(
            provider: selectedProvider,
            modelID: draftModelID,
            credential: credential,
            customHost: customHost
        ).normalized()
        return config.isConfigured
    }

    private func testVoiceConnection() {
        testState = .testing
        let config = OpenRockyRealtimeProviderConfiguration(
            provider: selectedProvider,
            modelID: draftModelID,
            credential: credential,
            customHost: customHost
        ).normalized()

        Task {
            do {
                let url: URL
                let testModelID: String
                switch config.provider {
                case .openAI:
                    testModelID = "gpt-realtime-mini"
                    let openAIHost = config.customHost ?? "wss://api.openai.com"
                    url = URL(string: "\(openAIHost)/v1/realtime?model=\(testModelID)")!
                case .glm:
                    testModelID = "glm-realtime"
                    let glmHost = config.customHost ?? "wss://open.bigmodel.cn"
                    url = URL(string: "\(glmHost)/api/paas/v4/realtime")!
                }

                var request = URLRequest(url: url)
                if config.provider == .glm {
                    request.setValue("Bearer \(config.credential ?? "")", forHTTPHeaderField: "Authorization")
                } else if config.provider == .openAI {
                    request.setValue("Bearer \(config.credential ?? "")", forHTTPHeaderField: "Authorization")
                    request.setValue("realtime=v1", forHTTPHeaderField: "openai-beta")
                }

                let socket = URLSession.shared.webSocketTask(with: request)
                socket.resume()

                // For GLM: send session.update
                if config.provider == .glm {
                    let sessionUpdate: [String: Any] = [
                        "type": "session.update",
                        "session": [
                            "model": testModelID,
                            "voice": "tongtong",
                            "modalities": ["audio", "text"],
                            "output_audio_format": "pcm"
                        ] as [String: Any]
                    ]
                    let setupData = try JSONSerialization.data(withJSONObject: sessionUpdate)
                    if let setupText = String(data: setupData, encoding: .utf8) {
                        try await socket.send(.string(setupText))
                    }
                }

                // Wait for first response with timeout
                let success = try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        let message = try await socket.receive()
                        switch message {
                        case .data(let data):
                            // Binary response: parse error details
                            if data.count >= 4 {
                                let msgType = data[1] >> 4
                                if msgType == 0x0F { // SERVER_ERROR
                                    // Extract error: skip header, read code + payload
                                    let headerSize = Int(data[0] & 0x0F) * 4
                                    if data.count > headerSize + 8 {
                                        let payloadStart = headerSize + 8
                                        var errorData = data.subdata(in: payloadStart..<data.count)
                                        let compression = data[2] & 0x0F
                                        if compression == 0x01 {
                                            errorData = (try? (errorData as NSData).decompressed(using: .zlib) as Data) ?? errorData
                                        }
                                        let errorText = String(data: errorData, encoding: .utf8) ?? "unknown"
                                        return "ERROR:\(errorText)"
                                    }
                                    return "ERROR:unknown server error"
                                }
                            }
                            return "OK"
                        case .string(let text):
                            rlog.debug("Realtime test response: \(text.prefix(300))", category: "Test")
                            if let d = text.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                                // Check for error in various formats
                                if let type = json["type"] as? String, type == "error" {
                                    let msg = (json["error"] as? [String: Any])?["message"] as? String ?? text
                                    return "ERROR:\(msg)"
                                }
                                if let errObj = json["error"] as? [String: Any] {
                                    let msg = errObj["message"] as? String ?? text
                                    return "ERROR:\(msg)"
                                }
                            }
                            return "OK"
                        @unknown default:
                            return "ERROR:unknown"
                        }
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 10_000_000_000)
                        throw URLError(.timedOut)
                    }
                    let first = try await group.next()!
                    group.cancelAll()
                    return first
                }

                socket.cancel(with: .goingAway, reason: nil)

                if success.hasPrefix("ERROR:") {
                    let msg = String(success.dropFirst(6))
                    rlog.error("Realtime test failed: \(msg)", category: "Test")
                    testState = .failure(message: msg)
                } else {
                    rlog.info("Realtime test passed: \(config.provider) \(testModelID)", category: "Test")
                    testState = .success(detail: testModelID)
                }
            } catch let error as URLError where error.code == .timedOut {
                rlog.warning("Realtime test timeout: \(config.provider)", category: "Test")
                testState = .failure(message: "Connection timed out")
            } catch {
                rlog.error("Realtime test error: \(error.localizedDescription)", category: "Test")
                let probeMsg = await probeEndpointError(config: config)
                rlog.debug("Realtime test probe: \(probeMsg)", category: "Test")
                testState = .failure(message: probeMsg)
            }
        }
    }

    /// When WebSocket handshake fails, make a plain HTTP request to get the real error body.
    private func probeEndpointError(config: OpenRockyRealtimeProviderConfiguration) async -> String {
        let httpURL: URL
        switch config.provider {
        case .openAI:
            let host = config.customHost?.replacingOccurrences(of: "wss://", with: "https://") ?? "https://api.openai.com"
            httpURL = URL(string: "\(host)/v1/realtime?model=gpt-realtime-mini")!
        case .glm:
            let host = config.customHost?.replacingOccurrences(of: "wss://", with: "https://") ?? "https://open.bigmodel.cn"
            httpURL = URL(string: "\(host)/api/paas/v4/models")!
        }

        var request = URLRequest(url: httpURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(config.credential ?? "")", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""

            // Try to extract error message from JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorDict = json["error"] as? [String: Any],
                   let msg = errorDict["message"] as? String {
                    return "HTTP \(status): \(msg)"
                }
                if let msg = json["message"] as? String {
                    return "HTTP \(status): \(msg)"
                }
            }

            let preview = String(body.prefix(200))
            return "HTTP \(status): \(preview.isEmpty ? "No response body" : preview)"
        } catch {
            return "Connection failed: \(error.localizedDescription)"
        }
    }

    private func saveInstance() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cred = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModelID = draftModelID

        if let id = editingInstanceID {
            var instance = realtimeProviderStore.instances.first(where: { $0.id == id })!
            instance.name = trimmedName
            instance.kind = selectedProvider
            instance.modelID = resolvedModelID
            instance.openaiVoice = openaiVoice
            instance.glmVoice = glmVoice
            instance.customHost = customHost.isEmpty ? nil : customHost
            realtimeProviderStore.update(instance, credential: cred.isEmpty ? nil : cred)
        } else {
            let instance = OpenRockyRealtimeProviderInstance(
                id: UUID().uuidString,
                name: trimmedName,
                kind: selectedProvider,
                modelID: resolvedModelID,
                openaiVoice: openaiVoice,
                glmVoice: glmVoice,
                customHost: customHost.isEmpty ? nil : customHost,
                isBuiltIn: false
            )
            realtimeProviderStore.add(instance, credential: cred.isEmpty ? nil : cred)
            realtimeProviderStore.setActive(id: instance.id)
        }
    }
}

// MARK: - Voice Test Connection State

private enum VoiceTestConnectionState: Equatable {
    case idle
    case testing
    case success(detail: String)
    case failure(message: String)
}

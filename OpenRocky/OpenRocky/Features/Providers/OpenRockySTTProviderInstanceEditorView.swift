//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySTTProviderInstanceEditorView: View {
    @ObservedObject var sttProviderStore: OpenRockySTTProviderStore
    @Environment(\.dismiss) private var dismiss

    let editingInstanceID: String?
    var initialProviderKind: OpenRockySTTProviderKind? = nil

    @State private var name: String = ""
    @State private var selectedProvider: OpenRockySTTProviderKind = .openAI
    @State private var credential: String = ""
    @State private var modelID: String = ""
    @State private var customHost: String = ""
    @State private var language: String = ""
    @State private var nameManuallyEdited: Bool = false
    @StateObject private var sttTest = OpenRockySTTTest()

    private var isNew: Bool { editingInstanceID == nil }

    var body: some View {
        List {
            Section {
                TextField("Name (e.g. My Whisper)", text: Binding(
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
                        ForEach(OpenRockySTTProviderKind.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("STT Provider")
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
                TextField("Model ID", text: $modelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                ForEach(selectedProvider.suggestedModels, id: \.self) { model in
                    Button {
                        modelID = model
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: modelID == model ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(modelID == model ? Color.accentColor : .secondary)
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
                Text("Model")
            }

            Section {
                TextField("e.g. zh, en, ja (optional)", text: $language)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Language Hint")
            } footer: {
                Text("ISO-639-1 language code. Leave empty for auto-detection.")
            }

            Section {
                TextField("https://your-proxy.example.com", text: $customHost)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            } header: {
                Text("Custom Host")
            } footer: {
                Text("Optional. Override the default API endpoint.")
            }

            // Test section
            Section {
                Button {
                    if case .recording = sttTest.state {
                        sttTest.stop()
                    } else {
                        sttTest.startTest(
                            provider: selectedProvider,
                            modelID: modelID.isEmpty ? selectedProvider.defaultModel : modelID,
                            credential: credential,
                            customHost: customHost.isEmpty ? nil : customHost,
                            language: language.isEmpty ? nil : language
                        )
                    }
                } label: {
                    HStack(spacing: 10) {
                        switch sttTest.state {
                        case .idle:
                            Image(systemName: "mic.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Test Speech Recognition")
                                .foregroundStyle(Color.accentColor)
                        case .recording(let seconds):
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(.pulse)
                            Text("Recording... \(seconds)s")
                                .foregroundStyle(.red)
                        case .transcribing:
                            ProgressView()
                                .controlSize(.small)
                            Text("Transcribing...")
                                .foregroundStyle(.secondary)
                        case .success(let text):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(text)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
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
                .disabled(sttTest.state == .transcribing || credential.isEmpty)

                if case .success = sttTest.state {
                    Button("Test Again") {
                        sttTest.reset()
                    }
                    .font(.system(size: 14))
                }
                if case .failure = sttTest.state {
                    Button("Try Again") {
                        sttTest.reset()
                    }
                    .font(.system(size: 14))
                }
            } header: {
                Text("Test")
            } footer: {
                Text("Records 4 seconds of microphone audio and sends it for transcription. Requires microphone permission.")
            }
        }
        .navigationTitle(isNew ? "Add STT Provider" : "Edit STT Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .onDisappear { sttTest.stop() }
        .onChange(of: selectedProvider) { _, newValue in
            sttTest.reset()
            if !nameManuallyEdited {
                name = newValue.displayName
            }
            if modelID.isEmpty || modelID == OpenRockySTTProviderKind.openAI.defaultModel || modelID == OpenRockySTTProviderKind.aliCloud.defaultModel {
                modelID = newValue.defaultModel
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    sttTest.stop()
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
              let instance = sttProviderStore.instances.first(where: { $0.id == id }) else {
            if let initial = initialProviderKind {
                selectedProvider = initial
            }
            name = selectedProvider.displayName
            modelID = selectedProvider.defaultModel
            nameManuallyEdited = false
            return
        }
        name = instance.name
        nameManuallyEdited = true
        selectedProvider = instance.kind
        credential = sttProviderStore.credential(for: instance) ?? ""
        modelID = instance.modelID
        customHost = instance.customHost ?? ""
        language = instance.language ?? ""
    }

    private func saveInstance() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cred = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModelID = modelID.isEmpty ? selectedProvider.defaultModel : modelID

        if let id = editingInstanceID {
            var instance = sttProviderStore.instances.first(where: { $0.id == id })!
            instance.name = trimmedName
            instance.kind = selectedProvider
            instance.modelID = resolvedModelID
            instance.customHost = customHost.isEmpty ? nil : customHost
            instance.language = language.isEmpty ? nil : language
            sttProviderStore.update(instance, credential: cred.isEmpty ? nil : cred)
        } else {
            let instance = OpenRockySTTProviderInstance(
                id: UUID().uuidString,
                name: trimmedName,
                kind: selectedProvider,
                modelID: resolvedModelID,
                customHost: customHost.isEmpty ? nil : customHost,
                language: language.isEmpty ? nil : language,
                isBuiltIn: false
            )
            sttProviderStore.add(instance, credential: cred.isEmpty ? nil : cred)
            sttProviderStore.setActive(id: instance.id)
        }
    }
}

//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyTTSProviderInstanceEditorView: View {
    @ObservedObject var ttsProviderStore: OpenRockyTTSProviderStore
    @Environment(\.dismiss) private var dismiss

    let editingInstanceID: String?
    var initialProviderKind: OpenRockyTTSProviderKind? = nil

    @State private var name: String = ""
    @State private var selectedProvider: OpenRockyTTSProviderKind = .openAI
    @State private var credential: String = ""
    @State private var modelID: String = ""
    @State private var selectedVoice: String = ""
    @State private var customHost: String = ""
    @State private var nameManuallyEdited: Bool = false

    private var isNew: Bool { editingInstanceID == nil }

    var body: some View {
        List {
            Section {
                TextField("Name (e.g. My OpenAI TTS)", text: Binding(
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
                        ForEach(OpenRockyTTSProviderKind.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }

                Text(selectedProvider.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("TTS Provider")
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
                ForEach(selectedProvider.availableVoices) { voice in
                    Button {
                        selectedVoice = voice.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedVoice == voice.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedVoice == voice.id ? Color.accentColor : .secondary)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.name)
                                    .foregroundStyle(.primary)
                                    .font(.subheadline.weight(.medium))
                                Text(voice.subtitle)
                                    .foregroundStyle(.secondary)
                                    .font(.caption2)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Voice")
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
        }
        .navigationTitle(isNew ? "Add TTS Provider" : "Edit TTS Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExisting() }
        .onChange(of: selectedProvider) { _, newValue in
            if !nameManuallyEdited {
                name = newValue.displayName
            }
            if modelID.isEmpty || modelID == OpenRockyTTSProviderKind.openAI.defaultModel || modelID == OpenRockyTTSProviderKind.miniMax.defaultModel {
                modelID = newValue.defaultModel
            }
            selectedVoice = newValue.defaultVoice
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
              let instance = ttsProviderStore.instances.first(where: { $0.id == id }) else {
            if let initial = initialProviderKind {
                selectedProvider = initial
            }
            name = selectedProvider.displayName
            modelID = selectedProvider.defaultModel
            selectedVoice = selectedProvider.defaultVoice
            nameManuallyEdited = false
            return
        }
        name = instance.name
        nameManuallyEdited = true
        selectedProvider = instance.kind
        credential = ttsProviderStore.credential(for: instance) ?? ""
        modelID = instance.modelID
        selectedVoice = instance.voice ?? selectedProvider.defaultVoice
        customHost = instance.customHost ?? ""
    }

    private func saveInstance() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let cred = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModelID = modelID.isEmpty ? selectedProvider.defaultModel : modelID

        if let id = editingInstanceID {
            var instance = ttsProviderStore.instances.first(where: { $0.id == id })!
            instance.name = trimmedName
            instance.kind = selectedProvider
            instance.modelID = resolvedModelID
            instance.voice = selectedVoice.isEmpty ? nil : selectedVoice
            instance.customHost = customHost.isEmpty ? nil : customHost
            ttsProviderStore.update(instance, credential: cred.isEmpty ? nil : cred)
        } else {
            let instance = OpenRockyTTSProviderInstance(
                id: UUID().uuidString,
                name: trimmedName,
                kind: selectedProvider,
                modelID: resolvedModelID,
                voice: selectedVoice.isEmpty ? nil : selectedVoice,
                customHost: customHost.isEmpty ? nil : customHost,
                isBuiltIn: false
            )
            ttsProviderStore.add(instance, credential: cred.isEmpty ? nil : cred)
            ttsProviderStore.setActive(id: instance.id)
        }
    }
}

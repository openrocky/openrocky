//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyCharacterEditorView: View {
    @ObservedObject var characterStore: OpenRockyCharacterStore
    @Environment(\.dismiss) private var dismiss

    let editingCharacterID: String?

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var personality: String = ""
    @State private var greeting: String = ""
    @State private var speakingStyle: String = ""
    @State private var openaiVoice: String = OpenRockyOpenAIVoice.alloy.rawValue

    private var isNew: Bool { editingCharacterID == nil }
    private var isBuiltIn: Bool {
        guard let id = editingCharacterID else { return false }
        return characterStore.characters.first(where: { $0.id == id })?.isBuiltIn ?? false
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            } header: {
                Text("Info")
            }

            Section {
                TextField("Greeting", text: $greeting, prompt: Text("Leave empty for no greeting"))
            } header: {
                Text("Greeting")
            } footer: {
                Text("What the character says when a voice session starts. Leave empty to stay silent.")
            }

            Section {
                TextField("Speaking Style", text: $speakingStyle, prompt: Text("简洁明了，语速适中，语调自然。"))
            } header: {
                Text("Speaking Style")
            } footer: {
                Text("Describes the character's conversation style for the voice model.")
            }

            Section {
                Picker("OpenAI Voice", selection: $openaiVoice) {
                    ForEach(OpenRockyOpenAIVoice.allCases) { voice in
                        Text("\(voice.displayName) — \(voice.subtitle)")
                            .tag(voice.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("OpenAI Voice")
            } footer: {
                Text("Preferred voice when using OpenAI realtime.")
            }

            Section {
                TextEditor(text: $personality)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(minHeight: 300)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Personality Prompt")
            } footer: {
                Text("The system prompt sent to the model. Defines behavior, tone, and tool routing.")
            }

            if isBuiltIn {
                Section {
                    Button("Reset to Default") {
                        if let builtIn = OpenRockyCharacterStore.builtInCharacters.first(where: { $0.id == editingCharacterID }) {
                            name = builtIn.name
                            description = builtIn.description
                            personality = builtIn.personality
                            greeting = builtIn.greeting
                            speakingStyle = builtIn.speakingStyle
                            openaiVoice = builtIn.openaiVoice ?? OpenRockyOpenAIVoice.alloy.rawValue
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isNew ? "New Character" : "Edit Character")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let id = editingCharacterID,
               let character = characterStore.characters.first(where: { $0.id == id }) {
                name = character.name
                description = character.description
                personality = character.personality
                greeting = character.greeting
                speakingStyle = character.speakingStyle
                openaiVoice = character.openaiVoice ?? OpenRockyOpenAIVoice.alloy.rawValue
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveCharacter()
                    dismiss()
                }
                .fontWeight(.bold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || personality.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func saveCharacter() {
        if let id = editingCharacterID {
            var character = characterStore.characters.first(where: { $0.id == id })!
            character.name = name.trimmingCharacters(in: .whitespaces)
            character.description = description.trimmingCharacters(in: .whitespaces)
            character.personality = personality
            character.greeting = greeting
            character.speakingStyle = speakingStyle
            character.openaiVoice = openaiVoice
            characterStore.update(character)
        } else {
            let character = OpenRockyCharacterDefinition(
                id: UUID().uuidString,
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                personality: personality,
                greeting: greeting,
                speakingStyle: speakingStyle,
                openaiVoice: openaiVoice,
                isBuiltIn: false
            )
            characterStore.add(character)
            characterStore.setActive(id: character.id)
        }
    }
}

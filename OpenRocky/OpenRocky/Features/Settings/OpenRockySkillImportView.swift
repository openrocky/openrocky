//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockySkillImportView: View {
    @ObservedObject var skillStore: OpenRockyCustomSkillStore
    @Environment(\.dismiss) private var dismiss

    @State private var repoURLString: String = ""
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedCount: Int?

    var body: some View {
        List {
            Section {
                TextField("https://github.com/username/repo", text: $repoURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                Button {
                    importFromGitHub()
                } label: {
                    HStack {
                        Label("Import Skills", systemImage: "square.and.arrow.down")
                        if isImporting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(repoURLString.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)
            } header: {
                Text("Custom GitHub Repository")
            } footer: {
                Text("Each skill should be in a subdirectory with a SKILL.md file. Already imported skills will be skipped.")
            }

            if let error = errorMessage {
                Section {
                    Label(error, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            if let count = importedCount {
                Section {
                    Label(
                        count > 0 ? "Imported \(count) skills" : "All skills already installed",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                    .font(.subheadline)
                }
            }
        }
        .navigationTitle("Custom Repository")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func importFromGitHub() {
        isImporting = true
        errorMessage = nil
        importedCount = nil

        Task {
            do {
                let skills = try await skillStore.importFromGitHubRepo(urlString: repoURLString)
                importedCount = skills.count
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
        }
    }
}

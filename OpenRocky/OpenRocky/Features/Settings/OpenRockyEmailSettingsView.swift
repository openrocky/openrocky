//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-06
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyEmailSettingsView: View {
    @ObservedObject var toolStore: OpenRockyBuiltInToolStore
    @State private var selectedPreset: EmailPreset = .gmail
    @State private var smtpHost: String = ""
    @State private var smtpPort: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var useTLS: Bool = true
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    @State private var isTesting = false
    @State private var showDeleteConfirmation = false

    enum EmailPreset: String, CaseIterable {
        case gmail = "Gmail"
        case outlook = "Outlook"
        case qq = "QQ Mail"
        case custom = "Custom SMTP"

        var config: OpenRockyEmailConfig? {
            switch self {
            case .gmail: return .gmailPreset
            case .outlook: return .outlookPreset
            case .qq: return .qqPreset
            case .custom: return nil
            }
        }
    }

    private var isConfigured: Bool {
        OpenRockyEmailConfig.load()?.isConfigured == true && OpenRockyEmailConfig.load()?.hasPassword == true
    }

    var body: some View {
        List {
            // Status
            Section {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isConfigured ? OpenRockyPalette.success.opacity(0.14) : Color.orange.opacity(0.14))
                            .frame(width: 48, height: 48)
                        Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isConfigured ? OpenRockyPalette.success : .orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isConfigured ? "Email Configured" : "Setup Required")
                            .font(.headline)
                        Text(isConfigured ? "SMTP is ready to send emails." : "Enter your SMTP server details and app password below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Preset selection
            Section {
                Picker("Email Provider", selection: $selectedPreset) {
                    ForEach(EmailPreset.allCases, id: \.self) { preset in
                        Text(LocalizedStringKey(preset.rawValue)).tag(preset)
                    }
                }
                .onChange(of: selectedPreset) { _, newPreset in
                    if let config = newPreset.config {
                        smtpHost = config.smtpHost
                        smtpPort = String(config.smtpPort)
                        useTLS = config.useTLS
                    }
                }
            } header: {
                Text("Provider")
            } footer: {
                if selectedPreset == .gmail {
                    Text("Use a Google App Password (not your Gmail password). Generate one at myaccount.google.com → Security → App passwords.")
                } else if selectedPreset == .outlook {
                    Text("Use your Outlook/Microsoft account password or an app password if 2FA is enabled.")
                } else if selectedPreset == .qq {
                    Text("Use QQ Mail authorization code (not your QQ password). Get it from QQ Mail Settings → Account → POP3/SMTP.")
                }
            }

            // SMTP Configuration
            Section("SMTP Server") {
                LabeledContent("Host") {
                    TextField("smtp.gmail.com", text: $smtpHost)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Port") {
                    TextField("465", text: $smtpPort)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Use TLS", isOn: $useTLS)
            }

            // Credentials
            Section("Account") {
                LabeledContent("Email") {
                    TextField("you@gmail.com", text: $username)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("App Password") {
                    SecureField("App password", text: $password)
                        .multilineTextAlignment(.trailing)
                }
            }

            // Actions
            Section {
                Button {
                    saveConfig()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Configuration")
                    }
                }
                .disabled(smtpHost.isEmpty || username.isEmpty || password.isEmpty)

                Button {
                    Task { await testConnection() }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane")
                        }
                        Text(isTesting ? "Testing..." : "Send Test Email")
                    }
                }
                .disabled(!isConfigured || isTesting)
            }

            // Remove
            if isConfigured {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Email Configuration")
                        }
                    }
                    .confirmationDialog("Remove email configuration?", isPresented: $showDeleteConfirmation) {
                        Button("Remove", role: .destructive) {
                            OpenRockyEmailConfig.remove()
                            toolStore.setEnabled("email-send", enabled: false)
                            clearFields()
                        }
                    } message: {
                        Text("This will remove your SMTP settings and password. The email tool will be disabled.")
                    }
                }
            }
        }
        .navigationTitle("Email Setup")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Test Result", isPresented: $showingTestResult) {
            Button("OK") { }
        } message: {
            Text(testResultMessage)
        }
        .onAppear { loadExistingConfig() }
    }

    private func loadExistingConfig() {
        guard let config = OpenRockyEmailConfig.load() else { return }
        smtpHost = config.smtpHost
        smtpPort = String(config.smtpPort)
        username = config.username
        useTLS = config.useTLS

        // Detect preset
        if config.smtpHost == "smtp.gmail.com" {
            selectedPreset = .gmail
        } else if config.smtpHost == "smtp.office365.com" {
            selectedPreset = .outlook
        } else if config.smtpHost == "smtp.qq.com" {
            selectedPreset = .qq
        } else {
            selectedPreset = .custom
        }

        if let saved = OpenRockyKeychain.live.value(for: OpenRockyEmailConfig.keychainAccount) {
            password = saved
        }
    }

    private func saveConfig() {
        let config = OpenRockyEmailConfig(
            smtpHost: smtpHost,
            smtpPort: Int(smtpPort) ?? 465,
            username: username,
            useTLS: useTLS
        )
        config.save()
        OpenRockyKeychain.live.set(password, for: OpenRockyEmailConfig.keychainAccount)
        toolStore.setEnabled("email-send", enabled: true)
    }

    private func clearFields() {
        smtpHost = ""
        smtpPort = ""
        username = ""
        password = ""
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        do {
            let messageID = try await OpenRockyEmailService.shared.send(
                to: [username],
                subject: "OpenRocky Email Test",
                body: "This is a test email from OpenRocky. If you received this, your email configuration is working correctly!"
            )
            testResultMessage = "Test email sent successfully! Check your inbox.\n\nMessage ID: \(messageID)"
        } catch {
            testResultMessage = "Failed: \(error.localizedDescription)"
        }
        showingTestResult = true
    }
}

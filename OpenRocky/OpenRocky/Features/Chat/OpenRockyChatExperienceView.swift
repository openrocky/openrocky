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
import LanguageModelChatUI

struct OpenRockyChatExperienceScreen: View {
    let bootstrap: OpenRockyShellProbeResult?
    let transcript: String
    let providerConfiguration: OpenRockyProviderConfiguration
    let skillStore: OpenRockyBuiltInToolStore
    let contentTopInset: CGFloat
    let conversationID: String
    let refreshToken: UUID
    let openSettings: () -> Void
    var isVoiceActive: Bool = false
    var voiceStatusText: String = ""
    var onVoiceToggle: (() -> Void)?
    var onVoiceStop: (() -> Void)?
    var onConversationListTap: (() -> Void)?

    var body: some View {
        ZStack {
            OpenRockyChatViewControllerRepresentable(
                transcript: transcript,
                bootstrap: bootstrap,
                providerConfiguration: providerConfiguration,
                skillStore: skillStore,
                contentTopInset: contentTopInset,
                conversationID: conversationID,
                isVoiceActive: isVoiceActive,
                voiceStatusText: voiceStatusText,
                onVoiceToggle: onVoiceToggle,
                onVoiceStop: onVoiceStop,
                onConversationListTap: onConversationListTap
            )
            .id(providerConfiguration.identity + conversationID + refreshToken.uuidString)
            .ignoresSafeArea()

            if !providerConfiguration.isConfigured {
                connectProviderButton
                    .transition(.opacity)
            }
        }
        .background(OpenRockyPalette.background)
    }

    private var connectProviderButton: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundStyle(OpenRockyPalette.accent)

            Text("Connect a Provider")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(OpenRockyPalette.text)

            Text("Add an API key in Settings to start chatting.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(OpenRockyPalette.muted)
                .multilineTextAlignment(.center)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(OpenRockyPalette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }
}

private struct OpenRockyChatViewControllerRepresentable: UIViewControllerRepresentable {
    let transcript: String
    let bootstrap: OpenRockyShellProbeResult?
    let providerConfiguration: OpenRockyProviderConfiguration
    let skillStore: OpenRockyBuiltInToolStore
    let contentTopInset: CGFloat
    let conversationID: String
    var isVoiceActive: Bool = false
    var voiceStatusText: String = ""
    var onVoiceToggle: (() -> Void)?
    var onVoiceStop: (() -> Void)?
    var onConversationListTap: (() -> Void)?

    private let characterStore = OpenRockyCharacterStore.shared

    func makeUIViewController(context: Context) -> UINavigationController {
        let toolProvider = OpenRockyToolProvider(skillStore: skillStore)
        let controller = ChatViewController(
            conversationID: conversationID,
            models: configuredModels(),
            sessionConfiguration: .init(
                storage: OpenRockyPersistentStorageProvider.shared,
                tools: toolProvider,
                systemPrompt: characterStore.systemPrompt,
                collapseReasoningWhenComplete: true,
                workspacePath: OpenRockyShellRuntime.shared.workspacePath
            )
        )
        controller.prefersNavigationBarManaged = true
        controller.title = "OpenRocky"
        controller.additionalSafeAreaInsets.top = contentTopInset
        let emptyState = OpenRockyEmptyStateView()
        emptyState.onQuickAction = { [weak controller] prompt in
            controller?.submitText(prompt)
        }
        controller.emptyStateView = emptyState
        controller.onVoiceSessionToggle = onVoiceToggle
        controller.onVoiceSessionStop = onVoiceStop
        controller.onConversationListTap = onConversationListTap
        controller.onPromptsTap = { [weak controller] in
            guard let controller else { return }
            let picker = OpenRockyPromptsPickerViewController()
            picker.onPromptSelected = { [weak controller] prompt in
                controller?.submitText(prompt)
            }
            picker.modalPresentationStyle = .pageSheet
            if let sheet = picker.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.selectedDetentIdentifier = .medium
                sheet.prefersGrabberVisible = true
            }
            controller.present(picker, animated: true)
        }
        controller.onLinkTap = { [weak controller] url in
            if url.scheme == "rocky", url.host == "workspace" {
                // rocky://workspace/path/to/file.md
                let relativePath = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
                guard let workspace = OpenRockyShellRuntime.shared.workspacePath else { return }
                let fileURL = URL(fileURLWithPath: workspace).appendingPathComponent(relativePath)
                guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
                let previewVC = UIHostingController(rootView: OpenRockyFilePreviewView(url: fileURL))
                previewVC.modalPresentationStyle = .pageSheet
                if let sheet = previewVC.sheetPresentationController {
                    sheet.detents = [.medium(), .large()]
                    sheet.selectedDetentIdentifier = .large
                    sheet.prefersGrabberVisible = true
                }
                controller?.present(previewVC, animated: true)
            } else if let scheme = url.scheme, scheme.hasPrefix("http") {
                UIApplication.shared.open(url)
            }
        }

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.navigationBar.isTranslucent = true
        OpenRockyUIPresenterService.shared.setPresenter(navigationController)
        return navigationController
    }

    func updateUIViewController(_ navigationController: UINavigationController, context: Context) {
        guard let controller = navigationController.viewControllers.first as? ChatViewController else { return }
        controller.additionalSafeAreaInsets.top = contentTopInset

        // Sync voice mode state
        let inputIsVoice = controller.chatInputView.isVoiceMode
        if isVoiceActive != inputIsVoice {
            controller.chatInputView.setVoiceMode(isVoiceActive)
        }
        if isVoiceActive {
            controller.chatInputView.updateVoiceStatus(voiceStatusText)
        }
    }

    private func configuredModels() -> ConversationSession.Models {
        guard providerConfiguration.isConfigured else { return .init() }

        let client: any ChatClient
        if providerConfiguration.provider == .appleFoundationModels {
            client = OpenRockyAppleFoundationModelsChatClient()
        } else {
            client = OpenRockySwiftOpenAIChatClient(configuration: providerConfiguration)
        }

        let isAppleFM = providerConfiguration.provider == .appleFoundationModels
        // Apple FM uses native FoundationModels Tool protocol for tool calling.
        // Visual (image) input is not supported by the on-device model.
        let capabilities: Set<ModelCapability> = isAppleFM ? [.tool] : [.tool, .visual]

        let model = ConversationSession.Model(
            client: client,
            capabilities: capabilities,
            contextLength: isAppleFM ? 32_768 : 1_000_000
        )
        return .init(chat: model, titleGeneration: model)
    }
}

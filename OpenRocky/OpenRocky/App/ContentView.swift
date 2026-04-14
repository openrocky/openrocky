//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var chatProviderStore = OpenRockyProviderStore()
    @StateObject private var voiceProviderStore = OpenRockyRealtimeProviderStore()
    @StateObject private var sttProviderStore = OpenRockySTTProviderStore()
    @StateObject private var ttsProviderStore = OpenRockyTTSProviderStore()
    @ObservedObject private var shellRuntime = OpenRockyShellRuntime.shared
    @StateObject private var sessionRuntime = OpenRockySessionRuntime()
    @StateObject private var skillStore = OpenRockyBuiltInToolStore.shared
    @ObservedObject private var characterStore = OpenRockyCharacterStore.shared
    @AppStorage("rocky.onboarding.completed") private var onboardingCompleted = false
    @State private var showsOnboarding = false
    @State private var showsProviderSettings = false
    @State private var showsVoiceOverlay = false
    @State private var showsVoiceNotConfiguredAlert = false
    @State private var showsConversationList = false
    @State private var conversationID: String = ""
    @State private var chatRefreshToken: UUID = UUID()
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private let storage = OpenRockyPersistentStorageProvider.shared

    // MARK: - Body

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            if conversationID.isEmpty {
                startNewConversation()
            }
            shellRuntime.bootstrapIfNeeded()
            sessionRuntime.conversationID = conversationID
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration,
                sttConfiguration: sttProviderStore.configuration,
                ttsConfiguration: ttsProviderStore.configuration
            )
            if !onboardingCompleted || !chatProviderStore.configuration.isConfigured {
                showsOnboarding = true
            }
            // Auto-start voice when launched from Siri (delay to let layout settle)
            if UserDefaults.standard.bool(forKey: "rocky.launch.startVoice") {
                UserDefaults.standard.set(false, forKey: "rocky.launch.startVoice")
                try? await Task.sleep(for: .seconds(0.8))
                if !showsVoiceOverlay {
                    toggleVoiceSession()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: OpenRockyAppLifecycleService.willExitNotification)) { _ in
            if showsVoiceOverlay {
                endVoiceSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // Check if Siri set the voice-start flag while the app was in the background
            if UserDefaults.standard.bool(forKey: "rocky.launch.startVoice") {
                UserDefaults.standard.set(false, forKey: "rocky.launch.startVoice")
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    if !showsVoiceOverlay {
                        toggleVoiceSession()
                    }
                }
            }
        }
        .onChange(of: conversationID) { _, newID in
            sessionRuntime.conversationID = newID
        }
        .onChange(of: chatProviderStore.configuration) { _, _ in
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration,
                sttConfiguration: sttProviderStore.configuration,
                ttsConfiguration: ttsProviderStore.configuration
            )
            // Force chat controller/client recreation when provider config changes,
            // even if high-level identity fields stay the same.
            chatRefreshToken = UUID()
        }
        .onChange(of: voiceProviderStore.configuration) { _, _ in
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration,
                sttConfiguration: sttProviderStore.configuration,
                ttsConfiguration: ttsProviderStore.configuration
            )
        }
        .onChange(of: sttProviderStore.configuration) { _, _ in
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration,
                sttConfiguration: sttProviderStore.configuration,
                ttsConfiguration: ttsProviderStore.configuration
            )
        }
        .onChange(of: ttsProviderStore.configuration) { _, _ in
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration,
                sttConfiguration: sttProviderStore.configuration,
                ttsConfiguration: ttsProviderStore.configuration
            )
        }
        .sheet(isPresented: $showsProviderSettings) {
            OpenRockyProviderSettingsView(
                providerStore: chatProviderStore,
                realtimeProviderStore: voiceProviderStore,
                sttProviderStore: sttProviderStore,
                ttsProviderStore: ttsProviderStore,
                skillStore: skillStore,
                characterStore: characterStore
            )
            .presentationSizing(.form)
        }
        .fullScreenCover(isPresented: $showsOnboarding, onDismiss: {
            onboardingCompleted = true
        }) {
            OpenRockyOnboardingView(
                providerStore: chatProviderStore,
                realtimeProviderStore: voiceProviderStore
            )
        }
        .overlay { keyboardShortcutButtons }
        .alert("Voice Not Configured", isPresented: $showsVoiceNotConfiguredAlert) {
            Button("Open Settings") {
                showsProviderSettings = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if sessionRuntime.activeVoiceMode == .traditional {
                Text("Traditional voice mode requires Chat, Speech-to-Text, and Text-to-Speech providers. Please configure them in Settings.")
            } else {
                Text("Please set up a voice provider in Settings before starting a voice session.")
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        NavigationStack {
            chatContentView
                .navigationTitle("Rocky")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { commonToolbarItems }
                .toolbarBackground(OpenRockyPalette.background, for: .navigationBar)
        }
        .sheet(isPresented: $showsConversationList) {
            OpenRockyConversationListView(
                conversations: storage.conversations,
                currentID: conversationID,
                onSelect: { id in conversationID = id },
                onNew: { startNewConversation() },
                onDelete: { id in storage.deleteConversation(id) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(OpenRockyPalette.background)
        }
    }

    // MARK: - iPad Layout (sidebar + detail)

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            // Sidebar: conversation list
            OpenRockyConversationListContent(
                conversations: storage.conversations,
                currentID: conversationID,
                onSelect: { id in conversationID = id },
                onNew: { startNewConversation() },
                onDelete: { id in storage.deleteConversation(id) }
            )
            .navigationTitle("Rocky")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { startNewConversation() } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(OpenRockyPalette.accent)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showsProviderSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(OpenRockyPalette.muted)
                    }
                }
            }
            .toolbarBackground(OpenRockyPalette.background, for: .navigationBar)
        } detail: {
            NavigationStack {
                chatContentView
                    .navigationTitle("Rocky")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { commonToolbarItems }
                    .toolbarBackground(OpenRockyPalette.background, for: .navigationBar)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Shared Chat Content

    private var chatContentView: some View {
        Group {
            if !conversationID.isEmpty {
                chatExperienceView
            }
        }
    }

    private var chatExperienceView: some View {
        OpenRockyChatExperienceScreen(
            bootstrap: shellRuntime.probe,
            transcript: sessionRuntime.session.liveTranscript,
            providerConfiguration: chatProviderStore.configuration,
            sttConfiguration: sttProviderStore.configuration,
            skillStore: skillStore,
            contentTopInset: 0,
            conversationID: conversationID,
            refreshToken: chatRefreshToken,
            openSettings: { showsProviderSettings = true },
            isVoiceActive: showsVoiceOverlay,
            voiceStatusText: sessionRuntime.statusText,
            onVoiceToggle: { toggleVoiceSession() },
            onVoiceStop: { endVoiceSession() },
            onConversationListTap: {
                if horizontalSizeClass == .regular {
                    sidebarVisibility = .all
                } else {
                    showsConversationList = true
                }
            }
        )
    }

    // MARK: - Common Toolbar

    @ToolbarContentBuilder
    private var commonToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { showsProviderSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OpenRockyPalette.muted)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            voiceToolbarButton
        }
    }

    private var voiceToolbarButton: some View {
        let tint = showsVoiceOverlay ? Color.red : OpenRockyPalette.accent
        return Button(action: { toggleVoiceSession() }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: tint.opacity(0.3), radius: 6, y: 2)

                Image(systemName: showsVoiceOverlay ? "stop.fill" : "waveform")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    /// Hidden buttons that register keyboard shortcuts for iPad external keyboards.
    private var keyboardShortcutButtons: some View {
        Group {
            Button("") { startNewConversation() }
                .keyboardShortcut("n", modifiers: .command)

            Button("") { showsProviderSettings = true }
                .keyboardShortcut(",", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }

    private func startNewConversation() {
        conversationID = storage.createConversation()
    }

    private func toggleVoiceSession() {
        if showsVoiceOverlay {
            endVoiceSession()
        } else if sessionRuntime.activeVoiceMode == .traditional {
            // Traditional mode needs STT + TTS + Chat configured
            let sttReady = sttProviderStore.configuration.isConfigured
            let ttsReady = ttsProviderStore.configuration.isConfigured
            let chatReady = chatProviderStore.configuration.isConfigured
            if sttReady && ttsReady && chatReady {
                showsVoiceOverlay = true
                sessionRuntime.startVoiceSession(configuration: voiceProviderStore.configuration)
            } else {
                showsVoiceNotConfiguredAlert = true
            }
        } else if !voiceProviderStore.configuration.isConfigured {
            showsVoiceNotConfiguredAlert = true
        } else {
            showsVoiceOverlay = true
            sessionRuntime.startVoiceSession(configuration: voiceProviderStore.configuration)
        }
    }

    private func endVoiceSession() {
        sessionRuntime.stopVoiceSession()
        showsVoiceOverlay = false
    }
}

#Preview {
    ContentView()
}

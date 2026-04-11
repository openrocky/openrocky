//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatProviderStore = OpenRockyProviderStore()
    @StateObject private var voiceProviderStore = OpenRockyRealtimeProviderStore()
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
    @State private var topChromeHeight: CGFloat = 0
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
        .onPreferenceChange(OpenRockyTopChromeHeightPreferenceKey.self) { topChromeHeight = $0 }
        .task {
            if conversationID.isEmpty {
                startNewConversation()
            }
            shellRuntime.bootstrapIfNeeded()
            sessionRuntime.conversationID = conversationID
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration
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
                voiceConfiguration: voiceProviderStore.configuration
            )
        }
        .onChange(of: voiceProviderStore.configuration) { _, _ in
            sessionRuntime.syncProviders(
                chatConfiguration: chatProviderStore.configuration,
                voiceConfiguration: voiceProviderStore.configuration
            )
        }
        .sheet(isPresented: $showsProviderSettings) {
            OpenRockyProviderSettingsView(
                providerStore: chatProviderStore,
                realtimeProviderStore: voiceProviderStore,
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
        .alert("Voice Provider Not Configured", isPresented: $showsVoiceNotConfiguredAlert) {
            Button("Open Settings") {
                showsProviderSettings = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please set up a voice provider in Settings before starting a voice session.")
        }
    }

    // MARK: - iPhone Layout (unchanged)

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            OpenRockyTopChromeView(
                providerStatus: chatProviderStore.status,
                isVoiceActive: showsVoiceOverlay,
                openProviderSettings: { showsProviderSettings = true },
                openVoiceOverlay: { toggleVoiceSession() },
                openConversationList: { showsConversationList = true },
                onNewConversation: { startNewConversation() }
            )

            if !conversationID.isEmpty {
                chatExperienceView
            }
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
            .navigationTitle("OpenRocky")
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
            // Detail: chat experience with top chrome
            ZStack(alignment: .top) {
                if !conversationID.isEmpty {
                    chatExperienceView
                        .ignoresSafeArea()
                }

                OpenRockyTopChromeView(
                    providerStatus: chatProviderStore.status,
                    isVoiceActive: showsVoiceOverlay,
                    openProviderSettings: { showsProviderSettings = true },
                    openVoiceOverlay: { toggleVoiceSession() },
                    openConversationList: {
                        withAnimation { sidebarVisibility = sidebarVisibility == .all ? .detailOnly : .all }
                    },
                    onNewConversation: { startNewConversation() }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Shared Chat View

    private var chatExperienceView: some View {
        OpenRockyChatExperienceScreen(
            bootstrap: shellRuntime.probe,
            transcript: sessionRuntime.session.liveTranscript,
            providerConfiguration: chatProviderStore.configuration,
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

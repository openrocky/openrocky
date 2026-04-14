//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation
import ChatClientKit
import LanguageModelChatUI

/// Voice mode: realtime (WebSocket end-to-end) or traditional (STT + Chat + TTS).
enum OpenRockyVoiceMode: String, CaseIterable, Identifiable {
    case realtime
    case traditional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realtime: "Realtime"
        case .traditional: "Traditional (STT+Chat+TTS)"
        }
    }

    var summary: String {
        switch self {
        case .realtime: "Low-latency end-to-end voice via WebSocket. Requires OpenAI or GLM."
        case .traditional: "Separate STT, Chat, and TTS providers. Works with any chat model."
        }
    }
}

@MainActor
final class OpenRockySessionRuntime: ObservableObject {
    @Published private(set) var session: OpenRockyPreviewSession
    @Published private(set) var statusText = "Voice runtime is idle."
    @Published private(set) var isMicrophoneActive = false

    private let bridge = OpenRockyRealtimeVoiceBridge()
    private let traditionalBridge = OpenRockyTraditionalVoiceBridge()
    private let toolbox = OpenRockyToolbox()
    private let chatRuntime = OpenRockyChatInferenceRuntime()
    private let characterStore = OpenRockyCharacterStore.shared
    private let storage = OpenRockyPersistentStorageProvider.shared
    private let usageService = OpenRockyUsageService.shared
    var conversationID: String = ""
    private var userTranscriptBuffer = ""
    private var assistantTranscriptBuffer = ""
    private var lastToolName: String?
    private var chatConfiguration = OpenRockyProviderConfiguration(provider: .openAI, modelID: OpenRockyProviderKind.openAI.defaultModel)
    private var voiceConfiguration = OpenRockyRealtimeProviderConfiguration(provider: .openAI, modelID: OpenRockyRealtimeProviderKind.openAI.defaultModel)
    private var sttConfiguration = OpenRockySTTProviderConfiguration(provider: .openAI, modelID: OpenRockySTTProviderKind.openAI.defaultModel)
    private var ttsConfiguration = OpenRockyTTSProviderConfiguration(provider: .openAI, modelID: OpenRockyTTSProviderKind.openAI.defaultModel)
    private var voiceFeatures = OpenRockyRealtimeVoiceFeatures.openAI
    /// The active voice mode for the current session.
    private(set) var activeVoiceMode: OpenRockyVoiceMode = .realtime
    private var chatTask: Task<Void, Never>?
    /// Active tool execution tasks from voice provider — cancelled on voice stop / turn reset.
    private var toolTasks: [Task<Void, Never>] = []
    /// Tool calls completed by the realtime voice provider (not via chatRuntime).
    private var realtimeCompletedToolCalls: [OpenRockyChatInferenceRuntime.CompletedToolCall] = []
    /// Set after `finishChatInference` saves the turn, so the TTS-end
    /// `assistantTranscriptFinal` event doesn't duplicate-save.
    private var chatTurnAlreadySaved = false

    init() {
        let provider = ProviderStatus(
            name: OpenRockyRealtimeProviderKind.openAI.displayName,
            model: OpenRockyRealtimeProviderKind.openAI.defaultModel,
            isConnected: false
        )
        session = .liveSeed(provider: provider)

        // Wire up subagent status updates from toolbox → session statusText
        let statusHandler: @MainActor (String) -> Void = { [weak self] status in
            self?.statusText = status
            self?.appendTimeline(kind: .tool, text: status)
        }
        toolbox.subagentStatusHandler = statusHandler
        chatRuntime.toolbox.subagentStatusHandler = statusHandler
    }

    func syncProviders(
        chatConfiguration: OpenRockyProviderConfiguration,
        voiceConfiguration: OpenRockyRealtimeProviderConfiguration,
        sttConfiguration: OpenRockySTTProviderConfiguration? = nil,
        ttsConfiguration: OpenRockyTTSProviderConfiguration? = nil
    ) {
        self.chatConfiguration = chatConfiguration.normalized()
        self.voiceConfiguration = voiceConfiguration.normalized()
        if let sttConfiguration { self.sttConfiguration = sttConfiguration.normalized() }
        if let ttsConfiguration { self.ttsConfiguration = ttsConfiguration.normalized() }
        // Keep the toolbox's subagent chat configuration in sync
        let normalizedChat = chatConfiguration.normalized()
        toolbox.subagentChatConfiguration = normalizedChat
        chatRuntime.toolbox.subagentChatConfiguration = normalizedChat

        // Determine voice mode: use traditional if STT+TTS are configured, otherwise realtime
        let sttReady = self.sttConfiguration.isConfigured
        let ttsReady = self.ttsConfiguration.isConfigured
        let preferTraditional = UserDefaults.standard.string(forKey: "rocky.pref.voiceMode") == OpenRockyVoiceMode.traditional.rawValue
        activeVoiceMode = (preferTraditional && sttReady && ttsReady) ? .traditional : .realtime

        let providerName = activeVoiceMode == .realtime
            ? voiceConfiguration.provider.displayName
            : "STT+Chat+TTS"
        session.provider = ProviderStatus(
            name: providerName,
            model: activeVoiceMode == .realtime ? voiceConfiguration.modelID : chatConfiguration.modelID,
            isConnected: activeVoiceMode == .realtime ? voiceConfiguration.isConfigured : (sttReady && ttsReady && chatConfiguration.isConfigured)
        )
    }

    func toggleVoiceSession(voiceConfiguration: OpenRockyRealtimeProviderConfiguration) {
        if isMicrophoneActive {
            stopVoiceSession()
        } else {
            startVoiceSession(configuration: voiceConfiguration)
        }
    }

    func startVoiceSession(configuration: OpenRockyRealtimeProviderConfiguration) {
        var config = configuration
        let character = characterStore.activeCharacter
        config.characterName = character.name
        config.characterSpeakingStyle = character.speakingStyle
        config.characterGreeting = character.greeting.isEmpty ? nil : character.greeting
        // Apply character's voice preferences if the provider instance doesn't specify one
        if config.openaiVoice == nil, let voice = character.openaiVoice {
            config.openaiVoice = voice
        }

        syncProviders(chatConfiguration: chatConfiguration, voiceConfiguration: config, sttConfiguration: sttConfiguration, ttsConfiguration: ttsConfiguration)
        // Clear all previous voice state for a fresh session
        resetAssistantTurn()
        userTranscriptBuffer = ""
        session.liveTranscript = ""
        session.timeline.removeAll()
        session.mode = .planning
        statusText = "Starting voice session..."
        refreshPlan(connect: .active, capture: .queued, tool: .queued, answer: .queued)

        if activeVoiceMode == .traditional {
            rlog.info("Starting traditional voice session: STT=\(sttConfiguration.provider.rawValue) TTS=\(ttsConfiguration.provider.rawValue) Chat=\(chatConfiguration.provider.rawValue)", category: "Session")
            Task {
                do {
                    try await traditionalBridge.start(
                        sttConfiguration: sttConfiguration,
                        ttsConfiguration: ttsConfiguration,
                        eventSink: makeEventSink()
                    )
                } catch {
                    handle(error: error)
                }
            }
        } else {
            rlog.info("Starting realtime voice session: provider=\(config.provider.rawValue) model=\(config.modelID)", category: "Session")
            Task {
                do {
                    try await bridge.startIfNeeded(
                        configuration: config,
                        voiceInputEnabled: true,
                        soulInstructions: characterStore.voiceSystemPrompt,
                        realtimeTools: toolbox.realtimeTools(),
                        eventSink: makeEventSink()
                    )
                } catch {
                    handle(error: error)
                }
            }
        }
    }

    func stopVoiceSession() {
        rlog.info("Stopping voice session (mode=\(activeVoiceMode.rawValue))", category: "Session")
        isMicrophoneActive = false
        session.mode = .ready
        statusText = "Voice session stopped."
        refreshPlan(connect: .queued, capture: .queued, tool: .queued, answer: .queued)
        appendTimeline(kind: .system, text: "Voice session stopped and the live runtime was disconnected.")

        Task {
            if activeVoiceMode == .traditional {
                await traditionalBridge.stop()
            } else {
                await bridge.stop()
            }
        }
    }

    func submitText(_ text: String, configuration: OpenRockyProviderConfiguration) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        syncProviders(chatConfiguration: configuration, voiceConfiguration: voiceConfiguration)
        session.liveTranscript = trimmed
        session.mode = .planning
        statusText = "Sending typed input..."
        userTranscriptBuffer = trimmed
        resetAssistantTurn()
        refreshPlan(connect: .active, capture: .done, tool: .queued, answer: .queued)
        appendTimeline(kind: .speech, text: "Typed input: \(trimmed)")

        if isMicrophoneActive, voiceFeatures.supportsTextInput {
            Task {
                do {
                    try await bridge.sendText(trimmed)
                } catch {
                    handle(error: error)
                }
            }
            return
        }

        runChatInference(prompt: trimmed, configuration: configuration)
    }

    private func makeEventSink() -> @Sendable (OpenRockyRealtimeEvent) -> Void {
        { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event: event)
            }
        }
    }

    private func handle(event: OpenRockyRealtimeEvent) {
        switch event {
        case .status(let text):
            statusText = text
        case .sessionReady(let model, let features):
            voiceFeatures = features
            session.provider = ProviderStatus(
                name: session.provider.name,
                model: model,
                isConnected: true
            )
            session.mode = isMicrophoneActive ? .listening : .ready
            statusText = isMicrophoneActive ? "Listening for voice input..." : "Realtime session ready for text and follow-up."
            refreshPlan(connect: .done, capture: isMicrophoneActive ? .active : .queued, tool: .queued, answer: .queued)
            appendTimeline(kind: .system, text: "Realtime model `\(model)` is attached to the home runtime.")
        case .inputSpeechStarted:
            // New turn — clear buffers from previous turn
            userTranscriptBuffer = ""
            assistantTranscriptBuffer = ""
            Task {
                await bridge.interruptPlayback()
            }
        case .microphoneActive(let isActive):
            isMicrophoneActive = isActive
            session.mode = isActive ? .listening : .ready
            statusText = isActive ? "Listening for voice input..." : statusText
        case .userTranscriptDelta(let delta):
            userTranscriptBuffer = delta
            session.liveTranscript = delta
            session.mode = .listening
            refreshPlan(connect: .done, capture: .active, tool: .queued, answer: .queued)
        case .userTranscriptFinal(let text):
            let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard finalText.isEmpty == false else { return }
            userTranscriptBuffer = finalText
            session.liveTranscript = finalText
            session.mode = .planning
            statusText = "Planning from live transcript..."
            refreshPlan(connect: .done, capture: .done, tool: voiceFeatures.supportsToolCalls ? .active : .queued, answer: .queued)
            appendTimeline(kind: .speech, text: "Voice transcript: \(finalText)")
            if activeVoiceMode == .traditional || voiceFeatures.supportsAssistantStreaming == false {
                runChatInference(prompt: finalText, configuration: chatConfiguration)
            }
        case .assistantTranscriptDelta(let delta):
            if assistantTranscriptBuffer.isEmpty {
                assistantTranscriptBuffer = delta
            } else {
                assistantTranscriptBuffer += delta
            }
            session.assistantReply = assistantTranscriptBuffer
            session.mode = .executing
            statusText = "OpenRocky is responding..."
            refreshPlan(connect: .done, capture: .done, tool: lastToolName == nil ? .done : .active, answer: .active)
        case .assistantTranscriptFinal(let text):
            let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedText = finalText.isEmpty ? assistantTranscriptBuffer : finalText
            guard resolvedText.isEmpty == false else {
                // TTS finished but no transcript text — still must resume mic.
                chatTurnAlreadySaved = false
                session.mode = .ready
                statusText = "OpenRocky is ready for the next follow-up."
                Task { await bridge.resumeMicAfterPlayback() }
                lastToolName = nil
                return
            }
            assistantTranscriptBuffer = resolvedText
            session.assistantReply = resolvedText
            session.mode = .ready
            statusText = "OpenRocky is ready for the next follow-up."
            refreshPlan(connect: .done, capture: .done, tool: lastToolName == nil ? .done : .done, answer: .done)
            if chatTurnAlreadySaved {
                // Chat model already saved this turn — skip duplicate save.
                chatTurnAlreadySaved = false
            } else {
                appendTimeline(kind: .result, text: resolvedText)
                saveVoiceTurnToConversation(userText: userTranscriptBuffer, assistantText: resolvedText)
                // Record voice usage (estimate tokens from transcript length)
                let estimatedTokens = max(1, (userTranscriptBuffer.count + resolvedText.count) / 4)
                usageService.recordVoice(
                    provider: voiceConfiguration.provider.displayName,
                    model: voiceConfiguration.modelID,
                    totalTokens: estimatedTokens
                )
            }
            // Resume mic after assistant finishes speaking (echo suppression lift)
            if activeVoiceMode == .traditional {
                Task { await traditionalBridge.resumeListening() }
            } else {
                Task { await bridge.resumeMicAfterPlayback() }
            }
            lastToolName = nil
        case .assistantAudioChunk:
            if activeVoiceMode == .realtime {
                Task {
                    await bridge.handlePlaybackEvent(event)
                }
            }
            // Traditional mode handles its own playback in synthesizeAndPlay
        case .assistantAudioDone:
            if activeVoiceMode == .realtime {
                Task {
                    await bridge.flushBufferedAudio()
                }
            }
        case .toolCallRequested(let name, let arguments, let callID):
            lastToolName = name
            session.mode = .executing
            statusText = "Running \(name)..."
            refreshPlan(connect: .done, capture: .done, tool: .active, answer: .queued, toolDetail: "Executing \(name) with live runtime arguments.")
            appendTimeline(kind: .tool, text: "Requested tool call: `\(name)`")

            let toolTask = Task {
                do {
                    rlog.info("Voice tool executing: \(name) args=\(arguments.prefix(200))", category: "Session")
                    let output = try await toolbox.execute(name: name, arguments: arguments)
                    guard !Task.isCancelled else { return }
                    self.realtimeCompletedToolCalls.append(.init(
                        id: callID, name: name, arguments: arguments,
                        result: output, succeeded: true
                    ))
                    appendTimeline(kind: .tool, text: "Completed tool call: `\(name)`")
                    try await bridge.sendToolOutput(callID: callID, output: output)
                } catch {
                    guard !Task.isCancelled else { return }
                    let message = error.localizedDescription
                    let nsError = error as NSError
                    rlog.error("Voice tool \(name) FAILED args=\(arguments.prefix(300)) error=\(message) domain=\(nsError.domain) code=\(nsError.code)", category: "Session")
                    self.realtimeCompletedToolCalls.append(.init(
                        id: callID, name: name, arguments: arguments,
                        result: message, succeeded: false
                    ))
                    appendTimeline(kind: .tool, text: "Tool `\(name)` failed: \(message)")
                    try? await bridge.sendToolOutput(callID: callID, output: #"{"error":"\#(message.replacingOccurrences(of: "\"", with: "\\\""))"}"#)
                }
            }
            toolTasks.append(toolTask)
        case .error(let text):
            handle(errorMessage: text)
        }
    }

    private func handle(error: Error) {
        rlog.error("Session error: \(error.localizedDescription) (type=\(type(of: error)))", category: "Session")
        handle(errorMessage: error.localizedDescription)
    }

    private func handle(errorMessage: String) {
        statusText = errorMessage
        session.mode = .ready
        refreshPlan(connect: .active, capture: .queued, tool: .queued, answer: .queued)
        appendTimeline(kind: .system, text: errorMessage)
    }

    private func appendTimeline(kind: TimelineKind, text: String) {
        session.timeline.append(
            TimelineEntry(
                kind: kind,
                time: Date().formatted(date: .omitted, time: .shortened),
                text: text
            )
        )
        if session.timeline.count > 8 {
            session.timeline.removeFirst(session.timeline.count - 8)
        }
    }

    private func resetAssistantTurn() {
        chatTask?.cancel()
        toolTasks.forEach { $0.cancel() }
        toolTasks.removeAll()
        assistantTranscriptBuffer = ""
        session.assistantReply = "OpenRocky is waiting for a model reply."
        lastToolName = nil
        chatTurnAlreadySaved = false
        realtimeCompletedToolCalls = []
    }

    private func saveVoiceTurnToConversation(userText: String, assistantText: String) {
        guard !conversationID.isEmpty, !userText.isEmpty, !assistantText.isEmpty else { return }
        let userMsg = ConversationMessage(conversationID: conversationID, role: .user)
        userMsg.parts = [.text(TextContentPart(text: userText))]

        var messages: [ConversationMessage] = [userMsg]

        // Include tool call parts from both chat inference and realtime voice provider (deduplicated by ID)
        var seenToolCallIDs: Set<String> = []
        let toolCalls = (chatRuntime.completedToolCalls + realtimeCompletedToolCalls).filter { seenToolCallIDs.insert($0.id).inserted }
        if !toolCalls.isEmpty {
            let allToolDefs = OpenRockyBuiltInToolStore.shared.tools
            let toolMsg = ConversationMessage(conversationID: conversationID, role: .assistant)
            toolMsg.parts = toolCalls.map { tc in
                let def = allToolDefs.first { $0.id == tc.name }
                // For skill tools, look up display name from custom skill store
                let displayName: String
                let icon: String?
                if let skill = OpenRockyCustomSkillStore.shared.skill(forToolName: tc.name) {
                    displayName = "Skill: \(skill.name)"
                    icon = "sparkles"
                } else {
                    displayName = def?.displayName ?? tc.name
                    icon = def?.icon
                }
                return .toolCall(ToolCallContentPart(
                    id: tc.id,
                    toolName: displayName,
                    apiName: tc.name,
                    toolIcon: icon,
                    parameters: tc.arguments,
                    state: tc.succeeded ? .succeeded : .failed,
                    result: tc.result
                ))
            }
            messages.append(toolMsg)
        }

        let assistantMsg = ConversationMessage(conversationID: conversationID, role: .assistant)
        assistantMsg.parts = [.text(TextContentPart(text: assistantText))]
        messages.append(assistantMsg)

        storage.save(messages)
        generateTitleIfNeeded()
    }

    private func generateTitleIfNeeded() {
        guard let session = ConversationSessionManager.shared.existingSession(for: conversationID) else { return }
        session.refreshContentsFromDatabase(scrolling: true)
        Task { await session.updateTitle() }
    }

    private func runChatInference(prompt: String, configuration: OpenRockyProviderConfiguration) {
        chatTask?.cancel()
        resetAssistantTurn()
        session.mode = .planning
        statusText = "Generating reply from the chat provider..."
        refreshPlan(connect: .done, capture: .done, tool: .queued, answer: .active)

        // Reset conversation for voice — avoids tool_use/tool_result mismatch from prior turns
        chatRuntime.resetConversation()

        // Reload recent messages so the chat model has conversation context
        // Limit to last 10 messages to keep inference fast for voice mode
        if !conversationID.isEmpty {
            let allHistory = storage.messages(in: conversationID)
            let recentHistory = Array(allHistory.suffix(10))
            chatRuntime.loadHistory(from: recentHistory)
        }

        chatTask = Task { [weak self] in
            guard let self else { return }

            do {
                rlog.info("Chat inference starting for prompt: \(prompt.prefix(80))", category: "Session")
                try await self.chatRuntime.run(
                    prompt: prompt,
                    configuration: configuration
                ) { chunk in
                    self.applyChatChunk(chunk)
                }
                rlog.info("Chat inference completed, reply=\(self.assistantTranscriptBuffer.prefix(100))", category: "Session")
                self.finishChatInference()
            } catch {
                self.handle(error: error)
            }
        }
    }

    private var isDoubaoVoiceMode: Bool {
        false
    }

    private func applyChatChunk(_ chunk: ChatResponseChunk) {
        switch chunk {
        case .reasoning:
            break
        case .text(let text):
            if assistantTranscriptBuffer.isEmpty {
                assistantTranscriptBuffer = text
            } else {
                assistantTranscriptBuffer += text
            }
            // In Doubao voice mode, skip streaming UI updates — TTS needs the
            // full text anyway, so we show the final result all at once.
            if !isDoubaoVoiceMode {
                session.assistantReply = assistantTranscriptBuffer
            }
            session.mode = .executing
            statusText = "OpenRocky is responding..."
            refreshPlan(connect: .done, capture: .done, tool: .queued, answer: .active)
        case .tool(let request):
            appendTimeline(kind: .tool, text: "Chat provider requested tool `\(request.name)` but typed fallback tool execution is not wired yet.")
        case .image, .thinkingBlock, .redactedThinking:
            break
        }
    }

    private func finishChatInference() {
        let finalText = assistantTranscriptBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        rlog.info("finishChatInference: \(finalText.prefix(100))", category: "Session")
        guard finalText.isEmpty == false else {
            rlog.warning("finishChatInference: empty text, skipping", category: "Session")
            return
        }
        session.assistantReply = finalText
        session.mode = .ready
        statusText = "OpenRocky is ready for the next follow-up."
        refreshPlan(connect: .done, capture: .done, tool: .queued, answer: .done)
        appendTimeline(kind: .result, text: finalText)
        saveVoiceTurnToConversation(userText: userTranscriptBuffer, assistantText: finalText)
        chatTurnAlreadySaved = true
        // Record chat usage (estimate tokens from transcript length)
        let estimatedTokens = max(1, (userTranscriptBuffer.count + finalText.count) / 4)
        usageService.recordVoice(
            provider: chatConfiguration.provider.displayName,
            model: chatConfiguration.modelID,
            totalTokens: estimatedTokens
        )
        // Send response to TTS
        let ttsText = OpenRockyTraditionalVoiceBridge.stripMarkdown(finalText)
        if activeVoiceMode == .traditional, isMicrophoneActive {
            // Traditional mode: use the dedicated TTS client
            Task {
                rlog.info("Traditional TTS: synthesizing \(ttsText.count) chars", category: "Session")
                await traditionalBridge.synthesizeAndPlay(text: ttsText)
            }
        } else {
            // Realtime mode: send to voice provider for TTS
            Task {
                do {
                    rlog.info("Sending TTS text (\(ttsText.count) chars)", category: "Session")
                    try await bridge.speakText(ttsText)
                } catch {
                    rlog.error("speakText failed: \(error.localizedDescription)", category: "Session")
                }
            }
        }
    }

    private func refreshPlan(
        connect: StepState,
        capture: StepState,
        tool: StepState,
        answer: StepState,
        toolDetail: String? = nil
    ) {
        session.plan = [
            PlanStep(
                title: "Connect live runtime",
                detail: "Attach one realtime session that both voice and text can reuse.",
                state: connect
            ),
            PlanStep(
                title: "Capture user intent",
                detail: "Stream microphone audio or accept the home text composer through the same session state.",
                state: capture
            ),
            PlanStep(
                title: "Run first Apple tools",
                detail: toolDetail ?? "Use `apple-location`, `apple-weather`, or `apple-alarm` only when they materially help finish the task.",
                state: tool
            ),
            PlanStep(
                title: "Reply with transcript and audio",
                detail: "Keep the answer visible on the home surface while the realtime model speaks back.",
                state: answer
            )
        ]
    }
}

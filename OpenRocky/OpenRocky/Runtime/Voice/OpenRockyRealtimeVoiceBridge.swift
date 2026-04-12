//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

@RealtimeActor
final class OpenRockyRealtimeVoiceBridge {
    private var client: (any OpenRockyRealtimeVoiceClient)?
    private var audioController: AudioController?
    private var microphoneTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var activeConfiguration: OpenRockyRealtimeProviderConfiguration?
    private var soulInstructions: String = ""

    /// When true, mic audio is not forwarded to the server (echo suppression).
    private var isMicSuspended: Bool = false

    /// Set when the server finishes its response, so we know to resume mic once playback drains.
    private var pendingMicResume: Bool = false

    func startIfNeeded(
        configuration: OpenRockyRealtimeProviderConfiguration,
        voiceInputEnabled: Bool,
        soulInstructions: String,
        realtimeTools: [OpenAIRealtimeSessionConfiguration.RealtimeTool],
        eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void
    ) async throws {
        self.eventSink = eventSink
        self.soulInstructions = soulInstructions
        let normalized = configuration.normalized()

        if activeConfiguration?.identity != normalized.identity || client == nil {
            if client != nil {
                await stop()
            }

            let client = try Self.makeClient(configuration: normalized, soulInstructions: soulInstructions, realtimeTools: realtimeTools)
            try await client.connect(eventSink: eventSink)
            self.client = client
            activeConfiguration = normalized
        }

        try await configureAudioController(voiceInputEnabled: voiceInputEnabled)
    }

    func stop() async {
        microphoneTask?.cancel()
        microphoneTask = nil

        do {
            try await client?.finishAudioInput()
        } catch {
            rlog.error("Voice stop error: \(error)", category: "Voice")
            emit(.status("Voice session ended."))
        }

        audioController?.stop()
        audioController = nil
        await client?.disconnect()
        client = nil
        activeConfiguration = nil
        isMicSuspended = false
        pendingMicResume = false
        emit(.microphoneActive(false))
        emit(.status("Voice session stopped."))
    }

    func sendText(_ text: String) async throws {
        guard let client else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        try await client.sendText(text)
    }

    func sendToolOutput(callID: String, output: String) async throws {
        guard let client else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        try await client.sendToolOutput(callID: callID, output: output)
    }

    func speakText(_ text: String) async throws {
        guard let client else {
            throw OpenRockyRealtimeVoiceClientError.notConnected
        }
        try await client.speakText(text)
    }

    private func configureAudioController(voiceInputEnabled: Bool) async throws {
        let modes: [AudioController.Mode] = voiceInputEnabled ? [.playback, .record] : [.playback]

        if voiceInputEnabled, audioController != nil, microphoneTask != nil {
            emit(.microphoneActive(true))
            return
        }

        audioController?.stop()
        audioController = try await AudioController(modes: modes)
        audioController?.setPlaybackDrainedHandler { [weak self] in
            Task { @RealtimeActor [weak self] in
                guard let self else { return }
                rlog.debug("Bridge: playback drained, pendingMicResume=\(self.pendingMicResume)", category: "Audio")
                guard self.pendingMicResume else { return }
                rlog.debug("Bridge: resuming mic after drain", category: "Audio")
                self.pendingMicResume = false
                self.isMicSuspended = false
            }
        }
        emit(.microphoneActive(voiceInputEnabled))

        if voiceInputEnabled {
            startMicrophoneLoop()
        } else {
            microphoneTask?.cancel()
            microphoneTask = nil
        }
    }

    private func startMicrophoneLoop() {
        guard let client, let audioController else { return }
        microphoneTask?.cancel()
        microphoneTask = Task {
            do {
                let micStream = try audioController.micStream()
                rlog.info("Mic stream started, suspended=\(isMicSuspended)", category: "Audio")
                var micBufferCount = 0
                var skippedCount = 0
                for await buffer in micStream {
                    guard Task.isCancelled == false else { break }
                    micBufferCount += 1
                    // Skip sending mic data while assistant is playing audio (echo suppression)
                    guard !isMicSuspended else {
                        skippedCount += 1
                        if skippedCount % 50 == 1 {
                            rlog.debug("Mic buffer skipped (suspended), skipped=\(skippedCount)", category: "Audio")
                        }
                        continue
                    }
                    guard let base64Audio = AudioUtils.base64EncodeAudioPCMBuffer(from: buffer) else {
                        rlog.warning("Mic buffer encode failed at #\(micBufferCount)", category: "Audio")
                        continue
                    }
                    if micBufferCount % 50 == 1 {
                        rlog.debug("Mic buffer #\(micBufferCount) sending, b64=\(base64Audio.count)", category: "Audio")
                    }
                    try await client.sendAudioChunk(base64Audio: base64Audio)
                }
                rlog.info("Mic stream ended, total buffers=\(micBufferCount)", category: "Audio")
            } catch {
                rlog.error("Mic stream error: \(error.localizedDescription)", category: "Audio")
                emit(.error(error.localizedDescription))
            }
        }
    }

    func handlePlaybackEvent(_ event: OpenRockyRealtimeEvent) {
        guard case .assistantAudioChunk(let audio) = event else { return }
        // Suspend mic while assistant audio is playing to prevent echo feedback.
        // Doubao server handles VAD/echo internally, so mic stays active.
        if client?.features.needsMicSuspension == true {
            if !isMicSuspended {
                rlog.debug("Suspending mic for playback", category: "Audio")
            }
            isMicSuspended = true
        }
        audioController?.playPCM16Audio(base64String: audio)
    }

    func interruptPlayback() {
        audioController?.interruptPlayback()
        // Resume mic immediately when playback is interrupted (user wants to speak)
        pendingMicResume = false
        isMicSuspended = false
    }

    /// Called when the assistant finishes its response (transcript final).
    /// Defers mic resume until all queued audio buffers have actually played out.
    func resumeMicAfterPlayback() {
        if audioController?.isPlaybackActive == true {
            // Audio still playing — defer resume until playback drains
            rlog.debug("resumeMicAfterPlayback: deferring (playback active)", category: "Audio")
            pendingMicResume = true
        } else {
            // No buffered audio left, safe to resume now
            rlog.debug("resumeMicAfterPlayback: resuming now", category: "Audio")
            pendingMicResume = false
            isMicSuspended = false
        }
    }

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }

    private static func makeClient(
        configuration: OpenRockyRealtimeProviderConfiguration,
        soulInstructions: String,
        realtimeTools: [OpenAIRealtimeSessionConfiguration.RealtimeTool]
    ) throws -> any OpenRockyRealtimeVoiceClient {
        switch configuration.provider {
        case .openAI:
            let chatConfiguration = OpenRockyProviderConfiguration(
                provider: .openAI,
                modelID: configuration.modelID,
                credential: configuration.credential
            )
            guard OpenRockyOpenAIServiceFactory.supportsRealtime(configuration: chatConfiguration) else {
                throw OpenRockyRealtimeVoiceBridgeError.unsupportedProvider
            }
            return OpenRockyOpenAIRealtimeVoiceClient(configuration: chatConfiguration, realtimeConfiguration: configuration, soulInstructions: soulInstructions, realtimeTools: realtimeTools)
        case .doubao:
            return OpenRockyDoubaoRealtimeVoiceClient(configuration: configuration, soulInstructions: soulInstructions, realtimeTools: realtimeTools)
        case .gemini:
            return OpenRockyGeminiRealtimeVoiceClient(configuration: configuration, soulInstructions: soulInstructions, realtimeTools: realtimeTools)
        case .glm:
            return OpenRockyGLMRealtimeVoiceClient(configuration: configuration, soulInstructions: soulInstructions, realtimeTools: realtimeTools)
        }
    }
}

enum OpenRockyRealtimeVoiceBridgeError: LocalizedError {
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            "Realtime voice currently requires a supported voice provider configuration."
        }
    }
}

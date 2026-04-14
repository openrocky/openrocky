//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AVFoundation
import Foundation
@preconcurrency import SwiftOpenAI

/// Traditional voice pipeline: Mic → VAD → STT → Chat → TTS → Speaker.
/// Emits the same `OpenRockyRealtimeEvent` as the realtime bridge, so the
/// SessionRuntime and UI layer need zero changes.
@RealtimeActor
final class OpenRockyTraditionalVoiceBridge {
    private var sttClient: (any OpenRockySTTClient)?
    private var ttsClient: (any OpenRockyTTSClient)?
    private var audioController: AudioController?
    private var microphoneTask: Task<Void, Never>?
    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private var audioPlayer: AVAudioPlayer?

    /// PCM16 audio buffer accumulated from microphone input.
    private var micBuffer = Data()
    /// Whether the user is currently speaking (based on VAD).
    private var isSpeaking = false
    /// Number of consecutive silent chunks (for VAD end-of-speech detection).
    private var silentChunkCount = 0
    /// Whether the bridge is actively processing (STT → Chat → TTS).
    private var isProcessing = false

    /// RMS threshold for voice activity detection.
    private let vadSpeechThreshold: Double = 800
    /// Number of silent chunks before committing speech (at ~24kHz with 2400-sample buffers ≈ 100ms each).
    private let vadSilenceChunks = 12  // ~1.2 seconds of silence

    let features = OpenRockyRealtimeVoiceFeatures(
        supportsTextInput: true,
        supportsAssistantStreaming: true,
        supportsToolCalls: true,
        supportsAudioOutput: true,
        needsMicSuspension: true
    )

    nonisolated init() {}

    // MARK: - Lifecycle

    func start(
        sttConfiguration: OpenRockySTTProviderConfiguration,
        ttsConfiguration: OpenRockyTTSProviderConfiguration,
        eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void
    ) async throws {
        self.eventSink = eventSink

        // Create STT client
        let sttConfig = sttConfiguration.normalized()
        sttClient = Self.makeSTTClient(configuration: sttConfig)

        // Create TTS client
        let ttsConfig = ttsConfiguration.normalized()
        ttsClient = Self.makeTTSClient(configuration: ttsConfig)

        // Configure audio
        audioController?.stop()
        audioController = try await AudioController(modes: [.playback, .record])

        emit(.status("Traditional voice session starting..."))
        emit(.sessionReady(model: "STT+Chat+TTS", features: features))
        emit(.microphoneActive(true))

        // Start mic loop
        startMicrophoneLoop()

        rlog.info("Traditional voice bridge started: STT=\(sttConfig.provider.displayName) TTS=\(ttsConfig.provider.displayName)", category: "Voice")
    }

    func stop() {
        microphoneTask?.cancel()
        microphoneTask = nil
        audioController?.stop()
        audioController = nil
        audioPlayer?.stop()
        audioPlayer = nil
        sttClient = nil
        ttsClient = nil
        micBuffer = Data()
        isSpeaking = false
        silentChunkCount = 0
        isProcessing = false
        emit(.microphoneActive(false))
        emit(.status("Voice session stopped."))
    }

    /// Speak text through TTS without going through the chat pipeline.
    func speakText(_ text: String) async {
        guard let ttsClient else { return }
        do {
            let audioData = try await ttsClient.synthesize(text: text)
            await playAudio(data: audioData)
        } catch {
            rlog.error("TTS speakText failed: \(error.localizedDescription)", category: "TTS")
        }
    }

    // MARK: - Microphone & VAD

    private func startMicrophoneLoop() {
        guard let audioController else { return }
        microphoneTask?.cancel()
        microphoneTask = Task { [weak self] in
            guard let self else { return }
            do {
                let micStream = try audioController.micStream()
                rlog.info("Traditional bridge: mic stream started", category: "Audio")

                for await buffer in micStream {
                    guard !Task.isCancelled else { break }
                    guard !self.isProcessing else { continue }

                    guard let pcmData = Self.extractPCMData(from: buffer) else { continue }
                    let rms = AudioUtils.computeRMS(pcmData)

                    if rms > self.vadSpeechThreshold {
                        if !self.isSpeaking {
                            self.isSpeaking = true
                            self.micBuffer = Data()
                            self.emit(.inputSpeechStarted)
                            rlog.debug("VAD: speech started (rms=\(rms))", category: "Audio")
                        }
                        self.silentChunkCount = 0
                        self.micBuffer.append(pcmData)
                    } else if self.isSpeaking {
                        self.micBuffer.append(pcmData)
                        self.silentChunkCount += 1

                        if self.silentChunkCount >= self.vadSilenceChunks {
                            rlog.info("VAD: speech ended, buffer=\(self.micBuffer.count) bytes", category: "Audio")
                            self.isSpeaking = false
                            self.silentChunkCount = 0
                            let audioData = self.micBuffer
                            self.micBuffer = Data()
                            self.processUserAudio(audioData)
                        }
                    }
                }
            } catch {
                rlog.error("Traditional bridge mic error: \(error.localizedDescription)", category: "Audio")
                self.emit(.error(error.localizedDescription))
            }
        }
    }

    /// Process captured user audio: STT → emit transcript.
    private func processUserAudio(_ audioData: Data) {
        guard let sttClient else {
            emit(.error("STT provider not configured"))
            return
        }
        guard audioData.count > 4800 else {
            rlog.debug("VAD: audio too short (\(audioData.count) bytes), ignoring", category: "Audio")
            return
        }

        isProcessing = true
        emit(.status("Recognizing speech..."))

        Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await sttClient.transcribe(audioData: audioData)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    rlog.debug("STT returned empty text, ignoring", category: "STT")
                    self.isProcessing = false
                    return
                }

                rlog.info("STT result: \(trimmed.prefix(100))", category: "STT")
                self.emit(.userTranscriptDelta(trimmed))
                self.emit(.userTranscriptFinal(trimmed))
            } catch {
                rlog.error("STT failed: \(error.localizedDescription)", category: "STT")
                self.emit(.error("Speech recognition failed: \(error.localizedDescription)"))
                self.isProcessing = false
            }
        }
    }

    // MARK: - TTS Playback

    /// Synthesize text via TTS and play it, emitting audio events.
    func synthesizeAndPlay(text: String) async {
        guard let ttsClient else {
            emit(.error("TTS provider not configured"))
            resumeListening()
            return
        }

        let cleanText = Self.stripMarkdown(text)
        guard !cleanText.isEmpty else {
            resumeListening()
            return
        }

        let sentences = Self.splitIntoSentences(cleanText)

        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            do {
                let audioData = try await ttsClient.synthesize(text: trimmed)
                await playAudio(data: audioData)
            } catch {
                rlog.error("TTS synthesis failed for sentence: \(error.localizedDescription)", category: "TTS")
            }
        }

        emit(.assistantAudioDone)
        resumeListening()
    }

    /// Resume mic listening after TTS playback completes.
    func resumeListening() {
        isProcessing = false
    }

    // MARK: - Audio Playback

    private func playAudio(data: Data) async {
        emit(.assistantAudioChunk(data.base64EncodedString()))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            do {
                let player = try AVAudioPlayer(data: data)
                self.audioPlayer = player
                let delegate = AudioPlayerDelegate {
                    continuation.resume()
                }
                player.delegate = delegate
                objc_setAssociatedObject(player, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                player.play()
            } catch {
                rlog.error("Audio playback failed: \(error.localizedDescription)", category: "Audio")
                continuation.resume()
            }
        }
    }

    // MARK: - Helpers

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }

    nonisolated private static func makeSTTClient(configuration: OpenRockySTTProviderConfiguration) -> any OpenRockySTTClient {
        switch configuration.provider {
        case .openAI, .groq, .aliCloud:
            // These all use OpenAI-compatible /v1/audio/transcriptions endpoint
            return OpenRockyOpenAISTTClient(configuration: configuration)
        case .deepgram:
            return OpenRockyDeepgramSTTClient(configuration: configuration)
        case .azureSpeech:
            return OpenRockyAzureSTTClient(configuration: configuration)
        case .googleCloud:
            return OpenRockyGoogleSTTClient(configuration: configuration)
        }
    }

    nonisolated private static func makeTTSClient(configuration: OpenRockyTTSProviderConfiguration) -> any OpenRockyTTSClient {
        switch configuration.provider {
        case .openAI, .aliCloud:
            // These use OpenAI-compatible /v1/audio/speech endpoint
            return OpenRockyOpenAITTSClient(configuration: configuration)
        case .miniMax:
            return OpenRockyMiniMaxTTSClient(configuration: configuration)
        case .elevenLabs:
            return OpenRockyElevenLabsTTSClient(configuration: configuration)
        case .volcengine:
            return OpenRockyVolcengineTTSClient(configuration: configuration)
        case .azureSpeech:
            return OpenRockyAzureTTSClient(configuration: configuration)
        case .googleCloud:
            return OpenRockyGoogleTTSClient(configuration: configuration)
        }
    }

    nonisolated private static func extractPCMData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard buffer.format.channelCount == 1,
              let ptr = buffer.audioBufferList.pointee.mBuffers.mData else { return nil }
        let byteCount = Int(buffer.audioBufferList.pointee.mBuffers.mDataByteSize)
        return Data(bytes: ptr, count: byteCount)
    }

    /// Strip markdown formatting for natural TTS.
    nonisolated static func stripMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
    }

    /// Split text into sentences for streaming TTS.
    nonisolated static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if "。！？.!?\n".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sentences.append(trimmed)
        }

        return sentences
    }
}

// MARK: - AVAudioPlayer Delegate

@preconcurrency
private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let onFinish: @Sendable () -> Void

    nonisolated init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
        super.init()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinish()
    }
}

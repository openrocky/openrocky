//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-10
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AVFoundation
import Foundation
import Speech
@preconcurrency import SwiftOpenAI

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A fully on-device voice client that combines:
/// - Apple Speech Recognition (STT) for user speech → text
/// - Apple Foundation Models (LLM) for generating responses
/// - AVSpeechSynthesizer (TTS) for reading responses aloud
///
/// No API key or network connection is required.
@RealtimeActor
final class OpenRockyAppleRealtimeVoiceClient: OpenRockyRealtimeVoiceClient {
    let modelID: String = "apple-native-voice"
    let features = OpenRockyRealtimeVoiceFeatures(
        supportsTextInput: true,
        supportsAssistantStreaming: true,
        supportsToolCalls: false,
        supportsAudioOutput: true,
        needsMicSuspension: true
    )

    private var eventSink: (@Sendable (OpenRockyRealtimeEvent) -> Void)?
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var pendingTranscript = ""
    private var silenceTimer: Task<Void, Never>?
    private var isProcessing = false
    private let soulInstructions: String

    // Audio format matching the mic stream from AudioController (PCM16, mono, 24kHz)
    private let audioFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    init(soulInstructions: String) {
        self.soulInstructions = soulInstructions
        self.speechRecognizer = SFSpeechRecognizer()
    }

    func connect(eventSink: @escaping @Sendable (OpenRockyRealtimeEvent) -> Void) async throws {
        self.eventSink = eventSink

        // Request speech recognition authorization
        let authStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard authStatus == .authorized else {
            throw OpenRockyAppleVoiceError.speechRecognitionNotAuthorized
        }

        guard speechRecognizer?.isAvailable == true else {
            throw OpenRockyAppleVoiceError.speechRecognizerUnavailable
        }

        emit(.sessionReady(model: modelID, features: features))
        emit(.status("Apple voice session is ready."))
        startRecognition()
    }

    func disconnect() async {
        silenceTimer?.cancel()
        silenceTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        pendingTranscript = ""
        isProcessing = false
    }

    func sendAudioChunk(base64Audio: String) async throws {
        guard let request = recognitionRequest else { return }
        guard let data = Data(base64Encoded: base64Audio) else { return }
        guard let buffer = pcm16DataToBuffer(data) else { return }
        request.append(buffer)
    }

    func finishAudioInput() async throws {
        recognitionRequest?.endAudio()
    }

    func sendText(_ text: String) async throws {
        emit(.userTranscriptFinal(text))
        await generateAndSpeak(text)
    }

    func sendToolOutput(callID: String, output: String) async throws {
        // Tool calling not supported for on-device Apple voice
    }

    // MARK: - Speech Recognition

    private func startRecognition() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @RealtimeActor [weak self] in
                guard let self, !self.isProcessing else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.pendingTranscript = transcript
                    self.emit(.userTranscriptDelta(transcript))

                    // Reset silence timer — after 1.5s of silence, finalize
                    self.silenceTimer?.cancel()
                    self.silenceTimer = Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        guard !Task.isCancelled else { return }
                        await self.finalizeAndRespond()
                    }

                    if result.isFinal {
                        self.silenceTimer?.cancel()
                        await self.finalizeAndRespond()
                    }
                }

                if let error {
                    let nsError = error as NSError
                    // Code 203 = no speech detected, not a real error
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203 {
                        self.restartRecognition()
                    } else {
                        rlog.error("Speech recognition error: \(error.localizedDescription)", category: "Voice")
                    }
                }
            }
        }
    }

    private func finalizeAndRespond() async {
        let text = pendingTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingTranscript = ""
        guard !text.isEmpty else {
            restartRecognition()
            return
        }

        emit(.userTranscriptFinal(text))
        isProcessing = true
        await generateAndSpeak(text)
        isProcessing = false
        restartRecognition()
    }

    private func restartRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        startRecognition()
    }

    // MARK: - LLM Response Generation

    private func generateAndSpeak(_ userText: String) async {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                var prompt = userText
                if !soulInstructions.isEmpty {
                    prompt = "[Instructions] \(soulInstructions)\n\n[User] \(userText)"
                }

                let session = LanguageModelSession()
                var fullResponse = ""

                // Stream response for incremental transcript updates
                let stream = session.streamResponse(to: prompt)
                for try await snapshot in stream {
                    let current = snapshot.content
                    if current.count > fullResponse.count {
                        let delta = String(current.dropFirst(fullResponse.count))
                        emit(.assistantTranscriptDelta(delta))
                        fullResponse = current
                    }
                }

                if !fullResponse.isEmpty {
                    emit(.assistantTranscriptFinal(fullResponse))
                    await synthesizeAndEmitAudio(fullResponse)
                }
            } catch {
                rlog.error("Apple FM voice response error: \(error.localizedDescription)", category: "Voice")
                emit(.error("Response generation failed: \(error.localizedDescription)"))
            }
            return
        }
        #endif

        emit(.error("Apple Intelligence is not available on this device."))
    }

    // MARK: - Text-to-Speech

    func speakText(_ text: String) async throws {
        await synthesizeAndEmitAudio(text)
    }

    private func synthesizeAndEmitAudio(_ text: String) async {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: speechRecognizer?.locale.identifier ?? "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // Use the write API to get PCM audio buffers and emit them as audio chunks
        // so the bridge's AudioController can play them through the existing pipeline.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            nonisolated(unsafe) var finished = false
            synthesizer.write(utterance) { [weak self] buffer in
                guard let self else {
                    if !finished { finished = true; cont.resume() }
                    return
                }
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
                    if !finished { finished = true; cont.resume() }
                    return
                }
                guard pcmBuffer.frameLength > 0 else {
                    // Empty buffer signals end of synthesis
                    if !finished { finished = true; cont.resume() }
                    return
                }
                // Convert to PCM16 base64 for the audio pipeline
                if let base64 = self.pcm16BufferToBase64(pcmBuffer) {
                    self.emit(.assistantAudioChunk(base64))
                }
            }
        }
    }

    // MARK: - Audio Conversion Helpers

    /// Convert base64 PCM16 data to AVAudioPCMBuffer for SFSpeechRecognizer.
    private nonisolated func pcm16DataToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / 2  // PCM16 = 2 bytes per frame
        guard frameCount > 0 else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawPtr in
            guard let src = rawPtr.baseAddress else { return }
            if let dst = buffer.int16ChannelData?[0] {
                dst.update(from: src.assumingMemoryBound(to: Int16.self), count: Int(frameCount))
            }
        }
        return buffer
    }

    /// Convert AVAudioPCMBuffer from TTS to base64 PCM16 string.
    private nonisolated func pcm16BufferToBase64(_ buffer: AVAudioPCMBuffer) -> String? {
        // If the buffer is already Int16, use it directly
        if buffer.format.commonFormat == .pcmFormatInt16 {
            return AudioUtils.base64EncodeAudioPCMBuffer(from: buffer)
        }

        // If Float32, convert to Int16
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              let floatData = buffer.floatChannelData?[0] else {
            return AudioUtils.base64EncodeAudioPCMBuffer(from: buffer)
        }

        let frameCount = Int(buffer.frameLength)
        var int16Data = Data(count: frameCount * 2)
        int16Data.withUnsafeMutableBytes { rawPtr in
            guard let dst = rawPtr.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            for i in 0..<frameCount {
                let clamped = max(-1.0, min(1.0, floatData[i]))
                dst[i] = Int16(clamped * Float(Int16.max))
            }
        }
        return int16Data.base64EncodedString()
    }

    private func emit(_ event: OpenRockyRealtimeEvent) {
        eventSink?(event)
    }
}

enum OpenRockyAppleVoiceError: LocalizedError {
    case speechRecognitionNotAuthorized
    case speechRecognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAuthorized:
            "Speech recognition permission is required. Please allow in Settings."
        case .speechRecognizerUnavailable:
            "Speech recognizer is not available on this device."
        }
    }
}

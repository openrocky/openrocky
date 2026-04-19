//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AVFoundation
import Combine
import Foundation
import UIKit

/// Dictation mode: auto-VAD (tap to start, silence to end) or push-to-talk (hold to record, release to end).
enum OpenRockyDictationMode {
    case autoVAD
    case pushToTalk
}

/// Handles mic recording and STT transcription for inline dictation in the chat input.
/// Supports two modes:
/// - **autoVAD**: Tap to start, automatically stops on silence (1.5s) or max duration.
/// - **pushToTalk**: Hold to record, release to stop and transcribe.
@MainActor
final class OpenRockyDictationService: ObservableObject {
    @Published private(set) var isRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTask: Task<Void, Never>?
    private var vadTimer: Timer?

    /// Callback with transcribed text on success.
    var onResult: ((String) -> Void)?
    /// Callback on error.
    var onError: ((String) -> Void)?
    /// Callback when recording state changes.
    var onRecordingStateChanged: ((Bool) -> Void)?
    /// Callback with normalized audio level (0.0–1.0) during recording, for waveform animation.
    var onAudioLevelUpdate: ((Float) -> Void)?

    private let maxRecordDuration: TimeInterval = 30
    private let silenceThreshold: Float = -40.0 // dB
    private let silenceDuration: TimeInterval = 1.5

    private var silenceStart: Date?
    /// Whether stop has been requested externally (push-to-talk release).
    private var stopRequested = false

    func startDictation(configuration: OpenRockySTTProviderConfiguration, mode: OpenRockyDictationMode = .autoVAD) {
        guard !isRecording else { return }
        guard configuration.isConfigured else {
            onError?("STT provider is not configured. Please set up Speech-to-Text in Settings.")
            return
        }

        recordingTask?.cancel()
        isRecording = true
        stopRequested = false
        onRecordingStateChanged?(true)

        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await self.recordWithVAD(mode: mode)
                guard !Task.isCancelled else { return }

                let client = Self.makeClient(configuration: configuration)
                let text = try await client.transcribe(audioData: audioData)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !Task.isCancelled else { return }
                self.isRecording = false
                self.onRecordingStateChanged?(false)
                self.onAudioLevelUpdate?(0)

                if trimmed.isEmpty {
                    rlog.debug("Dictation: STT returned empty text", category: "Dictation")
                } else {
                    rlog.info("Dictation result: \(trimmed.prefix(100))", category: "Dictation")
                    // Success haptic
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    self.onResult?(trimmed)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.isRecording = false
                self.onRecordingStateChanged?(false)
                self.onAudioLevelUpdate?(0)
                rlog.error("Dictation failed: \(error.localizedDescription)", category: "Dictation")
                // Failure haptic
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.error)
                self.onError?(error.localizedDescription)
            }
        }
    }

    /// Request the recording to stop (used for push-to-talk release).
    func requestStop() {
        stopRequested = true
    }

    func stopDictation() {
        recordingTask?.cancel()
        recordingTask = nil
        vadTimer?.invalidate()
        vadTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        silenceStart = nil
        stopRequested = false
        isRecording = false
        onRecordingStateChanged?(false)
        onAudioLevelUpdate?(0)
    }

    // MARK: - Recording with VAD

    private func recordWithVAD(mode: OpenRockyDictationMode) async throws -> Data {
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
        try AVAudioSession.sharedInstance().setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation_\(UUID().uuidString).wav")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()
        audioRecorder = recorder
        silenceStart = nil

        rlog.info("Dictation: recording started (mode=\(mode == .autoVAD ? "autoVAD" : "pushToTalk"))", category: "Dictation")

        // Poll metering for VAD and audio levels
        let startTime = Date()
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(100))

            guard let recorder = audioRecorder, recorder.isRecording else { break }
            recorder.updateMeters()
            let avgPower = recorder.averagePower(forChannel: 0)

            // Report normalized audio level for waveform (dB range: -60 to 0)
            let normalizedLevel = max(0, min(1, (avgPower + 60) / 60))
            onAudioLevelUpdate?(normalizedLevel)

            // Check max duration
            if Date().timeIntervalSince(startTime) >= maxRecordDuration {
                rlog.info("Dictation: max duration reached", category: "Dictation")
                break
            }

            // Push-to-talk: stop when release is signaled
            if mode == .pushToTalk && stopRequested {
                rlog.info("Dictation: push-to-talk released, stopping", category: "Dictation")
                break
            }

            // Auto-VAD: detect silence
            if mode == .autoVAD {
                if avgPower < silenceThreshold {
                    if silenceStart == nil {
                        silenceStart = Date()
                    } else if Date().timeIntervalSince(silenceStart!) >= silenceDuration {
                        rlog.info("Dictation: silence detected, stopping", category: "Dictation")
                        break
                    }
                } else {
                    silenceStart = nil
                }
            }
        }

        recorder.stop()
        audioRecorder = nil

        guard let data = try? Data(contentsOf: url) else {
            throw OpenRockySTTClientError.emptyAudio
        }

        // Strip WAV header (44 bytes) to get raw PCM
        let pcmData = data.count > 44 ? data.subdata(in: 44..<data.count) : data

        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        guard pcmData.count > 4800 else {
            // Too short (~100ms), likely no speech
            throw OpenRockySTTClientError.emptyAudio
        }

        return pcmData
    }

    // MARK: - Client Factory

    private static func makeClient(configuration: OpenRockySTTProviderConfiguration) -> any OpenRockySTTClient {
        switch configuration.provider {
        case .openAI, .groq, .aliCloud:
            return OpenRockyOpenAISTTClient(configuration: configuration)
        case .deepgram:
            return OpenRockyDeepgramSTTClient(configuration: configuration)
        case .azureSpeech:
            return OpenRockyAzureSTTClient(configuration: configuration)
        case .googleCloud:
            return OpenRockyGoogleSTTClient(configuration: configuration)
        }
    }
}

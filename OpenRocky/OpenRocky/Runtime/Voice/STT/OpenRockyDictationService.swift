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

/// Handles mic recording and STT transcription for inline dictation in the chat input.
/// Records until silence is detected (VAD) or a maximum duration is reached,
/// then sends audio to the configured STT provider.
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

    private let maxRecordDuration: TimeInterval = 30
    private let silenceThreshold: Float = -40.0 // dB
    private let silenceDuration: TimeInterval = 1.5

    private var silenceStart: Date?

    func startDictation(configuration: OpenRockySTTProviderConfiguration) {
        guard !isRecording else { return }
        guard configuration.isConfigured else {
            onError?("STT provider is not configured. Please set up Speech-to-Text in Settings.")
            return
        }

        recordingTask?.cancel()
        isRecording = true
        onRecordingStateChanged?(true)

        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await self.recordWithVAD()
                guard !Task.isCancelled else { return }

                let client = Self.makeClient(configuration: configuration)
                let text = try await client.transcribe(audioData: audioData)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !Task.isCancelled else { return }
                self.isRecording = false
                self.onRecordingStateChanged?(false)

                if trimmed.isEmpty {
                    rlog.debug("Dictation: STT returned empty text", category: "Dictation")
                } else {
                    rlog.info("Dictation result: \(trimmed.prefix(100))", category: "Dictation")
                    self.onResult?(trimmed)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.isRecording = false
                self.onRecordingStateChanged?(false)
                rlog.error("Dictation failed: \(error.localizedDescription)", category: "Dictation")
                self.onError?(error.localizedDescription)
            }
        }
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
        isRecording = false
        onRecordingStateChanged?(false)
    }

    // MARK: - Recording with VAD

    private func recordWithVAD() async throws -> Data {
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

        rlog.info("Dictation: recording started", category: "Dictation")

        // Poll metering for VAD
        let startTime = Date()
        while !Task.isCancelled {
            try await Task.sleep(for: .milliseconds(100))

            guard let recorder = audioRecorder, recorder.isRecording else { break }
            recorder.updateMeters()
            let avgPower = recorder.averagePower(forChannel: 0)

            // Check max duration
            if Date().timeIntervalSince(startTime) >= maxRecordDuration {
                rlog.info("Dictation: max duration reached", category: "Dictation")
                break
            }

            // VAD: detect silence
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

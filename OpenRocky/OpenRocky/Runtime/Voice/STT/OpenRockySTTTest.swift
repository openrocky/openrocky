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

/// Records a short mic sample and sends it to the STT provider for testing.
@MainActor
final class OpenRockySTTTest: ObservableObject {
    enum State: Equatable {
        case idle
        case recording(seconds: Int)
        case transcribing
        case success(text: String)
        case failure(message: String)
    }

    @Published var state: State = .idle

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTask: Task<Void, Never>?
    private let recordDuration: TimeInterval = 4.0

    func startTest(
        provider: OpenRockySTTProviderKind,
        modelID: String,
        credential: String,
        customHost: String?,
        language: String?
    ) {
        stop()
        guard !credential.isEmpty else {
            state = .failure(message: "Please fill in the API Key first.")
            return
        }

        state = .recording(seconds: Int(recordDuration))

        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioData = try await self.recordMicrophone()
                guard !Task.isCancelled else { return }

                self.state = .transcribing

                let config = OpenRockySTTProviderConfiguration(
                    provider: provider,
                    modelID: modelID,
                    credential: credential,
                    customHost: customHost,
                    language: language
                ).normalized()

                let client = Self.makeClient(configuration: config)
                let text = try await client.transcribe(audioData: audioData)

                guard !Task.isCancelled else { return }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.state = .success(text: "(No speech detected)")
                } else {
                    self.state = .success(text: trimmed)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failure(message: error.localizedDescription)
            }
        }
    }

    func stop() {
        recordingTask?.cancel()
        recordingTask = nil
        audioRecorder?.stop()
        audioRecorder = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
    }

    func reset() {
        stop()
        state = .idle
    }

    // MARK: - Recording

    private func recordMicrophone() async throws -> Data {
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement)
        try AVAudioSession.sharedInstance().setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stt_test_\(UUID().uuidString).wav")
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
        audioRecorder = recorder
        recorder.record()

        // Countdown
        for remaining in stride(from: Int(recordDuration), through: 1, by: -1) {
            guard !Task.isCancelled else { throw CancellationError() }
            state = .recording(seconds: remaining)
            try await Task.sleep(for: .seconds(1))
        }

        recorder.stop()
        audioRecorder = nil

        guard let data = try? Data(contentsOf: url) else {
            throw OpenRockySTTClientError.emptyAudio
        }

        // Strip WAV header (44 bytes) to get raw PCM data
        let pcmData = data.count > 44 ? data.subdata(in: 44..<data.count) : data

        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        return pcmData
    }

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

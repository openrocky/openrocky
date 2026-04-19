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

/// Plays a short TTS preview for a voice using the configured TTS provider.
@MainActor
final class OpenRockyTTSPreview: ObservableObject {
    @Published var playingVoice: String?
    @Published var isLoading = false
    @Published var error: String?

    private var audioPlayer: AVAudioPlayer?
    private var synthesizeTask: Task<Void, Never>?

    /// Sample text used for TTS preview, adapted by provider.
    static func sampleText(for provider: OpenRockyTTSProviderKind) -> String {
        switch provider {
        case .miniMax, .volcengine, .aliCloud, .qwenTTS, .zhipuGLM:
            "你好，我是你的语音助手，很高兴认识你。"
        case .openAI, .elevenLabs, .azureSpeech, .googleCloud:
            "Hello, I'm your voice assistant. Nice to meet you!"
        }
    }

    func play(
        voice: String,
        provider: OpenRockyTTSProviderKind,
        modelID: String,
        credential: String,
        customHost: String?
    ) {
        stop()
        guard !credential.isEmpty else {
            error = "Please fill in the API Key first."
            return
        }

        playingVoice = voice
        isLoading = true
        error = nil

        let config = OpenRockyTTSProviderConfiguration(
            provider: provider,
            modelID: modelID,
            credential: credential,
            voice: voice,
            customHost: customHost
        ).normalized()

        synthesizeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let client = Self.makeClient(configuration: config)
                let text = Self.sampleText(for: provider)
                let audioData = try await client.synthesize(text: text)

                guard !Task.isCancelled else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)

                let player = try AVAudioPlayer(data: audioData)
                self.audioPlayer = player
                self.isLoading = false
                player.play()

                let duration = player.duration
                try? await Task.sleep(for: .seconds(duration + 0.3))
                if self.playingVoice == voice {
                    self.playingVoice = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
                self.isLoading = false
                self.playingVoice = nil
            }
        }
    }

    func stop() {
        synthesizeTask?.cancel()
        synthesizeTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isLoading = false
        playingVoice = nil
        error = nil
    }

    private static func makeClient(configuration: OpenRockyTTSProviderConfiguration) -> any OpenRockyTTSClient {
        switch configuration.provider {
        case .openAI, .aliCloud:
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
        case .qwenTTS:
            return OpenRockyQwenTTSClient(configuration: configuration)
        case .zhipuGLM:
            return OpenRockyZhipuGLMTTSClient(configuration: configuration)
        }
    }
}

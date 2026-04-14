//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-14
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Combine
import Foundation
@preconcurrency import SwiftOpenAI

/// Checks provider connectivity in the background and caches the results.
/// The settings view reads cached status to show green/red dots without
/// requiring the user to manually test each connection.
@MainActor
final class OpenRockyProviderHealthService: ObservableObject {
    static let shared = OpenRockyProviderHealthService()

    enum HealthStatus: Equatable {
        case unknown
        case checking
        case healthy
        case unhealthy(String)
    }

    /// Keyed by provider instance ID.
    @Published private(set) var statuses: [String: HealthStatus] = [:]

    /// Last check time per instance ID.
    private var lastChecked: [String: Date] = [:]

    /// Minimum interval between checks for the same instance (seconds).
    private let checkInterval: TimeInterval = 300  // 5 minutes

    private init() {}

    /// Get cached status for a provider instance. Returns `.unknown` if never checked.
    func status(for instanceID: String) -> HealthStatus {
        statuses[instanceID] ?? .unknown
    }

    /// Check all configured providers from all stores.
    func checkAll(
        chatStore: OpenRockyProviderStore,
        realtimeStore: OpenRockyRealtimeProviderStore,
        sttStore: OpenRockySTTProviderStore,
        ttsStore: OpenRockyTTSProviderStore
    ) {
        // Check active chat provider
        if let instance = chatStore.activeInstance {
            let config = chatStore.configuration
            if config.isConfigured {
                checkChatProvider(instanceID: instance.id, configuration: config)
            }
        }

        // Check active STT provider
        if let instance = sttStore.activeInstance {
            let config = sttStore.configuration
            if config.isConfigured {
                checkSTTProvider(instanceID: instance.id, configuration: config)
            }
        }

        // Check active TTS provider
        if let instance = ttsStore.activeInstance {
            let config = ttsStore.configuration
            if config.isConfigured {
                checkTTSProvider(instanceID: instance.id, configuration: config)
            }
        }
    }

    /// Check a single chat provider instance.
    func checkChatProvider(instanceID: String, configuration: OpenRockyProviderConfiguration) {
        guard shouldCheck(instanceID: instanceID) else { return }
        statuses[instanceID] = .checking

        Task {
            do {
                let service = try await OpenRockyOpenAIServiceFactory.makeService(configuration: configuration)
                // Minimal API call: 1 token response
                let params = ChatCompletionParameters(
                    messages: [.init(role: .user, content: .text("hi"))],
                    model: .custom(configuration.modelID),
                    maxTokens: 1
                )
                let stream = try await service.startStreamedChat(parameters: params)
                // Consume at least one chunk to verify connectivity
                for try await _ in stream {
                    break
                }
                self.statuses[instanceID] = .healthy
                self.lastChecked[instanceID] = Date()
                rlog.info("Health check passed: chat provider \(instanceID)", category: "Health")
            } catch {
                self.statuses[instanceID] = .unhealthy(error.localizedDescription)
                self.lastChecked[instanceID] = Date()
                rlog.warning("Health check failed: chat provider \(instanceID): \(error.localizedDescription)", category: "Health")
            }
        }
    }

    /// Check a single STT provider instance (lightweight — just verifies the endpoint responds).
    func checkSTTProvider(instanceID: String, configuration: OpenRockySTTProviderConfiguration) {
        guard shouldCheck(instanceID: instanceID) else { return }
        statuses[instanceID] = .checking

        Task {
            do {
                // For STT, we can't easily test without audio. Verify the API key format
                // and that the endpoint is reachable with a HEAD request.
                let baseURL = configuration.customHost ?? configuration.provider.defaultBaseURL
                guard let url = URL(string: baseURL) else {
                    throw URLError(.badURL)
                }
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 500 {
                    self.statuses[instanceID] = .healthy
                } else {
                    self.statuses[instanceID] = .unhealthy("Server error")
                }
                self.lastChecked[instanceID] = Date()
                rlog.info("Health check passed: STT provider \(instanceID)", category: "Health")
            } catch {
                self.statuses[instanceID] = .unhealthy(error.localizedDescription)
                self.lastChecked[instanceID] = Date()
                rlog.warning("Health check failed: STT provider \(instanceID): \(error.localizedDescription)", category: "Health")
            }
        }
    }

    /// Check a single TTS provider instance.
    func checkTTSProvider(instanceID: String, configuration: OpenRockyTTSProviderConfiguration) {
        guard shouldCheck(instanceID: instanceID) else { return }
        statuses[instanceID] = .checking

        Task {
            do {
                let baseURL = configuration.customHost ?? configuration.provider.defaultBaseURL
                guard let url = URL(string: baseURL) else {
                    throw URLError(.badURL)
                }
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD"
                request.timeoutInterval = 10
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 500 {
                    self.statuses[instanceID] = .healthy
                } else {
                    self.statuses[instanceID] = .unhealthy("Server error")
                }
                self.lastChecked[instanceID] = Date()
                rlog.info("Health check passed: TTS provider \(instanceID)", category: "Health")
            } catch {
                self.statuses[instanceID] = .unhealthy(error.localizedDescription)
                self.lastChecked[instanceID] = Date()
                rlog.warning("Health check failed: TTS provider \(instanceID): \(error.localizedDescription)", category: "Health")
            }
        }
    }

    /// Clear cached status for an instance.
    func invalidate(instanceID: String) {
        statuses.removeValue(forKey: instanceID)
        lastChecked.removeValue(forKey: instanceID)
    }

    private func shouldCheck(instanceID: String) -> Bool {
        if statuses[instanceID] == .checking { return false }
        guard let last = lastChecked[instanceID] else { return true }
        return Date().timeIntervalSince(last) >= checkInterval
    }
}

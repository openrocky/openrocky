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

enum OpenRockyOpenAIServiceFactory {
    nonisolated static let defaultRealtimeModel = "gpt-realtime-mini"

    nonisolated static func makeService(configuration: OpenRockyProviderConfiguration) async throws -> any OpenAIService {
        let normalized = configuration.normalized()

        guard normalized.provider != .appleFoundationModels else {
            throw OpenRockyOpenAIServiceError.unsupportedProvider
        }

        guard let rawCredential = normalized.credential, rawCredential.isEmpty == false else {
            throw OpenRockyOpenAIServiceError.missingCredential
        }
        let credential = try await resolvedCredential(
            provider: normalized.provider,
            rawCredential: rawCredential
        )

        let host = normalized.customHost

        switch normalized.provider {
        case .appleFoundationModels:
            // Handled by OpenRockyAppleFoundationModelsChatClient directly
            throw OpenRockyOpenAIServiceError.unsupportedProvider
        case .openAI:
            if let host {
                return OpenAIServiceFactory.service(apiKey: credential, overrideBaseURL: host)
            }
            return OpenAIServiceFactory.service(apiKey: credential)
        case .azureOpenAI:
            guard let resourceName = normalized.azureResourceName, resourceName.isEmpty == false else {
                throw OpenRockyOpenAIServiceError.missingAzureResourceName
            }
            guard let apiVersion = normalized.azureAPIVersion, apiVersion.isEmpty == false else {
                throw OpenRockyOpenAIServiceError.missingAzureAPIVersion
            }
            return OpenAIServiceFactory.service(
                azureConfiguration: AzureOpenAIConfiguration(
                    resourceName: resourceName,
                    openAIAPIKey: .apiKey(credential),
                    apiVersion: apiVersion
                )
            )
        case .anthropic:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://api.anthropic.com",
                overrideVersion: "v1"
            )
        case .gemini:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://generativelanguage.googleapis.com",
                overrideVersion: "v1beta"
            )
        case .groq:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://api.groq.com",
                proxyPath: "openai"
            )
        case .xAI:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://api.x.ai",
                overrideVersion: "v1"
            )
        case .openRouter:
            var headers: [String: String] = [:]
            if let referer = normalized.openRouterReferer, referer.isEmpty == false {
                headers["HTTP-Referer"] = referer
            }
            if let title = normalized.openRouterTitle, title.isEmpty == false {
                headers["X-Title"] = title
            }
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://openrouter.ai",
                proxyPath: "api",
                extraHeaders: headers.isEmpty ? nil : headers
            )
        case .deepSeek:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://api.deepseek.com"
            )
        case .volcengine:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://ark.cn-beijing.volces.com",
                proxyPath: "api",
                overrideVersion: "v3"
            )
        case .zhipuAI:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://open.bigmodel.cn/api/paas",
                overrideVersion: "v4"
            )
        case .bailian:
            return OpenAIServiceFactory.service(
                apiKey: credential,
                overrideBaseURL: host ?? "https://coding.dashscope.aliyuncs.com",
                overrideVersion: "v1"
            )
        case .aiProxy:
            guard let serviceURL = normalized.aiProxyServiceURL, serviceURL.isEmpty == false else {
                throw OpenRockyOpenAIServiceError.missingAIProxyServiceURL
            }
            return OpenAIServiceFactory.service(
                aiproxyPartialKey: credential,
                aiproxyServiceURL: serviceURL
            )
        }
    }

    nonisolated static func realtimeModelID(for configuration: OpenRockyProviderConfiguration) -> String {
        let normalized = configuration.normalized()
        return normalized.modelID.localizedCaseInsensitiveContains("realtime")
            ? normalized.modelID
            : defaultRealtimeModel
    }

    nonisolated static func supportsRealtime(configuration: OpenRockyProviderConfiguration) -> Bool {
        configuration.normalized().provider == .openAI
    }

    private nonisolated static func resolvedCredential(
        provider: OpenRockyProviderKind,
        rawCredential: String
    ) async throws -> String {
        guard provider == .openAI else {
            return rawCredential
        }
        return try await OpenRockyOpenAIOAuthVault.resolvedAccessToken(from: rawCredential)
    }
}

enum OpenRockyOpenAIServiceError: LocalizedError {
    case missingCredential
    case missingAzureResourceName
    case missingAzureAPIVersion
    case missingAIProxyServiceURL
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            "Missing provider credential."
        case .missingAzureResourceName:
            "Azure OpenAI requires a resource name."
        case .missingAzureAPIVersion:
            "Azure OpenAI requires an API version."
        case .missingAIProxyServiceURL:
            "AIProxy requires a service URL."
        case .unsupportedProvider:
            "This provider does not use the OpenAI-compatible service."
        }
    }
}

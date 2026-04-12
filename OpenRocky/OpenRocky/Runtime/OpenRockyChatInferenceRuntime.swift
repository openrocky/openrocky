//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import ChatClientKit
import LanguageModelChatUI
@preconcurrency import SwiftOpenAI

@MainActor
final class OpenRockyChatInferenceRuntime {
    private let characterStore = OpenRockyCharacterStore.shared
    let toolbox = OpenRockyToolbox()
    private var conversationHistory: [ChatCompletionParameters.Message] = []

    /// Tool calls completed during the most recent `run()`. Reset at the start of each run.
    struct CompletedToolCall {
        let id: String
        let name: String
        let arguments: String
        let result: String
        let succeeded: Bool
    }
    private(set) var completedToolCalls: [CompletedToolCall] = []

    func run(
        prompt: String,
        configuration: OpenRockyProviderConfiguration,
        onChunk: @escaping @MainActor (ChatResponseChunk) -> Void
    ) async throws {
        completedToolCalls = []
        rlog.info("Chat inference starting: provider=\(configuration.provider.rawValue) model=\(configuration.modelID)", category: "Chat")
        let service = try await OpenRockyOpenAIServiceFactory.makeService(configuration: configuration)
        let usageService = OpenRockyUsageService.shared

        // Remove any trailing tool messages that lack a preceding tool_use context
        while let last = conversationHistory.last, last.role == "tool" {
            conversationHistory.removeLast()
        }

        conversationHistory.append(.init(role: .user, content: .text(prompt)))

        var continueLoop = true
        while continueLoop {
            continueLoop = false

            var allTools = OpenRockyToolbox.chatToolDefinitions()
            allTools.append(contentsOf: OpenRockyToolbox.skillToolDefinitions())
            let parameters = ChatCompletionParameters(
                messages: [.init(role: .system, content: .text(characterStore.systemPrompt))] + conversationHistory,
                model: .custom(configuration.modelID),
                tools: allTools,
                temperature: nil
            )

            let stream = try await service.startStreamedChat(parameters: parameters)
            var textBuffer = ""
            var toolCalls: [ToolCallAccumulator] = []
            var promptTokens = 0
            var completionTokens = 0

            for try await chunk in stream {
                // Capture token usage from the final chunk
                if let usage = chunk.usage {
                    promptTokens = usage.promptTokens ?? 0
                    completionTokens = usage.completionTokens ?? 0
                }

                guard let choice = chunk.choices?.first, let delta = choice.delta else { continue }

                if let text = delta.content, !text.isEmpty {
                    textBuffer += text
                    onChunk(.text(text))
                }

                if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
                    onChunk(.reasoning(reasoning))
                }

                if let deltaToolCalls = delta.toolCalls {
                    for tc in deltaToolCalls {
                        let index = tc.index ?? 0
                        while toolCalls.count <= index {
                            toolCalls.append(ToolCallAccumulator())
                        }
                        if let id = tc.id {
                            toolCalls[index].id = id
                        }
                        if let name = tc.function.name, !name.isEmpty {
                            toolCalls[index].name = name
                        }
                        if !tc.function.arguments.isEmpty {
                            toolCalls[index].arguments += tc.function.arguments
                        }
                    }
                }
            }

            // Record token usage
            let total = promptTokens + completionTokens
            if total > 0 {
                rlog.info("Chat tokens: prompt=\(promptTokens) completion=\(completionTokens) total=\(total)", category: "Chat")
                usageService.recordChat(
                    provider: configuration.provider.displayName,
                    model: configuration.modelID,
                    promptTokens: promptTokens,
                    completionTokens: completionTokens,
                    totalTokens: total
                )
            }

            // Append assistant message to history (with tool_calls if any)
            if !toolCalls.isEmpty {
                let tcStructs = toolCalls.compactMap { tc -> ToolCall? in
                    guard !tc.name.isEmpty else { return nil }
                    return ToolCall(id: tc.id, function: FunctionCall(arguments: tc.arguments, name: tc.name))
                }
                conversationHistory.append(.init(
                    role: .assistant,
                    content: .text(textBuffer),
                    toolCalls: tcStructs
                ))

                for tc in toolCalls where !tc.name.isEmpty {
                    rlog.info("Chat tool call: \(tc.name) args=\(tc.arguments.prefix(200))", category: "Chat")
                    let result: String
                    var succeeded = true
                    do {
                        result = try await toolbox.execute(name: tc.name, arguments: tc.arguments)
                    } catch {
                        let nsError = error as NSError
                        rlog.error("Chat tool \(tc.name) FAILED args=\(tc.arguments.prefix(300)) error=\(error.localizedDescription) domain=\(nsError.domain) code=\(nsError.code)", category: "Chat")
                        result = #"{"error":"\#(error.localizedDescription)"}"#
                        succeeded = false
                    }

                    completedToolCalls.append(CompletedToolCall(
                        id: tc.id, name: tc.name, arguments: tc.arguments,
                        result: result, succeeded: succeeded
                    ))
                    onChunk(.text("\n"))

                    conversationHistory.append(.init(role: .tool, content: .text(result), toolCallID: tc.id))
                }

                continueLoop = true
            } else if !textBuffer.isEmpty {
                conversationHistory.append(.init(role: .assistant, content: .text(textBuffer)))
            }
        }
    }

    func loadHistory(from messages: [ConversationMessage]) {
        conversationHistory = messages.flatMap { msg -> [ChatCompletionParameters.Message] in
            switch msg.role {
            case .user:
                let text = msg.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return [] }
                return [.init(role: .user, content: .text(text))]

            case .assistant:
                let text = msg.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                // Extract tool calls from parts
                let toolCallParts = msg.parts.compactMap { part -> ToolCallContentPart? in
                    guard case let .toolCall(tc) = part else { return nil }
                    return tc
                }

                if !toolCallParts.isEmpty {
                    // Build assistant message with tool_calls
                    let tcStructs = toolCallParts.map { tc in
                        ToolCall(
                            id: tc.id,
                            function: FunctionCall(
                                arguments: tc.parameters,
                                name: tc.apiName.isEmpty ? tc.toolName : tc.apiName
                            )
                        )
                    }
                    var result: [ChatCompletionParameters.Message] = [
                        .init(role: .assistant, content: .text(text), toolCalls: tcStructs)
                    ]
                    // Append tool result messages for each tool call
                    for tc in toolCallParts {
                        let resultText = tc.result ?? "{}"
                        result.append(.init(role: .tool, content: .text(resultText), toolCallID: tc.id))
                    }
                    return result
                }

                // Also check for separate toolResult parts
                let toolResults = msg.parts.compactMap { part -> ToolResultContentPart? in
                    guard case let .toolResult(tr) = part else { return nil }
                    return tr
                }
                if !toolResults.isEmpty {
                    return toolResults.map { tr in
                        .init(role: .tool, content: .text(tr.result), toolCallID: tr.toolCallID)
                    }
                }

                guard !text.isEmpty else { return [] }
                return [.init(role: .assistant, content: .text(text))]

            default:
                let text = msg.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return [] }
                return [.init(role: .user, content: .text(text))]
            }
        }
    }

    func resetConversation() {
        conversationHistory = []
    }
}

private struct ToolCallAccumulator {
    var id: String = ""
    var name: String = ""
    var arguments: String = ""
}

//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
@preconcurrency import SwiftOpenAI

// MARK: - Subagent Data Types

struct OpenRockySubagentTask: Sendable {
    let id: String
    let description: String
    /// Optional tool allowlist. When nil, all tools are available.
    let allowedTools: [String]?

    init(id: String = UUID().uuidString, description: String, allowedTools: [String]? = nil) {
        self.id = id
        self.description = description
        self.allowedTools = allowedTools
    }
}

struct OpenRockySubagentResult: Sendable {
    let taskID: String
    let summary: String
    let details: String
    let toolCalls: [OpenRockyChatInferenceRuntime.CompletedToolCall]
    let succeeded: Bool
    let elapsedSeconds: Double
}

/// Aggregated result from all subagents for a single delegate-task invocation.
struct OpenRockyDelegateTaskResult: Sendable {
    let taskDescription: String
    let results: [OpenRockySubagentResult]
    let totalElapsedSeconds: Double
}

// MARK: - Subagent Runtime

/// Executes complex tasks by spawning parallel subagents, each backed by a
/// text-based chat model that can call tools in a multi-turn loop.
///
/// Designed to be invoked from `OpenRockyToolbox` when the voice provider
/// calls the `delegate-task` tool.
@MainActor
final class OpenRockySubagentRuntime {
    /// Default timeout per subagent, in seconds.
    static let defaultTimeout: TimeInterval = 60

    private let toolbox: OpenRockyToolbox
    private let configuration: OpenRockyProviderConfiguration
    private let timeout: TimeInterval
    private let onStatusUpdate: (@MainActor (String) -> Void)?

    init(
        toolbox: OpenRockyToolbox,
        configuration: OpenRockyProviderConfiguration,
        timeout: TimeInterval = OpenRockySubagentRuntime.defaultTimeout,
        onStatusUpdate: (@MainActor (String) -> Void)? = nil
    ) {
        self.toolbox = toolbox
        self.configuration = configuration
        self.timeout = timeout
        self.onStatusUpdate = onStatusUpdate
    }

    // MARK: - Public API

    /// Execute a single delegate-task that may contain multiple parallel subtasks.
    func execute(taskDescription: String, subtasks: [OpenRockySubagentTask], context: String) async -> OpenRockyDelegateTaskResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        rlog.info("Subagent runtime starting: \(subtasks.count) subtask(s) for: \(taskDescription.prefix(200))", category: "Subagent")

        let tasks: [OpenRockySubagentTask]
        if subtasks.isEmpty {
            // No explicit subtasks — treat the whole task as a single subagent
            tasks = [OpenRockySubagentTask(description: taskDescription)]
        } else {
            tasks = subtasks
        }

        onStatusUpdate?("Delegating \(tasks.count) subtask\(tasks.count == 1 ? "" : "s")...")

        // Run all subtasks in parallel using TaskGroup
        let results = await withTaskGroup(of: OpenRockySubagentResult.self, returning: [OpenRockySubagentResult].self) { group in
            for task in tasks {
                group.addTask { [self] in
                    await self.runSingleAgent(task: task, parentContext: context)
                }
            }
            var collected: [OpenRockySubagentResult] = []
            for await result in group {
                collected.append(result)
                let completedCount = collected.count
                onStatusUpdate?("Subtask completed (\(completedCount)/\(tasks.count)): \(result.summary.prefix(60))")
            }
            return collected
        }

        let totalElapsed = CFAbsoluteTimeGetCurrent() - startTime
        rlog.info("Subagent runtime finished: \(results.count) result(s) in \(String(format: "%.1f", totalElapsed))s", category: "Subagent")
        onStatusUpdate?("All subtasks completed.")

        return OpenRockyDelegateTaskResult(
            taskDescription: taskDescription,
            results: results,
            totalElapsedSeconds: totalElapsed
        )
    }

    // MARK: - Single Agent Execution

    private func runSingleAgent(task: OpenRockySubagentTask, parentContext: String) async -> OpenRockySubagentResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        rlog.info("Subagent [\(task.id.prefix(8))] starting: \(task.description.prefix(200))", category: "Subagent")

        do {
            let result = try await withThrowingTaskGroup(of: OpenRockySubagentResult.self) { group in
                // Main execution task
                group.addTask { [self] in
                    try await self.executeAgentLoop(task: task, parentContext: parentContext)
                }

                // Timeout watchdog
                group.addTask {
                    try await Task.sleep(for: .seconds(self.timeout))
                    throw SubagentError.timeout(taskID: task.id, seconds: self.timeout)
                }

                // Return whichever finishes first
                let result = try await group.next()!
                group.cancelAll()
                return result
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            rlog.info("Subagent [\(task.id.prefix(8))] completed in \(String(format: "%.1f", elapsed))s", category: "Subagent")
            return result

        } catch is CancellationError {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            rlog.info("Subagent [\(task.id.prefix(8))] cancelled after \(String(format: "%.1f", elapsed))s", category: "Subagent")
            return OpenRockySubagentResult(
                taskID: task.id,
                summary: "Task was cancelled.",
                details: "The subagent task was cancelled before completion.",
                toolCalls: [],
                succeeded: false,
                elapsedSeconds: elapsed
            )

        } catch let error as SubagentError {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let message = error.localizedDescription
            rlog.error("Subagent [\(task.id.prefix(8))] failed: \(message)", category: "Subagent")
            return OpenRockySubagentResult(
                taskID: task.id,
                summary: "Task failed: \(message)",
                details: message,
                toolCalls: [],
                succeeded: false,
                elapsedSeconds: elapsed
            )

        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            rlog.error("Subagent [\(task.id.prefix(8))] unexpected error: \(error.localizedDescription)", category: "Subagent")
            return OpenRockySubagentResult(
                taskID: task.id,
                summary: "Task failed: \(error.localizedDescription)",
                details: error.localizedDescription,
                toolCalls: [],
                succeeded: false,
                elapsedSeconds: elapsed
            )
        }
    }

    /// Core multi-turn tool-use loop for a single subagent.
    /// Uses a fresh chat inference against the configured text model.
    private func executeAgentLoop(task: OpenRockySubagentTask, parentContext: String) async throws -> OpenRockySubagentResult {
        let service = try await OpenRockyOpenAIServiceFactory.makeService(configuration: configuration)

        let systemPrompt = buildSubagentSystemPrompt(task: task, parentContext: parentContext)
        var conversationHistory: [ChatCompletionParameters.Message] = [
            .init(role: .system, content: .text(systemPrompt)),
            .init(role: .user, content: .text(task.description))
        ]

        var allToolCalls: [OpenRockyChatInferenceRuntime.CompletedToolCall] = []
        let maxTurns = 10
        var finalText = ""

        for turn in 0 ..< maxTurns {
            try Task.checkCancellation()

            let tools = buildToolDefinitions(allowedTools: task.allowedTools)
            let parameters = ChatCompletionParameters(
                messages: conversationHistory,
                model: .custom(configuration.modelID),
                tools: tools.isEmpty ? nil : tools,
                temperature: nil
            )

            let stream = try await service.startStreamedChat(parameters: parameters)
            var textBuffer = ""
            var toolCallAccumulators: [ToolCallAccumulator] = []

            for try await chunk in stream {
                guard let choice = chunk.choices?.first, let delta = choice.delta else { continue }

                if let text = delta.content, !text.isEmpty {
                    textBuffer += text
                }

                if let deltaToolCalls = delta.toolCalls {
                    for tc in deltaToolCalls {
                        let index = tc.index ?? 0
                        while toolCallAccumulators.count <= index {
                            toolCallAccumulators.append(ToolCallAccumulator())
                        }
                        if let id = tc.id {
                            toolCallAccumulators[index].id = id
                        }
                        if let name = tc.function.name, !name.isEmpty {
                            toolCallAccumulators[index].name = name
                        }
                        if !tc.function.arguments.isEmpty {
                            toolCallAccumulators[index].arguments += tc.function.arguments
                        }
                    }
                }
            }

            // Process tool calls if any
            if !toolCallAccumulators.isEmpty {
                let tcStructs = toolCallAccumulators.compactMap { tc -> ToolCall? in
                    guard !tc.name.isEmpty else { return nil }
                    return ToolCall(id: tc.id, function: FunctionCall(arguments: tc.arguments, name: tc.name))
                }
                conversationHistory.append(.init(
                    role: .assistant,
                    content: .text(textBuffer),
                    toolCalls: tcStructs
                ))

                for tc in toolCallAccumulators where !tc.name.isEmpty {
                    try Task.checkCancellation()
                    rlog.info("Subagent [\(task.id.prefix(8))] tool call [\(turn)]: \(tc.name)", category: "Subagent")
                    onStatusUpdate?("Agent: \(tc.name)...")

                    let result: String
                    var succeeded = true
                    do {
                        result = try await toolbox.execute(name: tc.name, arguments: tc.arguments)
                    } catch {
                        rlog.error("Subagent tool \(tc.name) failed: \(error.localizedDescription)", category: "Subagent")
                        result = #"{"error":"\#(error.localizedDescription)"}"#
                        succeeded = false
                    }

                    allToolCalls.append(.init(
                        id: tc.id, name: tc.name, arguments: tc.arguments,
                        result: result, succeeded: succeeded
                    ))

                    conversationHistory.append(.init(role: .tool, content: .text(result), toolCallID: tc.id))
                }
                // Continue loop for next turn
            } else {
                // No tool calls — model has produced the final answer
                finalText = textBuffer
                break
            }

            // If this is the last turn and model still wants tools, take whatever text we have
            if turn == maxTurns - 1 {
                finalText = textBuffer.isEmpty ? "Task completed after \(maxTurns) tool-use rounds." : textBuffer
            }
        }

        // Extract summary (first sentence or first 200 chars) and details (full text)
        let summary = extractSummary(from: finalText)
        let elapsed = CFAbsoluteTimeGetCurrent() // placeholder, caller computes actual

        return OpenRockySubagentResult(
            taskID: task.id,
            summary: summary,
            details: finalText,
            toolCalls: allToolCalls,
            succeeded: true,
            elapsedSeconds: 0 // will be overwritten by caller
        )
    }

    // MARK: - Helpers

    private func buildSubagentSystemPrompt(task: OpenRockySubagentTask, parentContext: String) -> String {
        """
        You are a focused task agent within Rocky, an AI assistant on iPhone.
        You have been delegated a specific task by the main voice assistant.

        Your job:
        1. Complete the assigned task thoroughly using the available tools.
        2. Call tools as needed to gather information or perform actions.
        3. After completing all necessary tool calls, provide a clear, structured answer.
        4. Start your final answer with a one-sentence summary, then provide details.

        Important:
        - Be thorough — gather all necessary information before answering.
        - If a tool fails, try alternative approaches.
        - Keep your final answer concise but complete.
        - Do NOT make up information. If you cannot get data, say so.

        Context from the conversation: \(parentContext.isEmpty ? "None provided." : parentContext)
        Current date: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }

    private func buildToolDefinitions(allowedTools: [String]?) -> [ChatCompletionParameters.Tool] {
        var allTools = OpenRockyToolbox.chatToolDefinitions()
        allTools.append(contentsOf: OpenRockyToolbox.skillToolDefinitions())

        // Filter to allowed tools if specified
        guard let allowed = allowedTools, !allowed.isEmpty else {
            // Remove delegate-task from subagent to prevent recursive delegation
            return allTools.filter { $0.function.name != "delegate-task" }
        }

        let allowedSet = Set(allowed)
        return allTools.filter { allowedSet.contains($0.function.name ?? "") }
    }

    private func extractSummary(from text: String) -> String {
        guard !text.isEmpty else { return "Task completed." }

        // Try to extract first sentence
        let sentenceEnders: [Character] = [".", "!", "?", "。", "！", "？"]
        if let firstEnd = text.firstIndex(where: { sentenceEnders.contains($0) }) {
            let sentence = String(text[text.startIndex ... firstEnd])
            if sentence.count <= 200 {
                return sentence
            }
        }

        // Fall back to first 200 characters
        if text.count <= 200 { return text }
        let truncated = String(text.prefix(200))
        return truncated + "..."
    }

    // MARK: - Error Types

    enum SubagentError: LocalizedError {
        case timeout(taskID: String, seconds: TimeInterval)
        case noConfiguration

        var errorDescription: String? {
            switch self {
            case .timeout(_, let seconds):
                return "Subagent timed out after \(Int(seconds)) seconds."
            case .noConfiguration:
                return "No chat provider configured for subagent execution."
            }
        }
    }
}

// MARK: - Tool Call Accumulator (private to this file)

private struct ToolCallAccumulator {
    var id: String = ""
    var name: String = ""
    var arguments: String = ""
}

// MARK: - Delegate Task Request/Response (JSON codable for tool interface)

struct OpenRockyDelegateTaskRequest: Codable {
    let task: String
    let subtasks: [Subtask]?
    let context: String?

    struct Subtask: Codable {
        let description: String
        let tools: [String]?
    }
}

struct OpenRockyDelegateTaskResponse: Codable {
    let status: String
    let taskDescription: String
    let subtaskCount: Int
    let results: [SubtaskResult]
    let totalElapsedSeconds: Double

    struct SubtaskResult: Codable {
        let summary: String
        let details: String
        let toolsUsed: [String]
        let succeeded: Bool
        let elapsedSeconds: Double
    }
}

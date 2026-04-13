//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Testing
@testable import OpenRocky
import SwiftOpenAI

// MARK: - Shared Tool Name Constants

/// All tool names registered in realtimeToolDefinitions / chatToolDefinitions.
/// Single source of truth — all tests reference this instead of duplicating the list.
private let kRealtimeToolNames: Set<String> = [
    "apple-location", "apple-geocode", "weather", "apple-alarm",
    "memory_get", "memory_write",
    "apple-health-summary", "apple-health-metric",
    "shell-execute", "python-execute", "ffmpeg-execute",
    "browser-open", "browser-cookies", "browser-read",
    "oauth-authenticate", "crypto",
    "file-read", "file-write", "file-pick",
    "todo", "web-search",
    "apple-calendar-list", "apple-calendar-create",
    "apple-reminder-list", "apple-reminder-create",
    "notification-schedule", "open-url",
    "nearby-search", "apple-contacts-search",
    "camera-capture", "photo-pick",
    "delegate-task"
]

/// Tools registered only via OpenRockyToolProvider (conditionally enabled, not in realtime definitions).
private let kConditionalToolNames: Set<String> = [
    "app-exit", "email-send"
]

/// Every tool that has a dispatch case in _execute.
private let kAllDispatchedToolNames: Set<String> = kRealtimeToolNames.union(kConditionalToolNames)

/// Minimal valid JSON arguments for each tool, enough to pass decode and hit the handler.
private let kMinimalArgs: [String: String] = [
    "apple-location": "{}",
    "apple-geocode": #"{"address":"Tokyo"}"#,
    "weather": "{}",
    "apple-alarm": #"{"scheduled_at":"2099-01-01T07:00:00"}"#,
    "memory_get": #"{"key":"__dispatch_test__"}"#,
    "memory_write": #"{"key":"__dispatch_test__","value":"x"}"#,
    "apple-health-summary": #"{"date":"2025-01-01"}"#,
    "apple-health-metric": #"{"metric":"steps","start_date":"2025-01-01","end_date":"2025-01-02"}"#,
    "shell-execute": #"{"command":"echo hi"}"#,
    "python-execute": #"{"code":"print(1)"}"#,
    "ffmpeg-execute": #"{"args":"-version"}"#,
    "browser-open": #"{"url":"https://example.com"}"#,
    "browser-cookies": #"{"domain":"example.com"}"#,
    "browser-read": #"{"url":"https://example.com"}"#,
    "oauth-authenticate": #"{"auth_url":"https://example.com","callback_scheme":"rocky"}"#,
    "crypto": #"{"operation":"sha256","data":"test"}"#,
    "file-read": #"{"path":"__nonexistent__.txt"}"#,
    "file-write": #"{"path":"__dispatch_test__.txt","content":"test"}"#,
    "todo": #"{"action":"list"}"#,
    "web-search": #"{"query":"test"}"#,
    "apple-calendar-list": #"{"start_date":"2025-01-01","end_date":"2025-01-02"}"#,
    "apple-calendar-create": #"{"title":"test","start_date":"2099-01-01T10:00:00"}"#,
    "apple-reminder-list": "{}",
    "apple-reminder-create": #"{"title":"test"}"#,
    "notification-schedule": #"{"title":"test"}"#,
    "open-url": #"{"url":"https://example.com"}"#,
    "nearby-search": #"{"query":"coffee"}"#,
    "apple-contacts-search": #"{"query":"__nobody__"}"#,
    "camera-capture": "{}",
    "photo-pick": "{}",
    "file-pick": "{}",
    "app-exit": #"{"farewell_message":"test"}"#,
    "email-send": #"{"to":"test@test.com","subject":"test","body":"test"}"#,
    "delegate-task": #"{"task":"test task"}"#
]

@MainActor
struct OpenRockyTests {

    @Test func sampleSessionHasVisibleExecutionPlan() async throws {
        let session = OpenRockyPreviewSession.sample

        #expect(session.plan.count >= 4)
        #expect(session.completedCount == 1)
        #expect(session.timeline.count >= 4)
        #expect(session.artifactCount == 3)
    }

    @Test func sessionModeCyclesAcrossPrimaryStates() async throws {
        #expect(SessionMode.listening.next == .planning)
        #expect(SessionMode.planning.next == .executing)
        #expect(SessionMode.executing.next == .ready)
        #expect(SessionMode.ready.next == .listening)
    }

    @Test func capabilityInventoryKeepsLayerNamesDistinct() async throws {
        let groups = OpenRockyPreviewSession.sample.capabilityGroups

        #expect(groups.count == 3)
        #expect(groups.map(\.title).contains("iOS Native Bridge"))
        #expect(groups.map(\.title).contains("AI Tool Layer"))
        #expect(groups.map(\.title).contains("Platform Integrations"))
    }

    @Test func providerInventoryIncludesConfiguredBackends() async throws {
        #expect(OpenRockyProviderKind.allCases.contains(.openAI))
        #expect(OpenRockyProviderKind.allCases.contains(.azureOpenAI))
        #expect(OpenRockyProviderKind.allCases.contains(.anthropic))
        #expect(OpenRockyProviderKind.allCases.contains(.gemini))
        #expect(OpenRockyProviderKind.allCases.contains(.groq))
        #expect(OpenRockyProviderKind.allCases.contains(.xAI))
        #expect(OpenRockyProviderKind.allCases.contains(.openRouter))
        #expect(OpenRockyProviderKind.allCases.contains(.deepSeek))
        #expect(OpenRockyProviderKind.allCases.contains(.aiProxy))
        #expect(OpenRockyProviderKind.allCases.contains(.bailian))
        #expect(OpenRockyProviderKind.openAI.defaultModel == "gpt-5")
    }

    @Test func realtimeProviderInventorySupportsOpenAIAndGLM() async throws {
        #expect(OpenRockyRealtimeProviderKind.allCases.contains(.openAI))
        #expect(OpenRockyRealtimeProviderKind.allCases.contains(.glm))
        #expect(OpenRockyRealtimeProviderKind.openAI.defaultModel == "gpt-realtime-mini")
        #expect(OpenRockyRealtimeProviderKind.glm.defaultModel == "glm-realtime")
    }

    @Test func providerConfigurationReflectsConnectionStateInIdentity() async throws {
        let disconnected = OpenRockyProviderConfiguration(
            provider: .openAI,
            modelID: "gpt-5.2-codex",
            credential: nil
        )
        let connected = OpenRockyProviderConfiguration(
            provider: .openAI,
            modelID: "gpt-5.2-codex",
            credential: "sk-test-1234"
        )

        #expect(disconnected.identity.contains("disconnected"))
        #expect(connected.identity.contains("connected"))
        #expect(connected.maskedCredential.contains("••••"))
    }

    @Test func azureAndAIProxyRequireProviderSpecificFields() async throws {
        let azure = OpenRockyProviderConfiguration(
            provider: .azureOpenAI,
            modelID: "gpt-5-codex",
            credential: "azure-key",
            azureResourceName: "rocky-dev",
            azureAPIVersion: "2024-10-21"
        )
        let incompleteAzure = OpenRockyProviderConfiguration(
            provider: .azureOpenAI,
            modelID: "gpt-5-codex",
            credential: "azure-key"
        )
        let aiProxy = OpenRockyProviderConfiguration(
            provider: .aiProxy,
            modelID: "gpt-5.2-codex",
            credential: "pk_live_1234",
            aiProxyServiceURL: "https://api.aiproxy.pro/example"
        )

        #expect(azure.normalized().isConfigured)
        #expect(incompleteAzure.normalized().isConfigured == false)
        #expect(aiProxy.normalized().isConfigured)
    }

    @Test func realtimeProviderConfigurationReflectsCredentialState() async throws {
        let disconnected = OpenRockyRealtimeProviderConfiguration(
            provider: .glm,
            modelID: "glm-realtime",
            credential: nil
        )
        let connected = OpenRockyRealtimeProviderConfiguration(
            provider: .glm,
            modelID: "glm-realtime",
            credential: "sk-glm-test"
        )

        #expect(disconnected.identity.contains("disconnected"))
        #expect(connected.identity.contains("connected"))
        #expect(connected.normalized().isConfigured)
        #expect(connected.maskedCredential.contains("••••"))
    }

    // MARK: - Toolbox Registration Tests

    @Test func realtimeToolDefinitionsContainsAllTools() async throws {
        let tools = OpenRockyToolbox.realtimeToolDefinitions()
        var names: [String] = []
        for tool in tools {
            if case let .function(def) = tool {
                names.append(def.name)
            }
        }

        for name in kRealtimeToolNames {
            #expect(names.contains(name), "Missing realtime tool: \(name)")
        }
        #expect(names.count == kRealtimeToolNames.count, "Expected \(kRealtimeToolNames.count) tools, got \(names.count)")
    }

    @Test func chatToolDefinitionsContainsAllTools() async throws {
        let tools = OpenRockyToolbox.chatToolDefinitions()
        let names = tools.map { $0.function.name }

        for name in kRealtimeToolNames {
            #expect(names.contains(name), "Missing chat tool: \(name)")
        }
        #expect(names.count == kRealtimeToolNames.count, "Expected \(kRealtimeToolNames.count) chat tools, got \(names.count)")
    }

    @Test func realtimeAndChatToolDefinitionsAreInSync() async throws {
        let realtimeTools = OpenRockyToolbox.realtimeToolDefinitions()
        let chatTools = OpenRockyToolbox.chatToolDefinitions()

        var realtimeNames = Set<String>()
        for tool in realtimeTools {
            if case let .function(def) = tool {
                realtimeNames.insert(def.name)
            }
        }
        let chatNames = Set(chatTools.map { $0.function.name })

        #expect(realtimeNames == chatNames, "Realtime and chat tool sets differ: realtime-only=\(realtimeNames.subtracting(chatNames)), chat-only=\(chatNames.subtracting(realtimeNames))")
    }

    @Test func skillStoreCoversAllTools() async throws {
        let store = OpenRockyBuiltInToolStore()
        let toolIDs = Set(store.tools.map(\.id))

        let realtimeTools = OpenRockyToolbox.realtimeToolDefinitions()
        var toolNames = Set<String>()
        for tool in realtimeTools {
            if case let .function(def) = tool {
                toolNames.insert(def.name)
            }
        }

        for name in toolNames {
            #expect(toolIDs.contains(name), "Tool '\(name)' not in ToolStore")
        }
    }

    @Test func toolStoreGroupsAreNonEmpty() async throws {
        let store = OpenRockyBuiltInToolStore()
        let groups = store.toolsByGroup()

        #expect(groups.count >= 6, "Expected at least 6 tool groups, got \(groups.count)")
        for group in groups {
            #expect(!group.tools.isEmpty, "Group '\(group.group.rawValue)' has no tools")
        }
    }

    @Test func allToolsRegistered() async throws {
        let store = OpenRockyBuiltInToolStore()
        #expect(store.tools.count >= 31, "Should have at least 31 built-in tools")
    }

    @Test func characterPromptContainsAllToolNames() async throws {
        let store = OpenRockyCharacterStore()
        let prompt = store.systemPrompt

        for name in kRealtimeToolNames {
            #expect(prompt.contains(name), "Character prompt missing tool: \(name)")
        }
    }

    // MARK: - Dispatch Tests (Pure Logic Tools)

    /// Verify crypto tool dispatches and computes correct SHA256
    @Test func dispatchCryptoSHA256() async throws {
        let toolbox = OpenRockyToolbox()
        let result = try await toolbox.execute(
            name: "crypto",
            arguments: #"{"operation":"sha256","data":"hello"}"#
        )
        #expect(result.contains("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"))
    }

    /// Verify crypto tool dispatches and computes correct MD5
    @Test func dispatchCryptoMD5() async throws {
        let toolbox = OpenRockyToolbox()
        let result = try await toolbox.execute(
            name: "crypto",
            arguments: #"{"operation":"md5","data":"hello"}"#
        )
        #expect(result.contains("5d41402abc4b2a76b9719d911017c592"))
    }

    /// Verify crypto tool dispatches base64 encode
    @Test func dispatchCryptoBase64Encode() async throws {
        let toolbox = OpenRockyToolbox()
        let result = try await toolbox.execute(
            name: "crypto",
            arguments: #"{"operation":"base64_encode","data":"hello"}"#
        )
        #expect(result.contains("aGVsbG8="))
    }

    /// Verify crypto tool dispatches base64 decode
    @Test func dispatchCryptoBase64Decode() async throws {
        let toolbox = OpenRockyToolbox()
        let result = try await toolbox.execute(
            name: "crypto",
            arguments: #"{"operation":"base64_decode","data":"aGVsbG8="}"#
        )
        #expect(result.contains("hello"))
    }

    /// Verify todo tool dispatches add + list + delete cycle
    @Test func dispatchTodoLifecycle() async throws {
        let toolbox = OpenRockyToolbox()

        // Add
        let addResult = try await toolbox.execute(
            name: "todo",
            arguments: #"{"action":"add","title":"dispatch test item"}"#
        )
        #expect(addResult.contains("dispatch test item"))
        #expect(addResult.contains("\"created\":true") || addResult.contains("\"created\" : true"))

        // List
        let listResult = try await toolbox.execute(
            name: "todo",
            arguments: #"{"action":"list"}"#
        )
        #expect(listResult.contains("dispatch test item"))

        // Extract id from addResult for cleanup
        if let idRange = addResult.range(of: #"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"#, options: [.regularExpression, .caseInsensitive]) {
            let id = String(addResult[idRange])
            let deleteResult = try await toolbox.execute(
                name: "todo",
                arguments: #"{"action":"delete","id":"\#(id)"}"#
            )
            #expect(deleteResult.contains("\"deleted\":true") || deleteResult.contains("\"deleted\" : true"))
        }
    }

    /// Verify memory_write + memory_get round-trip
    @Test func dispatchMemoryRoundTrip() async throws {
        let toolbox = OpenRockyToolbox()
        let testKey = "dispatch_test_\(UUID().uuidString.prefix(8))"

        let writeResult = try await toolbox.execute(
            name: "memory_write",
            arguments: #"{"key":"\#(testKey)","value":"test_value_42"}"#
        )
        #expect(writeResult.contains("\"stored\":true") || writeResult.contains("\"stored\" : true"))

        let getResult = try await toolbox.execute(
            name: "memory_get",
            arguments: #"{"key":"\#(testKey)"}"#
        )
        #expect(getResult.contains("test_value_42"))
    }

    /// Verify unsupported tool name throws error
    @Test func dispatchUnknownToolThrows() async throws {
        let toolbox = OpenRockyToolbox()
        do {
            _ = try await toolbox.execute(name: "nonexistent-tool", arguments: "{}")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error.localizedDescription.contains("nonexistent-tool"))
        }
    }

    /// Verify all tool names (realtime + conditional) route without "unsupported tool" error.
    /// Tools may fail due to missing permissions/hardware, but must not hit the default case.
    @Test func dispatchAllToolsRoute() async throws {
        let toolbox = OpenRockyToolbox()

        for name in kAllDispatchedToolNames {
            let args = kMinimalArgs[name] ?? "{}"
            do {
                _ = try await toolbox.execute(name: name, arguments: args)
            } catch {
                // Acceptable: permission denied, hardware unavailable, SMTP not configured, etc.
                // NOT acceptable: "does not recognize tool" (means routing is broken)
                let msg = error.localizedDescription
                #expect(
                    !msg.contains("does not recognize tool"),
                    "Tool '\(name)' not routed in _execute switch"
                )
            }
        }
    }

    /// Verify kMinimalArgs covers every dispatched tool (no tool left without test args)
    @Test func minimalArgsCoverAllTools() async throws {
        for name in kAllDispatchedToolNames {
            #expect(kMinimalArgs[name] != nil, "Tool '\(name)' missing from kMinimalArgs")
        }
    }

    // MARK: - Skill Dispatch Tests

    /// Verify all 10 built-in skills are loaded
    @Test func builtInSkillsCount() async throws {
        #expect(OpenRockyBuiltInSkills.all.count == 10)
    }

    /// Verify each built-in skill has non-empty name, description, trigger, and prompt
    @Test func builtInSkillsHaveContent() async throws {
        for skill in OpenRockyBuiltInSkills.all {
            #expect(!skill.name.isEmpty, "Skill has empty name")
            #expect(!skill.description.isEmpty, "Skill '\(skill.name)' has empty description")
            #expect(!skill.trigger.isEmpty, "Skill '\(skill.name)' has empty trigger")
            #expect(!skill.prompt.isEmpty, "Skill '\(skill.name)' has empty prompt")
        }
    }

    /// Verify built-in skill names are unique
    @Test func builtInSkillNamesUnique() async throws {
        let names = OpenRockyBuiltInSkills.all.map(\.name)
        #expect(Set(names).count == names.count, "Duplicate skill names found")
    }
}

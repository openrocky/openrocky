//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-07
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Testing
@testable import OpenRocky
import ChatClientKit

// MARK: - E2E Tool Invocation Tests
//
// These tests send a real prompt to OpenAI, let it decide which tool(s) to call,
// then verify the expected tool was dispatched and returned a valid result.
//
// Run on device:
//   xcodebuild test -scheme OpenRocky -project OpenRocky/OpenRocky.xcodeproj \
//     -destination 'platform=iOS,name=<YourDevice>' \
//     -only-testing:OpenRockyTests/OpenRockyE2ETests

extension Tag {
    @Tag static var e2e: Self
}

/// Tests run serialized to avoid resource exhaustion from concurrent API calls.
@Suite(.serialized)
@MainActor
struct OpenRockyE2ETests {

    /// Read API key from environment. For on-device testing, set in Xcode scheme
    /// → Test → Arguments → Environment Variables, or hardcode temporarily (never commit a real key).
    private static var apiKey: String? {
        ProcessInfo.processInfo.environment["ROCKY_TEST_OPENAI_API_KEY"]
    }

    private static var configuration: OpenRockyProviderConfiguration {
        OpenRockyProviderConfiguration(
            provider: .openAI,
            modelID: "gpt-4o-mini",
            credential: apiKey
        )
    }

    /// Run a prompt through the chat inference runtime and return completed tool calls.
    private func runPrompt(_ prompt: String) async throws -> [OpenRockyChatInferenceRuntime.CompletedToolCall] {
        guard let key = Self.apiKey, !key.isEmpty else {
            throw SkipError()
        }
        _ = key

        let runtime = OpenRockyChatInferenceRuntime()
        try await runtime.run(
            prompt: prompt,
            configuration: Self.configuration,
            onChunk: { _ in }
        )
        return runtime.completedToolCalls
    }

    // MARK: - Crypto Tests

    @Test(.tags(.e2e))
    func e2eCryptoSHA256() async throws {
        let calls = try await runPrompt(
            "Calculate the SHA256 hash of the text 'hello'. Use the crypto tool, just return the hash."
        )
        let call = calls.first { $0.name == "crypto" }
        #expect(call != nil, "Expected crypto tool to be called")
        #expect(call?.succeeded == true)
        #expect(call?.result.contains("2cf24dba") == true)
    }

    @Test(.tags(.e2e))
    func e2eCryptoMD5() async throws {
        let calls = try await runPrompt(
            "Calculate the MD5 hash of 'hello'. Use the crypto tool with operation 'md5'."
        )
        let call = calls.first { $0.name == "crypto" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
        #expect(call?.result.contains("5d41402abc4b") == true)
    }

    @Test(.tags(.e2e))
    func e2eCryptoBase64() async throws {
        let calls = try await runPrompt(
            "Base64 encode the text 'hello world'. Use the crypto tool with operation 'base64_encode'."
        )
        let call = calls.first { $0.name == "crypto" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
        #expect(call?.result.contains("aGVsbG8gd29ybGQ=") == true)
    }

    // MARK: - Memory Tests

    @Test(.tags(.e2e))
    func e2eMemoryWriteAndGet() async throws {
        let calls = try await runPrompt(
            "Use memory_write to store key 'e2e_color' value 'blue'. Then use memory_get to retrieve key 'e2e_color'."
        )
        let writeCall = calls.first { $0.name == "memory_write" }
        #expect(writeCall != nil)
        #expect(writeCall?.succeeded == true)
    }

    // MARK: - Todo Tests

    @Test(.tags(.e2e))
    func e2eTodoAdd() async throws {
        let calls = try await runPrompt(
            "Add a todo item titled 'E2E test item'. Use the todo tool with action 'add'."
        )
        let call = calls.first { $0.name == "todo" }
        #expect(call != nil)
        #expect(call?.arguments.contains("add") == true)
    }

    // MARK: - File Tests

    @Test(.tags(.e2e))
    func e2eFileWriteAndRead() async throws {
        let calls = try await runPrompt(
            "Write 'hello e2e' to a file called 'e2e_test.txt', then read it back. Use file-write and file-read tools."
        )
        let writeCall = calls.first { $0.name == "file-write" }
        #expect(writeCall != nil)
        #expect(writeCall?.succeeded == true)
    }

    // MARK: - Location & Weather

    @Test(.tags(.e2e))
    func e2eAppleLocation() async throws {
        let calls = try await runPrompt(
            "Get my current location. Use the apple-location tool."
        )
        let call = calls.first { $0.name == "apple-location" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
    }

    @Test(.tags(.e2e))
    func e2eAppleGeocode() async throws {
        let calls = try await runPrompt(
            "Geocode the address 'Shibuya, Tokyo, Japan'. Use the apple-geocode tool."
        )
        let call = calls.first { $0.name == "apple-geocode" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
    }

    @Test(.tags(.e2e))
    func e2eWeather() async throws {
        let calls = try await runPrompt(
            "Get the weather in Tokyo. First geocode 'Tokyo' then get weather."
        )
        let weatherCall = calls.first { $0.name == "weather" }
        #expect(weatherCall != nil)
        #expect(weatherCall?.succeeded == true)
    }

    @Test(.tags(.e2e))
    func e2eNearbySearch() async throws {
        let calls = try await runPrompt(
            "Find nearby coffee shops. Use the nearby-search tool with query 'coffee shop'."
        )
        let call = calls.first { $0.name == "nearby-search" }
        #expect(call != nil)
    }

    // MARK: - Calendar & Reminders

    @Test(.tags(.e2e))
    func e2eCalendarList() async throws {
        let calls = try await runPrompt(
            "List my calendar events for today. Use the apple-calendar-list tool with today's date range."
        )
        let call = calls.first { $0.name == "apple-calendar-list" }
        #expect(call != nil)
    }

    @Test(.tags(.e2e))
    func e2eCalendarCreate() async throws {
        let calls = try await runPrompt(
            "Call the apple-calendar-create tool to create an event with title 'E2E Test Event', start_date '2099-12-31T10:00:00', end_date '2099-12-31T11:00:00'."
        )
        let call = calls.first { $0.name == "apple-calendar-create" }
        #expect(call != nil, "Expected apple-calendar-create tool to be called")
    }

    @Test(.tags(.e2e))
    func e2eReminderList() async throws {
        let calls = try await runPrompt(
            "Show me my current reminders. Call the apple-reminder-list tool to fetch them."
        )
        let call = calls.first { $0.name == "apple-reminder-list" }
        #expect(call != nil)
    }

    @Test(.tags(.e2e))
    func e2eReminderCreate() async throws {
        let calls = try await runPrompt(
            "Create a reminder titled 'E2E Test Reminder' due 2099-12-31. Use the apple-reminder-create tool."
        )
        let call = calls.first { $0.name == "apple-reminder-create" }
        #expect(call != nil)
    }

    // MARK: - Contacts

    @Test(.tags(.e2e))
    func e2eContactsSearch() async throws {
        let calls = try await runPrompt(
            "Search my contacts for someone named 'test'. Use the apple-contacts-search tool."
        )
        let call = calls.first { $0.name == "apple-contacts-search" }
        #expect(call != nil)
    }

    // MARK: - Health

    @Test(.tags(.e2e))
    func e2eHealthSummary() async throws {
        let calls = try await runPrompt(
            "Get my health summary for today. Use the apple-health-summary tool."
        )
        let call = calls.first { $0.name == "apple-health-summary" }
        #expect(call != nil)
    }

    @Test(.tags(.e2e))
    func e2eHealthMetric() async throws {
        let calls = try await runPrompt(
            "Query my step count for the last 7 days. Use the apple-health-metric tool with metric_type 'steps'."
        )
        let call = calls.first { $0.name == "apple-health-metric" }
        #expect(call != nil)
    }

    // MARK: - Shell & Python

    @Test(.tags(.e2e))
    func e2eShellExecute() async throws {
        let calls = try await runPrompt(
            "Run the shell command 'echo hello_e2e'. Use the shell-execute tool."
        )
        let call = calls.first { $0.name == "shell-execute" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
    }

    @Test(.tags(.e2e))
    func e2ePythonExecute() async throws {
        let calls = try await runPrompt(
            "Execute the Python code: print(2+3). Use the python-execute tool."
        )
        let call = calls.first { $0.name == "python-execute" }
        #expect(call != nil)
    }

    // MARK: - Web & Browser

    @Test(.tags(.e2e))
    func e2eWebSearch() async throws {
        let calls = try await runPrompt(
            "Search the web for 'OpenAI GPT-4o release date'. Use the web-search tool."
        )
        let call = calls.first { $0.name == "web-search" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
    }

    @Test(.tags(.e2e))
    func e2eBrowserRead() async throws {
        let calls = try await runPrompt(
            "Read the webpage at https://example.com. Use the browser-read tool."
        )
        let call = calls.first { $0.name == "browser-read" }
        #expect(call != nil)
        #expect(call?.succeeded == true)
    }

    // MARK: - Notifications & URL

    @Test(.tags(.e2e))
    func e2eNotificationSchedule() async throws {
        let calls = try await runPrompt(
            "Schedule a notification with title 'E2E Test' body 'test' after 60 seconds delay. Use the notification-schedule tool."
        )
        let call = calls.first { $0.name == "notification-schedule" }
        #expect(call != nil)
    }

    @Test(.tags(.e2e))
    func e2eOpenURL() async throws {
        let calls = try await runPrompt(
            "Open the URL https://example.com. Use the open-url tool."
        )
        let call = calls.first { $0.name == "open-url" }
        #expect(call != nil)
    }

    // MARK: - Alarm

    @Test(.tags(.e2e))
    func e2eAppleAlarm() async throws {
        let calls = try await runPrompt(
            "You must call the apple-alarm tool right now with this exact parameter: {\"scheduled_at\":\"2099-12-31T08:00:00\"}. Do not respond with text, just call the tool."
        )
        let call = calls.first { $0.name == "apple-alarm" }
        #expect(call != nil, "Expected apple-alarm tool to be called")
    }
}

private struct SkipError: Error, CustomStringConvertible {
    var description: String { "ROCKY_TEST_OPENAI_API_KEY not set — skipping E2E test" }
}

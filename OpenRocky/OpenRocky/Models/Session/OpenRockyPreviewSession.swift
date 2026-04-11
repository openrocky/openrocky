//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import SwiftUI

struct OpenRockyPreviewSession {
    var mode: SessionMode
    var liveTranscript: String
    var assistantReply: String
    var eta: String
    var provider: ProviderStatus
    var plan: [PlanStep]
    var timeline: [TimelineEntry]
    var quickTasks: [QuickTask]
    var capabilityGroups: [CapabilityGroup]
    var artifactCount: Int
    var sessionTag: String

    var completedCount: Int {
        plan.filter { $0.state == .done }.count
    }

    static let sample = OpenRockyPreviewSession(
        mode: .executing,
        liveTranscript: "Remind me every 40 minutes tomorrow between 10 and 8, then check the afternoon weather and tell me whether I should move the walk to the evening.",
        assistantReply: "I parsed the alarm window, I am holding the alarm batch for confirmation, and I will compare afternoon versus evening weather next.",
        eta: "02:18",
        provider: ProviderStatus(name: "OpenAI", model: "gpt-5.4", isConnected: true),
        plan: [
            PlanStep(title: "Parse the request into bounded actions", detail: "Split reminders, time window and weather follow-up into separate runtime steps.", state: .done),
            PlanStep(title: "Create recurring alarms safely", detail: "Prepare `apple-alarm` calls and hold destructive changes behind confirmation.", state: .active),
            PlanStep(title: "Fetch local forecast context", detail: "Use `apple-weather` after the alarm plan is stable.", state: .queued),
            PlanStep(title: "Summarize in one spoken answer", detail: "Return a short voice reply plus a detailed timeline card.", state: .queued)
        ],
        timeline: [
            TimelineEntry(kind: .speech, time: "09:41", text: "User asked OpenRocky to create tomorrow alarms every 40 minutes and compare afternoon and evening weather."),
            TimelineEntry(kind: .system, time: "09:41", text: "OpenRocky converted the voice request into a 4-step executable plan."),
            TimelineEntry(kind: .tool, time: "09:42", text: "Pending tool call: `apple-alarm batch_create` with 16 candidate alarms between 10:00 and 20:00."),
            TimelineEntry(kind: .result, time: "09:42", text: "Awaiting user confirmation before committing the alarm batch. Weather analysis is queued next.")
        ],
        quickTasks: [
            QuickTask(title: "Batch Alarms", prompt: "Create spaced reminders or alarms from one sentence.", symbol: "alarm.fill", tint: OpenRockyPalette.secondary),
            QuickTask(title: "Photo Memory", prompt: "Search photos and explain what happened around a time window.", symbol: "photo.on.rectangle.angled", tint: OpenRockyPalette.accent),
            QuickTask(title: "Route + Weather", prompt: "Compare travel time, rain risk and the better departure window.", symbol: "map.fill", tint: OpenRockyPalette.success),
            QuickTask(title: "Inbox Summary", prompt: "Read a page, a note or a file and extract the action items.", symbol: "text.bubble.fill", tint: OpenRockyPalette.warning)
        ],
        capabilityGroups: [
            CapabilityGroup(
                title: "iOS Native Bridge",
                status: "CURRENT PLAN",
                summary: "Use explicit `apple-*` commands for alarms, maps, weather, photos, speech and device services.",
                items: ["apple-alarm", "apple-calendar", "apple-location", "apple-maps", "apple-photos", "apple-player", "apple-speech", "apple-vision", "apple-weather"],
                tint: OpenRockyPalette.accent
            ),
            CapabilityGroup(
                title: "AI Tool Layer",
                status: "CURRENT PLAN",
                summary: "Route model intent through bounded tool actions instead of exposing a raw shell as the product interface.",
                items: ["shell_execute", "file_read", "file_write", "file_edit", "browser_use", "memory_get", "memory_write", "read_image", "multi_tool_use.parallel"],
                tint: OpenRockyPalette.secondary
            ),
            CapabilityGroup(
                title: "Platform Integrations",
                status: "REFERENCE / FUTURE",
                summary: "Keep deep links, CLIs and external execution environments documented as integrations, not as OpenRocky core UX.",
                items: ["shell", "python3", "curl", "pip", "git"],
                tint: OpenRockyPalette.success
            )
        ],
        artifactCount: 3,
        sessionTag: "VOICE-09A"
    )

    static func liveSeed(provider: ProviderStatus) -> OpenRockyPreviewSession {
        OpenRockyPreviewSession(
            mode: .ready,
            liveTranscript: "Speak or type a request to start a real session.",
            assistantReply: "OpenRocky is idle. Start voice or send text to attach a live runtime.",
            eta: "LIVE",
            provider: provider,
            plan: [
                PlanStep(title: "Connect a live session", detail: "Open a realtime model session and keep the conversation state attached to the home surface.", state: .active),
                PlanStep(title: "Capture speech or text input", detail: "Stream microphone audio or accept the typed fallback through the same runtime.", state: .queued),
                PlanStep(title: "Run first-party tools safely", detail: "Call `apple-location`, `apple-weather`, or `apple-alarm` only when they help complete the request.", state: .queued),
                PlanStep(title: "Return a concise answer", detail: "Speak the answer and keep the transcript visible on the home screen.", state: .queued)
            ],
            timeline: [
                TimelineEntry(kind: .system, time: Self.timestampLabel(for: .now), text: "Voice runtime is ready. The first real session will replace this placeholder timeline.")
            ],
            quickTasks: sample.quickTasks,
            capabilityGroups: sample.capabilityGroups,
            artifactCount: 0,
            sessionTag: "VOICE-LIVE"
        )
    }

    private static func timestampLabel(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

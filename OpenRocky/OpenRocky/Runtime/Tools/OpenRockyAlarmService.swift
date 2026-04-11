//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AlarmKit
import Foundation
import SwiftUI

struct OpenRockyAlarmSnapshot: Codable, Sendable {
    let id: UUID
    let title: String
    let scheduledAt: String
    let authorizationState: String
}

@available(iOS 26.0, *)
@MainActor
final class OpenRockyAlarmService {
    func createAlarm(title: String, scheduledAt: Date) async throws -> OpenRockyAlarmSnapshot {
        let manager = AlarmManager.shared
        let authorization = try await ensureAuthorized()
        let stopButton = AlarmButton(
            text: LocalizedStringResource(String.LocalizationValue("Stop")),
            textColor: .white,
            systemImageName: "stop.fill"
        )
        let presentation = AlarmPresentation(
            alert: .init(
                title: LocalizedStringResource(String.LocalizationValue(title)),
                stopButton: stopButton
            )
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: OpenRockyAlarmMetadata(title: title),
            tintColor: OpenRockyPalette.secondary
        )
        let alarm = try await manager.schedule(
            id: UUID(),
            configuration: .alarm(
                schedule: .fixed(scheduledAt),
                attributes: attributes
            )
        )

        return OpenRockyAlarmSnapshot(
            id: alarm.id,
            title: title,
            scheduledAt: scheduledAt.ISO8601Format(),
            authorizationState: String(describing: authorization)
        )
    }

    private func ensureAuthorized() async throws -> AlarmManager.AuthorizationState {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized:
            return .authorized
        case .notDetermined:
            let authorization = try await manager.requestAuthorization()
            guard authorization == .authorized else {
                throw OpenRockyAlarmServiceError.permissionDenied
            }
            return authorization
        case .denied:
            throw OpenRockyAlarmServiceError.permissionDenied
        @unknown default:
            throw OpenRockyAlarmServiceError.permissionDenied
        }
    }
}

@available(iOS 26.0, *)
private struct OpenRockyAlarmMetadata: AlarmMetadata {
    let title: String
}

enum OpenRockyAlarmServiceError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Alarm permission is required before OpenRocky can create an `apple-alarm`."
        }
    }
}

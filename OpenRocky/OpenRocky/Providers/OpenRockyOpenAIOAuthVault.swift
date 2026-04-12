//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation

enum OpenRockyOpenAIOAuthVault {
    private static let keyPrefix = "rocky.openai-oauth.account"
    private static let keychain = OpenRockyKeychain.live

    static func credential(for accountID: String) -> OpenRockyOpenAIOAuthCredential? {
        guard let json = keychain.value(for: accountKey(accountID: accountID)),
              let data = json.data(using: .utf8),
              let credential = try? JSONDecoder().decode(OpenRockyOpenAIOAuthCredential.self, from: data) else {
            return nil
        }
        return credential
    }

    static func save(_ credential: OpenRockyOpenAIOAuthCredential) {
        guard let data = try? JSONEncoder().encode(credential),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        keychain.set(json, for: accountKey(accountID: credential.accountID))
    }

    static func remove(accountID: String) {
        keychain.removeValue(for: accountKey(accountID: accountID))
    }

    static func resolvedAccessToken(from rawCredential: String) async throws -> String {
        guard let accountID = OpenRockyOpenAIOAuthService.accountID(fromAccessToken: rawCredential),
              let stored = credential(for: accountID) else {
            return rawCredential
        }

        let updated = try await OpenRockyOpenAIOAuthService.refreshIfNeeded(stored)
        if updated != stored {
            save(updated)
            rlog.info("Refreshed OpenAI OAuth access token for account \(accountID)", category: "Provider")
        }
        return updated.accessToken
    }

    private static func accountKey(accountID: String) -> String {
        "\(keyPrefix).\(accountID)"
    }
}

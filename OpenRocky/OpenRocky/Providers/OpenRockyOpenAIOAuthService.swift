//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import CryptoKit
import Foundation
import Security
import UIKit

struct OpenRockyOpenAIOAuthCredential: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var accountID: String
    var authorizedAt: Date

    var isExpired: Bool {
        expiresAt <= Date()
    }

    var maskedAccessToken: String {
        guard accessToken.count >= 10 else { return "••••" }
        return "\(accessToken.prefix(8))••••\(accessToken.suffix(4))"
    }
}

@MainActor
enum OpenRockyOpenAIOAuthService {
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let authorizeURL = "https://auth.openai.com/oauth/authorize"
    private static let tokenURL = "https://auth.openai.com/oauth/token"
    private static let redirectURI = "http://127.0.0.1:1455/auth/callback"
    private static let callbackPort: UInt16 = 1455
    private static let scope = "openid profile email offline_access"
    nonisolated private static let jwtAuthClaimPath = "https://api.openai.com/auth"

    static func signIn(originator: String = "openrocky") async throws -> OpenRockyOpenAIOAuthCredential {
        let flow = try makeAuthorizationFlow(originator: originator)

        // Start a local HTTP server to receive the OAuth callback,
        // mirroring how Codex CLI handles the redirect to 127.0.0.1:1455.
        let server = OpenRockyLocalOAuthServer(port: callbackPort)

        // Open the authorization URL in the system browser
        guard let authURL = URL(string: flow.url) else {
            throw OpenAIOAuthError.invalidAuthorizeURL
        }
        let opened = await UIApplication.shared.open(authURL)
        guard opened else {
            await server.stop()
            throw OpenAIOAuthError.invalidAuthorizeURL
        }

        // Wait for the callback on the local server
        let callback: OpenRockyLocalOAuthServer.OAuthCallbackResult
        do {
            callback = try await server.waitForCallback(timeout: 300)
        } catch {
            await server.stop()
            throw error
        }

        guard callback.state == flow.state else {
            throw OpenAIOAuthError.stateMismatch
        }

        let token = try await exchangeAuthorizationCode(code: callback.code, verifier: flow.verifier)
        guard let accountID = extractAccountID(from: token.accessToken) else {
            throw OpenAIOAuthError.missingAccountID
        }

        return OpenRockyOpenAIOAuthCredential(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: Date().addingTimeInterval(Double(token.expiresIn)),
            accountID: accountID,
            authorizedAt: Date()
        )
    }

    static func refresh(_ credential: OpenRockyOpenAIOAuthCredential) async throws -> OpenRockyOpenAIOAuthCredential {
        let token = try await refreshAccessToken(refreshToken: credential.refreshToken)
        guard let accountID = extractAccountID(from: token.accessToken) else {
            throw OpenAIOAuthError.missingAccountID
        }

        return OpenRockyOpenAIOAuthCredential(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: Date().addingTimeInterval(Double(token.expiresIn)),
            accountID: accountID,
            authorizedAt: credential.authorizedAt
        )
    }

    static func refreshIfNeeded(
        _ credential: OpenRockyOpenAIOAuthCredential,
        leeway: TimeInterval = 60
    ) async throws -> OpenRockyOpenAIOAuthCredential {
        if credential.expiresAt.timeIntervalSinceNow > leeway {
            return credential
        }
        return try await refresh(credential)
    }

    nonisolated static func accountID(fromAccessToken accessToken: String) -> String? {
        extractAccountID(from: accessToken)
    }

    private static func makeAuthorizationFlow(originator: String) throws -> AuthorizationFlow {
        let verifierData = try randomData(count: 32)
        let verifier = base64URLEncoded(verifierData)
        let challenge = base64URLEncoded(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = try randomData(count: 16).map { String(format: "%02x", $0) }.joined()

        var components = URLComponents(string: authorizeURL)
        components?.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "id_token_add_organizations", value: "true"),
            .init(name: "codex_cli_simplified_flow", value: "true"),
            .init(name: "originator", value: originator)
        ]

        guard let url = components?.url else {
            throw OpenAIOAuthError.invalidAuthorizeURL
        }
        return AuthorizationFlow(url: url.absoluteString, verifier: verifier, state: state)
    }

    private static func exchangeAuthorizationCode(code: String, verifier: String) async throws -> OpenAIOAuthTokenResponse {
        guard let url = URL(string: tokenURL) else {
            throw OpenAIOAuthError.invalidTokenURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = URLQueryEncoder.encode([
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIOAuthError.invalidTokenResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw OpenAIOAuthError.tokenExchangeFailed(statusCode: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(OpenAIOAuthTokenResponse.self, from: data)
        guard !decoded.accessToken.isEmpty, !decoded.refreshToken.isEmpty else {
            throw OpenAIOAuthError.invalidTokenResponse
        }
        return decoded
    }

    private static func refreshAccessToken(refreshToken: String) async throws -> OpenAIOAuthTokenResponse {
        guard let url = URL(string: tokenURL) else {
            throw OpenAIOAuthError.invalidTokenURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = URLQueryEncoder.encode([
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIOAuthError.invalidTokenResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw OpenAIOAuthError.tokenExchangeFailed(statusCode: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(OpenAIOAuthTokenResponse.self, from: data)
        guard !decoded.accessToken.isEmpty, !decoded.refreshToken.isEmpty else {
            throw OpenAIOAuthError.invalidTokenResponse
        }
        return decoded
    }

    nonisolated private static func extractAccountID(from accessToken: String) -> String? {
        let segments = accessToken.split(separator: ".")
        guard segments.count == 3 else { return nil }
        guard let payloadData = decodeBase64URL(String(segments[1])),
              let root = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let auth = root[jwtAuthClaimPath] as? [String: Any],
              let accountID = auth["chatgpt_account_id"] as? String,
              !accountID.isEmpty else {
            return nil
        }
        return accountID
    }

    private static func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes { pointer in
            SecRandomCopyBytes(kSecRandomDefault, count, pointer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw OpenAIOAuthError.randomGenerationFailed
        }
        return data
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }

    private struct AuthorizationFlow {
        var url: String
        var verifier: String
        var state: String
    }

    private struct OpenAIOAuthTokenResponse: Decodable {
        var accessToken: String
        var refreshToken: String
        var expiresIn: Int

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    enum OpenAIOAuthError: LocalizedError {
        case invalidAuthorizeURL
        case invalidTokenURL
        case stateMismatch
        case missingAuthorizationCode
        case missingAccountID
        case invalidTokenResponse
        case randomGenerationFailed
        case tokenExchangeFailed(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidAuthorizeURL:
                return "Invalid OpenAI authorize URL."
            case .invalidTokenURL:
                return "Invalid OpenAI token URL."
            case .stateMismatch:
                return "OpenAI OAuth state mismatch."
            case .missingAuthorizationCode:
                return "OpenAI OAuth did not return an authorization code."
            case .missingAccountID:
                return "OpenAI OAuth token is missing account information."
            case .invalidTokenResponse:
                return "OpenAI OAuth returned an invalid token response."
            case .randomGenerationFailed:
                return "Failed to generate secure random OAuth parameters."
            case let .tokenExchangeFailed(statusCode, message):
                return "OpenAI token exchange failed (\(statusCode)): \(message)"
            }
        }
    }
}

private enum URLQueryEncoder {
    static func encode(_ values: [String: String]) -> Data {
        let query = values
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .sorted()
            .joined(separator: "&")
        return Data(query.utf8)
    }

    private static func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

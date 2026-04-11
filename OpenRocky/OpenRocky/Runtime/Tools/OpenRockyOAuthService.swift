//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-03-25
// Copyright (c) 2026 everettjf. All rights reserved.
//

import AuthenticationServices
import UIKit

struct OAuthResult: Sendable {
    let callbackURL: String
    let parameters: [String: String]
}

@MainActor
final class OpenRockyOAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OpenRockyOAuthService()

    /// Start an OAuth flow using ASWebAuthenticationSession.
    /// Opens the auth URL in a system browser sheet, waits for redirect to callbackScheme.
    func authenticate(
        authURL: String,
        callbackScheme: String
    ) async throws -> OAuthResult {
        guard let url = URL(string: authURL) else {
            throw OAuthError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: OAuthError.noCallback)
                    return
                }

                // Parse query parameters from callback URL
                var params: [String: String] = [:]
                if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
                    for item in components.queryItems ?? [] {
                        params[item.name] = item.value ?? ""
                    }
                    // Also check fragment (some OAuth flows use fragment)
                    if let fragment = components.fragment {
                        let fragmentItems = fragment.components(separatedBy: "&")
                        for item in fragmentItems {
                            let parts = item.components(separatedBy: "=")
                            if parts.count == 2 {
                                params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                            }
                        }
                    }
                }

                continuation.resume(returning: OAuthResult(
                    callbackURL: callbackURL.absoluteString,
                    parameters: params
                ))
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return keyWindow
            }
            if let scene = scenes.first {
                return ASPresentationAnchor(windowScene: scene)
            }
            return ASPresentationAnchor(frame: .zero)
        }
    }

    enum OAuthError: Error, LocalizedError {
        case invalidURL
        case noCallback

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid OAuth URL"
            case .noCallback: return "No callback received from OAuth flow"
            }
        }
    }
}

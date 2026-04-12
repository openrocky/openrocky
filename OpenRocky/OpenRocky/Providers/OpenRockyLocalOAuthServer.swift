//
// OpenRocky — Voice-first AI Agent
// https://github.com/openrocky
//
// Developed by everettjf with the assistance of Claude Code and Codex.
// Date: 2026-04-11
// Copyright (c) 2026 everettjf. All rights reserved.
//

import Foundation
import Network

/// A lightweight local HTTP server that listens on 127.0.0.1 for OAuth callbacks.
/// This mirrors how the Codex CLI handles OAuth — by running a temporary local server
/// to receive the authorization code redirect from OpenAI.
actor OpenRockyLocalOAuthServer {
    private var listener: NWListener?
    private var continuation: CheckedContinuation<OAuthCallbackResult, any Error>?
    private let port: UInt16

    struct OAuthCallbackResult: Sendable {
        let code: String
        let state: String
    }

    enum ServerError: LocalizedError {
        case portUnavailable
        case serverFailed(String)
        case invalidRequest
        case missingParameters
        case timeout

        var errorDescription: String? {
            switch self {
            case .portUnavailable:
                return "OAuth callback port is unavailable."
            case .serverFailed(let reason):
                return "OAuth callback server failed: \(reason)"
            case .invalidRequest:
                return "Invalid OAuth callback request."
            case .missingParameters:
                return "OAuth callback missing code or state parameter."
            case .timeout:
                return "OAuth callback timed out."
            }
        }
    }

    init(port: UInt16 = 1455) {
        self.port = port
    }

    /// Start the local server and wait for the OAuth callback.
    /// Returns the authorization code and state from the callback URL.
    func waitForCallback(timeout: TimeInterval = 300) async throws -> OAuthCallbackResult {
        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<OAuthCallbackResult, any Error>) in
            self.continuation = cont
            do {
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
                self.listener = listener

                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .failed(let error):
                        Task { await self.fail(with: .serverFailed(error.localizedDescription)) }
                    case .cancelled:
                        break
                    default:
                        break
                    }
                }

                listener.newConnectionHandler = { [weak self] connection in
                    guard let self else { return }
                    Task { await self.handleConnection(connection) }
                }

                listener.start(queue: .global(qos: .userInitiated))

                // Set up timeout
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    await self?.fail(with: .timeout)
                }
            } catch {
                cont.resume(throwing: ServerError.portUnavailable)
                self.continuation = nil
            }
        }
        return result
    }

    /// Stop the server and clean up resources.
    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self else { return }
            Task { await self.processRequest(data: data, error: error, connection: connection) }
        }
    }

    private func processRequest(data: Data?, error: NWError?, connection: NWConnection) {
        guard let data, let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        // Parse the HTTP request line to get the path and query
        guard let firstLine = requestString.components(separatedBy: "\r\n").first,
              firstLine.hasPrefix("GET ") else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let pathAndQuery = String(parts[1])

        guard pathAndQuery.hasPrefix("/auth/callback") else {
            sendResponse(connection: connection, statusCode: 404, body: "Not Found")
            return
        }

        // Parse query parameters
        guard let components = URLComponents(string: "http://localhost\(pathAndQuery)"),
              let queryItems = components.queryItems else {
            sendResponse(connection: connection, statusCode: 400, body: "Missing parameters")
            fail(with: .missingParameters)
            return
        }

        let params = Dictionary(queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        }, uniquingKeysWith: { _, last in last })

        guard let code = params["code"], !code.isEmpty,
              let state = params["state"], !state.isEmpty else {
            // Check for error response from OAuth provider
            if let errorMsg = params["error"] {
                let description = params["error_description"] ?? errorMsg
                let html = Self.errorHTML(message: description)
                sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html")
                fail(with: .serverFailed("OAuth error: \(description)"))
            } else {
                sendResponse(connection: connection, statusCode: 400, body: "Missing code or state")
                fail(with: .missingParameters)
            }
            return
        }

        // Success — send a nice response page and resolve
        let html = Self.successHTML()
        sendResponse(connection: connection, statusCode: 200, body: html, contentType: "text/html")

        let result = OAuthCallbackResult(code: code, state: state)
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: result)
        }
        stop()
    }

    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "text/plain") {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }

        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType); charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func fail(with error: ServerError) {
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: error)
        }
        stop()
    }

    private static func successHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>Rocky</title>
        <style>
        body { font-family: -apple-system, sans-serif; display: flex; justify-content: center;
               align-items: center; height: 100vh; margin: 0; background: #f5f5f7; }
        .card { text-align: center; padding: 40px; background: white; border-radius: 16px;
                box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
        h1 { font-size: 24px; margin: 0 0 8px; }
        p { color: #666; margin: 0; }
        </style></head>
        <body><div class="card">
        <h1>✅ Signed In</h1>
        <p>You can close this page and return to Rocky.</p>
        </div></body></html>
        """
    }

    private static func errorHTML(message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>Rocky</title>
        <style>
        body { font-family: -apple-system, sans-serif; display: flex; justify-content: center;
               align-items: center; height: 100vh; margin: 0; background: #f5f5f7; }
        .card { text-align: center; padding: 40px; background: white; border-radius: 16px;
                box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
        h1 { font-size: 24px; margin: 0 0 8px; color: #d00; }
        p { color: #666; margin: 0; }
        </style></head>
        <body><div class="card">
        <h1>❌ Sign-In Failed</h1>
        <p>\(escaped)</p>
        </div></body></html>
        """
    }
}

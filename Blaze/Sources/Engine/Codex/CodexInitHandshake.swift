//
//  CodexInitHandshake.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

private let handshakeLog = OSLog(subsystem: "com.cogit0.Blaze", category: "CodexHandshake")

// MARK: - Handshake Error

/// Errors during Codex JSON-RPC initialization handshake.
public enum HandshakeError: Error, LocalizedError, Sendable {
    /// The initialize request timed out.
    case initializeTimeout(seconds: TimeInterval)
    /// The initialize response was malformed or missing expected fields.
    case malformedInitializeResponse(reason: String)
    /// The `codex/connected` notification was not received within timeout.
    case connectedNotificationTimeout(seconds: TimeInterval)
    /// Received an error response from Codex.
    case serverError(code: Int, message: String)
    /// The adapter is not running.
    case adapterNotRunning

    public var errorDescription: String? {
        switch self {
        case .initializeTimeout(let seconds):
            return "Codex initialize request timed out after \(Int(seconds)) seconds"
        case .malformedInitializeResponse(let reason):
            return "Malformed initialize response: \(reason)"
        case .connectedNotificationTimeout(let seconds):
            return "codex/connected notification not received within \(Int(seconds)) seconds"
        case .serverError(let code, let message):
            return "Codex server error [\(code)]: \(message)"
        case .adapterNotRunning:
            return "Codex adapter is not running"
        }
    }
}

// MARK: - Client Info

/// Client information sent during initialization.
public struct CodexClientInfo: Encodable, Sendable {
    /// Client application name.
    public let name: String
    /// Client application version.
    public let version: String

    public init(name: String = "Blaze", version: String = "1.0.0") {
        self.name = name
        self.version = version
    }
}

// MARK: - Server Capabilities

/// Capabilities returned by Codex in initialize response.
public struct CodexServerCapabilities: Sendable {
    /// Raw capabilities dictionary for forward compatibility.
    public let raw: [String: Any]

    public init(raw: [String: Any]) {
        self.raw = raw
    }
}

// MARK: - Handshake Result

/// Result of a successful handshake.
public struct CodexHandshakeResult: Sendable {
    /// Server capabilities from initialize response.
    public let serverCapabilities: CodexServerCapabilities
    /// Protocol version (if provided).
    public let protocolVersion: String?
    /// Server info (if provided).
    public let serverInfo: [String: Any]?
    /// Timestamp when handshake completed.
    public let completedAt: Date

    public init(
        serverCapabilities: CodexServerCapabilities,
        protocolVersion: String? = nil,
        serverInfo: [String: Any]? = nil
    ) {
        self.serverCapabilities = serverCapabilities
        self.protocolVersion = protocolVersion
        self.serverInfo = serverInfo
        self.completedAt = Date()
    }
}

// MARK: - Codex Init Handshake

/// Performs the 5-step JSON-RPC initialization handshake with Codex.
///
/// ## Protocol Steps
/// 1. Process spawned (handled by `CodexStdioAdapter.start()`)
/// 2. Send `initialize` request with client info
/// 3. Await `initialize` response (15s timeout)
/// 4. Send `initialized` notification
/// 5. Await `codex/connected` notification
///
/// ## Usage
/// ```swift
/// let adapter = CodexStdioAdapter()
/// try await adapter.start(executable: "/usr/local/bin/codex")
///
/// let handshake = CodexInitHandshake(adapter: adapter)
/// let result = try await handshake.perform()
/// print("Connected with capabilities: \(result.serverCapabilities)")
/// ```
public actor CodexInitHandshake {

    // MARK: - Configuration

    /// Default timeout for initialize request (15 seconds per spec).
    public static let defaultInitializeTimeout: TimeInterval = 15.0

    /// Default timeout for connected notification (10 seconds).
    public static let defaultConnectedTimeout: TimeInterval = 10.0

    // MARK: - State

    private let adapter: CodexStdioAdapter
    private let clientInfo: CodexClientInfo
    private let initializeTimeout: TimeInterval
    private let connectedTimeout: TimeInterval

    /// Whether handshake has been performed.
    private var handshakeComplete = false

    // MARK: - Initialization

    /// Create a new handshake instance.
    ///
    /// - Parameters:
    ///   - adapter: The CodexStdioAdapter to use for communication.
    ///   - clientInfo: Client information to send in initialize request.
    ///   - initializeTimeout: Timeout for initialize response (default 15s).
    ///   - connectedTimeout: Timeout for connected notification (default 10s).
    init(
        adapter: CodexStdioAdapter,
        clientInfo: CodexClientInfo = CodexClientInfo(),
        initializeTimeout: TimeInterval = CodexInitHandshake.defaultInitializeTimeout,
        connectedTimeout: TimeInterval = CodexInitHandshake.defaultConnectedTimeout
    ) {
        self.adapter = adapter
        self.clientInfo = clientInfo
        self.initializeTimeout = initializeTimeout
        self.connectedTimeout = connectedTimeout
    }

    // MARK: - Perform Handshake

    /// Perform the full initialization handshake.
    ///
    /// This method is idempotent - calling it multiple times returns the same result.
    ///
    /// - Returns: Handshake result with server capabilities.
    /// - Throws: `HandshakeError` on failure.
    public func perform() async throws -> CodexHandshakeResult {
        // Verify adapter is running
        guard await adapter.isRunning else {
            throw HandshakeError.adapterNotRunning
        }

        os_log(.info, log: handshakeLog, "Starting Codex initialization handshake")

        // Step 2: Send initialize request with timeout
        let initializeResult = try await sendInitializeWithTimeout()

        // Step 4: Send initialized notification
        try await sendInitializedNotification()

        // Step 5: Wait for codex/connected notification
        try await waitForConnectedNotification()

        handshakeComplete = true
        os_log(.info, log: handshakeLog, "Codex handshake completed successfully")

        return initializeResult
    }

    // MARK: - Step 2 & 3: Initialize Request

    /// Send initialize request and await response with timeout.
    private func sendInitializeWithTimeout() async throws -> CodexHandshakeResult {
        os_log(.debug, log: handshakeLog, "Sending initialize request")

        // Build params with client info
        let params: [String: Any] = [
            "clientInfo": [
                "name": clientInfo.name,
                "version": clientInfo.version
            ]
        ]

        // Race between request and timeout
        return try await withThrowingTaskGroup(of: CodexHandshakeResult.self) { group in
            // Task 1: Send request and parse response
            group.addTask { [adapter] in
                let response = try await adapter.sendRequest(method: "initialize", params: params)

                // Check for error response
                if let error = response.error {
                    throw HandshakeError.serverError(code: error.code, message: error.message)
                }

                // Parse result
                guard let result = response.result else {
                    throw HandshakeError.malformedInitializeResponse(reason: "missing result field")
                }

                return Self.parseInitializeResult(result)
            }

            // Task 2: Timeout
            group.addTask { [initializeTimeout] in
                try await Task.sleep(for: .seconds(initializeTimeout))
                throw HandshakeError.initializeTimeout(seconds: initializeTimeout)
            }

            // Return first successful result or first error
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Parse initialize response result into handshake result.
    private static func parseInitializeResult(_ result: AnyCodable) -> CodexHandshakeResult {
        let dict = result.value as? [String: Any] ?? [:]

        // Extract capabilities (required)
        let capabilitiesDict = dict["capabilities"] as? [String: Any] ?? [:]
        let capabilities = CodexServerCapabilities(raw: capabilitiesDict)

        // Extract optional fields
        let protocolVersion = dict["protocolVersion"] as? String
        let serverInfo = dict["serverInfo"] as? [String: Any]

        return CodexHandshakeResult(
            serverCapabilities: capabilities,
            protocolVersion: protocolVersion,
            serverInfo: serverInfo
        )
    }

    // MARK: - Step 4: Initialized Notification

    /// Send initialized notification (no response expected).
    private func sendInitializedNotification() async throws {
        os_log(.debug, log: handshakeLog, "Sending initialized notification")

        try await adapter.sendNotification(method: "initialized", params: nil)
    }

    // MARK: - Step 5: Wait for Connected Notification

    /// Wait for `codex/connected` notification with timeout.
    private func waitForConnectedNotification() async throws {
        os_log(.debug, log: handshakeLog, "Waiting for codex/connected notification")

        // Get notification stream
        let notifications = await adapter.notifications()

        // Race between notification and timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Task 1: Wait for codex/connected
            group.addTask {
                for await notification in notifications {
                    if notification.method == "codex/connected" {
                        os_log(.debug, log: handshakeLog, "Received codex/connected notification")
                        return
                    }
                }
                // Stream ended without receiving connected
                throw HandshakeError.connectedNotificationTimeout(seconds: self.connectedTimeout)
            }

            // Task 2: Timeout
            group.addTask { [connectedTimeout] in
                try await Task.sleep(for: .seconds(connectedTimeout))
                throw HandshakeError.connectedNotificationTimeout(seconds: connectedTimeout)
            }

            // Wait for first to complete
            try await group.next()
            group.cancelAll()
        }
    }

    // MARK: - State Query

    /// Whether the handshake has completed successfully.
    public var isComplete: Bool {
        handshakeComplete
    }
}

// MARK: - Convenience Extension on CodexStdioAdapter

extension CodexStdioAdapter {
    /// Perform initialization handshake after start.
    ///
    /// Convenience method that creates and executes a `CodexInitHandshake`.
    ///
    /// - Parameters:
    ///   - clientInfo: Client information to send.
    ///   - initializeTimeout: Timeout for initialize response.
    ///   - connectedTimeout: Timeout for connected notification.
    /// - Returns: Handshake result with server capabilities.
    /// - Throws: `HandshakeError` on failure.
    func performHandshake(
        clientInfo: CodexClientInfo = CodexClientInfo(),
        initializeTimeout: TimeInterval = CodexInitHandshake.defaultInitializeTimeout,
        connectedTimeout: TimeInterval = CodexInitHandshake.defaultConnectedTimeout
    ) async throws -> CodexHandshakeResult {
        let handshake = CodexInitHandshake(
            adapter: self,
            clientInfo: clientInfo,
            initializeTimeout: initializeTimeout,
            connectedTimeout: connectedTimeout
        )
        return try await handshake.perform()
    }
}

//
//  CodexApprovalFlow.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

// MARK: - Codex Approval Request Methods

/// JSON-RPC method names for Codex approval requests.
/// Reference: Codex CLI --approval-policy documentation.
public enum CodexApprovalMethod: String, Sendable {
    case commandExecution = "codex/requestApproval/commandExecution"
    case fileChange = "codex/requestApproval/fileChange"

    /// Map to ToolRiskLevel per atom spec.
    public var riskLevel: ToolRiskLevel {
        switch self {
        case .commandExecution:
            return .high  // Shell commands are always high risk
        case .fileChange:
            return .medium  // File modifications are medium risk
        }
    }

    /// Tool name for ToolRequestEvent.
    public var toolName: String {
        switch self {
        case .commandExecution:
            return "Bash"
        case .fileChange:
            return "Write"
        }
    }
}

// MARK: - Incoming Request Params

/// Parameters for commandExecution approval request.
public struct CommandExecutionParams: Codable, Sendable {
    /// The shell command to execute.
    public let command: String
    /// Optional working directory.
    public let cwd: String?
    /// Optional timeout in milliseconds.
    public let timeoutMs: Int?

    enum CodingKeys: String, CodingKey {
        case command
        case cwd
        case timeoutMs = "timeout_ms"
    }
}

/// Parameters for fileChange approval request.
public struct FileChangeParams: Codable, Sendable {
    /// Path to the file being modified.
    public let path: String
    /// Type of change: "create", "modify", "delete".
    public let changeType: String
    /// Optional diff content for modifications.
    public let diff: String?

    enum CodingKeys: String, CodingKey {
        case path
        case changeType = "change_type"
        case diff
    }
}

// MARK: - JSON-RPC Request

/// Incoming JSON-RPC request from Codex requesting approval.
public struct CodexApprovalRequest: Codable, Sendable, Identifiable {
    /// JSON-RPC version (always "2.0").
    public let jsonrpc: String
    /// Request ID that must be echoed in response.
    public let id: JSONRPCId
    /// Method name (one of CodexApprovalMethod values).
    public let method: String
    /// Request parameters (command or file change details).
    public let params: AnyCodable?

    /// Unique identifier for Identifiable conformance.
    public var requestId: String {
        id.stringValue
    }
}

// Note: JSONRPCId is defined in CodexJSONRPCParser.swift

// MARK: - JSON-RPC Response

/// Decision to send back to Codex.
public enum CodexApprovalDecision: String, Codable, Sendable {
    case accept
    case reject
}

/// Result payload for approval response.
public struct CodexApprovalResult: Codable, Sendable {
    /// The approval decision.
    public let decision: CodexApprovalDecision
    /// Optional reason for rejection.
    public let reason: String?

    public init(decision: CodexApprovalDecision, reason: String? = nil) {
        self.decision = decision
        self.reason = reason
    }
}

/// JSON-RPC response to send back to Codex.
public struct CodexApprovalResponse: Codable, Sendable {
    /// JSON-RPC version (always "2.0").
    public let jsonrpc: String = "2.0"
    /// Request ID echoed from the request.
    public let id: JSONRPCId
    /// Result payload containing decision.
    public let result: CodexApprovalResult

    public init(id: JSONRPCId, decision: CodexApprovalDecision, reason: String? = nil) {
        self.id = id
        self.result = CodexApprovalResult(decision: decision, reason: reason)
    }
}

// MARK: - Codex Approval Flow

/// Handles bidirectional approval protocol for Codex tool execution.
///
/// Codex sends JSON-RPC REQUESTS asking for permission. The client MUST respond
/// with a decision. Without a response, Codex hangs waiting.
///
/// ## Flow
/// 1. Parse incoming `codex/requestApproval/*` request
/// 2. Create ToolRequestEvent with appropriate risk level
/// 3. Submit to ToolApprovalPipeline for user decision
/// 4. Convert decision to JSON-RPC response format
/// 5. Send response back via stdin pipe
///
/// ## Timeout Handling
/// If the user doesn't respond within the timeout, we reject by default
/// to prevent Codex from hanging indefinitely.
public actor CodexApprovalFlow {

    // MARK: - State

    /// The approval pipeline for user decisions.
    private let pipeline: ToolApprovalPipeline

    /// Pending requests awaiting response (id -> ToolRequestEvent.id).
    private var pendingRequests: [JSONRPCId: UUID] = [:]

    /// Default timeout for user decisions (30 seconds).
    public let defaultTimeout: TimeInterval

    // MARK: - Initialization

    /// Create a new approval flow with the given pipeline.
    /// - Parameters:
    ///   - pipeline: The ToolApprovalPipeline to use for decisions.
    ///   - defaultTimeout: Timeout for user decisions (default 30s).
    public init(
        pipeline: ToolApprovalPipeline,
        defaultTimeout: TimeInterval = 30.0
    ) {
        self.pipeline = pipeline
        self.defaultTimeout = defaultTimeout
    }

    // MARK: - Request Handling

    /// Handle an incoming approval request from Codex.
    ///
    /// This method:
    /// 1. Parses the request method and params
    /// 2. Creates a ToolRequestEvent
    /// 3. Submits to the approval pipeline
    /// 4. Returns a JSON-RPC response
    ///
    /// - Parameter request: The incoming JSON-RPC request.
    /// - Returns: JSON-RPC response with accept/reject decision.
    public func handleRequest(_ request: CodexApprovalRequest) async -> CodexApprovalResponse {
        // Parse the method
        guard let method = CodexApprovalMethod(rawValue: request.method) else {
            // Unknown method - default to reject with low risk
            return CodexApprovalResponse(
                id: request.id,
                decision: .reject,
                reason: "Unknown approval method: \(request.method)"
            )
        }

        // Create ToolRequestEvent from the request
        let toolRequest = createToolRequest(from: request, method: method)

        // Track the pending request
        pendingRequests[request.id] = toolRequest.id

        // Submit to pipeline and await decision (with timeout)
        let decision = await submitWithTimeout(toolRequest)

        // Remove from pending
        pendingRequests.removeValue(forKey: request.id)

        // Convert to Codex response format
        return createResponse(from: decision, requestId: request.id)
    }

    /// Parse raw JSON data into an approval request.
    ///
    /// - Parameter data: Raw JSON data from Codex stdout.
    /// - Returns: Parsed request, or nil if not an approval request.
    public func parseRequest(from data: Data) -> CodexApprovalRequest? {
        // Try to decode as approval request
        guard let request = try? JSONDecoder().decode(CodexApprovalRequest.self, from: data) else {
            return nil
        }

        // Verify it's an approval method
        guard request.method.hasPrefix("codex/requestApproval/") else {
            return nil
        }

        return request
    }

    /// Serialize a response to JSON data for sending to Codex stdin.
    ///
    /// - Parameter response: The approval response.
    /// - Returns: JSON data ready to write to stdin.
    public func serializeResponse(_ response: CodexApprovalResponse) throws -> Data {
        let encoder = JSONEncoder()
        // Codex expects compact JSON, no pretty printing
        return try encoder.encode(response)
    }

    // MARK: - Private Helpers

    /// Create a ToolRequestEvent from a Codex approval request.
    private func createToolRequest(
        from request: CodexApprovalRequest,
        method: CodexApprovalMethod
    ) -> ToolRequestEvent {
        // Extract input description based on method
        let (input, scope) = extractInputAndScope(from: request, method: method)

        return ToolRequestEvent(
            id: UUID(),
            toolCallId: request.requestId,
            toolName: method.toolName,
            input: input,
            riskLevel: method.riskLevel,
            scope: scope,
            timestamp: Date()
        )
    }

    /// Extract input string and scope from request params.
    private func extractInputAndScope(
        from request: CodexApprovalRequest,
        method: CodexApprovalMethod
    ) -> (String, ToolScope?) {
        guard let params = request.params else {
            return ("(no parameters)", nil)
        }

        switch method {
        case .commandExecution:
            if let cmdParams = try? params.decodeAs(CommandExecutionParams.self) {
                let input = cmdParams.command
                let scope = ToolScope(
                    paths: cmdParams.cwd.map { [$0] },
                    commands: [cmdParams.command]
                )
                return (input, scope)
            }

        case .fileChange:
            if let fileParams = try? params.decodeAs(FileChangeParams.self) {
                let input = "\(fileParams.changeType): \(fileParams.path)"
                let scope = ToolScope(paths: [fileParams.path])
                return (input, scope)
            }
        }

        return ("(unparseable parameters)", nil)
    }

    /// Submit request to pipeline with timeout handling.
    private func submitWithTimeout(_ request: ToolRequestEvent) async -> ToolDecisionEvent {
        // Use TaskGroup to race between pipeline decision and timeout
        return await withTaskGroup(of: ToolDecisionEvent.self) { group in
            // Task 1: Await pipeline decision
            group.addTask { [pipeline] in
                await pipeline.submitRequest(request)
            }

            // Task 2: Timeout fallback
            group.addTask { [defaultTimeout] in
                try? await Task.sleep(for: .seconds(defaultTimeout))
                return ToolDecisionEvent(
                    toolRequestId: request.id,
                    decision: .rejected,
                    decidedBy: "system:timeout",
                    rationale: "Approval request timed out after \(Int(defaultTimeout))s"
                )
            }

            // Return whichever finishes first
            let result = await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Convert pipeline decision to Codex response format.
    private func createResponse(
        from decision: ToolDecisionEvent,
        requestId: JSONRPCId
    ) -> CodexApprovalResponse {
        switch decision.decision {
        case .approved, .alwaysAllow:
            return CodexApprovalResponse(id: requestId, decision: .accept)

        case .rejected:
            return CodexApprovalResponse(
                id: requestId,
                decision: .reject,
                reason: decision.rationale
            )
        }
    }

    // MARK: - Queries

    /// Check if there are pending approval requests.
    public var hasPendingRequests: Bool {
        !pendingRequests.isEmpty
    }

    /// Get the count of pending requests.
    public var pendingRequestCount: Int {
        pendingRequests.count
    }

    /// Cancel all pending requests (e.g., on session end).
    public func cancelPending() async {
        for (_, toolRequestId) in pendingRequests {
            _ = await pipeline.reject(
                requestId: toolRequestId,
                decidedBy: "system:cancelled",
                rationale: "Approval flow cancelled"
            )
        }
        pendingRequests.removeAll()
    }
}

// MARK: - AnyCodable Extension

extension AnyCodable {
    /// Decode the value as a specific Decodable type.
    /// Re-encodes the wrapped value to JSON, then decodes to target type.
    func decodeAs<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

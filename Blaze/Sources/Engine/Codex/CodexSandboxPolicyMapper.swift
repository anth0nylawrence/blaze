//
//  CodexSandboxPolicyMapper.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation

// MARK: - Codex Sandbox Policy

/// Maps to Codex CLI `--sandbox` flag values.
/// Reference: `codex exec --help` sandbox policy options.
public enum CodexSandboxPolicy: String, Codable, Sendable {
    /// Read-only access - no file modifications allowed
    case readOnly = "read-only"
    /// Can write within project workspace only
    case workspaceWrite = "workspace-write"
    /// Full filesystem access (dangerous)
    case dangerFullAccess = "danger-full-access"

    /// JSON value for CLI/RPC encoding
    public var jsonValue: String { rawValue }
}

// MARK: - Codex Approval Policy

/// Maps to Codex CLI `--approval-policy` flag values.
/// Controls when human approval is requested for tool calls.
public enum CodexApprovalPolicy: String, Codable, Sendable {
    /// Prompt user on each tool request
    case onRequest = "on-request"
    /// Never prompt (auto-approve all)
    case never = "never"

    /// JSON value for CLI/RPC encoding
    public var jsonValue: String { rawValue }
}

// MARK: - Policy Mapper

/// Translates Blaze SecurityTrustMode to Codex sandbox and approval policies.
///
/// ## Mapping Table
/// | Blaze Mode | Codex Sandbox        | Codex Approval |
/// |------------|----------------------|----------------|
/// | sandbox    | readOnly             | never          |
/// | review     | workspaceWrite       | onRequest      |
/// | trusted    | dangerFullAccess     | never          |
/// | yolo       | dangerFullAccess     | never          |
public enum CodexSandboxPolicyMapper {

    // MARK: - Security Mode Mapping

    /// Maps Blaze SecurityTrustMode to Codex sandbox policy.
    ///
    /// - Parameter mode: The Blaze security trust mode
    /// - Returns: Corresponding Codex sandbox policy
    public static func sandboxPolicy(for mode: SecurityTrustMode) -> CodexSandboxPolicy {
        switch mode {
        case .sandbox:
            return .readOnly
        case .review:
            return .workspaceWrite
        case .trusted, .yolo:
            return .dangerFullAccess
        }
    }

    /// Maps Blaze SecurityTrustMode to Codex approval policy.
    ///
    /// - Parameter mode: The Blaze security trust mode
    /// - Returns: Corresponding Codex approval policy
    public static func approvalPolicy(for mode: SecurityTrustMode) -> CodexApprovalPolicy {
        switch mode {
        case .review:
            return .onRequest
        case .sandbox, .trusted, .yolo:
            return .never
        }
    }

    // MARK: - CLI Arguments

    /// Generates CLI arguments for Codex invocation.
    ///
    /// - Parameters:
    ///   - mode: The Blaze security trust mode
    ///   - projectPath: Project root path (required for workspaceWrite)
    /// - Returns: Array of CLI arguments
    public static func cliArguments(
        for mode: SecurityTrustMode,
        projectPath: String? = nil
    ) -> [String] {
        var args: [String] = []

        let sandbox = sandboxPolicy(for: mode)
        args.append("--sandbox")
        args.append(sandbox.rawValue)

        let approval = approvalPolicy(for: mode)
        args.append("--approval-policy")
        args.append(approval.rawValue)

        // workspaceWrite requires writable roots
        if sandbox == .workspaceWrite, let path = projectPath {
            args.append("--writable-roots")
            args.append(path)
        }

        return args
    }

    // MARK: - JSON-RPC Encoding

    /// Encodes policies as JSON dictionary for RPC params.
    ///
    /// - Parameters:
    ///   - mode: The Blaze security trust mode
    ///   - projectPath: Project root path (for writableRoots)
    /// - Returns: Dictionary suitable for JSON encoding
    public static func toJSON(
        for mode: SecurityTrustMode,
        projectPath: String? = nil
    ) -> [String: Any] {
        var result: [String: Any] = [
            "sandboxPolicy": sandboxPolicy(for: mode).jsonValue,
            "approvalPolicy": approvalPolicy(for: mode).jsonValue
        ]

        if sandboxPolicy(for: mode) == .workspaceWrite, let path = projectPath {
            result["writableRoots"] = [path]
        }

        return result
    }
}

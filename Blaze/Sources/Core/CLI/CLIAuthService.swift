//
//  CLIAuthService.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import Foundation
import os.log

// MARK: - Auth Status

/// Authentication status for a CLI tool.
public enum CLIAuthStatus: Sendable, Equatable {
    case unknown
    case checking
    case authenticated
    case notAuthenticated
    case error(String)

    /// Human-readable description for UI.
    public var displayDescription: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .checking:
            return "Checking..."
        case .authenticated:
            return "Authenticated"
        case .notAuthenticated:
            return "Not authenticated"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    /// SF Symbol icon for this status.
    public var icon: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .checking:
            return "arrow.clockwise"
        case .authenticated:
            return "checkmark.circle.fill"
        case .notAuthenticated:
            return "xmark.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    /// Color for the status indicator.
    public var isPositive: Bool {
        switch self {
        case .authenticated:
            return true
        default:
            return false
        }
    }
}

// MARK: - Auth Errors

/// Errors that can occur during CLI authentication.
public enum CLIAuthError: Error, LocalizedError, Sendable {
    case cliNotFound(String)
    case authFailed(String)
    case timeout
    case userCancelled
    case processFailure(exitCode: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .cliNotFound(let cli):
            return "\(cli) CLI not found. Please install it first."
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .timeout:
            return "Authentication timed out. Please try again."
        case .userCancelled:
            return "Authentication was cancelled."
        case .processFailure(let exitCode, let output):
            return "Command failed (exit \(exitCode)): \(output)"
        }
    }
}

// MARK: - CLIAuthService

/// Thread-safe service for CLI authentication operations.
///
/// Handles login/logout flows for CLI tools that require OAuth or API key authentication.
/// Uses Swift actor isolation for safe concurrent access.
///
/// **Usage:**
/// ```swift
/// let service = CLIAuthService.shared
/// try await service.loginCodex()
/// let status = await service.checkCodexAuth()
/// ```
public actor CLIAuthService {

    // MARK: - Singleton

    /// Shared singleton instance.
    public static let shared = CLIAuthService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.cogit0.Blaze", category: "CLIAuthService")

    /// Environment variables for subprocess execution.
    private var environment: [String: String]

    /// Timeout for auth commands (2 minutes for OAuth flow).
    private let authTimeout: TimeInterval = 120

    /// Cached auth status.
    private var codexAuthStatus: CLIAuthStatus = .unknown

    // MARK: - Initialization

    public init() {
        // Inherit environment and ensure PATH includes common locations
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "\(NSHomeDirectory())/.nvm/current/bin",
            "\(NSHomeDirectory())/.npm-global/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        self.environment = env
    }

    // MARK: - Codex Authentication

    /// Initiates Codex CLI login flow.
    ///
    /// Runs `codex login` which:
    /// 1. Starts a local server on port 1455
    /// 2. Opens browser to OpenAI OAuth page
    /// 3. Waits for user to approve and redirect back
    /// 4. Saves fresh tokens to ~/.codex/auth.json
    ///
    /// - Throws: `CLIAuthError` if login fails.
    public func loginCodex() async throws {
        logger.info("Starting Codex login flow")

        // Verify codex CLI is available
        let whichResult = await runCommand("/usr/bin/which", arguments: ["codex"])
        guard whichResult.exitCode == 0, !whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Codex CLI not found")
            throw CLIAuthError.cliNotFound("Codex")
        }

        let codexPath = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Found codex at: \(codexPath)")

        // Run codex login
        let result = await runCommand(codexPath, arguments: ["login"], timeout: authTimeout)

        if result.exitCode != 0 {
            let errorOutput = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.error("Codex login failed: \(errorOutput)")
            throw CLIAuthError.processFailure(exitCode: result.exitCode, output: errorOutput)
        }

        logger.info("Codex login completed successfully")
        codexAuthStatus = .authenticated
    }

    /// Logs out of Codex CLI.
    ///
    /// Runs `codex logout` to clear stored credentials.
    ///
    /// - Throws: `CLIAuthError` if logout fails.
    public func logoutCodex() async throws {
        logger.info("Starting Codex logout")

        let whichResult = await runCommand("/usr/bin/which", arguments: ["codex"])
        guard whichResult.exitCode == 0, !whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Codex CLI not found")
            throw CLIAuthError.cliNotFound("Codex")
        }

        let codexPath = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        let result = await runCommand(codexPath, arguments: ["logout"])

        if result.exitCode != 0 {
            let errorOutput = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.error("Codex logout failed: \(errorOutput)")
            throw CLIAuthError.processFailure(exitCode: result.exitCode, output: errorOutput)
        }

        logger.info("Codex logout completed")
        codexAuthStatus = .notAuthenticated
    }

    /// Checks if Codex CLI is authenticated.
    ///
    /// Checks for existence of auth token file at ~/.codex/auth.json.
    ///
    /// - Returns: Current authentication status.
    public func checkCodexAuth() async -> CLIAuthStatus {
        logger.debug("Checking Codex auth status")

        let authFilePath = "\(NSHomeDirectory())/.codex/auth.json"
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: authFilePath) {
            // File exists - try to validate it has content
            if let data = fileManager.contents(atPath: authFilePath),
               data.count > 2 { // More than just "{}"
                codexAuthStatus = .authenticated
                logger.debug("Codex auth file found and appears valid")
            } else {
                codexAuthStatus = .notAuthenticated
                logger.debug("Codex auth file exists but appears empty/invalid")
            }
        } else {
            codexAuthStatus = .notAuthenticated
            logger.debug("Codex auth file not found")
        }

        return codexAuthStatus
    }

    /// Returns the cached auth status without re-checking.
    public func getCachedCodexAuthStatus() -> CLIAuthStatus {
        return codexAuthStatus
    }

    // MARK: - Private Helpers

    private struct CommandResult {
        let exitCode: Int32
        let output: String
    }

    private func runCommand(
        _ command: String,
        arguments: [String],
        timeout: TimeInterval = 30
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            // Timeout handling
            let timeoutTask = DispatchWorkItem { [weak process] in
                process?.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask)

            do {
                try process.run()
                process.waitUntilExit()
                timeoutTask.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                continuation.resume(returning: CommandResult(
                    exitCode: process.terminationStatus,
                    output: output
                ))
            } catch {
                timeoutTask.cancel()
                continuation.resume(returning: CommandResult(
                    exitCode: -1,
                    output: error.localizedDescription
                ))
            }
        }
    }
}

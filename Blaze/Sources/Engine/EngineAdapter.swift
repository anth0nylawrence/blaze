import Foundation

// MARK: - Engine Adapter Protocol

/// Protocol for CLI engine adapters. Each supported CLI (Claude, Gemini, Codex)
/// implements this protocol to provide a unified interface.
@MainActor
protocol EngineAdapter: AnyObject, Sendable {
    /// The type of engine this adapter supports
    var engineType: EngineType { get }

    /// Check if the CLI is installed and accessible
    func validateInstallation() async throws -> CLIInfo

    /// Start a new turn with the given prompt
    func startTurn(prompt: String, context: TurnContext) async throws -> AsyncStream<NormalizedEvent>

    /// Cancel the current turn
    func cancelTurn() async

    /// Check if the engine supports a specific feature
    func supports(feature: EngineFeature) -> Bool
}

/// Information about the installed CLI
struct CLIInfo: Sendable {
    let version: String
    let path: String
    let capabilities: Set<EngineFeature>
}

/// Context for a conversation turn
struct TurnContext: Sendable {
    let sessionId: UUID
    let projectPath: String?
    let allowedTools: Set<String>?
    let trustMode: TrustMode
    let systemPrompt: String?
    let previousMessages: [Message]

    /// Enable stdin mode for bidirectional communication (tool prompts)
    /// When true, uses PTY runner and --input-format stream-json
    let enableStdin: Bool

    init(
        sessionId: UUID,
        projectPath: String? = nil,
        allowedTools: Set<String>? = nil,
        trustMode: TrustMode = .review,
        systemPrompt: String? = nil,
        previousMessages: [Message] = [],
        enableStdin: Bool = false
    ) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.allowedTools = allowedTools
        self.trustMode = trustMode
        self.systemPrompt = systemPrompt
        self.previousMessages = previousMessages
        self.enableStdin = enableStdin
    }
}

/// Features that engines may or may not support
enum EngineFeature: String, Sendable, CaseIterable {
    case streaming           // Real-time token streaming
    case toolUse             // Tool/function calling
    case sessionPersistence  // Native session resume
    case multiModal          // Image/file input
    case mcpSupport          // MCP server integration
    case sandboxMode         // Built-in sandbox execution
    case contextCompaction   // Automatic context management
}

// MARK: - Engine Error

enum EngineError: Error, LocalizedError {
    case cliNotFound(EngineType)
    case cliVersionUnsupported(version: String, minimum: String)
    case authenticationRequired
    case processSpawnFailed(underlying: Error)
    case parsingError(line: String, underlying: Error)
    case timeout(seconds: TimeInterval)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .cliNotFound(let type):
            return "\(type.rawValue) CLI not found. Please install it first."
        case .cliVersionUnsupported(let version, let minimum):
            return "CLI version \(version) is not supported. Minimum: \(minimum)"
        case .authenticationRequired:
            return "Authentication required. Please log in via the CLI."
        case .processSpawnFailed(let underlying):
            return "Failed to start CLI process: \(underlying.localizedDescription)"
        case .parsingError(let line, let underlying):
            return "Failed to parse output: \(underlying.localizedDescription)\nLine: \(line)"
        case .timeout(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        case .cancelled:
            return "Operation was cancelled"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Engine Manager

/// Manages available engine adapters and their lifecycle.
///
/// **Session Isolation:**
/// Each session gets its own adapter instance to prevent PTY/process bleeding.
/// Use `adapter(for:sessionId:)` to get session-specific adapters.
/// The original `adapter(for:)` returns the template adapter for validation.
@MainActor
final class EngineManager: ObservableObject {
    @Published private(set) var availableEngines: [EngineType: CLIInfo] = [:]
    @Published private(set) var isValidating: Bool = false

    /// Template adapters used for registration and validation
    private var templateAdapters: [EngineType: any EngineAdapter] = [:]

    /// Per-session adapter instances: [sessionId: [engineType: adapter]]
    /// Each session gets its own isolated adapter to prevent PTY bleeding
    private var sessionAdapters: [UUID: [EngineType: any EngineAdapter]] = [:]

    /// Factory closures for creating new adapter instances
    private var adapterFactories: [EngineType: () -> any EngineAdapter] = [:]

    /// Register an adapter for an engine type
    /// This stores both the template adapter and a factory to create new instances
    func register(adapter: any EngineAdapter) {
        let type = adapter.engineType
        templateAdapters[type] = adapter

        // Create factory based on engine type
        switch type {
        case .claude:
            adapterFactories[type] = { ClaudeCodeAdapter() }
        case .gemini:
            adapterFactories[type] = { GeminiCliAdapter() }
        case .codex:
            adapterFactories[type] = { CodexCliAdapter() }
        }
    }

    /// Get the template adapter for a specific engine type (for validation, not for turns)
    func adapter(for type: EngineType) -> (any EngineAdapter)? {
        templateAdapters[type]
    }

    /// Get or create a session-specific adapter instance.
    /// Each session gets its own adapter to prevent PTY/process bleeding.
    ///
    /// - Parameters:
    ///   - type: The engine type (e.g., .claude)
    ///   - sessionId: The session UUID
    /// - Returns: An adapter instance dedicated to this session
    func adapter(for type: EngineType, sessionId: UUID) -> (any EngineAdapter)? {
        // Check if we already have an adapter for this session
        if let existing = sessionAdapters[sessionId]?[type] {
            return existing
        }

        // Create new adapter from factory
        guard let factory = adapterFactories[type] else {
            return nil
        }

        let newAdapter = factory()

        // Store in session registry
        if sessionAdapters[sessionId] == nil {
            sessionAdapters[sessionId] = [:]
        }
        sessionAdapters[sessionId]?[type] = newAdapter

        return newAdapter
    }

    /// Clean up adapters for a session when it ends
    /// This cancels any running turns and releases resources
    func cleanupSession(_ sessionId: UUID) async {
        guard let adaptersForSession = sessionAdapters[sessionId] else {
            return
        }

        // Cancel all adapters for this session
        for (_, adapter) in adaptersForSession {
            await adapter.cancelTurn()
        }

        // Remove from registry
        sessionAdapters.removeValue(forKey: sessionId)
    }

    /// Check if a session has an active adapter
    func hasAdapter(for sessionId: UUID) -> Bool {
        sessionAdapters[sessionId] != nil && !(sessionAdapters[sessionId]?.isEmpty ?? true)
    }

    /// Validate all registered engine installations
    func validateAll() async {
        isValidating = true
        defer { isValidating = false }

        var results: [EngineType: CLIInfo] = [:]

        await withTaskGroup(of: (EngineType, CLIInfo?).self) { group in
            for (type, adapter) in templateAdapters {
                group.addTask {
                    do {
                        let info = try await adapter.validateInstallation()
                        return (type, info)
                    } catch {
                        return (type, nil)
                    }
                }
            }

            for await (type, info) in group {
                if let info {
                    results[type] = info
                }
            }
        }

        availableEngines = results
    }
}

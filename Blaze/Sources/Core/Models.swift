import Foundation

// MARK: - Session

/// Represents a conversation session with an AI engine.
///
/// **Phase 2 System Contract:**
/// - `originalProjectPath`: Canonical repo root (used for project grouping)
/// - `worktreePath`: Working directory for CLI (`{repo}/.blaze-worktrees/<sessionId>/`)
/// - `branchName`: Git branch for this session (`blaze-session-<short-uuid>`)
/// - `status`: Session lifecycle status
/// - `trustMode`: Tool approval mode
struct Session: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var state: SessionState

    // MARK: - Legacy Field (Phase 1)
    /// Legacy project path - use `originalProjectPath` for new sessions
    var projectPath: String?

    // MARK: - Phase 2 Fields
    /// Canonical repo root path (used for project grouping in sidebar)
    var originalProjectPath: String?

    /// Worktree directory path: `{repo}/.blaze-worktrees/<sessionId>/`
    /// This is where the CLI runs and files are modified
    var worktreePath: String?

    /// Git branch name for this session: `blaze-session-<short-uuid>`
    var branchName: String?

    /// Session lifecycle status per Phase 2 spec
    var status: SessionStatus = .ready

    /// Tool approval mode per Phase 2 System Contract
    var trustMode: TrustMode = .prompt

    /// Associated repo ID (foreign key to repos table)
    var repoId: UUID?

    /// Path to NDJSON event log file
    var ndjsonLogPath: String?

    // MARK: - E005: Multi-CLI Support Fields
    /// AI provider for this session (anthropic, openai, google, community).
    /// Default: anthropic (for backward compatibility).
    var provider: AIProvider = .anthropic

    // MARK: - E005-F002: Unread Count (for sidebar badge)
    /// Number of unread messages in this session.
    /// Used by CountBadge in SessionRow. Defaults to 0.
    var unreadCount: Int = 0

    /// Model ID for this session (e.g., "sonnet").
    /// Must match CLI --model flag value.
    var modelId: String = "sonnet"

    /// Reasoning effort level for OpenAI o-series models.
    /// Only applicable when provider == .openai.
    var reasoningEffort: ReasoningEffort = .medium

    // MARK: - Existing Fields
    var engineType: EngineType
    var messages: [Message]
    var metadata: SessionMetadata

    // MARK: - Initializers

    /// Create a new Phase 2 session with worktree support
    init(
        id: UUID = UUID(),
        name: String,
        originalProjectPath: String? = nil,
        worktreePath: String? = nil,
        branchName: String? = nil,
        status: SessionStatus = .ready,
        trustMode: TrustMode = .prompt,
        engineType: EngineType = .claude,
        provider: AIProvider = .anthropic,
        modelId: String = "",
        reasoningEffort: ReasoningEffort = .medium
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.state = .idle
        self.projectPath = originalProjectPath // Legacy compat
        self.originalProjectPath = originalProjectPath
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.status = status
        self.trustMode = trustMode
        self.engineType = engineType
        self.provider = provider
        self.modelId = modelId
        self.reasoningEffort = reasoningEffort
        self.messages = []
        self.metadata = SessionMetadata()
    }

    /// Legacy initializer for backward compatibility
    init(
        id: UUID = UUID(),
        name: String,
        projectPath: String? = nil,
        engineType: EngineType = .claude
    ) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.state = .idle
        self.projectPath = projectPath
        self.originalProjectPath = projectPath // Use as originalProjectPath too
        self.worktreePath = nil
        self.branchName = nil
        self.status = .ready
        self.trustMode = .prompt
        self.engineType = engineType
        // Set provider based on engineType for correct adapter routing
        self.provider = switch engineType {
        case .claude: .anthropic
        case .codex: .openai
        case .gemini: .google
        }
        // Set default model based on provider
        self.modelId = switch engineType {
        case .claude: "sonnet"
        case .codex: "gpt-5.2-codex"
        case .gemini: "gemini-3.0-pro"
        }
        self.reasoningEffort = .medium
        self.messages = []
        self.metadata = SessionMetadata()
    }

    // MARK: - Computed Properties

    /// The effective working directory for the CLI.
    /// Returns worktreePath if available, falls back to originalProjectPath or projectPath.
    var effectiveWorkingDirectory: String? {
        worktreePath ?? originalProjectPath ?? projectPath
    }

    /// Whether this is a Phase 2 session with worktree support
    var hasWorktree: Bool {
        worktreePath != nil && branchName != nil
    }

    /// Whether this is a legacy/archived session
    var isArchived: Bool {
        status == .archived
    }

    /// Short UUID for branch naming (first 8 characters)
    var shortId: String {
        String(id.uuidString.prefix(8).lowercased())
    }

    // MARK: - E005: Model Resolution

    /// Resolves the AIModel from the registry using modelId.
    /// Returns nil if modelId is not in the registry.
    var model: AIModel? {
        AIModelRegistry.model(byId: modelId)
    }

    /// CLI flags for the current model.
    /// Returns empty array if model is not found.
    var modelCliFlags: [String] {
        model?.cliFlags ?? []
    }
}

// MARK: - Session Status (Phase 2)

/// Session lifecycle states per Phase 2 System Contract.
///
/// **Transitions:**
/// - `creating` -> `ready` (worktree created successfully)
/// - `creating` -> `errored` (worktree creation failed)
/// - `ready` -> `running` (CLI spawned)
/// - `running` -> `stopped` (CLI exited or user stopped)
/// - `running` -> `errored` (CLI crashed)
/// - `stopped` -> `running` (resumed)
/// - `*` -> `archived` (session archived/migrated)
public enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case creating   // Worktree being created
    case ready      // Ready to start (worktree exists)
    case running    // Claude CLI active
    case stopped    // Paused/stopped
    case errored    // Failed state
    case archived   // Phase 1 legacy session (read-only)

    public var displayName: String {
        switch self {
        case .creating: return "Creating"
        case .ready: return "Ready"
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .errored: return "Error"
        case .archived: return "Archived"
        }
    }

    public var icon: String {
        switch self {
        case .creating: return "gear"
        case .ready: return "checkmark.circle"
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle"
        case .errored: return "exclamationmark.triangle"
        case .archived: return "archivebox"
        }
    }

    /// Whether the session can be started/resumed
    public var canStart: Bool {
        self == .ready || self == .stopped
    }

    /// Whether the session is active (running or has activity)
    public var isActive: Bool {
        self == .running
    }
}

/// Session lifecycle states (from session-state-machine.md spec)
enum SessionState: String, Codable {
    case idle           // No active processing
    case preparing      // Setting up context
    case streaming      // Receiving response
    case toolPending    // Waiting for tool approval
    case toolExecuting  // Tool running
    case paused         // User paused
    case error          // Recoverable error
    case terminated     // Session ended
}

/// Additional session metadata
struct SessionMetadata: Codable {
    var totalTokens: Int = 0
    var totalCost: Decimal = 0
    var turnCount: Int = 0
    var lastError: String?
}

// MARK: - Message

/// A single message in the conversation
struct Message: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    var thinking: String?
    let timestamp: Date
    var toolCalls: [ToolCall]
    var attachments: [Attachment]

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        thinking: String? = nil,
        toolCalls: [ToolCall] = [],
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.timestamp = Date()
        self.toolCalls = toolCalls
        self.attachments = attachments
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

// MARK: - Tool Call

/// Represents a tool execution
struct ToolCall: Identifiable, Codable {
    let id: UUID
    let name: String
    var input: String
    var output: String?
    var status: ToolCallStatus
    let startedAt: Date
    var completedAt: Date?
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }

    init(
        id: UUID = UUID(),
        name: String,
        input: String
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.status = .pending
        self.startedAt = Date()
    }
}

enum ToolCallStatus: String, Codable {
    case pending
    case approved
    case rejected
    case running
    case succeeded
    case failed
    case cancelled
}

// MARK: - Attachment

/// File or image attachment
struct Attachment: Identifiable, Codable {
    let id: UUID
    let type: AttachmentType
    let path: String
    let name: String
    let size: Int64

    init(type: AttachmentType, path: String, name: String, size: Int64) {
        self.id = UUID()
        self.type = type
        self.path = path
        self.name = name
        self.size = size
    }
}

enum AttachmentType: String, Codable {
    case file
    case image
    case directory
}

// MARK: - Engine

/// Supported AI engine types
public enum EngineType: String, Codable, CaseIterable, Sendable {
    case claude = "Claude Code"
    case gemini = "Gemini CLI"
    case codex = "Codex CLI"

    var cliCommand: String {
        switch self {
        case .claude: return "claude"
        case .gemini: return "gemini"
        case .codex: return "codex"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "brain"
        case .gemini: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Maps EngineType to AIProvider for session creation.
    /// This is the reverse of AIProvider.engineType.
    var aiProvider: AIProvider {
        switch self {
        case .claude: return .anthropic
        case .gemini: return .google
        case .codex: return .openai
        }
    }
}

// MARK: - Diff

/// Represents a file diff produced by a tool
struct FileDiff: Identifiable, Codable {
    let id: UUID
    let filePath: String
    let hunks: [DiffHunk]
    var decision: DiffDecision
    let stats: DiffStats

    init(filePath: String, hunks: [DiffHunk]) {
        self.id = UUID()
        self.filePath = filePath
        self.hunks = hunks
        self.decision = .pending
        self.stats = DiffStats(
            additions: hunks.flatMap(\.lines).filter { $0.type == .addition }.count,
            deletions: hunks.flatMap(\.lines).filter { $0.type == .deletion }.count
        )
    }
}

public struct DiffHunk: Codable, Sendable {
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let lines: [DiffLine]

    public init(oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, lines: [DiffLine]) {
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }
}

public struct DiffLine: Codable, Sendable {
    public let type: DiffLineType
    public let content: String
    public let oldLineNumber: Int?
    public let newLineNumber: Int?

    public init(type: DiffLineType, content: String, oldLineNumber: Int?, newLineNumber: Int?) {
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

public enum DiffLineType: String, Codable, Sendable {
    case context
    case addition
    case deletion
}

enum DiffDecision: String, Codable {
    case pending
    case accepted
    case rejected
    case modified
}

struct DiffStats: Codable {
    let additions: Int
    let deletions: Int

    var total: Int { additions + deletions }
}

// MARK: - Policy

/// Trust mode for tool execution per Phase 2 System Contract.
///
/// **Ordering:** LockedDown < Prompt < Allowlisted < Unrestricted
///
/// Migrations:
/// - Old "review" -> Prompt
/// - Old "trusted" -> Unrestricted
/// - Old "sandbox" -> LockedDown
public enum TrustMode: String, Codable, CaseIterable, Sendable {
    case lockedDown = "locked_down"    // Read-only, safe tools only
    case prompt = "prompt"             // All risky tools gated (default)
    case allowlisted = "allowlisted"   // Auto-approve via allowlist rules
    case unrestricted = "unrestricted" // Minimal gates, auto-approve most

    // Legacy aliases for backwards compatibility
    public static let sandbox = TrustMode.lockedDown
    public static let review = TrustMode.prompt
    public static let trusted = TrustMode.unrestricted

    public var displayName: String {
        switch self {
        case .lockedDown: return "Locked Down"
        case .prompt: return "Prompt"
        case .allowlisted: return "Allowlisted"
        case .unrestricted: return "Unrestricted"
        }
    }

    public var description: String {
        switch self {
        case .lockedDown: return "Read-only, safe tools only"
        case .prompt: return "Risky tools require approval"
        case .allowlisted: return "Auto-approve via allowlist rules"
        case .unrestricted: return "Minimal approval gates"
        }
    }

    /// Risk threshold for auto-approval
    public var autoApproveThreshold: ToolRiskLevel? {
        switch self {
        case .lockedDown: return .low       // Only auto-approve low risk
        case .prompt: return nil            // No auto-approval
        case .allowlisted: return nil       // Depends on allowlist rules
        case .unrestricted: return .medium  // Auto-approve up to medium
        }
    }

    /// Whether to auto-reject above threshold
    public var autoRejectAboveThreshold: Bool {
        switch self {
        case .lockedDown: return true   // Auto-reject medium/high
        case .prompt: return false      // Wait for user
        case .allowlisted: return false // Check allowlist first
        case .unrestricted: return false // Wait for user on high-risk
        }
    }

    /// Migration from legacy enum values
    public init(fromLegacy: String) {
        switch fromLegacy.lowercased() {
        case "sandbox": self = .lockedDown
        case "review": self = .prompt
        case "trusted": self = .unrestricted
        case "locked_down", "lockeddown": self = .lockedDown
        case "prompt": self = .prompt
        case "allowlisted": self = .allowlisted
        case "unrestricted": self = .unrestricted
        default: self = .prompt  // Default to most restrictive safe option
        }
    }

    /// Custom decoding to handle migration from old format
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Try standard raw value first
        if let mode = TrustMode(rawValue: rawValue) {
            self = mode
        } else {
            // Fall back to legacy migration
            self = TrustMode(fromLegacy: rawValue)
        }
    }

    /// Order for comparison (lower = more restrictive)
    public var order: Int {
        switch self {
        case .lockedDown: return 0
        case .prompt: return 1
        case .allowlisted: return 2
        case .unrestricted: return 3
        }
    }

    /// Check if this mode is at least as permissive as another
    public func isAtLeastAsPermissive(as other: TrustMode) -> Bool {
        self.order >= other.order
    }

    /// Check if this mode is more restrictive than another
    public func isMoreRestrictive(than other: TrustMode) -> Bool {
        self.order < other.order
    }
}

// MARK: - Reasoning Effort (OpenAI o-series models)

/// Reasoning effort level for OpenAI o-series models.
///
/// Controls how much "thinking time" the model spends on a problem.
/// Higher effort = more thorough reasoning but more tokens/latency.
///
/// **Codex CLI:** Maps to `model_reasoning_effort` config.
public enum ReasoningEffort: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case extraHigh = "extra_high"

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .extraHigh: return "Extra High"
        }
    }

    public var description: String {
        switch self {
        case .low: return "Quick responses, less reasoning"
        case .medium: return "Balanced reasoning (default)"
        case .high: return "Deep reasoning, more thorough"
        case .extraHigh: return "Maximum reasoning, highest quality"
        }
    }

    /// Icon for UI display
    public var icon: String {
        switch self {
        case .low: return "hare"
        case .medium: return "scale.3d"
        case .high: return "brain.head.profile"
        case .extraHigh: return "flame.fill"
        }
    }
}

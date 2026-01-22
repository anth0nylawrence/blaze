import Foundation

// MARK: - Hook Timeline Event

/// Represents a hook execution event for Gantt-style timeline visualization.
/// Supports hierarchical nesting (session > turn > tool > file).
public struct HookTimelineEvent: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let category: HookTimelineCategory
    public let startTime: Date
    public var endTime: Date?
    public let depth: Int
    public var children: [HookTimelineEvent]
    public var status: HookTimelineStatus

    // MARK: - Computed Properties

    /// Duration in seconds if endTime exists
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    /// Whether the event is still active (running or pending)
    public var isActive: Bool {
        status == .running || status == .pending
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        category: HookTimelineCategory,
        startTime: Date = Date(),
        endTime: Date? = nil,
        depth: Int = 0,
        children: [HookTimelineEvent] = [],
        status: HookTimelineStatus = .pending
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.depth = depth
        self.children = children
        self.status = status
    }

    // MARK: - Factory Methods

    /// Create a timeline event from a HookExecution
    public static func from(execution: HookExecution, hook: Hook) -> HookTimelineEvent {
        let category = HookTimelineCategory.from(eventType: hook.eventType)
        let status: HookTimelineStatus

        if execution.completedAt != nil {
            if let success = execution.success {
                status = success ? .completed : .failed
            } else {
                status = .completed
            }
        } else {
            status = .running
        }

        return HookTimelineEvent(
            id: execution.id,
            name: hook.name,
            category: category,
            startTime: execution.startedAt,
            endTime: execution.completedAt,
            depth: 0,
            children: [],
            status: status
        )
    }

    /// Create a timeline event from a HookExecutionResult
    public static func from(result: HookExecutionResult) -> HookTimelineEvent {
        let status: HookTimelineStatus
        if result.cancelled {
            status = .cancelled
        } else if result.success {
            status = .completed
        } else {
            status = .failed
        }

        return HookTimelineEvent(
            id: result.hookId ?? UUID(),
            name: result.hookName ?? "Unknown Hook",
            category: .tool, // Default; caller should override if known
            startTime: result.startedAt,
            endTime: result.completedAt,
            depth: 0,
            children: [],
            status: status
        )
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Equatable

    public static func == (lhs: HookTimelineEvent, rhs: HookTimelineEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.category == rhs.category &&
        lhs.startTime == rhs.startTime &&
        lhs.endTime == rhs.endTime &&
        lhs.depth == rhs.depth &&
        lhs.children == rhs.children &&
        lhs.status == rhs.status
    }
}

// MARK: - Hook Timeline Category

/// Category of hook event, mapped to timeline colors
public enum HookTimelineCategory: String, CaseIterable, Codable, Sendable {
    case session  // blue
    case turn     // purple
    case tool     // orange
    case file     // green
    case git      // cyan

    /// Infer category from HookEventType
    public static func from(eventType: HookEventType) -> HookTimelineCategory {
        switch eventType {
        case .sessionStart, .sessionEnd:
            return .session
        case .turnStart, .turnEnd:
            return .turn
        case .preToolCall, .postToolCall, .toolApproved, .toolRejected:
            return .tool
        case .preFileWrite, .postFileWrite, .preFileDelete, .postFileDelete:
            return .file
        case .preCommit, .postCommit:
            return .git
        }
    }

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .session: return "Session"
        case .turn: return "Turn"
        case .tool: return "Tool"
        case .file: return "File"
        case .git: return "Git"
        }
    }
}

// MARK: - Hook Timeline Status

/// Status of a hook execution
public enum HookTimelineStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

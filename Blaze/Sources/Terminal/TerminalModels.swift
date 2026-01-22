import Foundation

// MARK: - Terminal Models (E001-F006-S001-T004-A001)

/// Represents a terminal tab in the UI.
///
/// **Phase 2 System Contract:**
/// - User terminals: Full PTY with interactive shell
/// - Claude terminals: Output display only (read-only)
/// - Scrollback: 10K line cap, truncate oldest
public struct TerminalTab: Identifiable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let kind: TerminalKind
    public var title: String
    public let createdAt: Date
    public var isActive: Bool
    public var isClosed: Bool
    public var closedAt: Date?

    /// Configuration for this terminal
    public let configuration: TerminalTabConfiguration

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        kind: TerminalKind,
        title: String? = nil,
        createdAt: Date = Date(),
        isActive: Bool = false,
        isClosed: Bool = false,
        closedAt: Date? = nil,
        configuration: TerminalTabConfiguration = .default
    ) {
        self.id = id
        self.sessionId = sessionId
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.createdAt = createdAt
        self.isActive = isActive
        self.isClosed = isClosed
        self.closedAt = closedAt
        self.configuration = configuration
    }
}

// MARK: - TerminalKind

/// Type of terminal tab
public enum TerminalKind: String, Sendable, Codable {
    case user = "user"
    case claude = "claude"

    public var defaultTitle: String {
        switch self {
        case .user: return "Terminal"
        case .claude: return "Claude Output"
        }
    }

    public var icon: String {
        switch self {
        case .user: return "terminal"
        case .claude: return "brain"
        }
    }

    public var isInteractive: Bool {
        switch self {
        case .user: return true
        case .claude: return false
        }
    }
}

// MARK: - TerminalTabConfiguration

/// Configuration for a terminal tab
public struct TerminalTabConfiguration: Sendable {
    /// Maximum scrollback lines
    public let scrollbackLimit: Int

    /// Initial terminal size
    public let initialSize: TerminalSize

    /// Shell configuration (for user terminals)
    public let shellConfiguration: ShellConfiguration?

    public init(
        scrollbackLimit: Int = 10_000,
        initialSize: TerminalSize = .standard,
        shellConfiguration: ShellConfiguration? = nil
    ) {
        self.scrollbackLimit = scrollbackLimit
        self.initialSize = initialSize
        self.shellConfiguration = shellConfiguration
    }

    public static let `default` = TerminalTabConfiguration()

    public static let claudeTerminal = TerminalTabConfiguration(
        scrollbackLimit: 10_000,
        initialSize: .standard,
        shellConfiguration: nil
    )
}

// MARK: - TerminalProcess

/// Represents a running terminal process (user terminals only)
public struct TerminalProcess: Identifiable, Sendable {
    public let id: UUID
    public let tabId: UUID
    public let pid: Int32
    public let command: String
    public let startedAt: Date
    public var exitCode: Int32?
    public var exitedAt: Date?

    public var isRunning: Bool {
        exitCode == nil
    }

    public var duration: TimeInterval? {
        guard let ended = exitedAt else { return nil }
        return ended.timeIntervalSince(startedAt)
    }

    public init(
        id: UUID = UUID(),
        tabId: UUID,
        pid: Int32,
        command: String,
        startedAt: Date = Date(),
        exitCode: Int32? = nil,
        exitedAt: Date? = nil
    ) {
        self.id = id
        self.tabId = tabId
        self.pid = pid
        self.command = command
        self.startedAt = startedAt
        self.exitCode = exitCode
        self.exitedAt = exitedAt
    }
}

// MARK: - TerminalOutputEvent

/// A single output event from a terminal
public struct TerminalOutputEvent: Identifiable, Sendable {
    public let id: UUID
    public let tabId: UUID
    public let sequence: Int
    public let timestamp: Date
    public let stream: OutputStream
    public let content: OutputContent

    public init(
        id: UUID = UUID(),
        tabId: UUID,
        sequence: Int,
        timestamp: Date = Date(),
        stream: OutputStream,
        content: OutputContent
    ) {
        self.id = id
        self.tabId = tabId
        self.sequence = sequence
        self.timestamp = timestamp
        self.stream = stream
        self.content = content
    }

    public enum OutputStream: String, Sendable, Codable {
        case stdout
        case stderr
    }

    public enum OutputContent: Sendable {
        case text(String)
        case bytes(Data)

        public var asString: String {
            switch self {
            case .text(let string):
                return string
            case .bytes(let data):
                return String(data: data, encoding: .utf8) ?? "<binary data>"
            }
        }

        public var asData: Data {
            switch self {
            case .text(let string):
                return string.data(using: .utf8) ?? Data()
            case .bytes(let data):
                return data
            }
        }
    }
}

// MARK: - Scrollback Buffer

/// A fixed-size buffer for terminal scrollback that truncates oldest lines.
///
/// **Phase 2 System Contract:**
/// - 10K line cap per terminal
/// - ~2MB per terminal (estimated)
/// - Oldest lines truncated when limit reached
public actor ScrollbackBuffer {
    private var lines: [ScrollbackLine] = []
    private let limit: Int
    private var sequenceCounter: Int = 0

    /// Total lines ever added (for sequence tracking)
    public private(set) var totalLinesAdded: Int = 0

    /// Number of lines truncated
    public private(set) var linesTruncated: Int = 0

    public init(limit: Int = 10_000) {
        self.limit = limit
    }

    /// Add a line to the buffer
    /// - Parameter content: The line content
    /// - Returns: The sequence number of the added line
    @discardableResult
    public func append(_ content: String) -> Int {
        let sequence = sequenceCounter
        sequenceCounter += 1
        totalLinesAdded += 1

        let line = ScrollbackLine(sequence: sequence, content: content, timestamp: Date())
        lines.append(line)

        // Truncate if over limit
        if lines.count > limit {
            let overflow = lines.count - limit
            lines.removeFirst(overflow)
            linesTruncated += overflow
        }

        return sequence
    }

    /// Append data (may contain multiple lines)
    /// - Parameter data: The data to append
    public func appendData(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }
        let newLines = string.components(separatedBy: .newlines)
        for line in newLines where !line.isEmpty {
            append(line)
        }
    }

    /// Get all lines in the buffer
    public var allLines: [ScrollbackLine] {
        lines
    }

    /// Get the last N lines
    /// - Parameter count: Number of lines to retrieve
    /// - Returns: The last N lines
    public func lastLines(_ count: Int) -> [ScrollbackLine] {
        Array(lines.suffix(count))
    }

    /// Get lines after a given sequence number
    /// - Parameter afterSequence: The sequence number to start from (exclusive)
    /// - Returns: Lines with sequence > afterSequence
    public func lines(after afterSequence: Int) -> [ScrollbackLine] {
        lines.filter { $0.sequence > afterSequence }
    }

    /// Clear the buffer
    public func clear() {
        lines.removeAll()
    }

    /// Current line count
    public var count: Int {
        lines.count
    }

    /// Estimated memory usage in bytes
    public var estimatedMemoryUsage: Int {
        lines.reduce(0) { $0 + $1.content.utf8.count + 32 } // 32 bytes overhead per line
    }

    /// Export buffer contents as a string
    public func export() -> String {
        lines.map(\.content).joined(separator: "\n")
    }
}

// MARK: - ScrollbackLine

/// A single line in the scrollback buffer
public struct ScrollbackLine: Identifiable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let content: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        sequence: Int,
        content: String,
        timestamp: Date
    ) {
        self.id = id
        self.sequence = sequence
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Terminal Preferences

/// User preferences for terminal behavior
public struct TerminalPreferences: Codable, Sendable {
    /// Which backend to use
    public var backendType: TerminalBackendType

    /// Default shell path (nil = auto-detect)
    public var defaultShell: String?

    /// Font family
    public var fontFamily: String

    /// Font size
    public var fontSize: CGFloat

    /// Line height multiplier
    public var lineHeight: CGFloat

    /// Cursor style
    public var cursorStyle: CursorStylePreference

    /// Whether to blink cursor
    public var cursorBlink: Bool

    /// Scrollback limit
    public var scrollbackLimit: Int

    /// Whether to auto-show terminal when Claude runs foreground commands
    public var autoShowOnForegroundCommand: Bool

    /// Whether to copy on select
    public var copyOnSelect: Bool

    /// Bell sound
    public var bellStyle: BellStyle

    public init(
        backendType: TerminalBackendType = .swiftTerm,
        defaultShell: String? = nil,
        fontFamily: String = "SF Mono",
        fontSize: CGFloat = 13,
        lineHeight: CGFloat = 1.2,
        cursorStyle: CursorStylePreference = .block,
        cursorBlink: Bool = true,
        scrollbackLimit: Int = 10_000,
        autoShowOnForegroundCommand: Bool = true,
        copyOnSelect: Bool = false,
        bellStyle: BellStyle = .visual
    ) {
        self.backendType = backendType
        self.defaultShell = defaultShell
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.cursorStyle = cursorStyle
        self.cursorBlink = cursorBlink
        self.scrollbackLimit = scrollbackLimit
        self.autoShowOnForegroundCommand = autoShowOnForegroundCommand
        self.copyOnSelect = copyOnSelect
        self.bellStyle = bellStyle
    }

    public static let `default` = TerminalPreferences()
}

// MARK: - CursorStylePreference

public enum CursorStylePreference: String, Codable, CaseIterable, Sendable {
    case block = "block"
    case underline = "underline"
    case bar = "bar"

    public var displayName: String {
        switch self {
        case .block: return "Block"
        case .underline: return "Underline"
        case .bar: return "Bar"
        }
    }
}

// MARK: - BellStyle

public enum BellStyle: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case visual = "visual"
    case audio = "audio"
    case both = "both"

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .visual: return "Visual"
        case .audio: return "Audio"
        case .both: return "Both"
        }
    }
}

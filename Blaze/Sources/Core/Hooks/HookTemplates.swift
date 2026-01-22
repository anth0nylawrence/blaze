import Foundation

// MARK: - Hook Template Category

/// Categories for organizing hook templates in the UI builder.
/// **E005-F009-S001-T005-A001**
public enum HookTemplateCategory: String, Codable, Sendable, CaseIterable {
    case logging       // Observability and debugging
    case security      // Confirmation, blocking dangerous ops
    case notification  // User alerts and notifications
    case custom        // User-defined shell/script templates
    case integration   // External service integrations

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .logging: return "Logging"
        case .security: return "Security"
        case .notification: return "Notification"
        case .custom: return "Custom"
        case .integration: return "Integration"
        }
    }

    /// SF Symbol icon for the category.
    public var icon: String {
        switch self {
        case .logging: return "doc.text.magnifyingglass"
        case .security: return "lock.shield"
        case .notification: return "bell.badge"
        case .custom: return "terminal"
        case .integration: return "link"
        }
    }

    /// Description of what templates in this category do.
    public var description: String {
        switch self {
        case .logging:
            return "Track tool calls, file changes, and session events for debugging"
        case .security:
            return "Gate dangerous operations with confirmation or automatic blocking"
        case .notification:
            return "Send alerts via macOS notifications, sounds, or external services"
        case .custom:
            return "Run custom shell scripts or commands on hook events"
        case .integration:
            return "Connect to external services like Slack, webhooks, or APIs"
        }
    }
}

// MARK: - Hook Template Variable

/// A variable that can be interpolated in hook templates.
/// Variables use $VARIABLE_NAME syntax in template code.
public struct HookTemplateVariable: Codable, Sendable, Equatable, Identifiable {
    public var id: String { name }

    /// Variable name (e.g., "TOOL_NAME", "FILE_PATH").
    public let name: String

    /// Human-readable description of the variable.
    public let description: String

    /// Example value for documentation.
    public let example: String

    /// Whether this variable is always available for the hook event.
    public let required: Bool

    public init(name: String, description: String, example: String, required: Bool = true) {
        self.name = name
        self.description = description
        self.example = example
        self.required = required
    }

    /// Placeholder string for use in templates.
    public var placeholder: String { "$\(name)" }
}

// MARK: - Hook Template

/// A predefined hook template that can be instantiated in the UI builder.
/// Templates provide ready-to-use hook configurations for common patterns.
public struct HookTemplate: Codable, Sendable, Equatable, Identifiable {
    /// Unique identifier for the template.
    public let id: String

    /// Human-readable name.
    public let name: String

    /// Detailed description of what this template does.
    public let description: String

    /// Category for UI organization.
    public let category: HookTemplateCategory

    /// Which hook event types this template supports.
    public let supportedEventTypes: [CLIHookEventType]

    /// The default/recommended event type for this template.
    public let defaultEventType: CLIHookEventType

    /// Script type for the template code.
    public let scriptType: HookScriptType

    /// The template code with $VARIABLE placeholders.
    public let codeTemplate: String

    /// Variables available for interpolation.
    public let variables: [HookTemplateVariable]

    /// Whether this template can block execution (for pre-event hooks).
    public let canBlock: Bool

    /// Default timeout in milliseconds.
    public let defaultTimeoutMs: Int

    /// Tags for search/filtering.
    public let tags: [String]

    /// SF Symbol icon override (uses category icon if nil).
    public let icon: String?

    public init(
        id: String,
        name: String,
        description: String,
        category: HookTemplateCategory,
        supportedEventTypes: [CLIHookEventType],
        defaultEventType: CLIHookEventType,
        scriptType: HookScriptType = .shell,
        codeTemplate: String,
        variables: [HookTemplateVariable] = [],
        canBlock: Bool = false,
        defaultTimeoutMs: Int = 30_000,
        tags: [String] = [],
        icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.supportedEventTypes = supportedEventTypes
        self.defaultEventType = defaultEventType
        self.scriptType = scriptType
        self.codeTemplate = codeTemplate
        self.variables = variables
        self.canBlock = canBlock
        self.defaultTimeoutMs = defaultTimeoutMs
        self.tags = tags
        self.icon = icon
    }

    /// Get the display icon (template-specific or category default).
    public var displayIcon: String {
        icon ?? category.icon
    }

    /// Interpolate variables into the template code.
    /// - Parameter values: Dictionary mapping variable names to values.
    /// - Returns: The code with variables replaced.
    public func interpolate(values: [String: String]) -> String {
        var result = codeTemplate
        for variable in variables {
            if let value = values[variable.name] {
                result = result.replacingOccurrences(of: variable.placeholder, with: value)
            }
        }
        return result
    }

    /// Create a Hook instance from this template.
    /// - Parameters:
    ///   - name: Name for the hook instance.
    ///   - repoId: Optional repo scope.
    ///   - eventType: Event type (uses default if nil).
    ///   - variableValues: Values to interpolate into the template.
    /// - Returns: A configured Hook ready to save.
    public func createHook(
        name: String? = nil,
        repoId: UUID? = nil,
        eventType: CLIHookEventType? = nil,
        variableValues: [String: String] = [:]
    ) -> Hook {
        let hookName = name ?? self.name
        let selectedEvent = eventType ?? defaultEventType
        let script = interpolate(values: variableValues)

        // Map CLI event type to Blaze's internal HookEventType
        let internalEventType: HookEventType = {
            switch selectedEvent {
            case .preToolUse: return .preToolCall
            case .postToolUse: return .postToolCall
            case .sessionStart: return .sessionStart
            case .stop: return .sessionEnd
            case .preCompact: return .turnEnd
            case .notification: return .postToolCall
            case .permissionRequest: return .toolApproved
            case .userPromptSubmit: return .turnStart
            }
        }()

        return Hook(
            repoId: repoId,
            name: hookName,
            description: description,
            eventType: internalEventType,
            inlineScript: script,
            scriptType: scriptType,
            enabled: true,
            priority: 0,
            timeoutMs: defaultTimeoutMs,
            runAsync: !canBlock
        )
    }
}

// MARK: - Common Variables

/// Standard variables available across multiple hook templates.
public enum HookTemplateVariables {
    /// Tool name variable.
    public static let toolName = HookTemplateVariable(
        name: "TOOL_NAME",
        description: "Name of the tool being called",
        example: "Bash"
    )

    /// Tool input JSON variable.
    public static let toolInput = HookTemplateVariable(
        name: "TOOL_INPUT",
        description: "JSON-encoded tool input parameters",
        example: "{\"command\": \"ls -la\"}"
    )

    /// Tool output variable.
    public static let toolOutput = HookTemplateVariable(
        name: "TOOL_OUTPUT",
        description: "Output from the tool execution",
        example: "file1.txt\nfile2.txt"
    )

    /// File path variable.
    public static let filePath = HookTemplateVariable(
        name: "FILE_PATH",
        description: "Path to the file being operated on",
        example: "/Users/dev/project/src/main.swift"
    )

    /// Session ID variable.
    public static let sessionId = HookTemplateVariable(
        name: "SESSION_ID",
        description: "Current session identifier",
        example: "abc123-def456"
    )

    /// Project path variable.
    public static let projectPath = HookTemplateVariable(
        name: "PROJECT_PATH",
        description: "Root path of the current project",
        example: "/Users/dev/project"
    )

    /// Timestamp variable.
    public static let timestamp = HookTemplateVariable(
        name: "TIMESTAMP",
        description: "ISO 8601 timestamp of the event",
        example: "2025-01-15T10:30:00Z"
    )

    /// Duration variable.
    public static let durationMs = HookTemplateVariable(
        name: "DURATION_MS",
        description: "Execution duration in milliseconds",
        example: "1234",
        required: false
    )

    /// Custom log file path.
    public static let logFile = HookTemplateVariable(
        name: "LOG_FILE",
        description: "Path to the log file",
        example: "/tmp/blaze-hooks.log"
    )

    /// Custom message variable.
    public static let message = HookTemplateVariable(
        name: "MESSAGE",
        description: "Custom message to display or log",
        example: "Task completed successfully"
    )

    /// Webhook URL variable.
    public static let webhookUrl = HookTemplateVariable(
        name: "WEBHOOK_URL",
        description: "URL for webhook notifications",
        example: "https://hooks.slack.com/services/..."
    )

    /// Notification title variable.
    public static let notificationTitle = HookTemplateVariable(
        name: "NOTIFICATION_TITLE",
        description: "Title for the notification",
        example: "Blaze Hook"
    )
}

// MARK: - Predefined Templates

/// Collection of predefined hook templates.
public enum HookTemplates {
    // MARK: - Logging Templates

    /// Logs all tool calls to a file.
    public static let toolCallLogger = HookTemplate(
        id: "logging.tool_calls",
        name: "Tool Call Logger",
        description: "Logs all tool calls with their inputs and outputs to a file for debugging and auditing.",
        category: .logging,
        supportedEventTypes: [.preToolUse, .postToolUse],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Tool Call Logger - logs tool executions to file
        LOG_FILE="${LOG_FILE:-/tmp/blaze-tool-calls.log}"
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Read hook input from stdin
        INPUT=$(cat)

        # Extract fields from JSON input
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
        TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' | head -c 500)
        DURATION=$(echo "$INPUT" | jq -r '.duration_ms // "N/A"')

        # Log the tool call
        echo "[$TIMESTAMP] Tool: $TOOL_NAME | Duration: ${DURATION}ms" >> "$LOG_FILE"
        echo "  Input: $TOOL_INPUT" >> "$LOG_FILE"
        if [ -n "$TOOL_OUTPUT" ]; then
            echo "  Output: ${TOOL_OUTPUT:0:200}..." >> "$LOG_FILE"
        fi
        echo "" >> "$LOG_FILE"

        # Return continue result
        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.logFile],
        canBlock: false,
        defaultTimeoutMs: 5_000,
        tags: ["logging", "audit", "debug", "file"]
    )

    /// Logs session lifecycle events.
    public static let sessionLogger = HookTemplate(
        id: "logging.session",
        name: "Session Logger",
        description: "Tracks session start, stop, and compact events for monitoring agent lifecycle.",
        category: .logging,
        supportedEventTypes: [.sessionStart, .stop, .preCompact],
        defaultEventType: .sessionStart,
        codeTemplate: """
        #!/bin/bash
        # Session Logger - tracks session lifecycle
        LOG_FILE="${LOG_FILE:-/tmp/blaze-sessions.log}"
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        INPUT=$(cat)
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        EVENT_TYPE=$(echo "$INPUT" | jq -r '.type // "event"')
        PROJECT=$(echo "$INPUT" | jq -r '.project_path // "unknown"')

        echo "[$TIMESTAMP] Session $EVENT_TYPE: $SESSION_ID" >> "$LOG_FILE"
        echo "  Project: $PROJECT" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"

        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.logFile],
        canBlock: false,
        defaultTimeoutMs: 5_000,
        tags: ["logging", "session", "lifecycle"]
    )

    /// JSON structured logger for machine parsing.
    public static let structuredLogger = HookTemplate(
        id: "logging.structured",
        name: "Structured JSON Logger",
        description: "Outputs structured JSON logs suitable for log aggregation systems like ELK or Datadog.",
        category: .logging,
        supportedEventTypes: [.preToolUse, .postToolUse, .sessionStart, .stop],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Structured JSON Logger - machine-readable logs
        LOG_FILE="${LOG_FILE:-/tmp/blaze-structured.jsonl}"

        INPUT=$(cat)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Build structured log entry
        LOG_ENTRY=$(echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '{
            timestamp: $ts,
            level: "info",
            service: "blaze-hooks",
            event: {
                tool_name: .tool_name,
                session_id: .session_id,
                project_path: .project_path,
                duration_ms: .duration_ms
            }
        }')

        echo "$LOG_ENTRY" >> "$LOG_FILE"
        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.logFile],
        canBlock: false,
        defaultTimeoutMs: 5_000,
        tags: ["logging", "json", "structured", "elk", "datadog"],
        icon: "curlybraces"
    )

    // MARK: - Security Templates

    /// Requires confirmation for dangerous tool operations.
    public static let dangerousOpConfirmation = HookTemplate(
        id: "security.dangerous_op_confirm",
        name: "Dangerous Operation Confirmation",
        description: "Blocks potentially dangerous operations (rm -rf, git reset --hard, etc.) and requires explicit confirmation.",
        category: .security,
        supportedEventTypes: [.preToolUse, .permissionRequest],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # Dangerous Operation Confirmation
        # Blocks commands matching dangerous patterns

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

        # Only check Bash commands
        if [ "$TOOL_NAME" != "Bash" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')

        # Dangerous patterns to block
        DANGEROUS_PATTERNS=(
            "rm -rf /"
            "rm -rf ~"
            "rm -rf \\*"
            "git reset --hard"
            "git clean -fdx"
            "git push.*--force"
            "chmod -R 777"
            "dd if="
            "> /dev/"
            "mkfs\\."
            ":(){ :|:& };:"
        )

        for pattern in "${DANGEROUS_PATTERNS[@]}"; do
            if echo "$COMMAND" | grep -qE "$pattern"; then
                echo "{\"result\": \"block\", \"reason\": \"Blocked dangerous command matching pattern: $pattern\"}"
                exit 0
            fi
        done

        echo '{"result": "continue"}'
        """,
        variables: [],
        canBlock: true,
        defaultTimeoutMs: 5_000,
        tags: ["security", "confirmation", "dangerous", "block"],
        icon: "exclamationmark.shield"
    )

    /// Blocks writes to sensitive paths.
    public static let sensitivePathGuard = HookTemplate(
        id: "security.sensitive_paths",
        name: "Sensitive Path Guard",
        description: "Prevents file operations on sensitive paths like /etc, ~/.ssh, credentials files, etc.",
        category: .security,
        supportedEventTypes: [.preToolUse, .permissionRequest],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # Sensitive Path Guard - blocks operations on sensitive paths

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

        # Check Write and Edit tools
        if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')

        # Sensitive path patterns
        SENSITIVE_PATHS=(
            "^/etc/"
            "^/System/"
            "^/usr/"
            "^\\.ssh/"
            "/\\.ssh/"
            "\\.env$"
            "credentials"
            "secrets"
            "\\.pem$"
            "\\.key$"
            "id_rsa"
            "id_ed25519"
            "passwd"
            "shadow"
        )

        for pattern in "${SENSITIVE_PATHS[@]}"; do
            if echo "$FILE_PATH" | grep -qE "$pattern"; then
                echo "{\"result\": \"block\", \"reason\": \"Cannot modify sensitive path: $FILE_PATH\"}"
                exit 0
            fi
        done

        echo '{"result": "continue"}'
        """,
        variables: [],
        canBlock: true,
        defaultTimeoutMs: 5_000,
        tags: ["security", "paths", "sensitive", "credentials"],
        icon: "folder.badge.minus"
    )

    /// Rate limits tool calls to prevent runaway loops.
    public static let rateLimiter = HookTemplate(
        id: "security.rate_limit",
        name: "Tool Rate Limiter",
        description: "Prevents runaway tool execution by limiting calls per minute. Useful for catching infinite loops.",
        category: .security,
        supportedEventTypes: [.preToolUse],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # Tool Rate Limiter - prevents runaway execution
        RATE_FILE="/tmp/blaze-rate-limit-$$"
        MAX_CALLS_PER_MINUTE=${MAX_CALLS:-60}
        WINDOW_SECONDS=60

        INPUT=$(cat)
        NOW=$(date +%s)

        # Clean old entries and count recent calls
        if [ -f "$RATE_FILE" ]; then
            CUTOFF=$((NOW - WINDOW_SECONDS))
            RECENT_CALLS=$(awk -v cutoff="$CUTOFF" '$1 >= cutoff' "$RATE_FILE" | wc -l)

            if [ "$RECENT_CALLS" -ge "$MAX_CALLS_PER_MINUTE" ]; then
                echo "{\"result\": \"block\", \"reason\": \"Rate limit exceeded: $RECENT_CALLS calls in last minute (max: $MAX_CALLS_PER_MINUTE)\"}"
                exit 0
            fi

            # Clean old entries
            awk -v cutoff="$CUTOFF" '$1 >= cutoff' "$RATE_FILE" > "${RATE_FILE}.tmp"
            mv "${RATE_FILE}.tmp" "$RATE_FILE"
        fi

        # Record this call
        echo "$NOW" >> "$RATE_FILE"

        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "MAX_CALLS",
                description: "Maximum tool calls allowed per minute",
                example: "60"
            )
        ],
        canBlock: true,
        defaultTimeoutMs: 5_000,
        tags: ["security", "rate-limit", "throttle", "loop-prevention"],
        icon: "gauge.with.dots.needle.67percent"
    )

    // MARK: - Notification Templates

    /// macOS notification on events.
    public static let macOSNotification = HookTemplate(
        id: "notification.macos",
        name: "macOS Notification",
        description: "Sends a native macOS notification when hook events occur. Great for long-running tasks.",
        category: .notification,
        supportedEventTypes: [.stop, .postToolUse, .notification],
        defaultEventType: .stop,
        codeTemplate: """
        #!/bin/bash
        # macOS Notification - sends native notifications

        INPUT=$(cat)
        TITLE="${NOTIFICATION_TITLE:-Blaze Hook}"
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // .notification_message // "Event triggered"')

        # Send notification via osascript
        osascript -e "display notification \\"$STOP_REASON\\" with title \\"$TITLE\\" subtitle \\"Session: ${SESSION_ID:0:8}...\\" sound name \\"Glass\\""

        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.notificationTitle],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["notification", "macos", "alert", "sound"],
        icon: "bell.badge"
    )

    /// Sound alert on events.
    public static let soundAlert = HookTemplate(
        id: "notification.sound",
        name: "Sound Alert",
        description: "Plays a system sound when events occur. Useful for getting attention without visual interruption.",
        category: .notification,
        supportedEventTypes: [.stop, .postToolUse, .notification],
        defaultEventType: .stop,
        codeTemplate: """
        #!/bin/bash
        # Sound Alert - plays system sound
        # Available sounds: Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink

        SOUND="${SOUND_NAME:-Glass}"
        afplay "/System/Library/Sounds/${SOUND}.aiff" 2>/dev/null || afplay "/System/Library/Sounds/Glass.aiff"

        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "SOUND_NAME",
                description: "macOS system sound name",
                example: "Glass"
            )
        ],
        canBlock: false,
        defaultTimeoutMs: 5_000,
        tags: ["notification", "sound", "audio", "alert"],
        icon: "speaker.wave.2"
    )

    /// Webhook notification.
    public static let webhookNotification = HookTemplate(
        id: "notification.webhook",
        name: "Webhook Notification",
        description: "Sends event data to a webhook URL (Slack, Discord, custom). Includes tool name, session, and output.",
        category: .notification,
        supportedEventTypes: [.stop, .postToolUse, .notification, .sessionStart],
        defaultEventType: .stop,
        codeTemplate: """
        #!/bin/bash
        # Webhook Notification - posts to external URL

        WEBHOOK_URL="${WEBHOOK_URL}"
        if [ -z "$WEBHOOK_URL" ]; then
            echo '{"result": "continue", "message": "WEBHOOK_URL not configured"}'
            exit 0
        fi

        INPUT=$(cat)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Build payload
        PAYLOAD=$(echo "$INPUT" | jq -c --arg ts "$TIMESTAMP" '{
            timestamp: $ts,
            event: {
                tool_name: .tool_name,
                session_id: .session_id,
                stop_reason: .stop_reason,
                notification_message: .notification_message
            }
        }')

        # Send webhook (async, don't block on response)
        curl -s -X POST "$WEBHOOK_URL" \\
            -H "Content-Type: application/json" \\
            -d "$PAYLOAD" \\
            --max-time 5 >/dev/null 2>&1 &

        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.webhookUrl],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["notification", "webhook", "slack", "discord", "http"],
        icon: "arrow.up.forward.app"
    )

    /// Slack-formatted webhook.
    public static let slackNotification = HookTemplate(
        id: "notification.slack",
        name: "Slack Notification",
        description: "Sends formatted messages to a Slack webhook with rich formatting and context.",
        category: .notification,
        supportedEventTypes: [.stop, .postToolUse, .notification],
        defaultEventType: .stop,
        codeTemplate: """
        #!/bin/bash
        # Slack Notification - sends formatted Slack messages

        WEBHOOK_URL="${WEBHOOK_URL}"
        if [ -z "$WEBHOOK_URL" ]; then
            echo '{"result": "continue", "message": "WEBHOOK_URL not configured"}'
            exit 0
        fi

        INPUT=$(cat)
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // .notification_message // "Event triggered"')
        PROJECT=$(echo "$INPUT" | jq -r '.project_path // "unknown"' | xargs basename)

        # Build Slack message
        PAYLOAD=$(cat <<EOF
        {
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "Blaze Hook Event"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {"type": "mrkdwn", "text": "*Project:*\\n$PROJECT"},
                        {"type": "mrkdwn", "text": "*Session:*\\n${SESSION_ID:0:8}..."}
                    ]
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "*Message:* $STOP_REASON"
                    }
                }
            ]
        }
        EOF
        )

        curl -s -X POST "$WEBHOOK_URL" \\
            -H "Content-Type: application/json" \\
            -d "$PAYLOAD" \\
            --max-time 5 >/dev/null 2>&1 &

        echo '{"result": "continue"}'
        """,
        variables: [HookTemplateVariables.webhookUrl],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["notification", "slack", "webhook", "messaging"],
        icon: "number"
    )

    // MARK: - Custom Templates

    /// Custom shell script template.
    public static let customShellScript = HookTemplate(
        id: "custom.shell",
        name: "Custom Shell Script",
        description: "A blank template for running custom shell commands. Input is provided via stdin as JSON.",
        category: .custom,
        supportedEventTypes: CLIHookEventType.allCases,
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Custom Shell Script Hook
        # Input is provided via stdin as JSON
        # Output must be JSON with at least {"result": "continue"} or {"result": "block", "reason": "..."}

        # Read input
        INPUT=$(cat)

        # Extract common fields
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
        PROJECT_PATH=$(echo "$INPUT" | jq -r '.project_path // ""')

        # --- Your custom logic here ---

        # Example: Log to a file
        # echo "Tool: $TOOL_NAME" >> /tmp/my-hook.log

        # Example: Block certain tools
        # if [ "$TOOL_NAME" == "Bash" ]; then
        #     echo '{"result": "block", "reason": "Bash is disabled"}'
        #     exit 0
        # fi

        # --- End custom logic ---

        # Return success
        echo '{"result": "continue"}'
        """,
        variables: [],
        canBlock: true,
        defaultTimeoutMs: 30_000,
        tags: ["custom", "shell", "bash", "script"],
        icon: "terminal"
    )

    /// Custom Python script template.
    public static let customPythonScript = HookTemplate(
        id: "custom.python",
        name: "Custom Python Script",
        description: "A blank template for running custom Python scripts. Input is provided via stdin as JSON.",
        category: .custom,
        supportedEventTypes: CLIHookEventType.allCases,
        defaultEventType: .postToolUse,
        scriptType: .python,
        codeTemplate: """
        #!/usr/bin/env python3
        # Custom Python Script Hook
        # Input is provided via stdin as JSON
        # Output must be JSON with at least {"result": "continue"} or {"result": "block", "reason": "..."}

        import json
        import sys

        def main():
            # Read input from stdin
            input_data = json.load(sys.stdin)

            # Extract common fields
            tool_name = input_data.get("tool_name", "")
            session_id = input_data.get("session_id", "")
            project_path = input_data.get("project_path", "")

            # --- Your custom logic here ---

            # Example: Log to a file
            # with open("/tmp/my-hook.log", "a") as f:
            #     f.write(f"Tool: {tool_name}\\n")

            # Example: Block certain tools
            # if tool_name == "Bash":
            #     print(json.dumps({"result": "block", "reason": "Bash is disabled"}))
            #     return

            # --- End custom logic ---

            # Return success
            print(json.dumps({"result": "continue"}))

        if __name__ == "__main__":
            main()
        """,
        variables: [],
        canBlock: true,
        defaultTimeoutMs: 30_000,
        tags: ["custom", "python", "script"],
        icon: "chevron.left.forwardslash.chevron.right"
    )

    /// Custom Node.js script template.
    public static let customNodeScript = HookTemplate(
        id: "custom.node",
        name: "Custom Node.js Script",
        description: "A blank template for running custom Node.js scripts. Input is provided via stdin as JSON.",
        category: .custom,
        supportedEventTypes: CLIHookEventType.allCases,
        defaultEventType: .postToolUse,
        scriptType: .node,
        codeTemplate: """
        #!/usr/bin/env node
        // Custom Node.js Script Hook
        // Input is provided via stdin as JSON
        // Output must be JSON with at least {"result": "continue"} or {"result": "block", "reason": "..."}

        const readline = require('readline');

        async function main() {
            // Read input from stdin
            const rl = readline.createInterface({ input: process.stdin });
            let inputData = '';

            for await (const line of rl) {
                inputData += line;
            }

            const input = JSON.parse(inputData);

            // Extract common fields
            const toolName = input.tool_name || '';
            const sessionId = input.session_id || '';
            const projectPath = input.project_path || '';

            // --- Your custom logic here ---

            // Example: Log to console (goes to stderr, not hook output)
            // console.error(`Tool: ${toolName}`);

            // Example: Block certain tools
            // if (toolName === 'Bash') {
            //     console.log(JSON.stringify({ result: 'block', reason: 'Bash is disabled' }));
            //     return;
            // }

            // --- End custom logic ---

            // Return success
            console.log(JSON.stringify({ result: 'continue' }));
        }

        main().catch(err => {
            console.error(err);
            console.log(JSON.stringify({ result: 'continue' }));
        });
        """,
        variables: [],
        canBlock: true,
        defaultTimeoutMs: 30_000,
        tags: ["custom", "node", "javascript", "script"],
        icon: "curlybraces.square"
    )

    // MARK: - Integration Templates

    /// Git auto-commit after file changes.
    public static let gitAutoCommit = HookTemplate(
        id: "integration.git_auto_commit",
        name: "Git Auto-Commit",
        description: "Automatically commits file changes after Write/Edit tool calls. Useful for tracking AI modifications.",
        category: .integration,
        supportedEventTypes: [.postToolUse],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Git Auto-Commit - commits after file writes

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        PROJECT_PATH=$(echo "$INPUT" | jq -r '.project_path // ""')

        # Only run for Write/Edit tools
        if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

        if [ -z "$PROJECT_PATH" ] || [ -z "$FILE_PATH" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        cd "$PROJECT_PATH" || exit 0

        # Check if in a git repo
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            echo '{"result": "continue"}'
            exit 0
        fi

        # Stage and commit the file
        RELATIVE_PATH="${FILE_PATH#$PROJECT_PATH/}"
        git add "$RELATIVE_PATH" 2>/dev/null
        git commit -m "Auto-commit: $RELATIVE_PATH (via Blaze)" --no-verify 2>/dev/null

        echo '{"result": "continue"}'
        """,
        variables: [],
        canBlock: false,
        defaultTimeoutMs: 30_000,
        tags: ["integration", "git", "auto-commit", "version-control"],
        icon: "arrow.triangle.branch"
    )

    /// File backup before modification.
    public static let fileBackup = HookTemplate(
        id: "integration.file_backup",
        name: "File Backup",
        description: "Creates a timestamped backup of files before they are modified by Write/Edit tools.",
        category: .integration,
        supportedEventTypes: [.preToolUse],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # File Backup - backs up files before modification

        BACKUP_DIR="${BACKUP_DIR:-/tmp/blaze-backups}"
        mkdir -p "$BACKUP_DIR"

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

        # Only run for Write/Edit tools
        if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

        if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        # Create backup with timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_NAME=$(basename "$FILE_PATH")_$TIMESTAMP
        cp "$FILE_PATH" "$BACKUP_DIR/$BACKUP_NAME"

        echo '{"result": "continue", "message": "Backup created: '"$BACKUP_DIR/$BACKUP_NAME"'"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "BACKUP_DIR",
                description: "Directory to store backup files",
                example: "/tmp/blaze-backups"
            )
        ],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["integration", "backup", "safety", "files"],
        icon: "doc.on.doc"
    )

    /// Auto-format on save - runs formatters after file writes.
    /// **E005-F009-S002-T008-A001**
    public static let autoFormatOnSave = HookTemplate(
        id: "integration.auto_format",
        name: "Auto-Format on Save",
        description: "Automatically runs code formatters (prettier, black, swiftformat) on files after Write/Edit operations. Detects file type and applies appropriate formatter.",
        category: .integration,
        supportedEventTypes: [.postToolUse],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Auto-Format on Save - applies formatters based on file extension
        # Supports: prettier (JS/TS/CSS/JSON), black (Python), swiftformat (Swift)

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

        # Only run for Write/Edit tools
        if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

        if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        # Detect file type and format
        EXT="${FILE_PATH##*.}"
        FORMATTED=false

        case "$EXT" in
            js|jsx|ts|tsx|css|scss|json|md|yaml|yml|html)
                if command -v prettier &> /dev/null; then
                    prettier --write "$FILE_PATH" 2>/dev/null && FORMATTED=true
                elif command -v npx &> /dev/null; then
                    npx prettier --write "$FILE_PATH" 2>/dev/null && FORMATTED=true
                fi
                ;;
            py)
                if command -v black &> /dev/null; then
                    black --quiet "$FILE_PATH" 2>/dev/null && FORMATTED=true
                elif command -v ruff &> /dev/null; then
                    ruff format "$FILE_PATH" 2>/dev/null && FORMATTED=true
                fi
                ;;
            swift)
                if command -v swiftformat &> /dev/null; then
                    swiftformat "$FILE_PATH" --quiet 2>/dev/null && FORMATTED=true
                fi
                ;;
            go)
                if command -v gofmt &> /dev/null; then
                    gofmt -w "$FILE_PATH" 2>/dev/null && FORMATTED=true
                fi
                ;;
            rs)
                if command -v rustfmt &> /dev/null; then
                    rustfmt "$FILE_PATH" 2>/dev/null && FORMATTED=true
                fi
                ;;
        esac

        if [ "$FORMATTED" = true ]; then
            echo '{"result": "continue", "message": "Formatted: '"$FILE_PATH"'"}'
        else
            echo '{"result": "continue"}'
        fi
        """,
        variables: [],
        canBlock: false,
        defaultTimeoutMs: 30_000,
        tags: ["integration", "format", "prettier", "black", "swiftformat", "code-quality"],
        icon: "wand.and.stars"
    )

    /// Git auto-stage - stages files on successful tool completion.
    /// **E005-F009-S002-T008-A001**
    public static let gitAutoStage = HookTemplate(
        id: "integration.git_auto_stage",
        name: "Git Auto-Stage",
        description: "Automatically stages modified files to git after successful Write/Edit operations. Unlike auto-commit, this just stages changes for you to review and commit manually.",
        category: .integration,
        supportedEventTypes: [.postToolUse],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Git Auto-Stage - stages files after successful writes (no commit)

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        PROJECT_PATH=$(echo "$INPUT" | jq -r '.project_path // ""')

        # Only run for Write/Edit tools
        if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')

        if [ -z "$PROJECT_PATH" ] || [ -z "$FILE_PATH" ]; then
            echo '{"result": "continue"}'
            exit 0
        fi

        cd "$PROJECT_PATH" || exit 0

        # Check if in a git repo
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            echo '{"result": "continue"}'
            exit 0
        fi

        # Stage the file (relative to repo root)
        RELATIVE_PATH="${FILE_PATH#$PROJECT_PATH/}"
        if git add "$RELATIVE_PATH" 2>/dev/null; then
            echo '{"result": "continue", "message": "Staged: '"$RELATIVE_PATH"'"}'
        else
            echo '{"result": "continue"}'
        fi
        """,
        variables: [],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["integration", "git", "stage", "version-control"],
        icon: "plus.circle"
    )

    /// Cost tracker - logs token usage and estimated costs.
    /// **E005-F009-S002-T008-A001**
    public static let costTracker = HookTemplate(
        id: "logging.cost_tracker",
        name: "Cost Tracker",
        description: "Tracks token usage and estimates API costs for each session. Logs to a CSV file for analysis and budgeting. Supports Claude, GPT-4, and other model pricing.",
        category: .logging,
        supportedEventTypes: [.postToolUse, .stop],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Cost Tracker - logs token usage and estimates costs
        # Pricing (per 1M tokens): Claude Sonnet $3/$15, GPT-4 $30/$60, etc.

        COST_LOG="${COST_LOG:-$HOME/.blaze/costs.csv}"
        mkdir -p "$(dirname "$COST_LOG")"

        # Initialize CSV if needed
        if [ ! -f "$COST_LOG" ]; then
            echo "timestamp,session_id,model,input_tokens,output_tokens,estimated_cost_usd" > "$COST_LOG"
        fi

        INPUT=$(cat)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        MODEL=$(echo "$INPUT" | jq -r '.model // "claude-3-sonnet"')

        # Extract token counts (adjust field names based on your CLI output)
        INPUT_TOKENS=$(echo "$INPUT" | jq -r '.usage.input_tokens // .input_tokens // 0')
        OUTPUT_TOKENS=$(echo "$INPUT" | jq -r '.usage.output_tokens // .output_tokens // 0')

        # Calculate cost based on model (prices per 1M tokens)
        calculate_cost() {
            local model=$1
            local input=$2
            local output=$3

            case "$model" in
                *claude-3-opus*|*claude-opus*)
                    # Opus: $15 input, $75 output per 1M
                    echo "scale=6; ($input * 15 + $output * 75) / 1000000" | bc
                    ;;
                *claude-3-sonnet*|*claude-sonnet*)
                    # Sonnet: $3 input, $15 output per 1M
                    echo "scale=6; ($input * 3 + $output * 15) / 1000000" | bc
                    ;;
                *claude-3-haiku*|*claude-haiku*)
                    # Haiku: $0.25 input, $1.25 output per 1M
                    echo "scale=6; ($input * 0.25 + $output * 1.25) / 1000000" | bc
                    ;;
                *gpt-4o*)
                    # GPT-4o: $5 input, $15 output per 1M
                    echo "scale=6; ($input * 5 + $output * 15) / 1000000" | bc
                    ;;
                *gpt-4*)
                    # GPT-4: $30 input, $60 output per 1M
                    echo "scale=6; ($input * 30 + $output * 60) / 1000000" | bc
                    ;;
                *gemini-1.5-pro*)
                    # Gemini 1.5 Pro: $3.50 input, $10.50 output per 1M
                    echo "scale=6; ($input * 3.5 + $output * 10.5) / 1000000" | bc
                    ;;
                *)
                    # Default to Sonnet pricing
                    echo "scale=6; ($input * 3 + $output * 15) / 1000000" | bc
                    ;;
            esac
        }

        # Only log if we have token data
        if [ "$INPUT_TOKENS" != "0" ] || [ "$OUTPUT_TOKENS" != "0" ]; then
            COST=$(calculate_cost "$MODEL" "$INPUT_TOKENS" "$OUTPUT_TOKENS")
            echo "$TIMESTAMP,$SESSION_ID,$MODEL,$INPUT_TOKENS,$OUTPUT_TOKENS,$COST" >> "$COST_LOG"
        fi

        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "COST_LOG",
                description: "Path to the cost tracking CSV file",
                example: "$HOME/.blaze/costs.csv"
            )
        ],
        canBlock: false,
        defaultTimeoutMs: 5_000,
        tags: ["logging", "cost", "tokens", "budget", "billing", "usage"],
        icon: "dollarsign.circle"
    )

    /// Session summary - generates summary on session end.
    /// **E005-F009-S002-T008-A001**
    public static let sessionSummary = HookTemplate(
        id: "logging.session_summary",
        name: "Session Summary",
        description: "Generates a markdown summary of the session on completion, including tools used, files modified, and duration. Saves to a configurable directory.",
        category: .logging,
        supportedEventTypes: [.stop],
        defaultEventType: .stop,
        codeTemplate: """
        #!/bin/bash
        # Session Summary - generates markdown summary on session end

        SUMMARY_DIR="${SUMMARY_DIR:-$HOME/.blaze/summaries}"
        mkdir -p "$SUMMARY_DIR"

        INPUT=$(cat)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        DATE_SLUG=$(date +"%Y-%m-%d_%H%M%S")
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        PROJECT=$(echo "$INPUT" | jq -r '.project_path // "unknown"' | xargs basename 2>/dev/null || echo "unknown")
        STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "completed"')

        # Extract session stats (adjust based on your CLI output format)
        DURATION_MS=$(echo "$INPUT" | jq -r '.duration_ms // .session_duration_ms // "N/A"')
        TOOL_COUNT=$(echo "$INPUT" | jq -r '.tool_call_count // .stats.tool_calls // "N/A"')
        FILES_MODIFIED=$(echo "$INPUT" | jq -r '.files_modified // .stats.files_modified // []' | jq -r 'if type == "array" then length else . end')

        # Convert duration to human readable
        if [ "$DURATION_MS" != "N/A" ] && [ "$DURATION_MS" != "null" ]; then
            DURATION_SEC=$((DURATION_MS / 1000))
            DURATION_MIN=$((DURATION_SEC / 60))
            DURATION_HUMAN="${DURATION_MIN}m $((DURATION_SEC % 60))s"
        else
            DURATION_HUMAN="N/A"
        fi

        # Generate summary markdown
        SUMMARY_FILE="$SUMMARY_DIR/${DATE_SLUG}_${PROJECT}_${SESSION_ID:0:8}.md"
        cat > "$SUMMARY_FILE" << EOF
        # Session Summary

        **Date:** $TIMESTAMP
        **Project:** $PROJECT
        **Session ID:** $SESSION_ID
        **Status:** $STOP_REASON

        ## Stats

        | Metric | Value |
        |--------|-------|
        | Duration | $DURATION_HUMAN |
        | Tool Calls | $TOOL_COUNT |
        | Files Modified | $FILES_MODIFIED |

        ## Raw Data

        ```json
        $(echo "$INPUT" | jq '.')
        ```
        EOF

        echo '{"result": "continue", "message": "Summary saved: '"$SUMMARY_FILE"'"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "SUMMARY_DIR",
                description: "Directory to save session summaries",
                example: "$HOME/.blaze/summaries"
            )
        ],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["logging", "summary", "session", "markdown", "report"],
        icon: "doc.text"
    )

    /// Safety guardrail - blocks dangerous operations with confirmation.
    /// **E005-F009-S002-T008-A001**
    public static let safetyGuardrail = HookTemplate(
        id: "security.safety_guardrail",
        name: "Safety Guardrail",
        description: "Enhanced safety hook that blocks dangerous operations and writes a confirmation request file. Operations remain blocked until the user confirms by creating a .confirmed file.",
        category: .security,
        supportedEventTypes: [.preToolUse],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # Safety Guardrail - blocks dangerous ops, requires confirmation file
        # To confirm: touch /tmp/blaze-confirm-<hash>.confirmed

        CONFIRM_DIR="${CONFIRM_DIR:-/tmp/blaze-confirms}"
        mkdir -p "$CONFIRM_DIR"

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

        # Generate unique hash for this operation
        OP_HASH=$(echo "${SESSION_ID}${TOOL_NAME}${TOOL_INPUT}" | md5 | head -c 8)
        CONFIRM_FILE="$CONFIRM_DIR/confirm-$OP_HASH"
        CONFIRMED_FILE="${CONFIRM_FILE}.confirmed"

        # Check if already confirmed
        if [ -f "$CONFIRMED_FILE" ]; then
            rm -f "$CONFIRM_FILE" "$CONFIRMED_FILE"
            echo '{"result": "continue", "message": "Operation confirmed"}'
            exit 0
        fi

        # Dangerous patterns by tool
        BLOCK=false
        REASON=""

        case "$TOOL_NAME" in
            Bash)
                COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""')
                # Check for dangerous patterns
                if echo "$COMMAND" | grep -qE 'rm\\s+(-[rf]+\\s+)*(/|~|\\$HOME|\\*)'; then
                    BLOCK=true
                    REASON="Recursive delete on root/home: $COMMAND"
                elif echo "$COMMAND" | grep -qE 'git\\s+(reset|clean|push.*--force)'; then
                    BLOCK=true
                    REASON="Destructive git operation: $COMMAND"
                elif echo "$COMMAND" | grep -qE '(chmod|chown)\\s+-R\\s+.*(/|~)'; then
                    BLOCK=true
                    REASON="Recursive permission change: $COMMAND"
                elif echo "$COMMAND" | grep -qE '(curl|wget).*\\|\\s*(bash|sh)'; then
                    BLOCK=true
                    REASON="Pipe to shell (potential RCE): $COMMAND"
                elif echo "$COMMAND" | grep -qE 'dd\\s+if=.*of=/dev/'; then
                    BLOCK=true
                    REASON="Direct disk write: $COMMAND"
                fi
                ;;
            Write|Edit)
                FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""')
                # Check for sensitive paths
                if echo "$FILE_PATH" | grep -qE '^(/etc/|/System/|~/.ssh/|.*\\.env$|.*credentials|.*\\.pem$)'; then
                    BLOCK=true
                    REASON="Write to sensitive path: $FILE_PATH"
                fi
                ;;
        esac

        if [ "$BLOCK" = true ]; then
            # Write confirmation request
            cat > "$CONFIRM_FILE" << EOF
        # Dangerous Operation Blocked
        **Time:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
        **Session:** $SESSION_ID
        **Tool:** $TOOL_NAME
        **Reason:** $REASON

        ## To Confirm
        Run: touch ${CONFIRMED_FILE}

        ## Input
        ```json
        $(echo "$TOOL_INPUT" | jq '.')
        ```
        EOF
            echo "{\"result\": \"block\", \"reason\": \"$REASON. To confirm: touch $CONFIRMED_FILE\"}"
            exit 0
        fi

        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "CONFIRM_DIR",
                description: "Directory for confirmation request files",
                example: "/tmp/blaze-confirms"
            )
        ],
        canBlock: true,
        defaultTimeoutMs: 5_000,
        tags: ["security", "guardrail", "confirmation", "dangerous", "block", "safety"],
        icon: "exclamationmark.triangle"
    )

    /// MCP proxy - routes MCP tool calls through custom handler.
    /// **E005-F009-S002-T008-A001**
    public static let mcpProxy = HookTemplate(
        id: "integration.mcp_proxy",
        name: "MCP Proxy",
        description: "Routes MCP tool calls through a custom handler for logging, modification, or custom routing. Useful for auditing MCP usage, adding custom tools, or implementing MCP middleware.",
        category: .integration,
        supportedEventTypes: [.preToolUse, .postToolUse],
        defaultEventType: .preToolUse,
        codeTemplate: """
        #!/bin/bash
        # MCP Proxy - routes MCP calls through custom handler
        # Can log, modify, or reroute MCP tool calls

        MCP_LOG="${MCP_LOG:-/tmp/blaze-mcp.jsonl}"
        MCP_HANDLER="${MCP_HANDLER:-}"  # Optional: path to custom handler script

        INPUT=$(cat)
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        # Check if this is an MCP tool (typically prefixed with mcp__ or contains server name)
        if ! echo "$TOOL_NAME" | grep -qE '^mcp__|__'; then
            echo '{"result": "continue"}'
            exit 0
        fi

        # Parse MCP tool info
        # Format is typically: mcp__<server>__<tool> or <server>__<tool>
        MCP_SERVER=$(echo "$TOOL_NAME" | sed -E 's/^(mcp__)?([^_]+)__.*/\\2/')
        MCP_TOOL=$(echo "$TOOL_NAME" | sed -E 's/^(mcp__)?[^_]+__//')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

        # Log the MCP call
        LOG_ENTRY=$(jq -n \\
            --arg ts "$TIMESTAMP" \\
            --arg sid "$SESSION_ID" \\
            --arg server "$MCP_SERVER" \\
            --arg tool "$MCP_TOOL" \\
            --argjson input "$TOOL_INPUT" \\
            '{
                timestamp: $ts,
                session_id: $sid,
                mcp_server: $server,
                mcp_tool: $tool,
                input: $input
            }')
        echo "$LOG_ENTRY" >> "$MCP_LOG"

        # If custom handler is specified, delegate to it
        if [ -n "$MCP_HANDLER" ] && [ -x "$MCP_HANDLER" ]; then
            echo "$INPUT" | "$MCP_HANDLER"
            exit $?
        fi

        # Default: allow the call
        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "MCP_LOG",
                description: "Path to MCP call log file (JSONL format)",
                example: "/tmp/blaze-mcp.jsonl"
            ),
            HookTemplateVariable(
                name: "MCP_HANDLER",
                description: "Optional path to custom MCP handler script",
                example: "/path/to/mcp-handler.sh",
                required: false
            )
        ],
        canBlock: true,
        defaultTimeoutMs: 30_000,
        tags: ["integration", "mcp", "proxy", "middleware", "tools"],
        icon: "arrow.triangle.swap"
    )

    /// Audit log - comprehensive logging for compliance.
    /// **E005-F009-S002-T008-A001**
    public static let auditLog = HookTemplate(
        id: "logging.audit",
        name: "Audit Log",
        description: "Comprehensive audit logging for compliance and security review. Records all tool calls with full context, timestamps, and tamper-evident checksums. Suitable for SOC2/HIPAA environments.",
        category: .logging,
        supportedEventTypes: [.preToolUse, .postToolUse, .sessionStart, .stop, .permissionRequest],
        defaultEventType: .postToolUse,
        codeTemplate: """
        #!/bin/bash
        # Audit Log - comprehensive compliance logging
        # Writes tamper-evident logs with checksums

        AUDIT_LOG="${AUDIT_LOG:-$HOME/.blaze/audit/audit.jsonl}"
        AUDIT_DIR=$(dirname "$AUDIT_LOG")
        mkdir -p "$AUDIT_DIR"

        INPUT=$(cat)
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        TIMESTAMP_EPOCH=$(date +%s)

        # Extract all relevant fields
        SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
        EVENT_TYPE=$(echo "$INPUT" | jq -r '.event_type // .type // "unknown"')
        TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "N/A"')
        TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // null')
        TOOL_OUTPUT=$(echo "$INPUT" | jq -c '.tool_output // null')
        PROJECT_PATH=$(echo "$INPUT" | jq -r '.project_path // "unknown"')
        USER=$(whoami)
        HOSTNAME=$(hostname)

        # Get previous checksum for chain integrity
        PREV_CHECKSUM=""
        if [ -f "$AUDIT_LOG" ]; then
            PREV_CHECKSUM=$(tail -1 "$AUDIT_LOG" 2>/dev/null | jq -r '.checksum // ""')
        fi

        # Build audit entry
        AUDIT_ENTRY=$(jq -n \\
            --arg ts "$TIMESTAMP" \\
            --arg epoch "$TIMESTAMP_EPOCH" \\
            --arg sid "$SESSION_ID" \\
            --arg event "$EVENT_TYPE" \\
            --arg tool "$TOOL_NAME" \\
            --argjson input "$TOOL_INPUT" \\
            --argjson output "$TOOL_OUTPUT" \\
            --arg project "$PROJECT_PATH" \\
            --arg user "$USER" \\
            --arg host "$HOSTNAME" \\
            --arg prev "$PREV_CHECKSUM" \\
            '{
                timestamp: $ts,
                timestamp_epoch: ($epoch | tonumber),
                session_id: $sid,
                event_type: $event,
                tool_name: $tool,
                tool_input: $input,
                tool_output: $output,
                project_path: $project,
                user: $user,
                hostname: $host,
                prev_checksum: $prev
            }')

        # Calculate checksum for tamper detection (includes previous checksum for chain)
        CHECKSUM=$(echo "$AUDIT_ENTRY" | sha256sum | cut -d' ' -f1)

        # Add checksum to entry
        FINAL_ENTRY=$(echo "$AUDIT_ENTRY" | jq --arg cs "$CHECKSUM" '. + {checksum: $cs}')

        # Append to audit log
        echo "$FINAL_ENTRY" >> "$AUDIT_LOG"

        # Rotate log if over 100MB
        LOG_SIZE=$(stat -f%z "$AUDIT_LOG" 2>/dev/null || stat -c%s "$AUDIT_LOG" 2>/dev/null || echo 0)
        if [ "$LOG_SIZE" -gt 104857600 ]; then
            mv "$AUDIT_LOG" "${AUDIT_LOG}.$(date +%Y%m%d_%H%M%S)"
        fi

        echo '{"result": "continue"}'
        """,
        variables: [
            HookTemplateVariable(
                name: "AUDIT_LOG",
                description: "Path to audit log file (JSONL format with checksums)",
                example: "$HOME/.blaze/audit/audit.jsonl"
            )
        ],
        canBlock: false,
        defaultTimeoutMs: 10_000,
        tags: ["logging", "audit", "compliance", "security", "soc2", "hipaa", "tamper-evident"],
        icon: "checkmark.shield"
    )

    // MARK: - All Templates

    /// All available templates, organized by category.
    public static let all: [HookTemplate] = [
        // Logging
        toolCallLogger,
        sessionLogger,
        structuredLogger,
        costTracker,
        sessionSummary,
        auditLog,
        // Security
        dangerousOpConfirmation,
        sensitivePathGuard,
        rateLimiter,
        safetyGuardrail,
        // Notification
        macOSNotification,
        soundAlert,
        webhookNotification,
        slackNotification,
        // Custom
        customShellScript,
        customPythonScript,
        customNodeScript,
        // Integration
        gitAutoCommit,
        gitAutoStage,
        fileBackup,
        autoFormatOnSave,
        mcpProxy
    ]

    /// Templates grouped by category.
    public static var byCategory: [HookTemplateCategory: [HookTemplate]] {
        Dictionary(grouping: all, by: \.category)
    }

    /// Get templates for a specific event type.
    public static func forEventType(_ eventType: CLIHookEventType) -> [HookTemplate] {
        all.filter { $0.supportedEventTypes.contains(eventType) }
    }

    /// Get template by ID.
    public static func template(id: String) -> HookTemplate? {
        all.first { $0.id == id }
    }

    /// Search templates by name, description, or tags.
    public static func search(query: String) -> [HookTemplate] {
        let lowercasedQuery = query.lowercased()
        return all.filter { template in
            template.name.lowercased().contains(lowercasedQuery) ||
            template.description.lowercased().contains(lowercasedQuery) ||
            template.tags.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
}

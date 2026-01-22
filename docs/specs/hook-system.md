# Hook System Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

The Hook System enables automation and extensibility by triggering user-defined actions in response to events. Hooks can fire on lifecycle events (session start/end), normalized events (tool calls, diffs), raw CLI events (before normalization), and custom triggers. This provides full flexibility while maintaining safety through sandboxing and timeout controls.

**Why This Matters:** Power users need extensibility. Without hooks, Blaze is a closed system. With hooks, users can integrate with external tools, enforce custom policies, and build workflows.

---

## Table of Contents

1. [Core Concepts](#1-core-concepts)
2. [Event Categories](#2-event-categories)
3. [Hook Registration](#3-hook-registration)
4. [Execution Model](#4-execution-model)
5. [Hook API](#5-hook-api)
6. [Built-in Hooks](#6-built-in-hooks)
7. [Safety & Sandboxing](#7-safety--sandboxing)
8. [Error Handling](#8-error-handling)
9. [Implementation](#9-implementation)

---

## 1. Core Concepts

### 1.1 What is a Hook?

A **Hook** is a user-defined action that executes in response to an event:

```
EVENT occurs → Hook triggered → Action executes → Optional result returned
```

Hooks can:
- Execute shell scripts or binaries
- Call HTTP endpoints (webhooks)
- Run Swift closures (for built-in hooks)
- Modify event data (interceptors)
- Block events (pre-hooks with veto power)

### 1.2 Hook Types

| Type | Timing | Can Block | Can Modify | Use Case |
|------|--------|-----------|------------|----------|
| **Pre-Hook** | Before event processed | Yes | Yes | Validation, transformation |
| **Post-Hook** | After event processed | No | No | Logging, notifications |
| **Interceptor** | During event processing | Yes | Yes | Custom policies |
| **Observer** | Async, fire-and-forget | No | No | Analytics, background sync |

### 1.3 Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HOOK EXECUTION FLOW                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Event Occurs (e.g., ToolCallStarted)                              │
│        │                                                             │
│        ▼                                                             │
│   ┌─────────────────┐                                               │
│   │  Find Hooks     │  Match event type + filters                   │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │  PRE-HOOKS      │  Sequential, can block/modify                 │
│   └────────┬────────┘                                               │
│            │                                                         │
│       ┌────┴────┐                                                   │
│       │ Blocked?│                                                   │
│       └────┬────┘                                                   │
│        No  │  Yes → Stop, return block reason                       │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │ PROCESS EVENT   │  Core event handling                          │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ▼                                                         │
│   ┌─────────────────┐                                               │
│   │  POST-HOOKS     │  Sequential, informational                    │
│   └────────┬────────┘                                               │
│            │                                                         │
│            ├──────────────┐                                         │
│            │              │                                          │
│            ▼              ▼                                          │
│   ┌─────────────┐  ┌─────────────┐                                  │
│   │  OBSERVERS  │  │   DONE      │                                  │
│   │  (async)    │  └─────────────┘                                  │
│   └─────────────┘                                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Event Categories

### 2.1 Lifecycle Events

Session and application lifecycle:

| Event | Payload | Pre-Hook | Use Case |
|-------|---------|----------|----------|
| `session.starting` | `{sessionId, project, engine}` | Yes | Setup, validation |
| `session.started` | `{sessionId, project, engine}` | No | Logging, notifications |
| `session.ending` | `{sessionId, reason}` | Yes | Cleanup confirmation |
| `session.ended` | `{sessionId, duration, stats}` | No | Analytics, archival |
| `session.error` | `{sessionId, error}` | No | Error reporting |
| `app.launching` | `{version}` | No | Initialization |
| `app.terminating` | `{}` | Yes | Save state |

### 2.2 Normalized Events

Events from the NormalizedEvent schema:

| Event | Payload | Pre-Hook | Use Case |
|-------|---------|----------|----------|
| `turn.started` | `{turnId, prompt}` | Yes | Prompt filtering |
| `turn.ended` | `{turnId, response}` | No | Response logging |
| `assistant.delta` | `{text, isFinal}` | No | Streaming display |
| `tool.calling` | `{toolName, args}` | Yes | Tool approval |
| `tool.completed` | `{toolName, result}` | No | Result processing |
| `diff.produced` | `{filePath, hunks}` | Yes | Diff review |
| `diff.applied` | `{filePath, success}` | No | Post-apply hooks |
| `file.read` | `{filePath, content}` | Yes | Content filtering |
| `file.written` | `{filePath, content}` | No | Backup, sync |
| `error.occurred` | `{type, message}` | No | Error reporting |

### 2.3 Raw CLI Events

Events before normalization (engine-specific):

| Event | Payload | Pre-Hook | Use Case |
|-------|---------|----------|----------|
| `raw.claude.*` | Raw Claude JSON | Yes | Custom parsing |
| `raw.gemini.*` | Raw Gemini JSON | Yes | Custom parsing |
| `raw.codex.*` | Raw Codex JSON | Yes | Custom parsing |
| `raw.stdout` | `{line}` | No | Debug logging |
| `raw.stderr` | `{line}` | No | Error capture |

### 2.4 Custom Triggers

User-defined events:

```swift
// Register custom trigger
HookManager.shared.registerTrigger("my.custom.event", schema: MyEventSchema.self)

// Fire custom event
HookManager.shared.fire("my.custom.event", payload: ["key": "value"])
```

| Event | Payload | Pre-Hook | Use Case |
|-------|---------|----------|----------|
| `custom.*` | User-defined | Configurable | Workflow integration |
| `timer.*` | `{interval, count}` | No | Scheduled tasks |
| `file.changed` | `{path, change}` | No | File watching |
| `keyboard.*` | `{shortcut}` | Yes | Hotkey actions |

---

## 3. Hook Registration

### 3.1 Configuration File

Hooks are registered in `~/.blaze/hooks.json` or `<project>/.blaze/hooks.json`:

```json
{
  "version": "1.0",
  "hooks": [
    {
      "id": "log-tool-calls",
      "event": "tool.completed",
      "type": "post",
      "action": {
        "type": "script",
        "command": "~/.blaze/scripts/log-tool.sh",
        "timeout": 5000
      },
      "filter": {
        "toolName": ["Bash", "Write", "Edit"]
      },
      "enabled": true
    },
    {
      "id": "block-dangerous-commands",
      "event": "tool.calling",
      "type": "pre",
      "action": {
        "type": "script",
        "command": "~/.blaze/scripts/check-command.sh"
      },
      "filter": {
        "toolName": "Bash"
      },
      "canBlock": true
    },
    {
      "id": "notify-session-end",
      "event": "session.ended",
      "type": "observer",
      "action": {
        "type": "webhook",
        "url": "https://hooks.example.com/blaze",
        "method": "POST"
      }
    }
  ]
}
```

### 3.2 Registration Schema

```swift
struct HookRegistration: Codable, Identifiable {
    let id: String
    let event: String              // Event pattern (supports wildcards)
    let type: HookType             // pre, post, interceptor, observer
    let action: HookAction         // What to execute
    let filter: [String: Any]?     // Optional payload filters
    let canBlock: Bool             // Can this hook block events?
    let canModify: Bool            // Can this hook modify payloads?
    let timeout: Int               // Milliseconds (default: 5000)
    let enabled: Bool              // Is this hook active?
    let scope: HookScope           // global, project, session
    let priority: Int              // Execution order (lower = first)
}

enum HookType: String, Codable {
    case pre
    case post
    case interceptor
    case observer
}

enum HookScope: String, Codable {
    case global     // ~/.blaze/hooks.json
    case project    // <project>/.blaze/hooks.json
    case session    // Runtime-registered
}
```

### 3.3 Action Types

```swift
enum HookAction: Codable {
    case script(ScriptAction)
    case webhook(WebhookAction)
    case builtin(String)  // Reference to built-in hook

    struct ScriptAction: Codable {
        let command: String       // Executable path
        let args: [String]?       // Additional arguments
        let workingDirectory: String?
        let environment: [String: String]?
        let timeout: Int          // Override default timeout
        let shell: String?        // Default: /bin/bash
    }

    struct WebhookAction: Codable {
        let url: String
        let method: String        // GET, POST, PUT
        let headers: [String: String]?
        let timeout: Int
        let retries: Int          // Default: 0
    }
}
```

### 3.4 Event Patterns

Hooks support glob-style event matching:

| Pattern | Matches |
|---------|---------|
| `tool.calling` | Exact match |
| `tool.*` | All tool events |
| `*.completed` | All completed events |
| `raw.claude.*` | All raw Claude events |
| `*` | All events (use carefully) |

---

## 4. Execution Model

### 4.1 Execution Order

1. **Pre-hooks** execute sequentially by priority (lowest first)
2. If any pre-hook blocks, remaining pre-hooks are skipped
3. **Event processing** occurs if not blocked
4. **Post-hooks** execute sequentially by priority
5. **Observers** execute concurrently (fire-and-forget)

### 4.2 Script Execution

Scripts receive event data via stdin (JSON) and environment variables:

```bash
#!/bin/bash
# ~/.blaze/scripts/log-tool.sh

# Event data available in stdin
EVENT_JSON=$(cat)

# Environment variables set by Blaze
echo "Session: $BLAZE_SESSION_ID"
echo "Project: $BLAZE_PROJECT_PATH"
echo "Event: $BLAZE_EVENT_TYPE"

# Parse event
TOOL_NAME=$(echo "$EVENT_JSON" | jq -r '.toolName')
echo "Tool executed: $TOOL_NAME"

# For pre-hooks that can block, output JSON:
# echo '{"block": true, "reason": "Dangerous command"}'

# For hooks that can modify, output modified payload:
# echo '{"modified": true, "payload": {...}}'
```

### 4.3 Environment Variables

| Variable | Description |
|----------|-------------|
| `BLAZE_SESSION_ID` | Current session UUID |
| `BLAZE_PROJECT_PATH` | Project root path |
| `BLAZE_EVENT_TYPE` | Event type that triggered hook |
| `BLAZE_EVENT_ID` | Unique event identifier |
| `BLAZE_ENGINE` | Current engine (claude, gemini, codex) |
| `BLAZE_HOOK_ID` | ID of the executing hook |
| `BLAZE_VERSION` | Blaze app version |

### 4.4 Response Format

Pre-hooks and interceptors can return JSON to control flow:

```json
{
  "block": false,
  "reason": null,
  "modified": true,
  "payload": {
    "toolName": "Bash",
    "args": {
      "command": "modified-command"
    }
  },
  "metadata": {
    "hookDuration": 45,
    "customField": "value"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `block` | boolean | If true, stop event processing |
| `reason` | string? | Explanation shown to user if blocked |
| `modified` | boolean | If true, use modified payload |
| `payload` | object? | Modified event payload |
| `metadata` | object? | Additional data for logging |

---

## 5. Hook API

### 5.1 Swift API (for built-in hooks)

```swift
// Hook protocol
protocol Hook {
    var id: String { get }
    var eventPattern: String { get }
    var type: HookType { get }

    func execute(event: HookEvent) async throws -> HookResult
}

// Event wrapper
struct HookEvent {
    let id: UUID
    let type: String
    let timestamp: Date
    let sessionId: UUID?
    let payload: [String: Any]
}

// Result type
enum HookResult {
    case success
    case blocked(reason: String)
    case modified(payload: [String: Any])
    case error(Error)
}

// Hook manager
@MainActor
final class HookManager: ObservableObject {
    static let shared = HookManager()

    @Published private(set) var registeredHooks: [HookRegistration] = []

    // Registration
    func register(_ hook: HookRegistration)
    func unregister(id: String)
    func loadFromConfig() throws

    // Execution
    func fire(_ eventType: String, payload: [String: Any]) async -> HookResult
    func fireAndForget(_ eventType: String, payload: [String: Any])

    // Custom triggers
    func registerTrigger(_ name: String, schema: Codable.Type)
    func fireTrigger(_ name: String, payload: Encodable) async -> HookResult
}
```

### 5.2 Usage Examples

```swift
// Pre-hook for tool approval
let approvalHook = HookRegistration(
    id: "tool-approval",
    event: "tool.calling",
    type: .pre,
    action: .builtin("policy-check"),
    canBlock: true,
    timeout: 10000,
    priority: 0
)
HookManager.shared.register(approvalHook)

// Fire event and handle result
let result = await HookManager.shared.fire("tool.calling", payload: [
    "toolName": "Bash",
    "args": ["command": "rm -rf /"]
])

switch result {
case .blocked(let reason):
    showBlockedAlert(reason: reason)
case .modified(let newPayload):
    executeToolWithPayload(newPayload)
case .success:
    executeTool()
case .error(let error):
    logError(error)
}
```

---

## 6. Built-in Hooks

### 6.1 Policy Check Hook

Integrates with Policy Engine:

```swift
struct PolicyCheckHook: Hook {
    let id = "policy-check"
    let eventPattern = "tool.calling"
    let type: HookType = .pre

    func execute(event: HookEvent) async throws -> HookResult {
        let decision = await PolicyEngine.shared.evaluate(
            toolName: event.payload["toolName"] as! String,
            args: event.payload["args"] as! [String: Any]
        )

        switch decision {
        case .allow:
            return .success
        case .deny(let reason):
            return .blocked(reason: reason)
        case .requireConfirm:
            // Show UI, wait for response
            let approved = await showApprovalDialog(event)
            return approved ? .success : .blocked(reason: "User declined")
        }
    }
}
```

### 6.2 Audit Log Hook

Logs all events for compliance:

```swift
struct AuditLogHook: Hook {
    let id = "audit-log"
    let eventPattern = "*"
    let type: HookType = .observer

    func execute(event: HookEvent) async throws -> HookResult {
        let entry = AuditEntry(
            eventId: event.id,
            eventType: event.type,
            timestamp: event.timestamp,
            sessionId: event.sessionId,
            payloadHash: hashPayload(event.payload)
        )
        try await AuditStore.shared.append(entry)
        return .success
    }
}
```

### 6.3 Session Stats Hook

Tracks session metrics:

```swift
struct SessionStatsHook: Hook {
    let id = "session-stats"
    let eventPattern = "session.ended"
    let type: HookType = .post

    func execute(event: HookEvent) async throws -> HookResult {
        let stats = SessionStats(
            sessionId: event.sessionId!,
            duration: event.payload["duration"] as! TimeInterval,
            turnCount: event.payload["turnCount"] as! Int,
            toolCallCount: event.payload["toolCallCount"] as! Int
        )
        try await StatsStore.shared.save(stats)
        return .success
    }
}
```

### 6.4 Diff Backup Hook

Creates backups before file changes:

```swift
struct DiffBackupHook: Hook {
    let id = "diff-backup"
    let eventPattern = "diff.produced"
    let type: HookType = .pre

    func execute(event: HookEvent) async throws -> HookResult {
        let filePath = event.payload["filePath"] as! String
        let backupPath = createBackupPath(filePath)
        try FileManager.default.copyItem(atPath: filePath, toPath: backupPath)
        return .success
    }
}
```

---

## 7. Safety & Sandboxing

### 7.1 Timeout Enforcement

All hooks have enforced timeouts:

| Hook Type | Default Timeout | Max Timeout |
|-----------|-----------------|-------------|
| Pre-hook | 5 seconds | 30 seconds |
| Post-hook | 5 seconds | 30 seconds |
| Interceptor | 10 seconds | 60 seconds |
| Observer | 30 seconds | 300 seconds |

```swift
func executeWithTimeout(_ hook: Hook, event: HookEvent) async throws -> HookResult {
    let timeout = min(hook.timeout, hook.type.maxTimeout)

    return try await withThrowingTaskGroup(of: HookResult.self) { group in
        group.addTask {
            try await hook.execute(event: event)
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000)
            throw HookError.timeout(hookId: hook.id, timeout: timeout)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

### 7.2 Script Sandboxing

External scripts run with restrictions:

```swift
struct SandboxConfig {
    var allowNetwork: Bool = false      // Deny by default
    var allowFileRead: [String] = []    // Whitelist paths
    var allowFileWrite: [String] = []   // Whitelist paths
    var maxMemoryMB: Int = 256          // Memory limit
    var maxCPUSeconds: Int = 30         // CPU time limit
}

// Applied via sandbox-exec (macOS)
func sandboxScript(_ script: ScriptAction) throws -> Process {
    let profile = generateSandboxProfile(script.sandbox ?? .default)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
    process.arguments = ["-p", profile, script.command] + (script.args ?? [])
    return process
}
```

### 7.3 Permission Model

Hooks declare required permissions:

```json
{
  "id": "my-hook",
  "permissions": {
    "network": ["https://api.example.com"],
    "fileRead": ["~/.blaze/*", "/tmp/blaze-*"],
    "fileWrite": ["~/.blaze/logs/*"],
    "environment": ["BLAZE_*", "HOME"]
  }
}
```

### 7.4 Dangerous Hook Protection

Certain actions require explicit user consent:

| Action | Risk Level | Consent Required |
|--------|------------|------------------|
| Block tool execution | Medium | First use |
| Modify prompts | High | Always |
| Access raw events | Medium | Project-level |
| Network access | Medium | Per-domain |
| File write outside project | High | Per-path |

---

## 8. Error Handling

### 8.1 Error Types

```swift
enum HookError: Error {
    case timeout(hookId: String, timeout: Int)
    case scriptFailed(hookId: String, exitCode: Int, stderr: String)
    case webhookFailed(hookId: String, statusCode: Int)
    case invalidResponse(hookId: String, reason: String)
    case permissionDenied(hookId: String, permission: String)
    case configInvalid(path: String, reason: String)
    case registrationFailed(hookId: String, reason: String)
}
```

### 8.2 Error Recovery

| Error | Pre-Hook Behavior | Post-Hook Behavior | Observer Behavior |
|-------|-------------------|--------------------|--------------------|
| Timeout | Block event | Log, continue | Log, ignore |
| Script fail | Block event | Log, continue | Log, ignore |
| Webhook fail | Retry then block | Retry then log | Retry then ignore |
| Invalid response | Block event | Log, continue | Log, ignore |

### 8.3 Circuit Breaker

Hooks that fail repeatedly are disabled:

```swift
struct CircuitBreaker {
    var failureThreshold: Int = 5
    var resetTimeout: TimeInterval = 300  // 5 minutes
    var state: State = .closed

    enum State {
        case closed      // Normal operation
        case open        // Failing, skip hook
        case halfOpen    // Testing recovery
    }

    mutating func recordFailure() {
        failureCount += 1
        if failureCount >= failureThreshold {
            state = .open
            openedAt = Date()
        }
    }

    mutating func recordSuccess() {
        failureCount = 0
        state = .closed
    }

    func shouldExecute() -> Bool {
        switch state {
        case .closed: return true
        case .open:
            if Date().timeIntervalSince(openedAt) > resetTimeout {
                return true  // Try once (half-open)
            }
            return false
        case .halfOpen: return true
        }
    }
}
```

---

## 9. Implementation

### 9.1 File Structure

```
Sources/
  Hooks/
    HookManager.swift           # Central registration and dispatch
    HookRegistration.swift      # Registration types
    HookExecutor.swift          # Execution engine
    ScriptExecutor.swift        # External script runner
    WebhookExecutor.swift       # HTTP webhook caller
    BuiltinHooks/
      PolicyCheckHook.swift
      AuditLogHook.swift
      SessionStatsHook.swift
      DiffBackupHook.swift
    Sandbox/
      SandboxProfile.swift      # sandbox-exec profiles
      PermissionChecker.swift   # Permission validation
    Config/
      HookConfigLoader.swift    # JSON config parser
      HookValidator.swift       # Config validation
```

### 9.2 Phase Implementation

| Phase | Deliverable |
|-------|-------------|
| **Phase 1 (MVP)** | Pre/post hooks, script execution, basic timeout |
| **Phase 2** | Interceptors, webhook support, circuit breaker |
| **Phase 3** | Observers, custom triggers, sandboxing |
| **Phase 4** | Hook marketplace, permission UI, analytics |

### 9.3 Testing Strategy

```swift
// Unit tests
func testPreHookCanBlock() async {
    let hook = MockHook(result: .blocked(reason: "test"))
    manager.register(hook)

    let result = await manager.fire("test.event", payload: [:])
    XCTAssertEqual(result, .blocked(reason: "test"))
}

func testTimeoutEnforcement() async {
    let slowHook = MockHook(delay: 10.0)
    slowHook.timeout = 1000  // 1 second
    manager.register(slowHook)

    let result = await manager.fire("test.event", payload: [:])
    XCTAssertThrowsError(result) { error in
        XCTAssertTrue(error is HookError.timeout)
    }
}

// Integration tests
func testScriptExecution() async {
    let script = """
    #!/bin/bash
    echo '{"block": false}'
    """
    let hook = ScriptHook(script: script)

    let result = await hook.execute(event: testEvent)
    XCTAssertEqual(result, .success)
}
```

### 9.4 Dependencies

| Component | Dependency | Purpose |
|-----------|------------|---------|
| Script execution | Foundation.Process | Run external scripts |
| Webhooks | URLSession | HTTP requests |
| Sandboxing | sandbox-exec | macOS sandbox |
| Config | JSONDecoder | Parse hooks.json |
| Async | Swift Concurrency | async/await execution |

---

## Appendix A: Hook Configuration Examples

### A.1 Slack Notification on Session End

```json
{
  "id": "slack-notify",
  "event": "session.ended",
  "type": "observer",
  "action": {
    "type": "webhook",
    "url": "https://hooks.slack.com/services/XXX",
    "method": "POST",
    "headers": {
      "Content-Type": "application/json"
    }
  },
  "transform": {
    "text": "Session {{sessionId}} ended after {{duration}}s"
  }
}
```

### A.2 Git Auto-Commit on File Write

```json
{
  "id": "auto-commit",
  "event": "file.written",
  "type": "post",
  "action": {
    "type": "script",
    "command": "~/.blaze/scripts/auto-commit.sh"
  },
  "filter": {
    "filePath": ["*.swift", "*.ts", "*.py"]
  }
}
```

### A.3 Custom Prompt Sanitization

```json
{
  "id": "sanitize-prompt",
  "event": "turn.started",
  "type": "interceptor",
  "action": {
    "type": "script",
    "command": "~/.blaze/scripts/sanitize-prompt.py"
  },
  "canModify": true,
  "canBlock": true
}
```

---

## Appendix B: Migration from Claude Code Hooks

For users migrating from Claude Code's hook system:

| Claude Code | Blaze Equivalent |
|-------------|------------------|
| `PreToolUse` | `tool.calling` (pre) |
| `PostToolUse` | `tool.completed` (post) |
| `UserPromptSubmit` | `turn.started` (pre) |
| `PreCompact` | `session.compacting` (pre) |
| `SessionStart` | `session.started` (post) |
| `Stop` | `session.ended` (post) |

Migration script:

```bash
~/.blaze/scripts/migrate-claude-hooks.sh ~/.claude/settings.json
```

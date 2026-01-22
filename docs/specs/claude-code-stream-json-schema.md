# Claude Code Stream-JSON Schema Reference

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**CLI Version:** 1.0.x (2.0.62+)
**Status:** Living Document

---

## Executive Summary

This document provides a comprehensive reference for the NDJSON (Newline Delimited JSON) event stream produced by Claude Code CLI when invoked with `--output-format stream-json`. This format enables programmatic consumption of Claude Code's output for building rich user interfaces.

---

## Table of Contents

1. [Invocation](#1-invocation)
2. [Stream Format](#2-stream-format)
3. [Event Types](#3-event-types)
4. [Event Payloads](#4-event-payloads)
5. [Event Sequences](#5-event-sequences)
6. [Parsing Guidelines](#6-parsing-guidelines)
7. [Error Handling](#7-error-handling)
8. [Version History](#8-version-history)

---

## 1. Invocation

### 1.1 Basic Headless Mode

```bash
claude -p "<prompt>" --output-format stream-json
```

### 1.2 Full Invocation Options

```bash
claude -p "<prompt>" \
  --output-format stream-json \
  --allowedTools "Bash,Edit,Read,Write,Glob,Grep,Task" \
  --max-turns 10 \
  --model sonnet \
  --verbose
```

### 1.3 Key Flags

| Flag | Description |
|------|-------------|
| `-p, --prompt` | Enable headless mode with prompt |
| `--output-format stream-json` | Emit NDJSON event stream |
| `--input-format stream-json` | Accept NDJSON input for multi-turn |
| `--allowedTools` | Comma-separated list of allowed tools |
| `--max-turns` | Maximum conversation turns |
| `--model` | Model to use (sonnet, opus, haiku) |
| `--verbose` | Include additional metadata |
| `--resume <session-id>` | Resume existing session |
| `--dangerously-skip-permissions` | Skip all permission prompts (CI only) |

---

## 2. Stream Format

### 2.1 NDJSON Structure

Each line is a complete, self-contained JSON object:

```
{"type":"init",...}\n
{"type":"user",...}\n
{"type":"assistant",...}\n
{"type":"assistant",...}\n
{"type":"result",...}\n
```

### 2.2 Common Envelope Fields

Every event contains these fields:

```typescript
interface EventEnvelope {
  // Required fields
  type: EventType;                    // Discriminator
  timestamp: string;                  // ISO 8601 timestamp
  uuid: string;                       // Unique event ID
  sessionId: string;                  // Session identifier

  // Common optional fields
  parentUuid?: string;                // Parent event for threading
  isSidechain?: boolean;              // Sub-agent/task events
  cwd?: string;                       // Working directory
  version?: string;                   // CLI version
  gitBranch?: string;                 // Current git branch
  userType?: "external" | "internal"; // Event source type
}
```

### 2.3 Event Type Discriminator

```typescript
type EventType =
  | "init"           // Session initialization
  | "user"           // User message
  | "assistant"      // Assistant response (streaming)
  | "system"         // System message
  | "result"         // Final result with stats
  | "summary"        // Session summary
  | "error";         // Error event
```

---

## 3. Event Types

### 3.1 Init Event

Emitted once at the start of a session.

```typescript
interface InitEvent extends EventEnvelope {
  type: "init";
  message: {
    sessionId: string;
    version: string;
    model: string;
    cwd: string;
    capabilities: string[];
    allowedTools: string[];
  };
}
```

**Example:**
```json
{
  "type": "init",
  "timestamp": "2025-12-25T10:00:00.000Z",
  "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "sessionId": "74192f7a-6bb9-4189-9387-99b4fb24fac6",
  "version": "1.0.58",
  "message": {
    "sessionId": "74192f7a-6bb9-4189-9387-99b4fb24fac6",
    "version": "1.0.58",
    "model": "claude-opus-4-20250514",
    "cwd": "/Users/dev/myproject",
    "capabilities": ["streaming", "tools", "vision"],
    "allowedTools": ["Bash", "Edit", "Read", "Write"]
  }
}
```

### 3.2 User Event

Represents user input to the conversation.

```typescript
interface UserEvent extends EventEnvelope {
  type: "user";
  message: {
    role: "user";
    content: string | ContentBlock[];
  };
  isMeta?: boolean;  // True for slash command expansions
}

type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; source: ImageSource }
  | { type: "tool_result"; tool_use_id: string; content: any; is_error?: boolean };
```

**Example (simple):**
```json
{
  "type": "user",
  "timestamp": "2025-12-25T10:00:01.000Z",
  "uuid": "user-uuid-1",
  "sessionId": "session-123",
  "parentUuid": null,
  "message": {
    "role": "user",
    "content": "Add a login page to my React app"
  }
}
```

**Example (with tool result):**
```json
{
  "type": "user",
  "timestamp": "2025-12-25T10:00:10.000Z",
  "uuid": "user-uuid-2",
  "sessionId": "session-123",
  "parentUuid": "assistant-uuid-1",
  "message": {
    "role": "user",
    "content": [{
      "type": "tool_result",
      "tool_use_id": "toolu_01ABC123",
      "content": [{"type": "text", "text": "File created successfully"}],
      "is_error": false
    }]
  },
  "toolUseResult": {
    "content": [{"type": "text", "text": "File created successfully"}],
    "totalDurationMs": 1250,
    "totalTokens": 500,
    "totalToolUseCount": 1,
    "wasInterrupted": false
  }
}
```

### 3.3 Assistant Event

Represents model output. Multiple events are emitted as streaming progresses.

```typescript
interface AssistantEvent extends EventEnvelope {
  type: "assistant";
  requestId: string;                  // API request ID
  message: {
    id: string;                       // Message ID
    type: "message";
    role: "assistant";
    model: string;
    content: AssistantContentBlock[];
    stop_reason: "end_turn" | "tool_use" | "max_tokens" | null;
    stop_sequence: string | null;
    usage: UsageStats;
  };
}

type AssistantContentBlock =
  | { type: "text"; text: string }
  | { type: "tool_use"; id: string; name: string; input: Record<string, any> }
  | { type: "thinking"; thinking: string };  // Extended thinking

interface UsageStats {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number;
  cache_read_input_tokens?: number;
  service_tier?: string;
}
```

**Example (streaming text):**
```json
{
  "type": "assistant",
  "timestamp": "2025-12-25T10:00:02.000Z",
  "uuid": "assistant-uuid-1",
  "sessionId": "session-123",
  "parentUuid": "user-uuid-1",
  "requestId": "req_011CRPBKFm3dXkTST6NgC1a3",
  "message": {
    "id": "msg_01DVbhK5xcQCKgNuVdHrNkpn",
    "type": "message",
    "role": "assistant",
    "model": "claude-opus-4-20250514",
    "content": [
      {"type": "text", "text": "I'll help you create a login page. Let me "}
    ],
    "stop_reason": null,
    "stop_sequence": null,
    "usage": {
      "input_tokens": 150,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0,
      "output_tokens": 12
    }
  }
}
```

**Example (with tool use):**
```json
{
  "type": "assistant",
  "timestamp": "2025-12-25T10:00:05.000Z",
  "uuid": "assistant-uuid-2",
  "sessionId": "session-123",
  "parentUuid": "assistant-uuid-1",
  "requestId": "req_011CRPBKFm3dXkTST6NgC1a3",
  "message": {
    "id": "msg_01DVbhK5xcQCKgNuVdHrNkpn",
    "type": "message",
    "role": "assistant",
    "model": "claude-opus-4-20250514",
    "content": [
      {"type": "text", "text": "I'll create the login component now."},
      {
        "type": "tool_use",
        "id": "toolu_01ABC123",
        "name": "Write",
        "input": {
          "file_path": "/src/components/Login.tsx",
          "content": "import React from 'react';\n..."
        }
      }
    ],
    "stop_reason": "tool_use",
    "stop_sequence": null,
    "usage": {
      "input_tokens": 150,
      "output_tokens": 250
    }
  }
}
```

### 3.4 Result Event

Final event containing session statistics. **This event signals completion.**

```typescript
interface ResultEvent extends EventEnvelope {
  type: "result";
  result: {
    success: boolean;
    exitCode: number;
    duration_ms: number;
    num_turns: number;
    session_id: string;
  };
  cost_usd?: number;
  usage: {
    input_tokens: number;
    output_tokens: number;
    cache_creation_input_tokens: number;
    cache_read_input_tokens: number;
    total_tokens: number;
  };
  subtype?: "success" | "error_max_turns" | "error_cancelled" | "error_api";
}
```

**Example:**
```json
{
  "type": "result",
  "timestamp": "2025-12-25T10:01:00.000Z",
  "uuid": "result-uuid-1",
  "sessionId": "session-123",
  "result": {
    "success": true,
    "exitCode": 0,
    "duration_ms": 59000,
    "num_turns": 5,
    "session_id": "session-123"
  },
  "cost_usd": 0.045,
  "usage": {
    "input_tokens": 5000,
    "output_tokens": 2500,
    "cache_creation_input_tokens": 1000,
    "cache_read_input_tokens": 500,
    "total_tokens": 9000
  },
  "subtype": "success"
}
```

### 3.5 Summary Event

Emitted with session summary for display.

```typescript
interface SummaryEvent extends EventEnvelope {
  type: "summary";
  summary: string;
  leafUuid: string;  // UUID of the final message
}
```

**Example:**
```json
{
  "type": "summary",
  "timestamp": "2025-12-25T10:01:01.000Z",
  "uuid": "summary-uuid-1",
  "sessionId": "session-123",
  "summary": "Created Login component with form validation",
  "leafUuid": "assistant-uuid-final"
}
```

### 3.6 System Event

System-level messages (errors, warnings, status).

```typescript
interface SystemEvent extends EventEnvelope {
  type: "system";
  message: {
    level: "info" | "warn" | "error";
    text: string;
    code?: string;
    details?: any;
  };
}
```

---

## 4. Event Payloads

### 4.1 Tool Use Payloads

Each tool has a specific input schema:

#### Bash Tool
```typescript
interface BashToolInput {
  command: string;
  description?: string;
  timeout?: number;
  run_in_background?: boolean;
}
```

#### Read Tool
```typescript
interface ReadToolInput {
  file_path: string;
  offset?: number;
  limit?: number;
}
```

#### Write Tool
```typescript
interface WriteToolInput {
  file_path: string;
  content: string;
}
```

#### Edit Tool
```typescript
interface EditToolInput {
  file_path: string;
  old_string: string;
  new_string: string;
  replace_all?: boolean;
}
```

#### Glob Tool
```typescript
interface GlobToolInput {
  pattern: string;
  path?: string;
}
```

#### Grep Tool
```typescript
interface GrepToolInput {
  pattern: string;
  path?: string;
  glob?: string;
  output_mode?: "content" | "files_with_matches" | "count";
}
```

#### Task Tool (Sub-agent)
```typescript
interface TaskToolInput {
  description: string;
  prompt: string;
  subagent_type?: string;
  run_in_background?: boolean;
}
```

#### TodoWrite Tool
```typescript
interface TodoWriteToolInput {
  todos: Array<{
    content: string;
    status: "pending" | "in_progress" | "completed";
    activeForm: string;
  }>;
}
```

### 4.2 Tool Result Payloads

```typescript
interface ToolResult {
  tool_use_id: string;
  content: Array<{
    type: "text";
    text: string;
  }>;
  is_error: boolean;
}

interface ToolUseResultMeta {
  content: any[];
  totalDurationMs: number;
  totalTokens: number;
  totalToolUseCount: number;
  wasInterrupted: boolean;
  usage?: UsageStats;
}
```

---

## 5. Event Sequences

### 5.1 Simple Turn (No Tools)

```
init
  └─► user (prompt)
        └─► assistant (streaming text...)
              └─► assistant (final, stop_reason: "end_turn")
                    └─► result
```

### 5.2 Turn with Tool Use

```
init
  └─► user (prompt)
        └─► assistant (text + tool_use, stop_reason: "tool_use")
              └─► [Tool executes externally]
                    └─► user (tool_result)
                          └─► assistant (continue with result...)
                                └─► assistant (final, stop_reason: "end_turn")
                                      └─► result
```

### 5.3 Multi-Turn Session

```
init
  └─► user (turn 1)
        └─► assistant (response 1)
              └─► user (turn 2)
                    └─► assistant (tool_use)
                          └─► user (tool_result)
                                └─► assistant (response 2)
                                      └─► user (turn 3)
                                            └─► assistant (final)
                                                  └─► result
```

### 5.4 Sub-Agent (Task Tool)

```
assistant (tool_use: Task)
  │
  ├─► user (sidechain) [isSidechain: true]
  │     └─► assistant (sidechain)
  │           └─► ... (sub-agent conversation)
  │                 └─► assistant (sidechain final)
  │
  └─► user (tool_result with sub-agent output)
        └─► assistant (continues main conversation)
```

### 5.5 Event Threading via parentUuid

```
uuid: "a"  (init)
  │
uuid: "b"  parentUuid: "a"  (user)
  │
uuid: "c"  parentUuid: "b"  (assistant - partial)
  │
uuid: "d"  parentUuid: "c"  (assistant - with tool)
  │
uuid: "e"  parentUuid: "d"  (user - tool result)
  │
uuid: "f"  parentUuid: "e"  (assistant - final)
  │
uuid: "g"  parentUuid: "f"  (result)
```

---

## 6. Parsing Guidelines

### 6.1 Swift NDJSON Parser

```swift
actor NDJSONParser {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    func parse(chunk: Data) throws -> [StreamEvent] {
        buffer.append(chunk)
        var events: [StreamEvent] = []

        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[..<newlineIndex]
            buffer = buffer[(newlineIndex + 1)...]

            guard !lineData.isEmpty else { continue }

            do {
                let event = try decoder.decode(StreamEvent.self, from: lineData)
                events.append(event)
            } catch {
                // Log but don't crash on parse errors
                Logger.warning("Failed to parse NDJSON line: \(error)")
            }
        }

        return events
    }

    func flush() throws -> [StreamEvent] {
        guard !buffer.isEmpty else { return [] }
        let remaining = buffer
        buffer = Data()

        // Try to parse remaining buffer as final event
        do {
            let event = try decoder.decode(StreamEvent.self, from: remaining)
            return [event]
        } catch {
            Logger.warning("Unparsed data in buffer: \(String(data: remaining, encoding: .utf8) ?? "<binary>")")
            return []
        }
    }
}
```

### 6.2 Event Type Discrimination

```swift
enum StreamEvent: Decodable {
    case `init`(InitEvent)
    case user(UserEvent)
    case assistant(AssistantEvent)
    case result(ResultEvent)
    case summary(SummaryEvent)
    case system(SystemEvent)
    case unknown(RawEvent)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "init":
            self = .init(try InitEvent(from: decoder))
        case "user":
            self = .user(try UserEvent(from: decoder))
        case "assistant":
            self = .assistant(try AssistantEvent(from: decoder))
        case "result":
            self = .result(try ResultEvent(from: decoder))
        case "summary":
            self = .summary(try SummaryEvent(from: decoder))
        case "system":
            self = .system(try SystemEvent(from: decoder))
        default:
            self = .unknown(try RawEvent(from: decoder))
        }
    }
}
```

### 6.3 Handling Streaming Text

```swift
class AssistantMessageAssembler {
    private var currentMessageId: String?
    private var accumulatedText: String = ""
    private var toolUses: [ToolUse] = []

    func process(_ event: AssistantEvent) -> AssistantUpdate {
        let message = event.message

        if currentMessageId != message.id {
            // New message started
            currentMessageId = message.id
            accumulatedText = ""
            toolUses = []
        }

        for block in message.content {
            switch block {
            case .text(let textBlock):
                accumulatedText = textBlock.text  // Note: Claude sends full text, not deltas
            case .toolUse(let toolBlock):
                toolUses.append(toolBlock)
            case .thinking(let thinkBlock):
                // Handle extended thinking
            }
        }

        return AssistantUpdate(
            messageId: message.id,
            text: accumulatedText,
            toolUses: toolUses,
            isComplete: message.stop_reason != nil,
            stopReason: message.stop_reason,
            usage: message.usage
        )
    }
}
```

### 6.4 Timeout Handling

```swift
class StreamWatcher {
    let eventTimeout: TimeInterval = 60  // Seconds without events
    let resultTimeout: TimeInterval = 300  // Total session timeout
    private var lastEventTime: Date = Date()

    func checkTimeouts() throws {
        let now = Date()
        let sinceLastEvent = now.timeIntervalSince(lastEventTime)

        if sinceLastEvent > eventTimeout {
            throw StreamError.eventTimeout(seconds: sinceLastEvent)
        }
    }

    func receivedEvent() {
        lastEventTime = Date()
    }
}
```

---

## 7. Error Handling

### 7.1 Known Issues

| Issue | Description | Mitigation |
|-------|-------------|------------|
| Missing result event | CLI may hang without emitting final result | Implement timeout + process monitoring |
| Partial JSON lines | Network/buffer issues cause incomplete lines | Buffer until newline received |
| Empty events | Occasional empty JSON objects | Skip events with missing required fields |
| Duplicate events | Same event emitted multiple times | Dedupe by uuid |

### 7.2 Error Event Structure

```json
{
  "type": "system",
  "timestamp": "2025-12-25T10:00:30.000Z",
  "uuid": "error-uuid-1",
  "sessionId": "session-123",
  "message": {
    "level": "error",
    "text": "Rate limit exceeded",
    "code": "rate_limit_error",
    "details": {
      "retry_after": 60
    }
  }
}
```

### 7.3 Graceful Degradation

```swift
class RobustStreamHandler {
    func handleEvent(_ event: StreamEvent) {
        switch event {
        case .unknown(let raw):
            // Log unknown event types for future compatibility
            Logger.info("Unknown event type: \(raw.type)")
            // Attempt to extract useful info anyway
            if let payload = raw.payload {
                handleRawPayload(payload)
            }

        case .assistant(let assistant) where assistant.message.content.isEmpty:
            // Skip empty assistant events (heartbeat)
            return

        default:
            processEvent(event)
        }
    }
}
```

---

## 8. Version History

### 8.1 CLI Version Compatibility

| CLI Version | Breaking Changes | New Features |
|-------------|------------------|--------------|
| 2.0.62+ | Baseline for Blaze | `--output-format stream-json` |
| 1.0.58+ | - | Session resumption, Task tool |
| 1.0.50+ | - | Extended thinking content block |
| 1.0.33+ | - | `toolUseResult` metadata |

### 8.2 Schema Version

The stream format is versioned in the `init` event:

```json
{
  "type": "init",
  "version": "1.0.58",
  "message": {
    "schemaVersion": "1.0"
  }
}
```

### 8.3 Future Considerations

| Feature | Expected Version | Impact |
|---------|------------------|--------|
| Structured output mode | TBD | New `structured_output` field in result |
| Diff events | TBD | Dedicated diff event type |
| Approval requests | TBD | Permission request events |

---

## Appendix A: Full TypeScript Definitions

```typescript
// Complete type definitions for Claude Code stream-json

export interface EventEnvelope {
  type: EventType;
  timestamp: string;
  uuid: string;
  sessionId: string;
  parentUuid?: string;
  isSidechain?: boolean;
  cwd?: string;
  version?: string;
  gitBranch?: string;
  userType?: "external" | "internal";
}

export type EventType = "init" | "user" | "assistant" | "result" | "summary" | "system";

export interface InitEvent extends EventEnvelope {
  type: "init";
  message: {
    sessionId: string;
    version: string;
    model: string;
    cwd: string;
    capabilities: string[];
    allowedTools: string[];
  };
}

export interface UserEvent extends EventEnvelope {
  type: "user";
  message: {
    role: "user";
    content: string | ContentBlock[];
  };
  isMeta?: boolean;
  toolUseResult?: ToolUseResultMeta;
}

export interface AssistantEvent extends EventEnvelope {
  type: "assistant";
  requestId: string;
  message: {
    id: string;
    type: "message";
    role: "assistant";
    model: string;
    content: AssistantContentBlock[];
    stop_reason: "end_turn" | "tool_use" | "max_tokens" | null;
    stop_sequence: string | null;
    usage: UsageStats;
  };
}

export interface ResultEvent extends EventEnvelope {
  type: "result";
  result: {
    success: boolean;
    exitCode: number;
    duration_ms: number;
    num_turns: number;
    session_id: string;
  };
  cost_usd?: number;
  usage: UsageStats & { total_tokens: number };
  subtype?: "success" | "error_max_turns" | "error_cancelled" | "error_api";
}

export interface SummaryEvent extends EventEnvelope {
  type: "summary";
  summary: string;
  leafUuid: string;
}

export interface SystemEvent extends EventEnvelope {
  type: "system";
  message: {
    level: "info" | "warn" | "error";
    text: string;
    code?: string;
    details?: unknown;
  };
}

export type ContentBlock =
  | { type: "text"; text: string }
  | { type: "image"; source: { type: "base64"; media_type: string; data: string } }
  | { type: "tool_result"; tool_use_id: string; content: unknown[]; is_error?: boolean };

export type AssistantContentBlock =
  | { type: "text"; text: string }
  | { type: "tool_use"; id: string; name: string; input: Record<string, unknown> }
  | { type: "thinking"; thinking: string };

export interface UsageStats {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number;
  cache_read_input_tokens?: number;
  service_tier?: string;
}

export interface ToolUseResultMeta {
  content: unknown[];
  totalDurationMs: number;
  totalTokens: number;
  totalToolUseCount: number;
  wasInterrupted: boolean;
  usage?: UsageStats;
}
```

---

## Appendix B: Sample Session Capture

```jsonl
{"type":"init","timestamp":"2025-12-25T10:00:00.000Z","uuid":"init-1","sessionId":"sess-abc","version":"1.0.58","message":{"sessionId":"sess-abc","version":"1.0.58","model":"claude-opus-4","cwd":"/project","capabilities":["streaming","tools"],"allowedTools":["Bash","Read","Write"]}}
{"type":"user","timestamp":"2025-12-25T10:00:01.000Z","uuid":"user-1","sessionId":"sess-abc","parentUuid":"init-1","message":{"role":"user","content":"Create a hello.py file"}}
{"type":"assistant","timestamp":"2025-12-25T10:00:02.000Z","uuid":"asst-1","sessionId":"sess-abc","parentUuid":"user-1","requestId":"req-1","message":{"id":"msg-1","type":"message","role":"assistant","model":"claude-opus-4","content":[{"type":"text","text":"I'll create a hello.py file for you."}],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":100,"output_tokens":15}}}
{"type":"assistant","timestamp":"2025-12-25T10:00:03.000Z","uuid":"asst-2","sessionId":"sess-abc","parentUuid":"asst-1","requestId":"req-1","message":{"id":"msg-1","type":"message","role":"assistant","model":"claude-opus-4","content":[{"type":"text","text":"I'll create a hello.py file for you."},{"type":"tool_use","id":"toolu-1","name":"Write","input":{"file_path":"hello.py","content":"print('Hello, World!')"}}],"stop_reason":"tool_use","stop_sequence":null,"usage":{"input_tokens":100,"output_tokens":50}}}
{"type":"user","timestamp":"2025-12-25T10:00:04.000Z","uuid":"user-2","sessionId":"sess-abc","parentUuid":"asst-2","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu-1","content":[{"type":"text","text":"File created successfully"}],"is_error":false}]},"toolUseResult":{"content":[{"type":"text","text":"File created successfully"}],"totalDurationMs":150,"totalTokens":5,"totalToolUseCount":1,"wasInterrupted":false}}
{"type":"assistant","timestamp":"2025-12-25T10:00:05.000Z","uuid":"asst-3","sessionId":"sess-abc","parentUuid":"user-2","requestId":"req-2","message":{"id":"msg-2","type":"message","role":"assistant","model":"claude-opus-4","content":[{"type":"text","text":"I've created hello.py with a simple Hello World program."}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":120,"output_tokens":20}}}
{"type":"result","timestamp":"2025-12-25T10:00:06.000Z","uuid":"result-1","sessionId":"sess-abc","result":{"success":true,"exitCode":0,"duration_ms":6000,"num_turns":1,"session_id":"sess-abc"},"cost_usd":0.005,"usage":{"input_tokens":220,"output_tokens":85,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"total_tokens":305},"subtype":"success"}
```

---

**Sources:**
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Claude Streaming Messages Documentation](https://platform.claude.com/docs/en/build-with-claude/streaming)
- [GitHub Issue #1920 - Missing Result Event](https://github.com/anthropics/claude-code/issues/1920)

---

**End of Document**

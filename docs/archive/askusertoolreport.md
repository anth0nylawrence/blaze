# Technical Report: AskUserQuestion Tool Response Mechanism

**Prepared for:** Senior Architect / CTO Specialist
**Subject:** Interactive Tool Prompts in Cogit0 Blaze - Claude Code Harness
**Repository:** `cogit0-blaze`
**Date:** 2026-01-03

---

## Executive Summary

Cogit0 Blaze is a native macOS SwiftUI application that acts as a structured event renderer for the Claude Code CLI. Rather than calling provider APIs directly, it spawns the CLI process with `--output-format stream-json` and parses NDJSON events to render a polished desktop UX.

We have implemented a complete bidirectional communication pipeline for interactive tool prompts (specifically `AskUserQuestion`). The UI successfully renders the prompt card, users can select options, and the response is correctly formatted and sent to the CLI's stdin. However, **the response is not being processed by the CLI as expected**.

---

## Architecture Overview

### Event Flow Pipeline

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Claude CLI Process                           │
│  claude -p "..." --output-format stream-json --input-format stream-json  │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ stdout (NDJSON events)
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       PtyProcessRunner.swift                          │
│  - Uses forkpty() for PTY-based bidirectional I/O                     │
│  - Non-blocking reads via readLines()                                 │
│  - Direct write to PTY master FD                                      │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ [String] lines
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        NDJSONParser.swift                             │
│  - Buffers partial lines until newline                                │
│  - Splits concatenated JSON objects                                   │
│  - Decodes to ClaudeStreamEvent discriminated union                   │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ ClaudeStreamEvent
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      ClaudeEventMapper.swift                          │
│  - Maps ClaudeStreamEvent → NormalizedEvent                           │
│  - Tracks active tool calls for duration calculation                  │
│  - Emits: toolCallStarted, toolCallComplete, assistantDelta, etc.     │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ NormalizedEvent
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    SessionOrchestrator.swift                          │
│  - Coordinates turn execution                                         │
│  - Routes events through ToolApprovalPipeline and HookRunner          │
│  - Persists to EventStore                                             │
│  - Calls appState.appendEvent() for UI reactivity                     │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         BlazeApp.swift                                │
│  AppState.sendMessage() → processes stream:                          │
│    case .toolCallStarted(let started):                                │
│      if started.toolName == "AskUserQuestion":                        │
│        parseAskUserQuestion(...) → enqueueToolPrompt(prompt)          │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       ToolPromptCard.swift                            │
│  - Renders interactive option selection UI                            │
│  - Supports singleSelect, multiSelect, freeText response types        │
│  - Calls onSubmit(response) when user clicks Submit                   │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ ToolPromptResponse
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   AppState.submitPromptResponse()                     │
│  - Converts response to content string                                │
│  - Calls adapter.sendToolResult(toolUseId, content)                   │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│              ClaudeCodeAdapter.sendToolResult()                       │
│  - Builds ToolResultEnvelope with session_id, tool_use_id, content    │
│  - Calls stdinWriter.sendJSONLine(envelope)                           │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      StdinWriter.swift                                │
│  - JSON encodes envelope to NDJSON line                               │
│  - Writes to PTY master FD via runner.write(data)                     │
│  - Fail-fast on EPIPE                                                 │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │ NDJSON to CLI stdin
                                 ▼
                         [ Claude CLI Process ]
```

---

## Key Implementation Details

### 1. PTY-Based Process Runner (`PtyProcessRunner.swift:26-314`)

We use `forkpty()` instead of standard `Pipe` to create a pseudo-terminal:

```swift
public func spawn(executable: String, arguments: [String], ...) throws {
    pid = forkpty(&masterFD, nil, nil, &ws)
    // ...
    // Parent: set non-blocking for reads
    fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)
}
```

**Why PTY?** When stdin is a pipe (not TTY), the CLI exhibits different buffering behavior. PTY gives the CLI a proper TTY, enabling bidirectional streaming without deadlock.

Key methods:
- `readLines()` - Non-blocking line-buffered reads, handles CRLF from PTY
- `write(_ data: Data)` - Direct write to PTY master, detects EPIPE/EIO
- `isRunning` - Uses `waitpid(..., WNOHANG)` to check process state

### 2. NDJSON Parser (`NDJSONParser.swift:37-233`)

Handles the stream-json output format:

```swift
func parse(chunk: Data) -> [ClaudeStreamEvent] {
    buffer.append(chunk)
    var events: [ClaudeStreamEvent] = []

    while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
        let lineData = buffer[..<newlineIndex]
        buffer = Data(buffer[(newlineIndex + 1)...])

        // Handle concatenated JSON objects (PTY merging)
        let jsonChunks = splitConcatenatedJSON(Data(lineData))
        for jsonData in jsonChunks {
            if let event = parseEvent(from: jsonData, lineNumber: lineCount) {
                events.append(event)
            }
        }
    }
    return events
}
```

**Notable:** We handle concatenated JSON objects (`{...}{...}` on single line) that occur when PTY merges rapid CLI writes.

### 3. Claude Event Mapper (`ClaudeEventMapper.swift:7-438`)

Maps raw Claude events to normalized events. For tool calls:

```swift
case .toolUse(let toolBlock):
    activeToolCalls[toolBlock.id] = ToolCallState(
        name: toolBlock.name,
        input: inputJson,
        startTime: event.timestamp
    )

    events.append(.toolCallStarted(ToolCallStarted(
        toolCallId: toolBlock.id,
        toolName: toolBlock.name,
        input: inputJson,
        timestamp: event.timestamp
    )))
```

### 4. AskUserQuestion Detection (`BlazeApp.swift:747-755`)

In the event stream processing:

```swift
case .toolCallStarted(let started):
    if started.toolName == "AskUserQuestion" {
        if let prompt = self.parseAskUserQuestion(
            toolCallId: started.toolCallId,
            input: started.input,
            timestamp: started.timestamp
        ) {
            self.enqueueToolPrompt(prompt)  // Routes to ToolPromptCard
        }
    }
```

### 5. ToolPromptCard UI (`ToolPromptCard.swift:1-475`)

A SwiftUI component that renders the interactive prompt:

```swift
public struct ToolPromptCard: View {
    let prompt: ToolPromptEvent
    let submissionState: SubmissionState
    let onSubmit: (ToolPromptResponse) -> Void

    @State private var selectedOptionIds: Set<String> = []

    // Renders options as radio buttons or checkboxes
    // Submit button calls onSubmit(response)
}
```

Submission states: `.idle`, `.submitting`, `.submitted`, `.failed(String)`

### 6. Tool Result Envelope (`StdinWriter.swift:115-180`)

The envelope format sent back to CLI:

```swift
public struct ToolResultEnvelope: Encodable, Sendable {
    // Output format:
    // {
    //   "type": "user",
    //   "session_id": "...",
    //   "parent_tool_use_id": null,
    //   "message": {
    //     "role": "user",
    //     "content": [{
    //       "type": "tool_result",
    //       "tool_use_id": "...",
    //       "content": "...",
    //       "is_error": false
    //     }]
    //   }
    // }
}
```

### 7. Response Submission (`ClaudeCodeAdapter.swift:356-386`)

```swift
func sendToolResult(toolUseId: String, content: String, isError: Bool = false) async throws {
    guard isInteractiveMode else {
        throw EngineError.unknown("Cannot send tool result: not in interactive mode")
    }

    let envelope = ToolResultEnvelope(
        sessionId: sessionId,
        parentToolUseId: nil,
        toolUseId: toolUseId,
        content: content,
        isError: isError
    )

    try await writer.sendJSONLine(envelope)
}
```

---

## CLI Invocation

The adapter spawns the CLI with these flags (`ClaudeCodeAdapter.swift:249`):

```swift
var args = [
    "-p", prompt,
    "--output-format", "stream-json",
    "--input-format", "stream-json",
    "--verbose"
]
```

---

## Observed Behavior

### What Works

1. CLI spawns successfully with PTY
2. NDJSON events stream and parse correctly
3. `toolCallStarted` events for `AskUserQuestion` are detected
4. `ToolPromptCard` renders in the UI with correct options
5. User can select options and click Submit
6. `ToolResultEnvelope` is correctly JSON-encoded
7. Write to PTY master succeeds (no EPIPE during write)

### What Fails

When the user submits their selection:

1. The `sendToolResult()` method succeeds (no exception)
2. The stdin write completes without EPIPE
3. **Shortly after**, the CLI process exits
4. `isRunning` becomes `false`
5. No `toolCallComplete` event is received for AskUserQuestion
6. The `result` event shows the turn ended

**Debug Logs (from `PtyProcessRunner.swift:228-232`):**

```
[PTY] isRunning: false - waitpid=<pid>, status=0, exitCode=0
[Adapter] PTY polling loop EXITED after N polls - isRunning became false
```

The process exits with code 0 (success) before our tool_result can be processed.

---

## Timing Analysis

The sequence observed is:

```
T+0ms:    CLI emits assistant message with tool_use (AskUserQuestion)
T+50ms:   Our UI receives toolCallStarted event
T+100ms:  ToolPromptCard renders, user sees options
T+???ms:  User selects option, clicks Submit
T+???ms:  We send tool_result via stdin
T+???ms:  CLI process exits (code 0)
```

The question is: **Why does the CLI exit before waiting for our stdin input?**

---

## Tested Permission Modes

We've tested various CLI permission configurations:

| Mode | Flag | Observation |
|------|------|-------------|
| default | (none) | Process exits shortly after tool_use emission |
| bypassPermissions | `--dangerously-skip-permissions` | Same behavior |
| dontAsk | `--permission-mode dontAsk` | Same behavior |
| delegate | `--permission-mode delegate` | Tools array is empty in system.init |

---

## Questions for Investigation

1. **Is `--input-format stream-json` sufficient for tool_result ingestion?**
   The docs suggest this enables stdin reading, but does the CLI actually wait for stdin input after emitting a tool_use?

2. **Is there a blocking read mechanism we need to trigger?**
   Perhaps the CLI requires a specific stdin message format to enter "waiting for input" mode?

3. **Does the CLI's headless mode (`-p` flag) affect tool_result handling differently than interactive mode?**
   We're using the print/headless mode rather than the full interactive session.

4. **Is there a timing race?**
   Perhaps we need to send the tool_result before the CLI finishes processing the tool_use block?

5. **Are there hooks or callbacks in the CLI that need to be configured?**
   The `system.init` event shows hook configuration - is there a permission hook for AskUserQuestion?

---

## Relevant Code References

| Component | File | Lines |
|-----------|------|-------|
| PTY spawn & polling | `PtyProcessRunner.swift` | 40-102, 282-309 |
| Stdin write | `PtyProcessRunner.swift` | 181-211 |
| Tool result envelope | `StdinWriter.swift` | 115-180 |
| Adapter sendToolResult | `ClaudeCodeAdapter.swift` | 356-386 |
| PTY turn execution | `ClaudeCodeAdapter.swift` | 247-340 |
| AskUserQuestion detection | `BlazeApp.swift` | 747-755, 1038-1071 |
| Prompt submission | `BlazeApp.swift` | 966-1006 |
| ToolPromptCard UI | `ToolPromptCard.swift` | 1-228 |

---

## Fixture Data

We have captured NDJSON fixtures from real CLI runs in:
- `Blaze/Tests/Fixtures/NDJSON/v2.0.76/`

The `AskUserQuestion` tool_use event structure:

```json
{
  "type": "assistant",
  "message": {
    "content": [{
      "type": "tool_use",
      "id": "toolu_...",
      "name": "AskUserQuestion",
      "input": {
        "questions": [{
          "question": "Which approach?",
          "header": "Solution",
          "options": [
            {"label": "Option A", "description": "..."},
            {"label": "Option B", "description": "..."}
          ],
          "multiSelect": false
        }]
      }
    }]
  }
}
```

---

## Request

We're seeking guidance on:

1. The expected protocol for tool_result submission in headless/stream-json mode
2. Whether there's additional CLI configuration needed for interactive tools
3. If the Agent SDK provides different capabilities for this use case

---

## Attachments

- Uncommitted debug logging in `PtyProcessRunner.swift`, `ClaudeCodeAdapter.swift`, `StdinWriter.swift`
- Latest handoff: `thoughts/shared/handoffs/cogit0-blaze/2026-01-03_15-06-41_askuserquestion-cli-limitation-discovered.md`

---

## Appendix: Full Source Code References

### ToolPromptTypes.swift

```swift
// MARK: - Tool Prompt Types

/// Option in a tool prompt (e.g., for AskUserQuestion)
public struct ToolPromptOption: Codable, Sendable, Identifiable {
    public let id: String           // Preferred for tool_result response
    public let label: String        // Display text
    public let description: String? // Optional explanation
}

/// Response type for tool prompts
public enum ToolPromptResponseType: String, Codable, Sendable {
    case singleSelect   // Radio buttons, one choice
    case multiSelect    // Checkboxes, multiple choices
    case freeText       // Text input (fallback for unknown tools)
}

/// Generic tool prompt event (works for any interactive tool)
public struct ToolPromptEvent: Codable, Sendable, Identifiable {
    public var id: String { toolUseId }

    public let toolUseId: String
    public let toolName: String
    public let title: String?
    public let body: String?
    public let options: [ToolPromptOption]
    public let responseType: ToolPromptResponseType
    public let rawInput: String      // Original JSON for debugging
    public let timestamp: Date

    /// Whether this prompt has no options and needs free-text input
    public var requiresFreeText: Bool {
        options.isEmpty || responseType == .freeText
    }
}

/// User's selection (for option-based prompts)
public struct ToolPromptSelection: Codable, Sendable {
    public let id: String
    public let label: String
}

/// User's response (covers both selections and free-text)
public enum ToolPromptResponse: Codable, Sendable {
    case selections([ToolPromptSelection])
    case freeText(String)
}

/// State machine for prompt submission
public enum SubmissionState: Equatable, Sendable {
    case idle           // Not yet submitted
    case submitting     // In progress
    case submitted      // Successfully sent
    case failed(String) // Failed with error message
}
```

### parseAskUserQuestion Implementation

```swift
/// Parse AskUserQuestion tool input JSON into a ToolPromptEvent
private func parseAskUserQuestion(toolCallId: String, input: String, timestamp: Date) -> ToolPromptEvent? {
    // Expected format: {"questions":[{"question":"...","header":"...","options":[{"label":"...","description":"..."}],"multiSelect":false}]}
    guard let data = input.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let questions = json["questions"] as? [[String: Any]],
          let firstQuestion = questions.first else {
        print("[AppState] Failed to parse AskUserQuestion input: \(input)")
        return nil
    }

    let questionText = firstQuestion["question"] as? String ?? ""
    let header = firstQuestion["header"] as? String
    let multiSelect = firstQuestion["multiSelect"] as? Bool ?? false
    let rawOptions = firstQuestion["options"] as? [[String: Any]] ?? []

    // Convert options to ToolPromptOption
    let options: [ToolPromptOption] = rawOptions.enumerated().map { index, opt in
        let label = opt["label"] as? String ?? "Option \(index + 1)"
        let description = opt["description"] as? String
        // Use label as ID since fixture doesn't have explicit IDs
        return ToolPromptOption(id: label, label: label, description: description)
    }

    return ToolPromptEvent(
        toolUseId: toolCallId,
        toolName: "AskUserQuestion",
        title: header,
        body: questionText,
        options: options,
        responseType: multiSelect ? .multiSelect : .singleSelect,
        rawInput: input,
        timestamp: timestamp
    )
}
```

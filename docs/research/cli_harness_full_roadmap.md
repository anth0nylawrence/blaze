# CLI Harness (macOS Native) — Full Roadmap (Claude v1 → Gemini v2 → Codex v3)

## What you’re building (one sentence)
A native macOS Swift app that **runs existing “agentic coding CLIs” as child processes** (Claude Code first), **parses their structured streaming output**, and renders a **buttery, Linear/Raycast/Zed‑style UI**—without re‑implementing the providers’ APIs in your app.

---

## Strategic framing (why this is not “three apps”)
All three targets (Claude Code, Gemini CLI, OpenAI Codex CLI) already behave like **agents** that:
1) maintain a conversation state,  
2) call tools (shell / filesystem / web / MCP),  
3) stream progress, and  
4) have safety/permission gates.  

Your native app is a **harness**: it standardizes *how you launch, observe, persist, and visualize* those agents.

The hard part is not SwiftUI; it’s building a **stable “EngineAdapter” abstraction** so that:
- Claude can be v1 with minimal abstraction debt
- Gemini and Codex become “new adapters,” not “new architectures”

---

## Golden constraints (product rules you should not violate)
1) **Never impersonate provider auth**. The harness only invokes each vendor’s CLI and triggers their own login flow.  
2) **Don’t parse ANSI**. Always prefer each CLI’s structured output mode (JSON / JSONL / stream‑JSON).  
3) **Keep a clean boundary** between “engine state” and “UI state.” The UI can be restarted without losing the engine’s on‑disk session state (when available).  
4) **Be paranoid about security**: file access, sandbox settings, approvals, and secrets must be explicit and visible in UI.

---

## Architecture overview (high level)

```
┌───────────────────────── macOS Native App (SwiftUI) ─────────────────────────┐
│                                                                              │
│  UI Layer:                                                                   │
│   - Chat timeline (streaming bubbles)                                        │
│   - Tool cards + inline diffs + approvals                                    │
│   - Right sidebar (plan, tasks, budget, timeline, sessions)                  │
│   - Command palette (Raycast-style)                                          │
│                                                                              │
│  Orchestration Layer (App Core):                                             │
│   - SessionStore (local DB)                                                  │
│   - ProjectManager (workspace roots, trust, policies)                        │
│   - EngineManager (Claude/Gemini/Codex adapters)                             │
│   - HookRunner (your concurrent automations)                                 │
│   - Telemetry (local-first)                                                  │
│                                                                              │
│  EngineAdapter Layer:                                                        │
│   - ClaudeCodeAdapter                                                        │
│   - GeminiCliAdapter                                                         │
│   - CodexCliAdapter                                                          │
│                                                                              │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ spawn child process / attach pipes
                                    ▼
                  ┌──────────────────────────────────────────────┐
                  │  Provider CLIs (unmodified binaries)         │
                  │  - Claude Code CLI                           │
                  │  - Gemini CLI                                │
                  │  - OpenAI Codex CLI                          │
                  └──────────────────────────────────────────────┘
                                    │
                                    ▼
                      Local repo + local tools + MCP servers
```

---

# EngineAdapter Spec (super detailed)

## 1) Core interfaces

### 1.1 `EngineAdapter` (the contract)
Each engine must implement the same interface so the UI never “knows” which vendor it’s talking to.

**Responsibilities**
- Launch / stop engine processes (headless and/or interactive)
- Ensure authentication status (trigger vendor login UX if needed)
- Stream normalized events (assistant tokens, tool calls, approvals, errors)
- Offer capability discovery + negotiation (tools, sandboxing, sessions)
- Map engine‑specific session persistence into a shared SessionStore

**Pseudo-interface**
```text
protocol EngineAdapter {
  var engineId: EngineId { get }
  func capabilities() async -> EngineCapabilities
  func ensureAuthenticated(context: AuthContext) async throws -> AuthState

  func startSession(config: SessionConfig) async throws -> EngineSessionHandle
  func resumeSession(handle: EngineSessionHandle, config: SessionConfig) async throws -> EngineSessionHandle
  func endSession(handle: EngineSessionHandle) async

  func send(userMessage: UserMessage, to handle: EngineSessionHandle) async throws -> EventStream<NormalizedEvent>
  func cancel(handle: EngineSessionHandle) async
}
```

### 1.2 `EngineCapabilities`
A compact declaration used to “grey out” unsupported UI features.

Fields (minimum):
- `supportsStreamingDeltas` (bool)
- `supportsStructuredEvents` (enum: none | json | jsonl | streamJson)
- `supportsSessionResume` (bool)
- `sessionScope` (enum: global | perProject | perWorkingDir)
- `supportsToolCards` (bool: can infer from events)
- `supportsInlineDiffEvents` (bool)
- `supportsMCPClient` (bool)
- `supportsMCPServer` (bool)
- `supportsWebSearch` (bool + gating)
- `supportsSandboxPolicy` (bool + policy enum)
- `supportsApprovalPolicy` (bool + policy enum)
- `supportsOutputSchema` (bool) — e.g., JSON Schema for final response

### 1.3 `EngineSessionHandle`
An opaque handle you store and pass back later.
- `engineId`
- `engineSessionId` (string) — CLI’s own identifier if available
- `projectId` (your stable project hash)
- `workingDir`
- `createdAt`, `lastUsedAt`
- `engineStateRef` (paths to engine-native state dirs, if any)

---

## 2) Normalized event model (the heart of “buttery UI”)

### 2.1 Why normalize?
Each CLI emits different shapes: you convert them to **one internal event schema** so:
- the chat UI is stable
- tool cards are consistent
- metrics + budgets compare apples-to-apples
- hooks can run across engines

### 2.2 `NormalizedEvent` taxonomy
Minimum set you should support:

**Session lifecycle**
- `SessionStarted`
- `SessionResumed`
- `SessionEnded`

**Model output**
- `AssistantDelta(textChunk)`
- `AssistantFinal(text)`
- `AssistantMeta(model, temperature?, reasoningSummary?, etc.)`

**Tooling**
- `ToolPlanned(toolName, rationale?)`
- `ToolCallStarted(toolName, input, toolCallId)`
- `ToolCallStdout(chunk, toolCallId)`
- `ToolCallStderr(chunk, toolCallId)`
- `ToolCallCompleted(output, toolCallId, success, durationMs)`
- `FileDiffProduced(diff, files[], toolCallId?)`
- `FileEditApplied(files[], linesAdded, linesRemoved)`

**Safety / permissions**
- `PermissionRequested(scope, details)`
- `PermissionDecision(allow/deny/modify, details)`
- `SandboxPolicyChanged(policy)`
- `ApprovalPolicyChanged(policy)`

**Errors**
- `EngineError(code, message, recoverable)`
- `ToolError(toolCallId, message)`

**Stats**
- `UsageStats(promptTokens, outputTokens, cachedTokens?, toolCalls, latencyMs, cost?, engineMeta)`
- `ContextBudget(used, limit, breakdown)`

**Attachments / references**
- `AttachmentRegistered(type, pathOrUri)`
- `ReferenceUsed(type: file|mcpResource|url, id)`

### 2.3 Event ordering guarantees
Your EngineAdapter must ensure:
- Monotonic timestamps (use app time on receipt)
- Stable IDs (`eventId`, `toolCallId`) even if the CLI omits them
- Well-formed sequences: `ToolCallStarted` → (stdout/stderr)* → `ToolCallCompleted`

### 2.4 Event persistence rules (SessionStore)
Persist:
- all normalized events (append-only)
- derived projections: “latest assistant final”, “diff list”, “tool timeline”, “token stats”

Never persist by default:
- secret env vars
- file contents beyond diffs (unless user explicitly enables “store snapshots”)

---

## 3) Two execution modes: HeadlessRunner vs InteractiveRunner

### 3.1 HeadlessRunner (recommended for MVP)
- Spawn a new CLI process per “turn” (or per task)
- Pass a prompt and request structured output
- Parse events; store; render

Pros
- Easier to parse structured output
- UI never fights a TUI’s screen control
- Better reliability (each run isolated)

Cons
- Some engines may not “remember” unless you resume (or you re-inject history)

### 3.2 InteractiveRunner (optional “pro mode”)
- Keep one long-lived CLI process attached to a PTY
- Send commands, parse events (harder)
- Use when structured headless mode is too limiting

Rule of thumb
- Start with headless for v1, add interactive only when a feature is impossible otherwise.

---

## 4) Engine-specific adapters (how each maps to the normalized model)

## 4.1 Claude Code Adapter (v1 priority)

### Invocation & structured output
Claude Code supports headless mode with `-p` and streaming JSON via `--output-format stream-json`. Headless mode does **not** persist between sessions (so you must manage continuity yourself if you want multi-turn).

**Adapter tactics**
- Default mode: `claude -p "<prompt>" --output-format stream-json ...`
- Maintain a `HarnessConversationState`:
  - full event log (your DB)
  - rolling summary + selected file excerpts
  - last “accepted diff” list
- For each new turn:
  - build a context preface from your stored state
  - call Claude headless with your preface + new user message
- Use `--allowedTools` gating when you want deterministic safety budgets (e.g., editing vs shell).

### Mapping to normalized events
- Parse stream-json events and map:
  - token deltas → `AssistantDelta`
  - tool execution info → tool events
  - file edits → `FileDiffProduced` / `FileEditApplied`
  - errors → `EngineError`

### Hooks concurrency (your harness advantage)
Even if Claude Code has its own hooks ecosystem, your **native app can run hooks in parallel** because you control:
- when a “turn” starts/ends
- when tool calls begin/complete
- when a diff is produced
- when approvals are needed

Your HookRunner can concurrently:
- compute context budget projections
- run lint/tests automatically *after tool calls* (or after diffs)
- index files into a local vector store
- push “tool summaries” into the sidebar
- emit desktop notifications

(Keep these hooks “advisory” at first: they should not mutate the repo without an explicit user action.)

---

## 4.2 Gemini CLI Adapter (v2 priority)

### Session persistence (stronger than Claude headless)
Gemini CLI includes automatic session management and can resume sessions via `--resume` (or `-r`). Sessions are stored locally (project-specific).

**Adapter tactics**
- Interactive mode for long chats is plausible because Gemini stores sessions.
- For headless turns:
  - Use `--prompt/-p` and `--output-format stream-json` (or `json`).
- For continuity:
  - Prefer engine-native resume where possible (`gemini --resume`), especially for interactive sessions.

### Mapping to normalized events
Gemini’s streaming JSON emits event types including (commonly) init/message/tool_use/tool_result/error/result.
- Map message deltas → `AssistantDelta`
- tool_use → `ToolCallStarted`
- tool_result → `ToolCallCompleted`
- stats if present → `UsageStats`
- session metadata (project hash) → `EngineSessionHandle.engineStateRef`

### Hooks
Gemini CLI has a formal hooks system; you can still run *your* harness hooks in parallel.
A nice trick: your harness can **translate** its own hook triggers into Gemini’s hook conventions for “engine-aware” automation later.

---

## 4.3 OpenAI Codex CLI Adapter (v3 priority)

### Invocation & structured output
Codex CLI supports a non-interactive mode (`codex exec` / `codex e`) and can emit newline-delimited JSON events via `--json`.

Codex CLI also exposes:
- sandbox policies (`--sandbox` variants)
- approval policies (`--ask-for-approval` variants; plus `--full-auto` presets)
- an optional `resume` subcommand for exec sessions
- experimental app-server and MCP commands

**Adapter tactics**
- Default headless: `codex exec --json "<prompt>"` (plus workspace settings)
- Build tool cards from JSONL events
- Support the CLI’s sandbox/approval toggles in your UI as first-class controls

### Mapping to normalized events
- JSONL events → incremental state changes
- tool run events → tool cards + timeline
- diffs → inline diff viewer
- approvals/sandbox events → permission UI

---

# Product: what makes the native harness “feel expensive”

## Core UX primitives
1) **Streaming without flicker**: render deltas inside a bubble; avoid repainting the whole view.  
2) **Tool cards**: each tool call becomes a collapsible card with: input → logs → result → duration.  
3) **Inline diff review**: “PR-style” unified diff with accept/reject per file or hunk.  
4) **Right sidebar** that always answers: “What’s happening, what’s next, what did it change, and how risky was it?”  
5) **Command palette**: everything is a command; keyboard-first operation.  

## “Premium” features you should add early
- **Timeline mode** (Linear-like): each tool call / checkpoint becomes an item
- **Context budget meter**: tokens used/remaining, plus “top context hogs” list
- **Failure triage**: when tools fail, show the failure cause, logs, and suggested recovery commands
- **Workspace trust & secrets**: visually show whether the project is trusted, which tools are enabled, and which env vars are masked

---

# Roadmap

## MVP (7 days) — Claude-first, single-engine, headless turns
Goal: A working native app where you can “chat with Claude Code” and see tool cards/diffs, using structured output.

### Day 1 — Skeleton + process runner
- SwiftUI shell: main window + split view (chat + sidebar)
- Project picker (choose a repo folder)
- `ProcessRunner`:
  - spawn `claude` as child process
  - capture stdout/stderr
  - support cancellation (SIGINT / terminate)
- Local DB (SQLite) schema:
  - Projects
  - Sessions
  - Events (append-only)
  - Files (metadata only)

### Day 2 — Claude headless integration (stream-json)
- Implement `ClaudeCodeAdapter.send()` via headless mode
- Stream parser: decode JSON events line-by-line
- Map to `NormalizedEvent` and render in UI

### Day 3 — Tool cards + timeline
- Collapsible tool cards
- “Tool timeline” sidebar list:
  - start/end
  - duration
  - success/failure
- Basic errors: show actionable failure messages

### Day 4 — Diff viewer v0
- Parse diffs from events where available
- If diff is not emitted, derive diff from git (use `git diff` after tool run)
- Inline PR-style diff view
- Accept/reject workflow:
  - accept = keep changes
  - reject = `git checkout -- <file>` (or stash revert)

### Day 5 — Permissions & safety UI
- Tool allowlist UI (edit/shell/web/mcp)
- “Risk toggles” surfaced in toolbar:
  - safe mode vs “workspace write” vs “yolo” (but hide yolo behind friction)
- Clear display of active policy

### Day 6 — Command palette + session browser
- Raycast-style palette:
  - new session
  - reopen session
  - toggle tools
  - clear context (app-level)
- Session list per project (local DB)

### Day 7 — Packaging
- .dmg packaging + auto-update stub (Sparkle or your own updater)
- Crash logging local-only (no vendor data exfiltration by default)
- Basic onboarding:
  - “Install Claude Code if missing” checklist
  - “Login” button that launches `claude` login flow

Deliverable: “Claude Harness v1” — feels like a real app, not a wrapper.

---

## 30-day build — Multi-engine architecture + Gemini integration

### Week 2 — Refactor to true EngineAdapter + normalized event schema
- Freeze `NormalizedEvent` v1 schema
- Move Claude integration behind `EngineAdapter`
- Build `EngineRegistry`:
  - detects installed CLIs
  - surfaces engine capabilities
- Build “Engine switcher” UI:
  - choose engine per session or per message
  - show what changes (tools/sandbox/support)

### Week 3 — Gemini CLI adapter (headless + resume)
- Add `GeminiCliAdapter`:
  - `gemini -p ... --output-format stream-json` (headless)
  - interactive resume (`gemini --resume`) support for long sessions
- Map Gemini event types into normalized events
- Add SessionStore bridges:
  - store Gemini session IDs + engine state path references
- Add MCP browser (engine-aware)
  - list configured MCP servers
  - show discovered tools/resources

### Week 4 — Shared “Hooks Harness” (engine-agnostic)
- Implement HookRunner triggers on normalized events:
  - `OnSessionStart`, `OnMessageSent`, `OnToolStart`, `OnToolEnd`, `OnDiffReady`, `OnFailure`
- Provide built-in hook examples (safe by default):
  - auto-run tests after edits
  - auto-summarize tool output into the sidebar
  - auto-create “task checklist” from plan
- “Hook sandbox”:
  - hooks run in a restricted environment (no network unless allowed)
  - timeouts + resource limits

Deliverable: “CLI Harness v0.2” — Claude rock solid; Gemini usable; architecture proven.

---

## 3-month build — Codex integration + “pro” workflows

### Month 2 — Codex CLI adapter + policy parity
- Add `CodexCliAdapter` using `codex exec --json`
- Surface Codex policies in UI:
  - sandbox policy selector
  - approval policy selector (`--full-auto` etc.)
- Implement exec resume if you need multi-turn tasks
- Add “Output Schema mode” UI:
  - attach a JSON schema file for structured final answers (Codex supports this concept)

### Month 2 — Advanced diff + branch workflows
- “Worktree mode”:
  - create a git worktree per session
  - isolate agent changes per session
- “Pro PR review”:
  - accept per hunk
  - convert accepted diff into a commit with templated message

### Month 3 — Multi-agent orchestration (your moat)
- Run parallel sessions across engines:
  - Claude writes code
  - Gemini runs broader repo reasoning
  - Codex reviews diff for security issues
- “Verifier agents”:
  - attach a second engine as reviewer for each diff
- “Consensus mode”:
  - require 2/3 engines to approve a risky command

Deliverable: “CLI Harness v1.0” — multi-engine, multi-agent, genuinely differentiated.

---

## 6-month build — Marketplace-level product (still free, but addictive)

### Engine ecosystem
- Add OpenRouter (two paths):
  1) If OpenRouter has its own CLI: add it as a new adapter
  2) If not: run OpenRouter via a “provider shim” CLI you own (careful: this becomes an API client, different compliance surface)
- Add “Local OSS provider” adapters (e.g., Ollama-backed modes if supported by an engine)

### “Raycast + Linear + Zed” polish layer
- “Global quick launcher” (menu bar + hotkey)
- Inline code intelligence:
  - open multiple files Zed-style
  - quick search + symbol navigation
- Task system:
  - tasks created from plans
  - checkbox progress
  - per-task context packing

### Safety and governance (if you ever go enterprise)
- Per-project policy templates
- “Secrets vault” integration (1Password/Keychain) with masking
- Audit logs export (local-first)
- Deterministic tool allowlists + approval workflows

### Extensions (your distribution flywheel)
- A plugin system that subscribes to normalized events:
  - `onEvent(NormalizedEvent) -> Action`
- A “plugin gallery” hosted on your site (free):
  - plugins distributed as signed bundles or WASM modules
  - strict permission model

Deliverable: “CLI Harness v2.x” — you’re no longer a wrapper; you’re the control plane.

---

# Rework impact (answering your core question)

If you start Claude v1 with a **real** EngineAdapter + normalized event schema from day 1:
- adding Gemini and Codex is **not** a significant rework; it’s “write adapters + mapping.”

If you ship Claude v1 as a Claude-specific app without normalization:
- Gemini/Codex will force a refactor of your core data model (sessions/events/tools), i.e. **rework is significant**.

So: build the adapter boundary early even if you only implement one adapter initially.

---

# Sources / primary docs to build against (for exact flags & behavior)
(Keep these in your repo as pinned references.)
- Claude Code headless mode and `--output-format stream-json` guidance (Anthropic engineering best practices): https://www.anthropic.com/engineering/claude-code-best-practices
- Gemini CLI headless + streaming JSON output: https://geminicli.com/docs/cli/headless/
- Gemini CLI session management (`--resume` and storage location): https://geminicli.com/docs/cli/session-management/
- OpenAI Codex CLI reference (`codex exec --json`, sandbox/approval flags, resume): https://developers.openai.com/codex/cli/reference/
- Gemini CLI MCP server integration docs: https://geminicli.com/docs/tools/mcp-server/
- Claude Code MCP docs: https://code.claude.com/docs/en/mcp

---

# Appendix: Suggested repo structure for your harness
```
cli-harness/
  app/
    Sources/
      AppUI/
      AppCore/
      EngineKit/
        EngineAdapter.swift
        NormalizedEvent.swift
        SessionStore.swift
        ProcessRunner.swift
        Adapters/
          ClaudeCodeAdapter.swift
          GeminiCliAdapter.swift
          CodexCliAdapter.swift
      Hooks/
      Security/
  docs/
    architecture/
    adapters/
    event-schema/
    threat-model/
  scripts/
    packaging/
    dev/
```

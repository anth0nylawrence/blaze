# Cogit0 Blaze - Product Requirements Document

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Status:** Draft for Review
**Authors:** Product Team

---

## Executive Summary

Cogit0 Blaze is a native macOS SwiftUI application that serves as the definitive harness for agentic coding CLIs. Starting with Claude Code, then expanding to Gemini CLI and OpenAI Codex CLI, Blaze transforms how developers interact with AI coding agents by treating them as structured event streams rather than terminal output.

**The core insight:** Existing approaches (web UIs, terminal usage) inherit fundamental constraints. Blaze becomes meaningfully better by acting as:
1. A **structured event renderer** (not a terminal emulator)
2. A **governance layer** (policies, permissions, review gates)
3. A **productivity cockpit** (timeline, tasks, multi-file workspace)
4. A **concurrency orchestrator** (background work, hooks, daemons)

**Distribution model:** Signed and notarized `.dmg` hosted on cogit0.com, gated behind email capture with marketing consent. Not App Store.

---

## Table of Contents

1. [Product Vision & Positioning](#1-product-vision--positioning)
2. [Target Users & Jobs to Be Done](#2-target-users--jobs-to-be-done)
3. [Competitive Moat Analysis](#3-competitive-moat-analysis)
4. [System Architecture](#4-system-architecture)
5. [Core Requirements](#5-core-requirements)
6. [User Experience Design](#6-user-experience-design)
7. [Security & Trust Model](#7-security--trust-model)
8. [Advanced Features](#8-advanced-features)
9. [Distribution & Growth](#9-distribution--growth)
10. [Technical Constraints & Dependencies](#10-technical-constraints--dependencies)
11. [Risk Register & Mitigation](#11-risk-register--mitigation)
12. [Success Metrics](#12-success-metrics)
13. [Roadmap & Milestones](#13-roadmap--milestones)
14. [Appendices](#14-appendices)

---

## Documentation Index

This PRD is the central document for Cogit0 Blaze. The following companion specifications provide detailed designs for specific features and systems. Cross-reference these documents as you work on the corresponding areas.

**Document Organization:**
- `/specs/` - Authoritative specifications (implementation-ready)
- `/research/` - Background research and roadmaps
- `/archive/` - Superseded working documents

### Architecture & Data

| Document | Description | Key Topics | Status |
|----------|-------------|------------|--------|
| [Data Model Spec](./specs/data-model-spec.md) | Complete data layer design | LanceDB schema, JSONL events, relationships | ✅ Approved |
| [Claude Code Stream-JSON Schema](./specs/claude-code-stream-json-schema.md) | Event format reference | NDJSON parsing, event types, field mappings | ✅ Approved |
| [CLI Version Compatibility](./specs/cli-version-compatibility.md) | Supported CLI versions | Version detection, deprecation policy, feature flags | ✅ Approved |
| [Settings Specification](./specs/settings-specification.md) | User preferences system | Defaults, persistence, sync | ✅ Approved |
| [Multi-Session Architecture](./specs/multi-session-architecture.md) | Concurrent session management | Tabs, windows, split view, worktrees | ✅ Approved |

### Security & Safety

| Document | Description | Key Topics | Status |
|----------|-------------|------------|--------|
| [Threat Model](./specs/threat-model.md) | Security architecture | Attack surfaces, mitigations, trust boundaries | ✅ Approved |
| [Error Taxonomy & Recovery Matrix](./specs/error-taxonomy-recovery-matrix.md) | Error handling strategy | Error codes, recovery flows, user messaging | ✅ Approved |

### User Experience

| Document | Description | Key Topics | Status |
|----------|-------------|------------|--------|
| [Design System](./specs/design-system.md) | Component library | BlazeButton, BlazeCard, design tokens | ✅ Approved |
| [Dark Mode Spec](./specs/dark-mode-spec.md) | Color system | Raycast-inspired palette, semantic colors | ✅ Approved |
| [Animation & Motion Spec](./specs/animation-motion-spec.md) | Motion design | Timing curves, micro-interactions, streaming | ✅ Approved |
| [Empty States & Onboarding](./specs/empty-states-onboarding.md) | First-run experience | Empty states, onboarding flow, CLI setup | ✅ Approved |
| [Accessibility Spec](./specs/accessibility-spec.md) | A11y requirements | VoiceOver, keyboard nav, reduced motion | ✅ Approved |
| [Localization Strategy](./specs/localization-strategy.md) | i18n approach | String extraction, RTL support, locale handling | ✅ Approved |
| [SwiftUI Native Features](./specs/swiftui-native-features.md) | Platform integration | Menu bar, Spotlight, drag/drop, animations, Quick Look | 📝 Draft |

### Advanced Features

| Document | Description | Key Topics | Status |
|----------|-------------|------------|--------|
| [Branch Conversations Spec](./specs/branch-conversations-spec.md) | Conversation forking | Tree structure, UI design, merge patterns | ✅ Approved |
| [Diff Stacking & Batch Review Spec](./specs/diff-stacking-batch-review-spec.md) | Multi-diff workflows | Changeset model, batch actions, keyboard shortcuts | ✅ Approved |
| [Multi-File Workspace Spec](./specs/multi-file-workspace-spec.md) | Editor workspace | Tab bar, live preview, Quick Open | ✅ Approved |
| [Voice & Dictation Spec](./specs/voice-dictation-spec.md) | Voice input/output | Speech recognition, TTS, voice commands | ✅ Approved |

### Quality & Operations

| Document | Description | Key Topics | Status |
|----------|-------------|------------|--------|
| [QA Test Plan](./specs/qa-test-plan.md) | Testing strategy | Unit/integration/E2E, CI/CD, test matrix | ✅ Approved |
| [Performance Benchmarking Plan](./specs/performance-benchmarking-plan.md) | Performance targets | Benchmarks, profiling, budgets | ✅ Approved |
| [Beta Program Design](./specs/beta-program-design.md) | Beta rollout | Alpha/Private/Public phases, feedback loops | ✅ Approved |
| [Support Runbook](./specs/support-runbook.md) | Troubleshooting guide | Common issues, diagnostics, escalation | ✅ Approved |
| [Telemetry & Analytics Spec](./specs/telemetry-analytics-spec.md) | Metrics collection | Events, opt-in, privacy | ✅ Approved |
| [Implementation Blueprint](./specs/implementation-blueprint.md) | Build execution guide | Dependency graphs, critical path, atomic tasks | 📝 Draft |

### Research & Planning

| Document | Description | Key Topics |
|----------|-------------|------------|
| [Branch Conversations Research](./research/branch-conversations-research.md) | Background research | Prior art, GitHub issues, implementation options |
| [Cross-Platform Research](./research/cross-platform-research.md) | Future platform strategy | Windows/Linux considerations |
| [Claude Harness Full Roadmap](./research/claude_harness_full_roadmap.md) | Extended roadmap | Long-term vision, milestones |
| [CLI Harness Full Roadmap](./research/cli_harness_full_roadmap.md) | Multi-CLI roadmap | Engine integration timeline |

### Archive (Superseded)

| Document | Description | Superseded By |
|----------|-------------|---------------|
| [Diff Stacking Batch Review](./archive/diff-stacking-batch-review.md) | Working notes on diff stacking | diff-stacking-batch-review-spec.md |
| [Multi-File Workspace](./archive/multi-file-workspace.md) | Working notes on workspace | multi-file-workspace-spec.md |
| [Voice Dictation Mode](./archive/voice-dictation-mode.md) | Working notes on voice mode | voice-dictation-spec.md |

---

## 1. Product Vision & Positioning

> **ELI5:** *Imagine if your AI coding assistant lived inside a beautiful app instead of a boring terminal. This section explains what we're building and why it matters - Blaze is like giving your AI superpowers with a control room to watch everything it does.*

### 1.1 Vision Statement

Blaze is the control plane for agentic coding. It provides the governance, observability, and premium UX that makes AI-assisted development trustworthy, efficient, and delightful.

### 1.2 Product Principles

| Principle | Description |
|-----------|-------------|
| **Structured-first** | Never parse ANSI terminal output. Consume structured events. |
| **Local-first** | Everything works offline (except the model). Transparent storage. |
| **Safety by default** | Risky operations require explicit confirmation with explainable rules. |
| **Latency is UX** | Streaming and responsiveness are features, not polish. |
| **Composable** | Hooks, policies, and recipes are small building blocks users can share. |
| **Engine-agnostic** | The UI never "knows" which vendor it's talking to. |

### 1.3 What We Are Building

A native macOS application that:
1. Runs agentic CLIs headlessly and consumes **streamed structured output** (NDJSON) to render:
   - Assistant tokens streaming into message bubbles
   - Tool calls as collapsible cards with durations/failures
   - Diffs inline with accept/reject workflows
   - Multi-file workspace tabs (Zed-style)
2. Uses **Claude Code hooks** as middleware for deterministic logging, enforcement, and automation
3. Maintains **local-first state**: sessions, events, diffs, policies, and optional memory index

### 1.4 What We Are NOT Building (Non-Goals)

- A full cloud IDE replacement
- A GitHub/CI replacement (integrate lightly)
- Windows/Linux support (until macOS is excellent)
- Direct Anthropic/OpenAI/Google API integration (we use their CLIs only)
- A terminal emulator or ANSI parser

---

## 2. Target Users & Jobs to Be Done

> **ELI5:** *Who is this app for? Power users who already love Claude Code but want a better experience. Think of it like upgrading from a flip phone to a smartphone - same calls, way better everything else.*

### 2.1 Primary Users

**Power users already using Claude Code CLI heavily:**
- Founders and solo builders who want speed without sacrificing control
- Senior engineers exploring agentic coding workflows
- Operators building plugins, local memory layers, and automation

### 2.2 Secondary Users

**Teams wanting safer agent workflows:**
- Organizations requiring controls, approvals, and audit logs
- Teams needing consistency across repos and developers

### 2.3 Jobs to Be Done

| Job | Priority | Unmet by Current Tools |
|-----|----------|------------------------|
| Use Claude Code all day in a UI that feels like a modern app | P0 | Terminal lacks structure, web UIs feel sluggish |
| Trust a timeline: what happened, when, why | P0 | Terminal output scrolls away, no persistence |
| Approve risky changes before they land | P0 | CLI approval prompts are modal and blocking |
| Work across multiple files obviously and fast | P1 | Context switching between editor and terminal |
| Set guardrails so the agent doesn't do something stupid at 3am | P1 | No policy engine in existing tools |
| Integrate my own local memory layer / context control | P2 | No pluggable memory architecture |
| Run multiple agents in parallel safely | P2 | No orchestration layer |

---

## 3. Competitive Moat Analysis

> **ELI5:** *Why can't competitors just copy us? Because we're building things the hard way - with native code, structured data, and deep integration. It's like the difference between a house built on concrete vs. cardboard. Ours takes longer to build but lasts forever.*

### 3.1 What Makes Blaze Genuinely Better

| Advantage | Why It Matters | Why Competitors Can't Easily Copy |
|-----------|----------------|-----------------------------------|
| **Structured event renderer** | Tool cards, timelines, and diffs are first-class. Not afterthoughts parsed from ANSI. | Requires architectural commitment from day 1. Retrofitting is painful. |
| **Native macOS performance** | 60fps scrolling, instant command palette, no Electron overhead | Web-first tools carry baggage |
| **Policy engine** | Deterministic rules that gate dangerous operations | Requires deep integration with event stream |
| **EngineAdapter abstraction** | Same premium UX regardless of Claude/Gemini/Codex | Multi-engine support as core architecture, not bolted on |
| **Local-first trust** | No code leaves your machine except to the model | Enterprise-ready privacy story |
| **Hook system** | User automation runs in parallel with engine | Native concurrency unlocks workflows web can't match |

### 3.2 Defensibility Over Time

**6-month moat:** Premium UX + policy engine + hook ecosystem creates switching costs.

**12-month moat:** Multi-engine orchestration (consensus mode, verifier agents) is genuinely novel. Local memory layer with context intelligence becomes indispensable.

**24-month moat:** Plugin/recipe marketplace with network effects. Enterprise teams standardize on Blaze policies.

---

## 4. System Architecture

> **ELI5:** *This is the blueprint of how Blaze works under the hood. The app talks to AI CLIs through pipes (like tubes), stores everything in a database (like a filing cabinet), and shows you pretty cards and timelines (like a dashboard). No magic - just smart engineering.*

### 4.1 High-Level Components

```
+---------------------------- Cogit0 Blaze (SwiftUI) ----------------------------+
|                                                                                 |
|  UI Layer:                                                                      |
|   - Chat timeline (streaming bubbles)                                           |
|   - Tool cards + inline diffs + approvals                                       |
|   - Right sidebar (plan, tasks, budget, timeline, sessions)                     |
|   - Command palette (Raycast-style)                                             |
|   - Editor + diff viewer                                                        |
|                                                                                 |
|  Orchestration Layer (App Core):                                                |
|   - SessionStore (local SQLite + append-only JSONL)                             |
|   - ProjectManager (workspace roots, trust, policies)                           |
|   - EngineManager (Claude/Gemini/Codex adapters)                                |
|   - PolicyEngine (rules evaluation + approval workflows)                        |
|   - HookRunner (concurrent automations)                                         |
|   - Telemetry (local-first, opt-in)                                             |
|                                                                                 |
|  EngineAdapter Layer:                                                           |
|   - ClaudeCodeAdapter                                                           |
|   - GeminiCliAdapter                                                            |
|   - CodexCliAdapter                                                             |
|                                                                                 |
+------------------------------------|--------------------------------------------+
                                     | spawn child process / attach pipes
                                     v
                  +--------------------------------------------------+
                  |  Provider CLIs (unmodified binaries)              |
                  |  - claude (Claude Code CLI)                       |
                  |  - gemini (Gemini CLI)                            |
                  |  - codex (OpenAI Codex CLI)                       |
                  +--------------------------------------------------+
                                     |
                                     v
                      Local repo + local tools + MCP servers
```

### 4.2 Process Model

| Component | Lifecycle | Communication |
|-----------|-----------|---------------|
| **Main App** | Primary process, always running | SwiftUI main actor |
| **CLI Process** | Per-turn or per-session, spawned by app | stdin/stdout pipes, NDJSON streaming |
| **Background Daemon** | Long-lived, handles heavy tasks | Unix domain socket or append-only JSONL |
| **Workers** | Concurrent tasks: indexing, diffs, tests | Grand Central Dispatch queues |

### 4.3 Data Storage Model

**LanceDB (Primary Storage)**

Blaze uses **LanceDB** as the primary storage engine, providing vector-native storage for semantic search, columnar format for efficient queries, and embedded mode requiring no separate server process.

```
~/.cogit0-blaze/
├── db/
│   └── blaze.lance/              # Main LanceDB database
│       ├── sessions.lance/       # Session table
│       ├── events.lance/         # Event log table
│       ├── projects.lance/       # Project configurations
│       ├── diffs.lance/          # File diff storage
│       ├── policies.lance/       # Security policies
│       ├── approvals.lance/      # Approval decisions
│       ├── hooks.lance/          # Hook configurations
│       ├── branches.lance/       # Conversation branches
│       └── _versions/            # Version metadata
├── events/
│   └── <session_id>.jsonl        # Append-only event journal (crash recovery)
├── cache/
│   └── embeddings/               # Cached embedding vectors
└── exports/
    └── <export_id>/              # Exported session bundles
```

**Core Tables (LanceDB Schema):**

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `sessions` | Conversation sessions | id, project_id, engine_id, name, state, parent_id (branching) |
| `events` | Event log with embeddings | id, session_id, sequence, event_type, payload, embedding[] |
| `projects` | Workspace configurations | id, path, name, trust_level, policy_ids[] |
| `diffs` | File change tracking | id, event_id, file_path, unified_diff, stats, decision |
| `policies` | Security rule sets | id, name, scope, rules[], enabled |
| `approvals` | Approval decisions | id, session_id, event_id, decision, scope, expires_at |
| `hooks` | Automation configs | id, name, event_type, script_path, timeout_ms, permissions |

**Append-Only JSONL (Crash Safety)**

- `~/.cogit0-blaze/events/<session_id>.jsonl` - raw event ingestion
- Rehydrated into LanceDB asynchronously
- Enables recovery after hard kill

See [Data Model Spec](./data-model-spec.md) for complete schema details.

### 4.4 EngineAdapter Protocol

```swift
protocol EngineAdapter {
    var engineId: EngineId { get }

    func capabilities() async -> EngineCapabilities
    func ensureAuthenticated(context: AuthContext) async throws -> AuthState

    func startSession(config: SessionConfig) async throws -> EngineSessionHandle
    func resumeSession(handle: EngineSessionHandle) async throws -> EngineSessionHandle
    func endSession(handle: EngineSessionHandle) async

    func send(message: UserMessage, to handle: EngineSessionHandle) async throws -> AsyncStream<NormalizedEvent>
    func cancel(handle: EngineSessionHandle) async
}
```

**EngineCapabilities Fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `supportsStreamingDeltas` | Bool | Can stream token-by-token |
| `supportsStructuredEvents` | Enum | none, json, jsonl, streamJson |
| `supportsSessionResume` | Bool | Engine-native resume |
| `sessionScope` | Enum | global, perProject, perWorkingDir |
| `supportsToolCards` | Bool | Tool events in stream |
| `supportsInlineDiffEvents` | Bool | Diff data in events |
| `supportsMCPClient` | Bool | Can connect to MCP servers |
| `supportsSandboxPolicy` | Bool | Sandbox controls available |
| `supportsApprovalPolicy` | Bool | Approval controls available |

---

## 5. Core Requirements

> **ELI5:** *These are the must-have features that make Blaze work. Every AI tool call becomes a card you can click. Every file change becomes a diff you can review. Every message streams in real-time like a live conversation. Without these, the app is useless.*

### 5.1 NormalizedEvent Schema [P0]

All engine adapters must map their output to this unified schema. This is the heart of "buttery UI."

**Event Taxonomy:**

```typescript
// Session lifecycle
type SessionStarted = { sessionId: string; engineId: EngineId; config: SessionConfig }
type SessionResumed = { sessionId: string; resumedFrom: string }
type SessionEnded = { sessionId: string; reason: 'user' | 'error' | 'timeout' }

// Model output
type AssistantDelta = { textChunk: string; role: 'assistant' }
type AssistantFinal = { text: string; model: string; finishReason: string }
type AssistantMeta = { model: string; temperature?: number; reasoningSummary?: string }

// Tooling
type ToolPlanned = { toolName: string; rationale?: string }
type ToolCallStarted = { toolCallId: string; toolName: string; input: any }
type ToolCallStdout = { toolCallId: string; chunk: string }
type ToolCallStderr = { toolCallId: string; chunk: string }
type ToolCallCompleted = { toolCallId: string; output: any; success: boolean; durationMs: number }
type FileDiffProduced = { toolCallId?: string; diff: UnifiedDiff; files: string[] }
type FileEditApplied = { files: string[]; linesAdded: number; linesRemoved: number }

// Safety / permissions
type PermissionRequested = { scope: PermissionScope; details: any; toolCallId?: string }
type PermissionDecision = { decision: 'allow' | 'deny' | 'modify'; scope: PermissionScope; details: any }
type PolicyViolation = { ruleId: string; reason: string; toolCallId?: string; overridable: boolean }

// Errors
type EngineError = { code: string; message: string; recoverable: boolean }
type ToolError = { toolCallId: string; message: string; exitCode?: number }

// Stats
type UsageStats = { promptTokens: number; outputTokens: number; cachedTokens?: number; toolCalls: number; latencyMs: number; cost?: number }
type ContextBudget = { used: number; limit: number; breakdown: Record<string, number> }

// Attachments
type AttachmentRegistered = { type: 'file' | 'image' | 'url'; pathOrUri: string }
type ReferenceUsed = { type: 'file' | 'mcpResource' | 'url'; id: string }
```

**Event Ordering Guarantees:**
- Monotonic timestamps (use app time on receipt)
- Stable IDs even if CLI omits them (generate deterministically)
- Well-formed sequences: `ToolCallStarted` -> (stdout/stderr)* -> `ToolCallCompleted`

**Acceptance Criteria:**
- [ ] All three adapters produce identical event shapes for equivalent operations
- [ ] Events can be replayed from JSONL to reproduce UI state exactly
- [ ] Event schema is versioned with migration path

### 5.2 Engine Runner [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Spawn CLI process with correct cwd | P0 | Process runs in project directory |
| Stream stdout/stderr with NDJSON parsing | P0 | Partial lines buffered correctly |
| Handle process exit (clean and crash) | P0 | Exit code captured, cleanup runs |
| Support cancellation (SIGINT, then SIGKILL) | P0 | Cancel button stops run within 2s |
| Environment sanitization | P0 | Secrets not leaked to child process |
| Custom env vars per profile | P1 | User can set env vars per project |
| Max line size enforcement | P1 | Lines >1MB truncated with warning |
| Process timeout | P1 | Configurable timeout per run |

**Implementation Spec:**

```swift
class ProcessRunner {
    func spawn(
        executable: String,
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String],
        timeout: TimeInterval?
    ) -> ProcessHandle

    func send(input: String, to handle: ProcessHandle) async throws
    func cancel(handle: ProcessHandle, gracePeriod: TimeInterval = 2.0) async
    func stream(handle: ProcessHandle) -> AsyncStream<ProcessOutput>
}

enum ProcessOutput {
    case stdout(Data)
    case stderr(Data)
    case exit(code: Int32, signal: Int32?)
}
```

### 5.3 Session Management [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Create new session | P0 | Session appears in list, persists to SQLite |
| Resume existing session | P0 | Full event history restored |
| Continue session (new turn) | P0 | Context maintained across turns |
| Fork session | P1 | New session with copied context |
| Delete session | P1 | Data removed from SQLite and JSONL |
| Export session | P1 | Session exported as sharable bundle |
| Session search | P1 | Search by name, content, date |
| Session tags | P2 | User-defined tags for organization |

**Session State Machine:**

```
[Created] -> [Active] -> [Idle] -> [Archived]
              |           ^
              +-----------+
              (resume)
```

### 5.4 Claude Code Adapter [P0]

**Invocation:**
```bash
claude -p "<prompt>" --output-format stream-json [--allowedTools ...] [--max-turns ...]
```

**Mapping to NormalizedEvents:**

| Claude Event | NormalizedEvent |
|--------------|-----------------|
| `init` | `SessionStarted` |
| `assistant` (partial) | `AssistantDelta` |
| `assistant` (final) | `AssistantFinal` |
| `tool_use` start | `ToolCallStarted` |
| `tool_result` | `ToolCallCompleted` |
| `error` | `EngineError` or `ToolError` |
| `result` | `UsageStats` + `SessionEnded` |

**State Management:**
- Headless mode does not persist between sessions
- Blaze maintains `HarnessConversationState`:
  - Full event log (SQLite)
  - Rolling summary + selected file excerpts
  - Last accepted diff list
- Each turn builds context preface from stored state

**Acceptance Criteria:**
- [ ] All Claude stream-json event types mapped
- [ ] Tool calls appear as cards within 50ms of event
- [ ] Diffs extracted and rendered correctly
- [ ] Session can be continued after app restart

### 5.5 Gemini CLI Adapter [P1]

**Invocation:**
```bash
gemini -p "<prompt>" --output-format stream-json
gemini --resume  # for session continuity
```

**Key Differences from Claude:**
- Native session persistence (`--resume` flag)
- Different event type names
- Project-specific session storage

**Acceptance Criteria:**
- [ ] Engine-native resume works seamlessly
- [ ] Session IDs mapped to Blaze session store
- [ ] MCP server discovery integrated

### 5.6 Codex CLI Adapter [P2]

**Invocation:**
```bash
codex exec --json "<prompt>" [--sandbox ...] [--ask-for-approval ...]
```

**Key Differences:**
- Sandbox policy is a first-class concept
- Approval policy variants (full-auto, etc.)
- Resume via `resume` subcommand

**Acceptance Criteria:**
- [ ] Sandbox policy surfaced in UI
- [ ] Approval policy controls functional
- [ ] Output schema mode supported

---

## 6. User Experience Design

> **ELI5:** *How does the app look and feel? Three panels: your chat history on the left, the conversation in the middle, and helpful tools on the right. Plus a magic keyboard shortcut (Cmd+K) that opens a search bar to do anything instantly. It should feel as smooth as Apple's own apps.*

### 6.1 Layout Structure [P0]

**Three-Pane NavigationSplitView:**

```
+------------------+--------------------------------+------------------+
|                  |                                |                  |
|  Sessions List   |       Chat Timeline            |    Sidebar       |
|                  |                                |                  |
|  - Search        |  [User message]                |  [Tab: Plan]     |
|  - Filters       |  [Assistant response...]       |  [Tab: Tools]    |
|  - Session items |  [Tool card: bash]             |  [Tab: Files]    |
|                  |  [Diff card: Edit]             |  [Tab: Budget]   |
|  + New Session   |  [User message]                |  [Tab: Timeline] |
|                  |                                |                  |
+------------------+--------------------------------+------------------+
|                        Command Palette (Cmd+K)                       |
+----------------------------------------------------------------------+
```

**Focus Modes:**

| Mode | Purpose | Layout Adjustment |
|------|---------|-------------------|
| Chat Focus | Normal conversation | Default three-pane |
| Review Focus | Diff review workflow | Center pane becomes full-width diff viewer |
| Timeline Focus | Audit and debugging | Right sidebar expands, timeline becomes primary |

### 6.2 Command Palette [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Open with Cmd+K | P0 | Palette visible within 50ms |
| Fuzzy search all commands | P0 | Results update as user types |
| Recent commands | P0 | Last 10 commands shown by default |
| Quick session switch | P0 | Sessions searchable from palette |
| Quick file open | P1 | Files in project searchable |
| Custom user commands | P2 | Users can add palette entries |

**Command Categories:**

```
Session:     New Session, Continue, Fork, Export, Delete
Navigation:  Switch Project, Switch Engine, Open File, Jump to Event
Actions:     Run Tests, Lint, Accept All Diffs, Reject All Diffs
Modes:       Toggle Safe Mode, Toggle Trusted Mode, Enable Sandbox
Settings:    Open Preferences, Edit Policies, Manage Hooks
Debug:       Show Event Log, Export Support Bundle, Engine Diagnostics
```

### 6.3 Streaming UX [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Token-by-token rendering | P0 | No visible batching delay |
| Smooth scrolling during stream | P0 | No jank, 60fps maintained |
| Partial message visible immediately | P0 | First token appears < 100ms after engine sends |
| Cursor/typing indicator | P0 | Visual feedback during generation |
| Stream can be cancelled | P0 | Stop button halts generation |
| Handle large outputs | P1 | Messages > 50KB render without freeze |

**Implementation Notes:**
- Use `Text` with attributed string for incremental updates
- Batch UI updates at 16ms intervals (60fps)
- Virtualize message list for long sessions
- Pre-allocate message container on stream start

### 6.4 Tool Cards [P0]

**Anatomy:**

```
+------------------------------------------------------------------+
| [icon] Tool: bash                                    [1.2s] [v]  |
+------------------------------------------------------------------+
| > git status                                                     |
+------------------------------------------------------------------+
| stdout:                                                          |
| On branch main                                                   |
| nothing to commit, working tree clean                            |
+------------------------------------------------------------------+
| [Copy Input] [Copy Output] [Rerun] [Explain]                     |
+------------------------------------------------------------------+
```

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Collapsible/expandable | P0 | Click header to toggle |
| Duration displayed | P0 | Accurate to 100ms |
| Success/failure indicator | P0 | Visual distinction (color, icon) |
| Copy actions | P0 | Copy input or output to clipboard |
| Input preview | P0 | First line always visible when collapsed |
| Output streaming | P0 | Long outputs virtualized |
| Stderr distinguished | P1 | Different styling from stdout |
| Rerun action | P2 | Re-execute with same args |
| Explain action | P2 | Ask engine to justify the tool call |

### 6.5 Diff Viewer [P0]

**Modes:**
- **Unified diff** (default): Classic `+/-` format
- **Side-by-side**: Before/after columns
- **Inline**: Changes highlighted within lines

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Render unified diff | P0 | Standard diff format displayed |
| Syntax highlighting | P0 | Language-aware colors |
| Accept/reject per file | P0 | Buttons apply or revert changes |
| Accept/reject per hunk | P1 | Granular control over changes |
| Side-by-side mode | P1 | Toggle between modes |
| Copy hunk | P1 | Copy selected hunk to clipboard |
| Jump to file | P1 | Click filename opens in editor |
| Handle large diffs | P1 | >2000 line diffs paginated |
| Conflict detection | P2 | Warn if file changed since diff |

**Acceptance Criteria:**
- [ ] Diff renders within 100ms for files up to 10,000 lines
- [ ] Accept action persists changes to disk immediately
- [ ] Reject action reverts via `git checkout` or stash restore

### 6.6 Timeline View [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Chronological event list | P0 | All events in order |
| Filter by event type | P0 | Tools, diffs, errors, messages |
| Duration histogram | P1 | Visual distribution of tool times |
| Jump to event in chat | P1 | Click event scrolls to context |
| Export timeline | P1 | Export as Markdown or JSON |
| Failure cluster view | P2 | Group related failures |

### 6.7 Sidebar Tabs [P0]

| Tab | Content | Priority |
|-----|---------|----------|
| **Plan** | Parsed task list from agent output, checkboxes | P0 |
| **Tools** | Tool call history with durations | P0 |
| **Files** | Changed files with diff previews | P0 |
| **Budget** | Token usage, context pressure | P1 |
| **Timeline** | Full event log | P1 |
| **Memory** | Pinned items, retrieved context | P2 |

### 6.8 Keyboard Shortcuts [P0]

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | Open command palette |
| `Cmd+N` | New session |
| `Cmd+Enter` | Send message |
| `Cmd+.` | Cancel current run |
| `Cmd+D` | Toggle diff viewer |
| `Cmd+T` | Toggle timeline |
| `Cmd+1/2/3` | Switch sidebar tabs |
| `Cmd+[/]` | Navigate sessions |
| `Escape` | Close palette/modal |
| `Cmd+Shift+C` | Copy last response |
| `Cmd+Shift+E` | Export session |

### 6.9 Onboarding Flow [P1]

**First Run Experience:**

1. **Welcome Screen**
   - Product value prop (30 seconds)
   - "Get Started" button

2. **CLI Detection**
   - Auto-detect installed CLIs
   - Offer to install missing ones
   - Show installation instructions

3. **Authentication**
   - Trigger each CLI's native login flow
   - Show auth status per engine

4. **Project Selection**
   - "Open a project" folder picker
   - Recent projects list
   - Trust level selection

5. **Safety Mode**
   - Explain Review/Trusted/Sandbox modes
   - Recommend Review mode for new users

6. **Hook Installation (Optional)**
   - Offer recommended hook pack
   - Explain what hooks do

7. **Email Capture**
   - Request email for updates
   - Marketing consent checkbox
   - "Skip" option (never block usage)

8. **First Session**
   - Pre-populated example prompt
   - Guided tour of UI elements

**Acceptance Criteria:**
- [ ] Complete onboarding in < 3 minutes
- [ ] User can skip any optional step
- [ ] App functional even if user skips everything

### 6.10 Error Handling UX [P0]

**Error Categories:**

| Category | UX Treatment |
|----------|--------------|
| **Engine Error** | Red banner, "Retry" and "Report" buttons |
| **Tool Failure** | Yellow tool card, stderr visible, "Explain" action |
| **Policy Block** | Modal with explanation, override options |
| **Auth Failure** | Re-auth prompt with CLI login trigger |
| **Network Error** | Toast notification, auto-retry with backoff |
| **Parse Error** | Log silently, show raw output fallback |

**Recovery Actions:**

| Action | Description |
|--------|-------------|
| Retry | Re-send last message |
| Fix tests | Run suggested fix command |
| Revert last change | Git checkout or stash pop |
| Explain | Ask engine what went wrong |
| Report issue | Export support bundle |

### 6.11 Multi-Session Architecture [P0]

> **ELI5:** *Power users run multiple Claude Code terminals at once - maybe one for frontend, one for backend, each in different git worktrees. Blaze handles this elegantly: one app, many sessions. Think browser tabs, but for AI coding assistants.*

**Why This Matters:**

macOS apps are single-instance by default. Rather than fighting this, we embrace it - a single Blaze process manages multiple concurrent Claude Code CLI processes, each with its own working directory and context.

**Session Layout Modes:**

| Mode | Description | Best For | Default |
|------|-------------|----------|---------|
| **Tabs** | Sessions as browser-like tabs in tab bar | Quick switching, overview | **Yes** |
| **Windows** | Each session in separate window | Multi-monitor, different projects | No |
| **Split View** | Side-by-side sessions in same window | Comparison, code review | No |
| **Agent Lanes** | Parallel agents visualized as swim lanes | Multi-agent orchestration | No |

**User Preference:** Layout mode is configurable in Settings → Appearance → Session Layout.

**Architecture Overview:**

```
┌─────────────────────── Blaze (Single Process) ───────────────────────────┐
│                                                                           │
│  SessionManager (coordinates all active sessions)                         │
│    ├── Session 1 → EngineRunner 1 → claude CLI (PID 1234)                │
│    ├── Session 2 → EngineRunner 2 → claude CLI (PID 1235)                │
│    ├── Session 3 → EngineRunner 3 → gemini CLI (PID 1236)                │
│    └── Session 4 → EngineRunner 4 → claude CLI (PID 1237)                │
│                                                                           │
│  Shared: PolicyEngine, SessionStore, HookRunner, Preferences              │
└───────────────────────────────────────────────────────────────────────────┘
```

**Key Behaviors:**

| Behavior | Implementation |
|----------|----------------|
| New session | Cmd+T (new tab) or Cmd+Shift+N (new window) |
| Switch sessions | Cmd+1/2/3 or click tab |
| Close session | Cmd+W (closes tab, keeps CLI process until confirmed) |
| Session per worktree | Each git worktree can have its own session |
| Cross-session context | Copy/paste messages and diffs between sessions |
| Unified command palette | Cmd+K searches across all sessions |

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Tab-based session switching | P0 | Cmd+T creates new tab, Cmd+1/2/3 switches |
| Multiple concurrent CLI processes | P0 | Each session spawns independent CLI |
| Session state isolation | P0 | Sessions don't interfere with each other |
| Worktree-aware session creation | P0 | "New Session" shows available worktrees |
| Window mode option | P1 | Preference to use windows instead of tabs |
| Split view mode | P1 | Side-by-side sessions in same window |
| Session drag-and-drop | P2 | Drag tab to new window or reorder |
| Session persistence | P0 | Sessions restored on app restart |

**See Also:** [Multi-Session Architecture Spec](./multi-session-architecture.md) for complete implementation details.

---

## 7. Security & Trust Model

> **ELI5:** *How do we keep you safe? The AI can do powerful things, but you're always in control. Three safety levels: Review Mode (the AI asks permission for risky stuff), Trusted Mode (you trust the AI more), and Sandbox Mode (the AI can only read, never write). Like parental controls but for code.*

### 7.1 Trust Modes [P0]

| Mode | Description | Use Case |
|------|-------------|----------|
| **Review Mode** (default) | Risky tools gated, file writes require review, shell commands need confirmation | General use, new users |
| **Trusted Mode** | Minimal gates, warnings but no blocks | Experienced users, personal projects |
| **Sandbox Mode** | Read-only + safe tools only, all writes blocked | Exploratory sessions, untrusted repos |

**Acceptance Criteria:**
- [ ] Mode clearly visible in UI at all times
- [ ] Switching modes requires confirmation
- [ ] Mode persists per-project

### 7.2 Policy Engine [P0]

**Rule Types:**

```json
{
  "name": "Safe Default",
  "rules": [
    {
      "type": "deny_file_write",
      "glob": "**/.env*",
      "reason": "Secrets file"
    },
    {
      "type": "deny_file_write",
      "glob": "**/prod/**",
      "reason": "Production config"
    },
    {
      "type": "require_confirm_bash",
      "pattern": "git push",
      "reason": "Network side effect"
    },
    {
      "type": "deny_bash",
      "pattern": "rm -rf",
      "reason": "Destructive command"
    },
    {
      "type": "require_confirm_bash",
      "pattern": "npm publish",
      "reason": "Public package release"
    }
  ]
}
```

**Rule Evaluation:**

1. On `PreToolUse` event, extract tool name and arguments
2. Match against policy rules in order
3. If match found:
   - `deny` -> Block with explanation
   - `require_confirm` -> Show approval modal
   - `allow` -> Proceed
4. If no match, use mode default

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Built-in policy presets | P0 | Paranoid, Safe Default, Fast/Trusted |
| Policy rule editor UI | P0 | Add, edit, delete rules |
| Policy import/export | P1 | JSON format |
| Per-project policies | P1 | Policies scoped to projects |
| Policy inheritance | P2 | Global + project policies merge |

### 7.3 Approval Workflows [P0]

**Approval Scopes:**

| Scope | Duration |
|-------|----------|
| **Once** | This specific action only |
| **Session** | All matching actions this session |
| **Project** | All matching actions in this project |
| **Always** | Add to allowlist permanently |

**Approval UI:**

```
+------------------------------------------------------------------+
| Policy: "Dangerous command detected"                              |
+------------------------------------------------------------------+
| The following action requires approval:                          |
|                                                                  |
| Tool: bash                                                       |
| Command: rm -rf ./build                                          |
| Matched rule: "deny_bash" with pattern "rm -rf"                  |
| Reason: Destructive command                                      |
|                                                                  |
| [Deny] [Allow Once] [Allow for Session] [Allow Always]           |
+------------------------------------------------------------------+
```

**Acceptance Criteria:**
- [ ] Blocked actions show clear explanation
- [ ] User understands exactly what they're approving
- [ ] Audit log records all approval decisions

### 7.4 Secrets Handling [P0]

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Never log secrets by default | P0 | `.env`, credentials files excluded |
| Secret pattern detection | P0 | Regex for API keys, tokens |
| Private mode toggle | P1 | Session marked "do not persist" |
| Secrets vault integration | P2 | 1Password/Keychain optional |

**Secret Patterns (Built-in):**
- `(api[_-]?key|apikey)\s*[:=]\s*['"][^'"]+['"]`
- `(password|passwd|pwd)\s*[:=]\s*['"][^'"]+['"]`
- `(secret|token)\s*[:=]\s*['"][^'"]+['"]`
- `sk-[a-zA-Z0-9]{32,}`
- `ghp_[a-zA-Z0-9]{36}`

### 7.5 Audit Trail [P1]

**Logged Events:**

| Event | Data Captured |
|-------|---------------|
| Session start/end | Timestamp, engine, project, mode |
| Tool execution | Tool name, sanitized args, success/failure, duration |
| Policy decisions | Rule matched, decision, scope |
| File modifications | File path, before/after hash, diff stats |
| Approval decisions | Action, user decision, scope |

**Acceptance Criteria:**
- [ ] Audit log queryable by date, project, event type
- [ ] Export audit log as CSV or JSON
- [ ] Audit data never contains file contents

---

## 8. Advanced Features

> **ELI5:** *These are the "pro user" features that make Blaze magical. Hooks let you run your own scripts when things happen (like auto-running tests after code changes). Memory lets the AI remember things across sessions. Recipes are like cooking recipes but for coding tasks. Worktrees let you work on multiple things at once without messing up your main code.*

### 8.1 Hook System [P1]

**Hook Events:**

| Event | Trigger |
|-------|---------|
| `OnSessionStart` | New session created |
| `OnSessionEnd` | Session completed or cancelled |
| `OnMessageSent` | User sends a message |
| `OnToolStart` | Tool execution begins |
| `OnToolEnd` | Tool execution completes |
| `OnDiffReady` | File diff produced |
| `OnError` | Engine or tool error |
| `OnApprovalRequired` | Policy block triggered |

**Hook Pack Format:**

```
myhooks/
  manifest.json
  hooks/
    on_tool_end.sh
    on_diff_ready.py
  config.json
```

**manifest.json:**
```json
{
  "name": "My Hook Pack",
  "version": "1.0.0",
  "events": ["OnToolEnd", "OnDiffReady"],
  "permissions": ["filesystem:read", "network:local"],
  "timeout_ms": 5000
}
```

**Hook Safety:**
- Hooks run in restricted environment
- Network access opt-in (local only by default)
- Timeout enforcement (5s default)
- Stdout captured as hook event

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Hook pack install/uninstall | P1 | CLI or UI management |
| Built-in hook examples | P1 | Auto-test, auto-summary |
| Hook event streaming | P1 | Hook output in timeline |
| Hook sandbox | P1 | Restricted execution environment |
| Hook pack linting | P2 | Security checks on install |

### 8.2 Context Intelligence [P2]

**Context Budget Monitoring:**

| Metric | Display |
|--------|---------|
| Tokens used | Progress bar toward limit |
| Tokens by category | Breakdown (system, messages, tools, files) |
| Compaction warning | Alert when > 80% used |
| Top context hogs | List of largest context consumers |

**Pre-Compaction Actions:**
1. Auto-generate session recap
2. Store recap to memory layer
3. Identify key files for next context
4. Build compact primer

**Context Pack Builder:**
- Select key files to include
- Select pinned messages
- Generate compact primer for new session

### 8.3 Local Memory Layer [P2]

**Memory Providers:**

| Provider | Implementation | Use Case |
|----------|----------------|----------|
| **Pins** | SQLite storage | User-selected important items |
| **Summaries** | Auto-generated | Session recaps, file summaries |
| **Vector Store** | Embedded SQLite-vec | Semantic search (optional) |

**Memory UI:**

```
+------------------------------------------------------------------+
| Memory: "Authentication flow"                                     |
+------------------------------------------------------------------+
| Pinned by user at 2025-12-24 10:30                               |
| Source: Session "Implement login"                                 |
|                                                                  |
| Content:                                                          |
| The auth flow uses JWT tokens with refresh...                    |
|                                                                  |
| [Unpin] [Edit] [Copy]                                            |
+------------------------------------------------------------------+
```

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Pin any message/diff/file | P2 | "Pin" action available everywhere |
| Memory retrieval view | P2 | Show why each item retrieved |
| Memory writeback | P2 | Auto-summarize sessions |
| Search memory | P2 | Keyword and semantic search |

### 8.4 Worktree-per-Task [P2]

**Workflow:**

1. User creates a "task" from command palette or plan item
2. Blaze creates `git worktree` for the task
3. Session runs in worktree directory
4. Changes isolated from main branch
5. User can merge or discard worktree

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Create worktree for task | P2 | Worktree in `.blaze-worktrees/` |
| Switch between worktrees | P2 | UI shows active worktree |
| Merge worktree | P2 | Creates commit on target branch |
| Discard worktree | P2 | Cleans up completely |
| Parallel worktrees | P2 | Multiple tasks simultaneously |

### 8.5 Recipes (Automation Workflows) [P2]

**Recipe Definition:**

```json
{
  "name": "Refactor Flow",
  "steps": [
    { "action": "create_branch", "name": "refactor/{task}" },
    { "action": "send_message", "prompt": "Analyze and propose refactoring plan" },
    { "action": "await_approval", "message": "Review plan before proceeding" },
    { "action": "send_message", "prompt": "Implement the refactoring" },
    { "action": "run_tests" },
    { "action": "if_success", "then": "create_commit" },
    { "action": "generate_pr_description" }
  ]
}
```

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Recipe list UI | P2 | View all available recipes |
| Run recipe | P2 | Execute with progress display |
| Pause/resume recipe | P2 | Human-in-the-loop at any step |
| Recipe editor | P3 | Create custom recipes |
| Recipe sharing | P3 | Export/import recipe packs |

### 8.6 Multi-Agent Orchestration [P3]

**Modes:**

| Mode | Description |
|------|-------------|
| **Sequential** | Claude writes, Gemini reviews |
| **Parallel** | Multiple engines working on subtasks |
| **Consensus** | 2/3 engines must agree on risky operations |
| **Verifier** | Secondary engine validates each diff |

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Run parallel sessions | P3 | Multiple engines active |
| Consensus mode | P3 | Configurable agreement threshold |
| Verifier agent | P3 | Auto-attach reviewer |
| Agent lanes UI | P3 | Visualize parallel work |

---

## 9. Distribution & Growth

> **ELI5:** *How do we get Blaze into people's hands and keep growing? We sign and notarize the app so Macs trust it, we capture emails for updates, and most importantly - we build virality so every user brings more users. The app stays free because our referral system builds an audience we can monetize later.*

### 9.1 Packaging Pipeline [P0]

**Build Steps:**

```bash
# 1. Build release
xcodebuild -project Blaze.xcodeproj -scheme Blaze -configuration Release

# 2. Sign
codesign --deep --force --options runtime \
  --sign "Developer ID Application: Your Name" \
  Blaze.app

# 3. Notarize
xcrun notarytool submit Blaze.zip \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

# 4. Staple
xcrun stapler staple Blaze.app

# 5. Package DMG
hdiutil create -volname "Cogit0 Blaze" \
  -srcfolder Blaze.app \
  -ov -format UDZO \
  Blaze.dmg

# 6. Verify
spctl --assess --type execute Blaze.app
```

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Developer ID signing | P0 | Valid signature |
| Notarization | P0 | Apple notarization passes |
| DMG packaging | P0 | Professional installer |
| Gatekeeper passes | P0 | Opens without warning on clean Mac |
| Reproducible builds | P1 | Same source -> same binary |

### 9.2 Auto-Update System [P1]

**Implementation:** Sparkle framework (or custom)

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Check for updates on launch | P1 | Silent background check |
| User-initiated check | P1 | Menu item "Check for Updates" |
| Release notes display | P1 | Show what's new before update |
| Delta updates | P2 | Smaller downloads for patches |
| Release channels | P2 | Stable, Beta, Nightly |
| Staged rollouts | P2 | Gradual percentage rollout |

### 9.3 Email Capture Flow [P1]

**Touchpoints:**

| Touchpoint | Conversion |
|------------|------------|
| Onboarding | Optional email during first run |
| Export session | Offer email for cloud backup (future) |
| Recipe marketplace | Email for pack downloads |
| Support bundle | Email for follow-up |

**Requirements:**

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Email capture form | P1 | Validated email input |
| Marketing consent checkbox | P1 | GDPR compliant |
| Backend integration | P1 | POST to cogit0.com/api/subscribe |
| Local fallback | P1 | Works even if backend down |
| Never block usage | P0 | App fully functional without email |

### 9.4 Viral Mechanics & Referral System [P1]

> **ELI5:** *Every user becomes a growth engine. When you invite a friend, and they invite their friends, everyone earns rewards. We track 3 levels deep - so if Alice invites Bob, and Bob invites Carol, and Carol invites Dave, Alice benefits from all three. This is how we build a massive email list for free.*

#### 9.4.1 RefRef.ai Integration

We use [RefRef.ai](https://refref.ai) as our referral infrastructure to enable multi-level invite tracking without building complex backend systems.

**Platform Hierarchy:**

```
Cogit0 Organization
    └── Blaze Product
        └── Launch Program (3-tier referrals)
            └── Participants (users)
                └── Referrals (tracked invites)
                    └── Qualifying Events (conversions)
                        └── Rewards (unlocked benefits)
```

**Integration Architecture:**

```swift
// RefRefIntegration.swift

@Observable
final class ReferralManager {
    private let apiKey: String
    private let programId: String
    private let baseURL = URL(string: "https://api.refref.ai/v1")!

    struct Participant: Codable {
        let id: String
        let email: String
        let referralCode: String
        let referralLink: URL
        let referredBy: String?
        let tier: Int  // 0 = direct signup, 1 = referred, 2 = 2nd level, 3 = 3rd level
        let totalReferrals: Int
        let qualifiedReferrals: Int
    }

    struct ReferralTree: Codable {
        let participant: Participant
        let directReferrals: [Participant]     // Level 1
        let secondLevelReferrals: [Participant] // Level 2
        let thirdLevelReferrals: [Participant]  // Level 3
    }

    /// Register a new user as a participant
    func registerParticipant(email: String, referredByCode: String?) async throws -> Participant {
        // POST /programs/{programId}/participants
        // Returns unique referral code and link
    }

    /// Track when a referred user completes activation (first session)
    func trackQualifyingEvent(participantId: String, eventType: QualifyingEvent) async throws {
        // POST /participants/{participantId}/qualifying-events
    }

    /// Get referral tree for a participant (3 levels deep)
    func getReferralTree(participantId: String) async throws -> ReferralTree {
        // GET /participants/{participantId}/referrals?depth=3
    }

    /// Check and award pending rewards
    func checkRewards(participantId: String) async throws -> [Reward] {
        // GET /participants/{participantId}/rewards
    }
}

enum QualifyingEvent: String, Codable {
    case emailVerified = "email_verified"
    case firstSession = "first_session"        // Primary conversion event
    case weeklyActive = "weekly_active"        // 7 days of usage
    case powerUser = "power_user"              // 50+ sessions
}
```

#### 9.4.2 Three-Level Invite System

**How It Works:**

```
                    ┌──────────────────────────────────────────────────────────────┐
                    │                    REFERRAL PYRAMID                          │
                    ├──────────────────────────────────────────────────────────────┤
                    │                                                              │
                    │     Alice (You)                                              │
                    │         │                                                    │
                    │         ├─────> Bob (Level 1: Direct Invite)                 │
                    │         │         │                                          │
                    │         │         ├─────> Carol (Level 2: Bob's invite)      │
                    │         │         │         │                                │
                    │         │         │         └─────> Dave (Level 3: Carol's)  │
                    │         │         │                                          │
                    │         │         └─────> Eve (Level 2)                      │
                    │         │                                                    │
                    │         └─────> Frank (Level 1)                              │
                    │                   │                                          │
                    │                   └─────> Grace (Level 2)                    │
                    │                                                              │
                    │  Alice's Total Referral Tree: 6 people across 3 levels       │
                    │                                                              │
                    └──────────────────────────────────────────────────────────────┘
```

**Reward Tiers:**

| Referral Level | Reward for Referrer | Example |
|----------------|---------------------|---------|
| **Level 1** (Direct) | Priority beta access + 30 extra context credits | You invite Bob directly |
| **Level 2** | 15 extra context credits | Bob invites Carol (you still benefit) |
| **Level 3** | 5 extra context credits | Carol invites Dave (you still benefit) |

**Cumulative Benefits:**

| Referral Milestone | Unlocked Benefit |
|--------------------|------------------|
| 3 qualified referrals | "Early Adopter" badge + priority support |
| 10 qualified referrals | Lifetime premium features (when released) |
| 25 qualified referrals | Name in credits + beta tester for new features |
| 100 qualified referrals | VIP Discord channel + direct product input |

#### 9.4.3 Referral Flow Implementation

**Step 1: User Registration (Email Capture)**

```swift
struct OnboardingEmailView: View {
    @State private var email = ""
    @State private var referralCode: String?  // From deep link or manual entry
    @Environment(ReferralManager.self) private var referrals

    var body: some View {
        VStack(spacing: 24) {
            Text("Join the Blaze Community")
                .font(.title)

            TextField("Your email", text: $email)
                .textFieldStyle(.roundedBorder)

            if let code = referralCode {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.green)
                    Text("Invited by a friend! You'll both get rewards.")
                }
            }

            Button("Continue") {
                Task {
                    let participant = try await referrals.registerParticipant(
                        email: email,
                        referredByCode: referralCode
                    )
                    // Store participant ID locally
                }
            }

            Text("Optional - skip if you prefer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

**Step 2: Referral Code Display (After First Session)**

```swift
struct ReferralDashboardView: View {
    @Environment(ReferralManager.self) private var referrals
    @State private var tree: ReferralManager.ReferralTree?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite Friends, Earn Rewards")
                .font(.headline)

            if let tree = tree {
                // Shareable referral link
                ShareableReferralCard(
                    link: tree.participant.referralLink,
                    code: tree.participant.referralCode
                )

                // Referral stats
                HStack(spacing: 24) {
                    StatCard(
                        title: "Level 1",
                        count: tree.directReferrals.count,
                        color: .green
                    )
                    StatCard(
                        title: "Level 2",
                        count: tree.secondLevelReferrals.count,
                        color: .blue
                    )
                    StatCard(
                        title: "Level 3",
                        count: tree.thirdLevelReferrals.count,
                        color: .purple
                    )
                }

                // Leaderboard position (optional gamification)
                LeaderboardPosition(rank: tree.participant.rank)
            }
        }
    }
}
```

**Step 3: Attribution Script for Web Landing Page**

```html
<!-- cogit0.com/blaze landing page -->
<script src="https://assets.refref.app/attribution.js"
        data-program-id="blaze-launch-2025"
        data-cookie-days="30">
</script>

<script>
// On download button click, capture attribution
document.getElementById('download-btn').addEventListener('click', function() {
    RefRef.trackEvent('download_initiated', {
        platform: 'macos',
        source: RefRef.getReferralCode() || 'organic'
    });
});
</script>
```

**Step 4: Deep Link Handling in App**

```swift
// Handle blaze://invite/CODE or https://cogit0.com/blaze?ref=CODE
@main
struct BlazeApp: App {
    @State private var pendingReferralCode: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if let code = extractReferralCode(from: url) {
                        pendingReferralCode = code
                        // Show email capture with referral attribution
                    }
                }
        }
    }

    private func extractReferralCode(from url: URL) -> String? {
        // Handle: blaze://invite/ABC123
        if url.scheme == "blaze" && url.host == "invite" {
            return url.pathComponents.last
        }
        // Handle: https://cogit0.com/blaze?ref=ABC123
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "ref" }?
            .value
    }
}
```

#### 9.4.4 Qualifying Events (Conversion Tracking)

Not every signup counts equally. We track specific "qualifying events" that indicate genuine usage:

| Event | Description | Triggers Reward |
|-------|-------------|-----------------|
| `email_verified` | User confirmed email | No (baseline requirement) |
| `first_session` | Completed first Claude Code session | **Yes** (primary conversion) |
| `weekly_active` | Used app on 3+ days in a week | Yes (bonus) |
| `power_user` | Completed 50+ sessions | Yes (bonus) |

**Webhook Processing:**

```swift
// Backend webhook handler (Vapor/Swift on server)
func handleRefRefWebhook(_ request: Request) async throws -> Response {
    let event = try request.content.decode(RefRefWebhookEvent.self)

    switch event.type {
    case "participant.created":
        // New user registered via referral
        await notifyReferrer(event.data.referredBy, newReferral: event.data.participant)

    case "qualifying_event.completed":
        // User completed a qualifying action
        if event.data.eventType == "first_session" {
            await awardReferralCredits(for: event.data.participant)
        }

    case "reward.unlocked":
        // User earned a reward
        await sendRewardNotification(event.data.participant, reward: event.data.reward)

    default:
        break
    }

    return Response(status: .ok)
}
```

#### 9.4.5 Viral Sharing Mechanics

Beyond the referral system, we embed sharing opportunities throughout the product:

| Mechanic | Implementation | Sharing Hook |
|----------|----------------|--------------|
| **Session sharing** | Export session as `.blaze` bundle | "Share with your team" CTA |
| **Policy pack sharing** | Export/import policy JSON | "Share your safety settings" |
| **Recipe sharing** | Export/import recipe packs | "Share your automation" |
| **Template packs** | Curated starter configurations | "Get started faster" |
| **Issue from diff** | "Open GitHub issue" from diff card | Attribution link in issue |
| **Social proof** | "Built with Blaze" badge | Optional footer for PRs |

**Referral Prompt Triggers:**

| Trigger | Prompt |
|---------|--------|
| First successful session | "Blaze worked! Share it with a friend for bonus credits" |
| 10th session | "You're a power user! Your referral tree could earn you lifetime premium" |
| After diff accept | "Just shipped code with AI? Invite teammates to try Blaze" |
| Weekly digest email | "Your referral stats + leaderboard position" |

#### 9.4.6 Analytics & Growth Metrics

**RefRef Dashboard Metrics:**

| Metric | Definition | Target (6 months) |
|--------|------------|-------------------|
| Viral coefficient | Avg referrals per user | > 1.0 (viral growth) |
| Referral conversion rate | Signups → First session | > 40% |
| Multi-level depth | Avg depth of referral trees | > 2.0 levels |
| Email capture rate | Downloads → Emails collected | > 60% |
| Referral link share rate | Users who share their link | > 30% |

**Revenue Readiness:**

The referral system builds a segmented email list:

| Segment | Criteria | Monetization Potential |
|---------|----------|------------------------|
| Power Users | 50+ sessions, weekly active | High - enterprise features |
| Influencers | 10+ qualified referrals | High - affiliate programs |
| Engaged | Weekly active, low referrals | Medium - premium upsell |
| Casual | Occasional use | Low - keep free, nurture |

When premium features launch, we can:
1. Offer early access to top referrers
2. Grandfather "lifetime premium" for 10+ referral users
3. Target enterprise outreach to power user emails
4. Create tiered pricing based on usage patterns

---

## 10. Technical Constraints & Dependencies

> **ELI5:** *What do you need to run Blaze? A Mac with macOS 14 or newer, the CLI tools installed (we help you set those up), and an internet connection for the AI. We depend on external CLIs that can change, so we're careful to handle updates gracefully.*

### 10.1 System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| macOS version | 14.0 (Sonoma) | 15.0 (Sequoia) |
| Architecture | Apple Silicon + Intel | Apple Silicon |
| RAM | 4 GB | 8 GB |
| Storage | 500 MB | 2 GB (with indexes) |
| CLI dependencies | Claude Code CLI | All three CLIs |

### 10.2 External Dependencies

| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| Claude Code CLI | Latest | Primary engine | Medium (breaking changes) |
| Gemini CLI | Latest | Secondary engine | Medium |
| Codex CLI | Latest | Tertiary engine | Medium |
| SQLite | 3.x | Local storage | Low |
| Sparkle | 2.x | Auto-updates | Low |
| Swift | 5.9+ | Language | Low |

### 10.3 API Constraints

| Constraint | Implication |
|------------|-------------|
| No direct Anthropic API | Must use Claude Code CLI |
| No direct Google API | Must use Gemini CLI |
| No direct OpenAI API | Must use Codex CLI |
| CLIs may change output format | Robust parsing with fallbacks |
| CLIs may add/remove features | Feature detection required |

### 10.4 Performance Budgets

| Metric | Target | Critical |
|--------|--------|----------|
| Launch time | < 1s | < 3s |
| Command palette open | < 50ms | < 200ms |
| First token render | < 100ms | < 500ms |
| Tool card render | < 50ms | < 200ms |
| Diff render (10K lines) | < 500ms | < 2s |
| Memory usage (idle) | < 200 MB | < 500 MB |
| Memory usage (active) | < 500 MB | < 1 GB |

---

## 11. Risk Register & Mitigation

> **ELI5:** *What could go wrong and how do we prevent it? CLIs might change their output format (we build robust parsers). Hooks could be security risks (we sandbox them). Users might leak secrets (we detect and warn). We think about problems before they happen.*

### 11.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **CLI breaking changes** | High | High | Pin supported versions, feature detection, robust parser fallbacks, engine diagnostics panel |
| **Hook inconsistencies** | Medium | Medium | Don't rely on single hook for safety, prefer PreToolUse gating, maintain own timeline |
| **Performance on large repos** | Medium | Medium | Incremental indexing, throttled file watchers, lazy UI rendering, pagination |
| **NDJSON parsing edge cases** | Medium | Low | Partial line buffering, max line limits, raw fallback mode |

### 11.2 Security Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Hooks as code execution vector** | Low | Critical | Ship minimal safe packs, warnings before enable, sandbox, pack signatures |
| **Secret leakage in logs** | Medium | High | Pattern detection, exclude sensitive files, private mode |
| **Malicious policy packs** | Low | Medium | Pack linting, signature verification, warning UI |

### 11.3 Product Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **User trust concerns** | Medium | High | Clear privacy policy, local-first, opt-in telemetry, "what was sent" viewer |
| **Complexity overwhelms users** | Medium | Medium | Progressive disclosure, sane defaults, excellent onboarding |
| **CLI adoption too slow** | Medium | Medium | Focus on Claude first, add value before multi-engine |

### 11.4 Business Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Apple Developer Program delays** | Low | Medium | Start enrollment early, have unsigned alpha ready |
| **CLI vendors build competing UI** | Medium | High | Build moat via policy engine, multi-engine, and ecosystem |
| **macOS-only limits market** | Low | Low | Validate value before cross-platform investment |

---

## 12. Success Metrics

> **ELI5:** *How do we know if Blaze is working? We track downloads, active users, crashes, and how happy people are. If users keep coming back daily and telling their friends, we're winning. Numbers don't lie - they tell us what to fix and what to double down on.*

### 12.1 Activation Metrics

| Metric | Definition | Target (30 days) |
|--------|------------|------------------|
| Downloads | DMG downloaded | 1,000 |
| Installs | App opened at least once | 800 |
| Activation | First successful session completed | 500 |
| Email capture | Emails collected | 300 |

### 12.2 Engagement Metrics

| Metric | Definition | Target (Weekly) |
|--------|------------|-----------------|
| WAU | Weekly active users | 200 |
| Sessions/user | Avg sessions per week per user | 5 |
| Tool cards/session | Avg tool calls per session | 10 |
| Diffs reviewed | Diffs viewed in diff viewer | 80% of sessions |

### 12.3 Quality Metrics

| Metric | Target |
|--------|--------|
| Crash-free rate | > 99.5% |
| P99 launch time | < 2s |
| P99 command palette open | < 100ms |
| NPS (surveyed users) | > 50 |

### 12.4 Business Metrics

| Metric | Definition | Target (6 months) |
|--------|------------|-------------------|
| Email list size | Subscribed users | 2,000 |
| Policy pack downloads | Pack import count | 500 |
| Recipe downloads | Recipe import count | 300 |

---

## 13. Roadmap & Milestones

> **ELI5:** *When do features ship? Weeks 1-2: basic app that works with Claude with proper testing. Month 1: stable daily driver. Month 3: support multiple AI engines. Month 6: advanced features like memory and recipes. Year 1: marketplace and enterprise features. We ship fast and iterate.*

### 13.1 Phase 1: MVP (Days 1-14)

**Goal:** Working app with Claude Code, streaming UI, tool cards, basic diffs, with proper testing and stabilization.

**Structure:** Days 1-10 for feature development, Days 11-14 for testing and stabilization.

| Day | Focus | Deliverables |
|-----|-------|--------------|
| 0 | Setup | Xcode project, CLI validation, LanceDB integration |
| 1 | Foundation | NavigationSplitView, ProcessRunner, EngineAdapter protocol |
| 2 | Data Layer | LanceDB schema setup, JSONL journaling |
| 3 | Streaming | NDJSON decoder, incremental text rendering |
| 4 | Streaming Polish | Smooth scrolling, 60fps rendering, typing indicator |
| 5 | Tool Cards | Collapsible cards, duration display, success/failure states |
| 6 | Timeline Sidebar | Event list, filtering, jump-to-event |
| 7 | Diffs | Basic unified diff viewer, syntax highlighting |
| 8 | Diff Actions | Accept/reject per file, before/after preview |
| 9 | Command Palette | Raycast-style palette, fuzzy search, keyboard shortcuts |
| 10 | Session Management | Create/resume sessions, persistence, session list UI |
| 11 | Testing | Unit tests, integration tests, edge case handling |
| 12 | Testing | Performance profiling, memory leak detection |
| 13 | Stabilization | Bug fixes, crash recovery testing, error handling |
| 14 | Packaging | Signing stub, DMG script, notarization prep |

**Acceptance Criteria:**
- [ ] App runs Claude Code headlessly
- [ ] Streaming output renders smoothly at 60fps
- [ ] Tool cards display with durations and status
- [ ] Diffs viewable and actionable (accept/reject)
- [ ] Sessions persist across restart (LanceDB + JSONL recovery)
- [ ] Command palette opens in < 50ms
- [ ] All P0 features have unit tests
- [ ] DMG builds successfully
- [ ] No known crash conditions

### 13.2 Phase 2: Daily Driver (Days 15-45)

**Goal:** Robust session model, real workspace, policy engine, stability.

| Week | Focus | Key Deliverables |
|------|-------|------------------|
| 3 | Sessions | Session library, profiles, resume/fork, branch conversations |
| 4 | Workspace | File tree, read-only editor, multi-file workspace |
| 5 | Policies | Policy packs, PreToolUse gating, approval workflows |
| 6 | Observability | Timeline filters, checkpoints, error recovery flows |
| 7 | Polish | Performance optimization, keyboard shortcuts, accessibility |

**Acceptance Criteria:**
- [ ] 100+ sessions manageable
- [ ] Large files (1-3MB) open without stutter
- [ ] Policy blocks are explainable and overrideable
- [ ] App never loses session data
- [ ] Timeline exportable as report

### 13.3 Phase 3: Multi-Engine (Days 46-105)

**Goal:** EngineAdapter abstraction, Gemini integration, Codex integration.

| Week | Focus | Key Deliverables |
|------|-------|------------------|
| 8-9 | Abstraction | NormalizedEvent v1, EngineAdapter refinement, EngineRegistry |
| 10-11 | Gemini | GeminiCliAdapter, session resume, MCP browser |
| 12-13 | Codex | CodexCliAdapter, sandbox/approval policies |
| 14-15 | Hooks | Engine-agnostic HookRunner, built-in hook examples |

**Acceptance Criteria:**
- [ ] All three engines functional
- [ ] Engine switcher UI works
- [ ] Same UX quality regardless of engine
- [ ] Hooks work across all engines

### 13.4 Phase 4: Premium Features (Days 106-195)

**Goal:** Editor, recipes, memory layer, context intelligence, multi-agent.

| Week | Focus | Key Deliverables |
|------|-------|------------------|
| 16-18 | Editing | Embedded editor, LSP integration, worktree-per-task |
| 19-21 | Memory | Local memory layer, pins, retrieval UI, context budgeting |
| 22-24 | Context | Context window management, auto-summarization, compaction |
| 25-28 | Orchestration | Recipes, multi-agent modes, consensus, parallel agents |

**Acceptance Criteria:**
- [ ] Edit files directly in app
- [ ] Run 3 tasks in parallel safely
- [ ] Context budget visible and actionable
- [ ] Recipes run end-to-end

### 13.5 Phase 5: Platform (Days 196-365)

**Goal:** Extensibility, marketplace patterns, enterprise readiness.

| Week | Focus | Key Deliverables |
|------|-------|------------------|
| 29-36 | Extensibility | Hook/policy marketplace, plugin system, diagnostics bundles |
| 37-44 | Enterprise | Team policies, audit exports, role-based permissions |
| 45-52 | Scale | Performance at scale, multi-user support, cloud sync (optional) |

---

## 14. Appendices

> **ELI5:** *Extra reference material: code snippets to copy-paste, checklists to follow, schemas to implement. Think of this as the cookbook recipes that go with the main menu.*

### Appendix A: MVP Prompt for Claude Code

Use this to bootstrap development:

```
Project goal: Implement a macOS SwiftUI app that runs Claude Code CLI headlessly and renders stream-json output into a modern UI.

Must-have:
- NavigationSplitView (sessions | chat | sidebar)
- Process runner that executes `claude -p <prompt> --output-format stream-json`
- LanceDB for primary storage with JSONL journaling for crash recovery
- Parse NDJSON line-by-line into typed events
- Streaming assistant output rendered incrementally
- Tool calls rendered as collapsible cards with duration
- Session persistence and event log to disk

Deliverables:
- Xcode project
- ClaudeRunner.swift
- EventModels.swift
- EventStore.swift (JSONL + SQLite)
- MainView.swift (3-pane UI)
- CommandPalette.swift
- DiffViewer.swift (initial)
- release.sh placeholder
```

### Appendix B: Hook Telemetry JSONL Format

```json
{
  "source": "hook",
  "hook_event": "PreToolUse",
  "ts": "2025-12-24T12:34:56Z",
  "session_id": "abc123",
  "payload": {
    "tool": "bash",
    "args": "git status"
  }
}
```

### Appendix C: Policy Rules Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "version": { "type": "string" },
    "rules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": {
            "enum": [
              "deny_file_write",
              "deny_file_read",
              "deny_bash",
              "require_confirm_bash",
              "allow_bash",
              "deny_tool",
              "require_confirm_tool"
            ]
          },
          "glob": { "type": "string" },
          "pattern": { "type": "string" },
          "tool": { "type": "string" },
          "reason": { "type": "string" }
        },
        "required": ["type", "reason"]
      }
    }
  },
  "required": ["name", "rules"]
}
```

### Appendix D: NormalizedEvent Swift Types

```swift
enum NormalizedEvent: Codable {
    // Session lifecycle
    case sessionStarted(SessionStartedPayload)
    case sessionResumed(SessionResumedPayload)
    case sessionEnded(SessionEndedPayload)

    // Model output
    case assistantDelta(AssistantDeltaPayload)
    case assistantFinal(AssistantFinalPayload)
    case assistantMeta(AssistantMetaPayload)

    // Tooling
    case toolPlanned(ToolPlannedPayload)
    case toolCallStarted(ToolCallStartedPayload)
    case toolCallStdout(ToolCallStdoutPayload)
    case toolCallStderr(ToolCallStderrPayload)
    case toolCallCompleted(ToolCallCompletedPayload)
    case fileDiffProduced(FileDiffProducedPayload)
    case fileEditApplied(FileEditAppliedPayload)

    // Safety
    case permissionRequested(PermissionRequestedPayload)
    case permissionDecision(PermissionDecisionPayload)
    case policyViolation(PolicyViolationPayload)

    // Errors
    case engineError(EngineErrorPayload)
    case toolError(ToolErrorPayload)

    // Stats
    case usageStats(UsageStatsPayload)
    case contextBudget(ContextBudgetPayload)
}

struct EventEnvelope: Codable {
    let id: UUID
    let sessionId: String
    let timestamp: Date
    let sequence: Int
    let source: EventSource
    let event: NormalizedEvent
}

enum EventSource: String, Codable {
    case engine
    case hook
    case worker
    case user
}
```

### Appendix E: Release Checklist

**Pre-Release:**
- [ ] All P0 features complete and tested
- [ ] Performance budgets met
- [ ] Crash-free rate > 99.5% on internal testing
- [ ] Privacy policy published on website
- [ ] Terms of service published
- [ ] Email capture backend ready

**Build:**
- [ ] Clean build on CI
- [ ] All tests passing
- [ ] Version number incremented
- [ ] Release notes written

**Signing:**
- [ ] Developer ID certificate valid
- [ ] Codesign successful
- [ ] Notarization submitted and approved
- [ ] Ticket stapled

**Distribution:**
- [ ] DMG passes Gatekeeper on clean VM
- [ ] Download page live
- [ ] Analytics tracking download events
- [ ] Email notification ready

**Post-Release:**
- [ ] Monitor crash reports
- [ ] Monitor download counts
- [ ] Monitor email signups
- [ ] Respond to initial user feedback

### Appendix F: Glossary

| Term | Definition |
|------|------------|
| **Blaze** | Cogit0 Blaze, this application |
| **Engine** | An agentic coding CLI (Claude Code, Gemini CLI, Codex CLI) |
| **EngineAdapter** | The abstraction layer between Blaze and an engine |
| **NormalizedEvent** | The unified event schema all adapters produce |
| **Hook** | User-defined automation triggered by events |
| **Policy** | Rules that gate or allow engine actions |
| **Recipe** | Multi-step automation workflow |
| **Worktree** | Git worktree for isolated task work |
| **Session** | A conversation with an engine in a project context |
| **Turn** | One user message + engine response cycle |
| **Tool Card** | UI component showing a tool call |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-25 | Product Team | Initial PRD |

---

**End of Document**

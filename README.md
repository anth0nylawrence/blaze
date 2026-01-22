# Cogit0 Blaze

<p align="center">
  <img src="./Blaze/Resources/Logos/blaze-logo.png" alt="Blaze Logo" width="128" height="128" />
</p>

<h3 align="center">The native control plane for agentic coding.</h3>

<p align="center">
  <strong>Claude Code. Gemini CLI. OpenAI Codex. One cockpit.</strong>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> |
  <a href="#features">Features</a> |
  <a href="#architecture">Architecture</a> |
  <a href="./docs/CONTRIBUTING.md">Contributing</a>
</p>

<p align="center">
  <!-- Badges - replace with actual URLs when ready -->
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square&logo=apple" />
  <img alt="Swift 5.9" src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" />
  <img alt="License" src="https://img.shields.io/badge/license-TBD-lightgrey?style=flat-square" />
  <img alt="Build Status" src="https://img.shields.io/badge/build-passing-brightgreen?style=flat-square" />
</p>

---

**Three promises:**

1. **Native performance** - SwiftUI with glass effects, 60fps streaming, zero Electron bloat
2. **Visual automation** - Node-based hooks builder. Drag. Connect. Ship.
3. **Run agents in parallel** - Claude fixes bugs while Codex writes tests. Same repo. Different worktrees.

---

## What is Blaze?

Blaze is a macOS desktop application that wraps agentic coding CLIs (Claude Code, Gemini CLI, OpenAI Codex CLI) in a polished native interface.

**The elevator pitch:** You get the raw power of CLI agents, minus the terminal fatigue. Tool calls become cards. Diffs become reviewable PRs. Bash commands need your approval. Everything streams at 60fps with that macOS glass aesthetic.

### Plain English

Think of Blaze as Mission Control for AI coding agents. The CLI does the work. Blaze shows you what's happening, lets you approve dangerous operations, and keeps a perfect audit trail.

It spawns CLI processes, reads their structured JSON output, and renders everything in a proper GUI. No API keys to manage. No token counting in your head. Just run `claude` or `gemini` through a UI that doesn't make your eyes bleed.

### What Blaze is NOT

| Not This | This Instead |
|----------|--------------|
| Terminal emulator | Structured event renderer |
| Web wrapper / Electron app | Native SwiftUI with glass materials |
| API client | CLI orchestrator (uses official CLIs) |
| Code editor | Coding agent cockpit |

### Who is Blaze for?

**Great fit:**
- Developers who use Claude Code / Gemini CLI daily and want a better UX
- Teams that need audit trails and approval workflows for AI-assisted coding
- Anyone who wants to run multiple agents in parallel on the same codebase

**Not a fit:**
- Looking for a VS Code extension (try Cursor or Continue)
- Need Windows/Linux today (macOS only for now)
- Want direct API access (Blaze uses CLIs, not provider APIs)

---

## 30-Second Demo

<p align="center">
  <!-- TODO: Replace with actual GIF/video -->
  <img src="./docs/resources/demo-placeholder.gif" alt="Blaze Demo" width="800" />
  <br />
  <em>Creating a React component with Claude Code through Blaze</em>
</p>

**What you just saw:**

1. **Prompt sent** - Natural language request in the chat pane
2. **Tool cards appear** - Each `Read`, `Write`, `Bash` call gets its own collapsible card with timing
3. **Diff review** - File changes shown in PR-style unified diff. Accept or reject.
4. **Streaming response** - Token-by-token rendering. No waiting for the full response.
5. **Session saved** - Everything persisted. Resume tomorrow where you left off.

### Minimal Walkthrough

```bash
# 1. Install Blaze (download DMG from releases)
open Blaze.dmg && cp -R Blaze.app /Applications/

# 2. Launch and authenticate
# Blaze triggers `claude login` on first run - you auth with Anthropic directly

# 3. Open a project
# Cmd+O or drag a folder onto Blaze

# 4. Start coding
# Type a prompt. Watch the magic.
```

---

## Why Blaze Exists

### The Pain of CLI-Only

Terminal-based AI coding is powerful but exhausting:

- **Context blindness** - You can't see what the agent is about to do until it does it
- **Scroll archaeology** - Finding that one tool call from 10 minutes ago
- **Copy-paste diffs** - Reviewing changes means manual `git diff` gymnastics
- **No pause button** - Agent runs wild. You watch. You pray.
- **Session amnesia** - Close terminal, lose context. Start over.

### What "Agentic" Feels Like in a Native GUI

Blaze transforms the experience:

| CLI Pain | Blaze Solution |
|----------|----------------|
| Wall of text | Collapsible tool cards with duration, inputs, outputs |
| Scroll to find | Timeline view with filters. Jump to any event. |
| `git diff \| less` | Inline diff viewer with syntax highlighting. Accept/Reject buttons. |
| No control | Three trust modes: Review (approve everything), Trusted, Sandbox |
| Lost sessions | SQLite + JSONL persistence. Crash-safe. Searchable. |

### The Opportunity Cost

Every hour spent fighting terminal UX is an hour not shipping. Blaze gives you back that time.

The hooks builder alone saves days of YAML wrangling. Drag a "PreToolUse" trigger, connect it to a "Block if path matches" condition, wire up a notification action. Export. Done.

And with git worktree support, you can run Claude Code on a bug fix while Codex writes integration tests - simultaneously, isolated, on the same repo. That's not a workflow optimization. That's a multiplier.
## 4. Key Concepts

Before diving into features, here are the core concepts that make Blaze tick.

### Agents

AI assistants that execute coding tasks. Each agent is a CLI process (Claude Code, Codex CLI, or Gemini CLI) that Blaze spawns, monitors, and orchestrates. Agents can run in parallel, each isolated in its own worktree.

**Key points:**
- Agents are defined as markdown files in `~/.claude/agents/`
- You can configure concurrency limits (default: 10, max: 100)
- Auto-throttle reduces concurrency when system resources run low
- Each agent has a timeout (default: 300 seconds)

### Providers

The AI backend powering your agents. Currently supported:

| Provider | CLI | Model Examples |
|----------|-----|----------------|
| Anthropic | Claude Code | Claude Sonnet, Claude Opus |
| OpenAI | Codex CLI | o1, o3-mini, GPT-4 |
| Google | Gemini CLI | Gemini Pro, Gemini Ultra |

Switch providers per-session. Each has its own authentication flow and environment variables.

### Sessions

A session represents a single task or conversation with an agent. Sessions persist across app restarts and include:

- **Messages**: The full conversation history
- **Metadata**: Token usage, cost, turn count
- **State**: Idle, streaming, waiting, or error
- **Project binding**: Linked to a specific repository

Sessions are stored in SQLite with WAL mode for durability. Each session gets an NDJSON log file for replay and debugging.

### Workspaces (Projects)

Your codebase. Sessions are grouped by project path. The sidebar shows all your projects with their active sessions nested underneath.

When you select a project folder, Blaze canonicalizes the path to handle symlinks and relative paths consistently.

### Git Worktrees

Each session can have its own isolated git worktree. This means multiple agents can work on the same repo simultaneously without stepping on each other.

**How it works:**
1. Worktrees live in `{repo}/.blaze-worktrees/{sessionId}/`
2. Each worktree gets its own branch: `blaze-session-{short-uuid}`
3. Changes stay isolated until you merge them
4. Orphan detection cleans up abandoned worktrees

**Why this matters:** Run frontend fixes and backend refactoring in parallel. No merge conflicts until you choose to merge.

### Tools

Actions that agents can take: read files, write files, run commands, search the web, etc. Blaze intercepts tool calls and renders them as rich cards in the timeline.

Tool categories:
- **Read-only**: `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`
- **Write**: `Write`, `Edit`, `NotebookEdit`
- **Execute**: `Bash` (shell commands)
- **Interactive**: `AskUserQuestion`, `TodoWrite`

### Hooks

Event handlers that run before or after tool execution. Blaze supports the Claude Code hooks system:

| Hook Event | When It Fires |
|------------|---------------|
| `PreToolUse` | Before a tool runs (can block) |
| `PostToolUse` | After a tool completes |
| `UserPromptSubmit` | Before processing user input |
| `SessionStart` | On session start or resume |
| `Stop` | When agent finishes |

Register hooks in `.claude/settings.json`. They run as shell commands with JSON input/output.

### Trust Modes

Security levels that control what agents can do without asking.

| Mode | Behavior | CLI Flag |
|------|----------|----------|
| **Review** | Ask permission for everything | (default) |
| **Trusted** | Ask once per tool, then auto-allow | `--allowedTools <list>` |
| **YOLO** | Skip ALL permission prompts | `--dangerously-skip-permissions` |
| **Sandbox** | Read-only tools only | `--allowedTools Read,Glob,Grep,...` |

**Review** is recommended for most users. **YOLO** mode is for experienced users who accept full risk.

---

## 5. Feature Tour

### 5.1 Native macOS GUI and Theme Engine

Blaze is a native SwiftUI app. No Electron. No web wrapper. Just pure macOS performance with proper transparency, vibrancy, and system integration.

#### What

A fully customizable appearance system with glass effects, accent colors, and six built-in themes.

#### Why

Terminal-based CLIs force you into their aesthetic. Blaze lets you match your desktop, reduce eye strain, and work the way you want.

#### How

The theme engine uses semantic color tokens that adapt to your choices:

```swift
// Core semantic colors
background    // Deepest layer
surface       // Card backgrounds
surfaceHover  // Interactive states
accent        // Primary brand color
accentHover   // Hover states for accent
textPrimary   // Main text
textSecondary // Subtitles, labels
textMuted     // Tertiary text
border        // Separators, outlines
success       // Positive states
warning       // Caution indicators
error         // Error states
```

#### Built-in Themes

| Theme | Description | Vibe |
|-------|-------------|------|
| **Nebula** | Deep blue dark aesthetic | Ghostty-inspired |
| **Obsidian** | Pure dark with minimal contrast | Sleek, professional |
| **Aurora** | Cyan/teal accents on dark | Nature-inspired |
| **Sunrise** | Warm dark with orange accents | Cozy, inviting |
| **Monochrome** | Grayscale only, no color | Minimalist |
| **Hyperion** | Deep purple dark aesthetic | Original Nebula colors |

#### Glass Levels

Control transparency and blur intensity:

- **None**: Solid backgrounds, no blur
- **Subtle**: Light transparency
- **Regular**: Balanced (default)
- **Prominent**: Maximum glass effect

Glass effects use `NSVisualEffectView` under the hood for native macOS vibrancy.

#### Accent Colors

Nine preset accent colors plus custom:

Blue, Purple, Pink, Red, Orange, Yellow, Green, Mint, Teal

Select any color and it propagates through the entire UI: buttons, selections, highlights, focus rings.

#### Custom Themes

Don't like the presets? Create your own:

1. Open **Settings > Appearance**
2. Click **New Theme**
3. Pick colors for each semantic token
4. Adjust glass level and accent
5. Save with a custom name

Custom themes persist and can be exported/shared.

#### Controls

**Settings > Appearance**
- Theme picker grid with live preview
- Glass level segmented control
- Accent color swatches
- Reset to defaults button
- Theme editor for full customization

---

### 5.2 Multi-Provider, Multi-Agent Orchestration

Run Claude Code and Codex CLI side by side. Assign different tasks to different engines. Let the best model for the job handle each task.

#### What

A unified orchestration layer that spawns, monitors, and coordinates multiple AI agents across providers.

#### Why

Different models excel at different tasks:
- Claude Sonnet: Fast iteration, broad knowledge
- Claude Opus: Complex reasoning, long-context
- o1/o3: Mathematical reasoning, code optimization
- GPT-4: General purpose, tool use

Why choose one when you can use them all?

#### How

The `EngineAdapter` protocol abstracts CLI differences:

```
+-----------------------------------------------------+
|                    Blaze UI                         |
+-----------------------------------------------------+
|              SessionOrchestrator                    |
+-----------------------------------------------------+
|   ClaudeAdapter    CodexAdapter    GeminiAdapter    |
|        |                |               |           |
|        v                v               v           |
|   claude -p ...    codex exec ...  gemini -p ...    |
+-----------------------------------------------------+
```

Each adapter:
- Spawns the CLI with correct flags
- Parses streaming JSON output
- Maps events to `NormalizedEvent` types
- Handles authentication flows
- Manages process lifecycle

#### Parallel Worktrees

Run multiple agents on the same repo without conflicts:

```
my-project/
  .blaze-worktrees/
    abc12345-session-1/    # Claude working on auth
    def67890-session-2/    # Codex optimizing queries
    ghi11111-session-3/    # Claude writing tests
```

Each worktree is a full checkout with its own branch. Merge when ready.

#### Collaboration Patterns

**Divide and conquer:**
1. Start Session A with Claude: "Implement the data model"
2. Start Session B with Codex: "Optimize the SQL queries"
3. Both run in parallel, isolated
4. Review and merge results

**Specialist agents:**
- Use Claude Opus for architecture decisions
- Use Claude Sonnet for rapid implementation
- Use o1 for algorithmic problems
- Use Gemini for research and docs

#### Engine Settings

Per-provider configuration:

**Claude Code:**
- API key (Anthropic, Bedrock, or Vertex)
- Max tokens per response
- Model selection

**Codex CLI:**
- OpenAI API key
- Organization ID
- Sandbox mode toggle
- OAuth login flow

**Gemini CLI:**
- Google API key
- Model selection
- Service account credentials

#### Controls

**Settings > Engines**
- Default engine picker (segmented)
- Environment variables per engine
- OAuth authentication for Codex
- Test connection button
- MCP server configuration (coming soon)

**Session creation:**
- Provider dropdown (Anthropic, OpenAI, Google)
- Model dropdown (filtered by provider)
- Per-session overrides

---

### 5.3 Structured Event Rendering

Raw CLI output becomes a rich, interactive timeline. Every tool call, file diff, and status update gets its own card.

#### What

A real-time event stream that transforms JSON events into visual components: tool cards, diff viewers, progress indicators, and interactive prompts.

#### Why

Terminal output is linear and ephemeral. You can't easily:
- Jump back to see what that file edit actually changed
- Approve or reject individual diffs
- Track which tools are pending vs complete
- Get an overview of session activity

Blaze structures everything so you can review, navigate, and interact.

#### How

The event pipeline:

```
CLI stdout (NDJSON)
    |
    v
EngineAdapter.parseEvent()
    |
    v
NormalizedEvent (unified type)
    |
    v
EventEnvelope (sequenced, timestamped)
    |
    v
EventStore (SQLite persistence)
    |
    v
ChatTimeline (SwiftUI rendering)
```

#### Event Types

Content events:
- `assistantDelta` - Streaming text chunks
- `assistantComplete` - Full response when done
- `thinkingDelta` - Model reasoning (Claude)
- `reasoningDelta` - Model reasoning (Codex)

Tool events:
- `toolCallStarted` - Tool invocation begins
- `toolCallComplete` - Tool finishes with result
- `toolRequest` - Pending approval request
- `toolDecision` - User approved/rejected
- `toolResult` - Execution output

File events:
- `fileDiffProduced` - Unified diff with hunks
- `fileWritten` - Write confirmation
- `fileRead` - Read operation logged

Subagent events:
- `subagentSpawned` - Background agent started
- `subagentProgress` - Status update
- `subagentCompleted` - Finished successfully
- `subagentFailed` - Encountered error

#### Tool Cards

Every tool call renders as an expandable card:

```
+-----------------------------------------------+
| ? AskUserQuestion                             |
|                                               |
| Which approach do you prefer?                 |
| Please select one option to continue.         |
|                                               |
| ( ) Quick Implementation                      |
|     Fast but minimal features                 |
|                                               |
| (*) Thorough Implementation                   |
|     Complete features with full test coverage |
|                                               |
| ( ) Iterative Approach                        |
|     Start simple and expand over time         |
|                                               |
|                            [Submit]           |
+-----------------------------------------------+
```

Features:
- Single-select or multi-select options
- Free-text input for unknown tools
- Submission state (idle, submitting, submitted, failed)
- Retry button on failure
- Raw JSON disclosure for debugging

#### Rich Diff Viewer

File changes display as syntax-highlighted diffs:

```
+-----------------------------------------------+
| > ContentView.swift       +5 -2       [v] [x] |
+-----------------------------------------------+
| @@ -3,5 +3,7 @@                                |
|   import SwiftUI                              |
|                                               |
| - struct OldView: View {                      |
| + struct NewView: View {                      |
| +     let title: String                       |
|       var body: some View {                   |
| -         Text("Hello")                       |
| +         Text(title)                         |
| +             .font(.headline)                |
|       }                                       |
+-----------------------------------------------+
```

Features:
- Syntax highlighting per language
- Line numbers (old and new)
- Collapsible hunks
- Accept/Reject buttons per file
- Large diff warning with "Show All" option
- Decision badges (Pending, Accepted, Rejected, Modified)

Supported languages: Swift, JavaScript, TypeScript, Python, Go, Rust, and more.

#### Real-Time Streaming

Text streams character-by-character as the model generates. No waiting for complete responses.

The UI accumulates `assistantDelta` events into a growing text block. When `assistantComplete` fires, the message is finalized and persisted.

Progress indicators show:
- Thinking spinner during model reasoning
- Tool execution status
- Subagent activity

#### Activity Timeline

The sidebar shows recent activity across all sessions:

- Which session is streaming
- Pending approval requests (badge count)
- Errors requiring attention
- Subagent spawns and completions

Click any event to jump to that point in the conversation.

#### Controls

**Chat view:**
- Collapsible tool cards (click to expand/collapse)
- Diff viewer modal (click diff card for full-screen)
- Copy button for code blocks
- Scroll-to-bottom with new message indicator

**Sidebar:**
- Activity stream with timestamps
- Filter by event type
- Session quick-switch

**Settings > Chat:**
- Auto-expand tool cards toggle
- Diff viewer theme
- Code font family and size
## 5.4 Governance & Permissions

Blaze provides a comprehensive security layer between you and the AI agent. Rather than relying solely on CLI-level prompts, Blaze offers a visual governance system that maps directly to provider CLI flags while adding approval workflows the CLIs don't natively support.

### Trust Modes

Four security levels control how Blaze interacts with agent CLIs:

| Mode | Description | CLI Mapping | Risk Level |
|------|-------------|-------------|------------|
| **Review** | Every tool invocation requires approval | Default CLI behavior (no flags) | Safest |
| **Trusted** | Ask once per tool, then auto-approve | `--allowedTools <list>` | Moderate |
| **YOLO** | Skip ALL permission prompts | `--dangerously-skip-permissions` | Dangerous |
| **Sandbox** | Read-only tools only | `--allowedTools Read,Glob,Grep,WebFetch,WebSearch` | Safest |

**Review Mode (Default)**: The agent asks permission for every file write, command execution, and network request. This mirrors the default Claude Code behavior but adds Blaze's visual diff previews and one-click approval UI.

**Trusted Mode**: Implements "ask once" semantics. When you approve a tool (e.g., `Bash`), it's added to your trusted list and auto-approves for the rest of the session. The trusted tools list persists and can be managed in Settings:

```
Trusted Tools: [Bash] [Read] [Write] [Edit] [Glob] [+]
              Quick add: Grep | WebFetch | WebSearch
```

**YOLO Mode**: For experienced users who understand the risks. Blaze passes `--dangerously-skip-permissions` to the CLI, bypassing all safety prompts. A confirmation dialog warns:

> "YOLO mode uses --dangerously-skip-permissions to bypass ALL Claude Code safety prompts. The agent can execute any command, write any file, and make network requests without asking."

**Sandbox Mode**: Read-only exploration. Only safe tools are allowed: `Read`, `Glob`, `Grep`, `WebFetch`, `WebSearch`. Perfect for auditing codebases or learning without risk.

### Command Allowlist

Beyond trust modes, Blaze maintains a granular command allowlist for shell operations:

```
Command     | Description              | Permission
----------- | ------------------------ | -----------
ls          | List directory contents  | [x] Read
cat         | Display file contents    | [x] Read
grep        | Search text patterns     | [x] Read
mkdir       | Create directories       | [ ] Read+Write
rm          | Remove files/directories | [ ] Read+Write
```

Each command can be toggled individually with **Read** or **Read+Write** permissions. Git commands redirect to a separate Git Settings panel for more granular control.

### Auto-Approve Patterns

File patterns that skip confirmation prompts (for Trusted and Review modes):

```
*.swift     - All Swift files
src/*       - Files in src/ directory
**/*.ts     - TypeScript files anywhere
tests/**/*  - Anything in tests folder
```

Pattern matching uses glob syntax. In Sandbox mode, patterns are ignored (no writes allowed). In YOLO mode, all files auto-approve.

### Approval Flow in Practice

When the agent requests a risky operation in Review or Trusted mode:

```
 ┌─────────────────────────────────────────────────────────────┐
 │  Permission Request                                         │
 │  ─────────────────────────────────────────────────────────  │
 │  Tool: Bash                                                 │
 │  Command: rm -rf ./build/                                   │
 │                                                             │
 │  This command will delete the build directory.              │
 │                                                             │
 │  ┌─────────────────────────────────────────────────────┐   │
 │  │ ./build/                                             │   │
 │  │   cache/          (147 files)                        │   │
 │  │   artifacts/      (23 files)                         │   │
 │  │   ...                                                │   │
 │  └─────────────────────────────────────────────────────┘   │
 │                                                             │
 │  [Deny]  [Allow Once]  [Allow & Trust Bash]                │
 └─────────────────────────────────────────────────────────────┘
```

Choosing "Allow & Trust Bash" adds Bash to your trusted tools list, auto-approving future Bash commands for this session.

---

## 5.5 Session Workspaces

Blaze treats each project as a **workspace** with its own session history, file state, and task tracking. Unlike terminal-based workflows where context scatters across shell history and editor tabs, Blaze maintains coherent state.

### Multi-File Editing

The agent often edits multiple files in a single turn. Blaze presents these as a unified changeset:

```
 ┌─────────────────────────────────────────────────────────────┐
 │  Changes (3 files)                                   [Apply All]
 │  ─────────────────────────────────────────────────────────  │
 │                                                             │
 │  src/App.swift                                    +12 -3    │
 │  ┌─────────────────────────────────────────────────────┐   │
 │  │  - import Foundation                                │   │
 │  │  + import Foundation                                │   │
 │  │  + import SwiftUI                                   │   │
 │  │    ...                                              │   │
 │  └─────────────────────────────────────────────────────┘   │
 │  [Revert] [Edit] [Apply]                                   │
 │                                                             │
 │  src/Models/User.swift                            +45 -0    │
 │  (new file)                                                │
 │  [Preview] [Apply]                                         │
 │                                                             │
 │  tests/AppTests.swift                             +8 -2     │
 │  [Expand] [Apply]                                          │
 └─────────────────────────────────────────────────────────────┘
```

Features:
- **Unified diffs**: See all changes before applying any
- **Selective application**: Apply files individually or all at once
- **Inline editing**: Modify the agent's proposed changes before applying
- **Revert tracking**: Undo applied changes with full history

### Task Tracking

Long-running agent tasks are tracked in a sidebar panel:

```
 Tasks
 ──────────────────────────────
 [x] Create User model
 [x] Add authentication routes
 [>] Implement OAuth flow
     - Fetching Google SDK docs...
 [ ] Write integration tests
 [ ] Update README
```

Tasks sync with the agent's `TodoWrite` tool calls. The `[>]` indicator shows the currently active task. Click any task to jump to its associated conversation turn.

### Worktree Management (Planned)

For advanced workflows, Blaze supports **git worktrees** - isolated working directories that let you run parallel agent tasks without branch conflicts:

```
 Worktrees
 ──────────────────────────────
 main          ~/Projects/app/
 feature/auth  ~/Projects/app/.worktrees/auth/
 fix/bug-123   ~/Projects/app/.worktrees/bug-123/
```

Each worktree gets its own agent session. Changes in one worktree don't affect others. When ready, merge back to main via Blaze's git integration.

**Status**: Worktree support follows the CodexMonitor pattern and is planned for the 30-day milestone.

### Session Persistence

Every session is crash-safe:
- **Event log**: Append-only JSONL captures every agent event
- **SQLite index**: Fast queries over session history
- **Recovery**: Resume interrupted sessions exactly where you left off

```swift
// Under the hood
SessionStore.save(event: .toolCallStarted(tool: "Write", args: [...]))
SessionStore.save(event: .fileDiffProduced(path: "src/App.swift", diff: ...))
```

---

## 5.6 Visual Hooks Workflow Builder

**This is Blaze's flagship feature.** No other agent harness offers visual, node-based automation for AI coding workflows.

### What Are Hooks?

Hooks are automation scripts that trigger on agent events:
- **PreToolUse**: Before the agent uses a tool (can block)
- **PostToolUse**: After a tool completes
- **SessionStart**: When a session begins or resumes
- **PreCompact**: Before context compaction
- **Stop**: When the agent finishes

Normally, hooks require writing shell scripts and manually editing `settings.json`. Blaze's Hooks Builder provides a visual canvas where you drag, drop, and connect nodes to build workflows.

### The Canvas Interface

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │  Hook Workflow Builder                            [Test] [Save]         │
 ├────────────┬────────────────────────────────────────────────┬───────────┤
 │  Nodes     │                                                │ Inspector │
 │  ────────  │    ┌──────────────┐      ┌──────────────┐     │ ───────── │
 │            │    │ PreToolUse   │      │   Filter     │     │           │
 │  Events    │    │   Trigger    │─────▶│  tool=Bash   │     │  Filter   │
 │  ○ Pre...  │    └──────────────┘      └──────┬───────┘     │           │
 │  ○ Post... │                                 │              │  Pattern: │
 │  ○ Session │                                 ▼              │  [Bash  ] │
 │            │                          ┌──────────────┐     │           │
 │  Filters   │                          │   Condition  │     │  Match:   │
 │  ○ Tool    │    ┌──────────────┐◀─No──│  rm -rf ?    │     │  [Exact ] │
 │  ○ Pattern │    │   Continue   │      └──────┬───────┘     │           │
 │  ○ Path    │    └──────────────┘             │ Yes         │           │
 │            │                                 ▼              │           │
 │  Actions   │                          ┌──────────────┐     │           │
 │  ○ Block   │                          │    Block     │     │           │
 │  ○ Command │                          │  "Dangerous" │     │           │
 │  ○ Log     │                          └──────────────┘     │           │
 │  ○ Notify  │                                               │           │
 └────────────┴────────────────────────────────────────────────┴───────────┘
```

**Left Panel**: Node palette organized by category (Events, Filters, Actions, Outputs)

**Center Canvas**: Visual workflow editor with:
- Drag nodes from palette
- Connect nodes by dragging between ports
- Zoom/pan controls (Cmd+/-, fit to view)
- Multi-select for bulk operations

**Right Panel**: Inspector showing properties for selected node

### Node Types

| Category | Nodes | Purpose |
|----------|-------|---------|
| **Events** | PreToolUse, PostToolUse, SessionStart, PreCompact, Stop | Workflow triggers |
| **Filters** | Tool Match, Path Pattern, Content Match, Regex | Narrow which events fire |
| **Actions** | Block, Continue, Run Command, Log, Notify, Modify | What happens when triggered |
| **Outputs** | System Message, User Notification, File Write | Results and side effects |

### Example Workflows

**1. Block Destructive Commands**

Prevent `rm -rf`, `git reset --hard`, and other dangerous operations:

```
[PreToolUse] → [Tool = Bash] → [Regex: rm -rf|git reset --hard] → [Block: "Destructive command blocked"]
```

**2. Auto-Index Artifacts**

Index files to a search database after the agent writes them:

```
[PostToolUse] → [Tool = Write] → [Path: *.md] → [Command: index-file.sh $FILE_PATH]
```

**3. Session Continuity**

Load context from a continuity ledger when sessions start:

```
[SessionStart] → [Type = resume] → [Command: load-ledger.sh] → [System Message: $OUTPUT]
```

**4. Notification on Completion**

Get a macOS notification when long tasks finish:

```
[Stop] → [Notify: "Agent finished: $SUMMARY"]
```

**5. Dangerous Pattern Detection**

Warn when the agent tries to access sensitive files:

```
[PreToolUse] → [Tool = Read|Write] → [Path: **/.env|**/credentials*] → [Block: "Accessing secrets requires manual approval"]
```

### Testing Workflows

Before saving, test your workflow with the built-in test runner:

1. Click **Test** in the toolbar
2. Blaze runs command nodes with captured stdout/stderr
3. Results appear in a modal:

```
 ┌─────────────────────────────────────────────────────────────┐
 │  Test Results                                      [Done]   │
 │  ─────────────────────────────────────────────────────────  │
 │                                                             │
 │  Validation                                       PASSED    │
 │                                                             │
 │  Command Results                                            │
 │  ┌─────────────────────────────────────────────────────┐   │
 │  │ [OK] Run Command: echo "test"                       │   │
 │  │      Output: test                                   │   │
 │  └─────────────────────────────────────────────────────┘   │
 │  ┌─────────────────────────────────────────────────────┐   │
 │  │ [OK] Run Command: load-ledger.sh                    │   │
 │  │      Output: Loaded continuity from session abc123  │   │
 │  └─────────────────────────────────────────────────────┘   │
 └─────────────────────────────────────────────────────────────┘
```

### Template Gallery

Don't want to build from scratch? Blaze includes **22 production-ready templates**:

- Security: Block destructive commands, detect secrets access, sandbox enforcement
- Productivity: Auto-index artifacts, log tool calls, session continuity
- Integration: Slack notifications, webhook triggers, custom MCP routing
- Debugging: Trace tool calls, capture timing, breakpoint hooks

Browse templates by category, preview the workflow graph, and install with one click.

### Export & Share

Export workflows as JSON for backup or sharing:

```json
{
  "name": "block-destructive",
  "event": "PreToolUse",
  "nodes": [...],
  "connections": [...]
}
```

Import workflows from teammates or the community. Blaze validates imported workflows before installation.

### Why This Matters

Other tools give you hooks via config files:

```json
// settings.json (the old way)
{
  "hooks": {
    "PreToolUse": [{
      "matcher": ["Bash"],
      "hooks": [{"type": "command", "command": "./block-rm.sh"}]
    }]
  }
}
```

Blaze gives you a visual canvas where non-trivial workflows become obvious at a glance. Conditional logic, branching paths, and complex filters that would be error-prone in JSON become drag-and-drop simple.

---

## 6. Feature Comparison Matrix

How does Blaze compare to other ways of using AI coding agents?

### Overview Matrix

| Feature | Blaze | [Warp 2.0](https://www.warp.dev/) | [Cursor](https://www.cursor.com/) | VS Code + Extensions | CLI (Claude/Codex) | [Commander](https://commanderai.app/) | [CodexMonitor](https://github.com/Dimillian/CodexMonitor) |
|---------|-------|------|--------|---------------------|-------------------|-----------|-------------|
| **Native macOS** | Yes | Yes | Electron | Electron | Terminal | Yes | Yes (Tauri) |
| **Multi-CLI Support** | Claude, Gemini, Codex | Warp agents only | Cursor models | Via extensions | Single CLI | Claude only | Codex only |
| **Structured Event Parsing** | Yes | Partial | No | No | N/A | TBD | Yes |
| **Visual Diff Review** | Yes | No | Yes | Via extensions | No | Yes | Yes |
| **Hooks/Automation** | Visual Builder | No | No | Extension-based | Config files | No | No |
| **Trust Mode Control** | 4 modes + allowlists | Model-level | Project rules | Extension settings | CLI flags | TBD | Via Codex |
| **Session Persistence** | SQLite + JSONL | Warp Drive | Project-based | Workspace | Varies by CLI | TBD | Thread storage |
| **Worktree Support** | Planned | No | No | No | Manual | No | Yes |
| **Task Tracking** | Visual sidebar | No | No | Extensions | TodoWrite | TBD | Thread list |
| **Cross-Platform** | macOS only | macOS, Linux, Win | All | All | All | macOS only | macOS only |
| **Price** | TBD | Free tier + Pro | $20/mo | Free + extensions | Free (API costs) | Free | Free |

### Detailed Comparisons

#### Blaze vs Warp 2.0

[Warp](https://www.warp.dev/) is an "Agentic Development Environment" that embeds AI agents into a terminal.

| Aspect | Blaze | Warp |
|--------|-------|------|
| **Approach** | CLI harness (spawns external CLIs) | Built-in agents |
| **Models** | Uses provider CLIs (Claude, Gemini, Codex) | OpenAI, Anthropic, Google via Warp |
| **Code Editing** | Agent-driven via CLI | Warp Code feature |
| **Terminal** | Separate from agent | Integrated terminal |
| **Hooks** | Visual workflow builder | Not available |
| **Collaboration** | TBD | Warp Drive sharing |

**Choose Warp if**: You want an all-in-one terminal replacement with AI built in.

**Choose Blaze if**: You prefer using official provider CLIs with a governance layer and visual automation.

#### Blaze vs Cursor

[Cursor](https://www.cursor.com/) is a VS Code fork with AI capabilities deeply integrated.

| Aspect | Blaze | Cursor |
|--------|-------|--------|
| **Type** | Agent harness | Full IDE |
| **Code Editing** | Agent suggests, you review | Inline completions + Composer |
| **Multi-file** | Unified changeset view | Composer mode |
| **Context Window** | CLI-dependent | 272k tokens |
| **Customization** | Hooks, trust modes | Rules, .cursorrules |
| **Price** | TBD | $20/month |

**Choose Cursor if**: You want AI integrated into your editor with inline completions.

**Choose Blaze if**: You want a dedicated agent workflow tool alongside your existing editor.

#### Blaze vs VS Code + Extensions

| Aspect | Blaze | VS Code + Copilot/Cline/etc |
|--------|-------|----------------------------|
| **Setup** | Single app | Install multiple extensions |
| **Agent Experience** | First-class | Extension-dependent |
| **Consistency** | Unified UX | Varies by extension |
| **Governance** | Built-in trust modes | Extension settings |
| **Automation** | Visual hooks builder | None or manual |

**Choose VS Code if**: You're invested in the VS Code ecosystem and want AI as an add-on.

**Choose Blaze if**: You want a purpose-built agent interface with consistent governance.

#### Blaze vs Raw CLI

| Aspect | Blaze | Claude/Codex CLI directly |
|--------|-------|---------------------------|
| **Interface** | Visual UI | Terminal |
| **Diff Review** | Inline previews | Terminal output |
| **Approval UX** | One-click buttons | Y/N prompts |
| **Session History** | Searchable timeline | Scroll back |
| **Automation** | Visual builder | Edit settings.json |
| **Learning Curve** | Lower | Higher |

**Choose CLI if**: You're terminal-native and want minimal overhead.

**Choose Blaze if**: You want visual tooling for review, approval, and automation.

#### Blaze vs Commander

[Commander](https://commanderai.app/) is a native macOS interface for Claude Code.

| Aspect | Blaze | Commander |
|--------|-------|-----------|
| **CLI Support** | Claude, Gemini, Codex | Claude only |
| **Hooks** | Visual workflow builder | Not available |
| **Trust Modes** | 4 modes + allowlists | TBD |
| **Git Integration** | Planned | Built-in |
| **Price** | TBD | Free |

**Choose Commander if**: You only use Claude Code and want a simple, free native wrapper.

**Choose Blaze if**: You want multi-CLI support and visual automation workflows.

#### Blaze vs CodexMonitor

[CodexMonitor](https://github.com/Dimillian/CodexMonitor) is a macOS app for managing Codex CLI agents.

| Aspect | Blaze | CodexMonitor |
|--------|-------|--------------|
| **CLI Support** | Claude, Gemini, Codex | Codex only |
| **Worktrees** | Planned | Built-in |
| **Custom Prompts** | TBD | Yes, with autocomplete |
| **Hooks** | Visual builder | Not available |
| **Architecture** | Native Swift | Tauri (Rust + Web) |
| **Open Source** | TBD | Yes |

**Choose CodexMonitor if**: You're Codex-only and want proven worktree management.

**Choose Blaze if**: You want multi-CLI support and visual hook automation.

### Decision Guide

```
                     Do you use multiple AI coding CLIs?
                              /              \
                           Yes                No
                            |                  |
                     Use Blaze          Which CLI?
                                        /    |    \
                                  Claude  Codex  Gemini
                                    |       |       |
                              Commander  CodexMonitor  CLI directly
                              or Blaze   or Blaze      or Blaze

              Do you want visual automation/hooks?
                              /              \
                           Yes                No
                            |                  |
                     Use Blaze          Warp, Cursor, or CLI

                     Do you want a full IDE?
                              /              \
                           Yes                No
                            |                  |
                   Cursor or VS Code      Use Blaze
```

### Summary

**Choose Blaze if you want:**
- A native macOS experience for AI coding agents
- Visual governance with trust modes and approval workflows
- The only visual hooks workflow builder for agent automation
- Multi-CLI support (Claude, Gemini, Codex) from one interface
- Purpose-built agent UX separate from your editor

**Consider alternatives if:**
- You want an all-in-one IDE (Cursor)
- You prefer terminal-native workflows (CLI, Warp)
- You only use one CLI and want the simplest wrapper (Commander for Claude, CodexMonitor for Codex)

---

*Feature availability based on public documentation as of January 2025. Features marked "TBD" or "Planned" are on the roadmap but not yet implemented.*
## 7. Security Model

Blaze is a **governance layer** that sits between you and powerful AI coding agents. The security model assumes that AI agents will attempt operations you might not want—and gives you control over what actually happens.

### 7.1 Threat Model

| Threat | Risk Level | Mitigation |
|--------|-----------|------------|
| **Accidental file deletion** | High | Pre-hook blocking for destructive commands (`rm -rf`, `git clean`) |
| **Secret exfiltration** | Critical | Pattern scanning for `.env`, credentials; network request auditing |
| **Unreviewed code changes** | Medium | Mandatory diff review in Review mode |
| **Shell command injection** | High | Command allowlisting; dangerous pattern detection |
| **Scope creep** | Medium | Directory restrictions; project boundaries |
| **Runaway resource usage** | Low | Timeout enforcement; process monitoring |

### 7.2 Trust Modes

Blaze provides four trust modes, configurable per-project or globally:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TRUST MODE SPECTRUM                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   SANDBOX ◀───────── REVIEW ───────── TRUSTED ─────────▶ YOLO      │
│   (Locked)         (Default)          (Expert)        (Dangerous)   │
│                                                                      │
│   Read-only        Approvals          Minimal gates   No gates      │
│   Safe tools       Required           Trust user      Auto-approve  │
│   No writes                                           everything    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

| Mode | File Writes | Shell Commands | Network | Best For |
|------|-------------|----------------|---------|----------|
| **Sandbox** | Blocked | Safe only (`ls`, `git status`) | Blocked | Code review, exploration |
| **Review** (default) | Requires approval | Requires approval | Logged | Daily development |
| **Trusted** | Allowed in project | Most allowed | Allowed | Experienced users |
| **YOLO** | All allowed | All allowed | All allowed | Testing only; use at your own risk |

**Setting trust mode:**

```bash
# In Blaze settings (Settings > Security > Trust Mode)
# Or via project-level config:
cat > .blaze/config.json << 'EOF'
{
  "trustMode": "review",
  "allowedPaths": ["src/", "tests/", "docs/"],
  "blockedPaths": [".env", "secrets/", "*.pem"]
}
EOF
```

### 7.3 Approval Workflows

When an operation requires approval, you can grant permission at different scopes:

| Scope | Duration | Example |
|-------|----------|---------|
| **Once** | This operation only | "Run `npm install` this one time" |
| **Session** | Until session ends | "Allow file writes for this session" |
| **Project** | Persisted to project config | "Always allow in this repo" |
| **Always** | Global user preference | "Never ask about `git commit` again" |

**Approval dialog example:**

```
┌─────────────────────────────────────────────────────────────────┐
│  APPROVAL REQUIRED                                              │
├─────────────────────────────────────────────────────────────────┤
│  Claude wants to run:                                           │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ rm -rf node_modules && npm install                         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  [Deny]  [Allow Once]  [Allow Session]  [Always Allow]         │
└─────────────────────────────────────────────────────────────────┘
```

### 7.4 Tool Allowlists

Control which tools the AI can use:

```json
{
  "toolPolicy": {
    "allow": ["Read", "Grep", "Glob", "Edit", "Write"],
    "requireApproval": ["Bash", "WebFetch"],
    "block": ["Task"]
  }
}
```

**Default tool classifications:**

| Category | Tools | Default Policy |
|----------|-------|----------------|
| **Safe** | `Read`, `Grep`, `Glob` | Auto-allow |
| **Moderate** | `Edit`, `Write`, `WebFetch` | Allow in Review mode |
| **Risky** | `Bash`, `Task` | Require approval |
| **Dangerous** | N/A (custom hooks) | Block by default |

### 7.5 Command Blocking

Pre-configured patterns that trigger blocking or approval:

```bash
# Always blocked (unless YOLO mode):
rm -rf /               # Root deletion
rm -rf ~               # Home deletion
git push --force       # Force push to remote
chmod -R 777           # Unsafe permissions
curl | bash            # Pipe to shell

# Require approval:
rm -rf *               # Wildcard deletion
git reset --hard       # Discard changes
npm publish            # Package publishing
docker rm              # Container deletion
```

### 7.6 Audit Logging

Every operation is logged to an append-only audit trail:

```json
{
  "timestamp": "2026-01-19T10:30:45.123Z",
  "sessionId": "abc-123",
  "eventType": "tool.calling",
  "tool": "Bash",
  "input": { "command": "npm test" },
  "decision": "allow",
  "decidedBy": "user",
  "scope": "session"
}
```

**Audit log locations:**

```
~/.blaze/audit/
  sessions.jsonl        # Session lifecycle events
  tools.jsonl           # Tool call decisions
  approvals.jsonl       # User approval history
  blocked.jsonl         # Blocked operations
```

**Querying the audit log:**

```bash
# View recent blocked operations
jq 'select(.decision == "blocked")' ~/.blaze/audit/tools.jsonl | tail -20

# Export session audit for review
blaze audit export --session abc-123 --format csv > audit.csv
```

### 7.7 Safe Defaults

Blaze ships with conservative defaults:

- Trust mode: **Review**
- New projects: Inherit global settings
- Unknown tools: Require approval
- External network: Logged
- File writes outside project: Blocked
- Secrets in diffs: Flagged for review

---

## 8. Privacy & Telemetry

Blaze is designed with a **privacy-first** architecture. Your code, conversations, and data stay on your machine.

### 8.1 What Stays Local

| Data Type | Location | Encrypted |
|-----------|----------|-----------|
| Session transcripts | `~/.blaze/sessions/` | Optional |
| Event logs (JSONL) | `~/.blaze/events/` | No |
| Audit trail | `~/.blaze/audit/` | No |
| SQLite database | `~/.blaze/blaze.db` | Optional |
| Cached context | `~/.blaze/cache/` | No |
| User preferences | `~/.blaze/config.json` | No |

### 8.2 What Leaves Your Machine

**By design, Blaze sends data ONLY to:**

1. **Provider CLIs** (Claude Code, Gemini CLI, Codex CLI)
   - Your prompts and code context
   - Controlled by each provider's privacy policy
   - Blaze does NOT add tracking to CLI calls

2. **Webhook hooks** (if YOU configure them)
   - Only the data you explicitly send
   - You control the destination

3. **Optional telemetry** (disabled by default)
   - See section 8.4

### 8.3 What Blaze Never Collects

- Your source code
- Your API keys or credentials
- Your conversation content
- Your file system structure
- Your usage patterns (unless opted in)
- Screenshots or screen recordings

### 8.4 Optional Telemetry

Telemetry is **disabled by default**. If you opt in, we collect:

| Data | Purpose | Identifiable? |
|------|---------|---------------|
| App crashes | Stability | Hashed device ID |
| Feature usage counts | Prioritization | No |
| Performance metrics | Optimization | No |
| Error messages | Debugging | Sanitized |

**To enable/disable:**

```bash
# In Settings > Privacy > Telemetry
# Or via config:
echo '{"telemetry": {"enabled": false}}' > ~/.blaze/privacy.json
```

### 8.5 Data Storage & Retention

**Local retention defaults:**

| Data Type | Default Retention | Configurable |
|-----------|------------------|--------------|
| Session transcripts | 90 days | Yes |
| Audit logs | 365 days | Yes |
| Cached context | 7 days | Yes |
| Performance metrics | 30 days | Yes |

**To configure retention:**

```json
{
  "retention": {
    "sessions": "90d",
    "audit": "365d",
    "cache": "7d",
    "metrics": "30d"
  }
}
```

**To delete all local data:**

```bash
# From Blaze menu: Blaze > Delete All Data...
# Or manually:
rm -rf ~/.blaze/sessions ~/.blaze/events ~/.blaze/audit
```

### 8.6 Provider Privacy Considerations

Remember: Blaze spawns provider CLIs, so your prompts go to the provider:

| Provider | Privacy Policy | Data Usage |
|----------|---------------|------------|
| Anthropic (Claude Code) | [anthropic.com/privacy](https://anthropic.com/privacy) | API data not used for training |
| Google (Gemini CLI) | [cloud.google.com/terms](https://cloud.google.com/terms) | Check your workspace settings |
| OpenAI (Codex CLI) | [openai.com/privacy](https://openai.com/privacy) | API data not used for training by default |

---

## 9. Installation

### 9.1 System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **macOS** | 14.0 (Sonoma) | 15.0 (Sequoia) |
| **Processor** | Apple Silicon or Intel | Apple Silicon (M1+) |
| **RAM** | 8 GB | 16 GB |
| **Disk** | 500 MB | 2 GB (with caches) |
| **Xcode CLT** | Required | Latest |

### 9.2 Prerequisites

Before installing Blaze, you need at least one supported CLI:

```bash
# Claude Code (recommended)
npm install -g @anthropic-ai/claude-code
claude auth login

# Gemini CLI (optional)
npm install -g @google/gemini-cli
gemini auth login

# OpenAI Codex CLI (optional, coming soon)
# npm install -g @openai/codex-cli
# codex auth login
```

### 9.3 Installation Methods

#### Method 1: DMG Download (Recommended)

```bash
# Download latest release
curl -L https://github.com/cogit0/blaze/releases/latest/download/Blaze.dmg -o Blaze.dmg

# Mount and install
hdiutil attach Blaze.dmg
cp -R /Volumes/Blaze/Blaze.app /Applications/
hdiutil detach /Volumes/Blaze

# First launch (will prompt for permissions)
open /Applications/Blaze.app
```

#### Method 2: Homebrew (Coming Soon)

```bash
# TBD - Not yet available
brew install --cask cogit0-blaze
```

#### Method 3: Build from Source

```bash
# Clone repository
git clone https://github.com/cogit0/blaze.git
cd blaze

# Build with Xcode
xcodebuild -project Blaze/Blaze.xcodeproj \
  -scheme Blaze \
  -configuration Release \
  -derivedDataPath build

# Copy to Applications
cp -R build/Build/Products/Release/Blaze.app /Applications/
```

### 9.4 Verifying the Installation

Blaze is code-signed and notarized by Apple:

```bash
# Verify code signature
codesign -dv --verbose=4 /Applications/Blaze.app

# Check notarization
spctl -a -v /Applications/Blaze.app
# Expected: "source=Notarized Developer ID"
```

### 9.5 First Launch Setup

On first launch, Blaze will:

1. **Request permissions:**
   - Full Disk Access (optional, for project access)
   - Accessibility (optional, for global shortcuts)

2. **Detect installed CLIs:**
   - Scans for `claude`, `gemini`, `codex` on PATH
   - Verifies authentication status

3. **Create data directories:**
   ```
   ~/.blaze/
     config.json       # User preferences
     sessions/         # Session transcripts
     events/           # Event logs
     audit/            # Audit trail
     cache/            # Cached context
   ```

### 9.6 Updating

Blaze checks for updates automatically (can be disabled in Settings).

```bash
# Manual update check
# From menu: Blaze > Check for Updates...

# Or download and replace:
curl -L https://github.com/cogit0/blaze/releases/latest/download/Blaze.dmg -o Blaze.dmg
# Follow DMG installation steps above
```

### 9.7 Uninstalling

```bash
# Remove application
rm -rf /Applications/Blaze.app

# Remove user data (optional)
rm -rf ~/.blaze

# Remove caches (optional)
rm -rf ~/Library/Caches/com.cogit0.blaze
rm -rf ~/Library/Application\ Support/Blaze
```

---

## 10. Quickstart

Get from zero to productive in under 5 minutes.

### 10.1 Provider Setup

First, ensure you have at least one CLI authenticated:

```bash
# Check Claude Code
claude --version
claude auth status
# If not logged in:
claude auth login

# Check Gemini (optional)
gemini --version
gemini auth status
```

### 10.2 Create Your First Workspace

1. **Launch Blaze**
   ```bash
   open /Applications/Blaze.app
   ```

2. **Add a project**
   - Click **+** in the sidebar or press `Cmd+Shift+N`
   - Select your project directory
   - Blaze auto-detects git repos and existing `.claude/` configs

3. **Configure the workspace** (optional)
   - Right-click project > **Settings**
   - Set trust mode (default: Review)
   - Add to tool allowlist if needed

### 10.3 Start Your First Session

1. **Select your project** in the sidebar

2. **Press `Cmd+N`** or click **New Session**

3. **Choose your engine:**
   ```
   ┌─────────────────────────────────────────┐
   │  New Session                            │
   ├─────────────────────────────────────────┤
   │  Engine: [Claude Code v]                │
   │                                         │
   │  Name: "Fix authentication bug"         │
   │                                         │
   │  [Cancel]                  [Create]     │
   └─────────────────────────────────────────┘
   ```

4. **Send your first prompt:**
   ```
   Look at the auth flow in src/auth/ and identify why
   login fails when the session token expires.
   ```

### 10.4 Understanding the Timeline

The main view shows your conversation as a timeline:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Fix authentication bug                              Claude Code    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  10:30 AM  YOU                                                      │
│  Look at the auth flow in src/auth/ and identify why login fails... │
│                                                                      │
│  10:30 AM  CLAUDE                                                   │
│  I'll analyze the authentication flow. Let me start by reading...   │
│                                                                      │
│  ┌─ Tool: Read ─────────────────────────────────────────────────┐   │
│  │ src/auth/session.ts                               1.2s       │   │
│  │ 245 lines read                                    [Expand]   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─ Tool: Grep ─────────────────────────────────────────────────┐   │
│  │ Pattern: "token.*expir"                          0.3s        │   │
│  │ 3 matches in 2 files                             [Expand]    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  I found the issue. The token refresh logic in session.ts...        │
│                                                                      │
│  ┌─ Diff: src/auth/session.ts ──────────────────────────────────┐   │
│  │ +  if (isTokenExpired(token)) {                              │   │
│  │ +    token = await refreshToken(token);                       │   │
│  │ +  }                                                          │   │
│  │                                     [Accept] [Reject] [Edit] │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 10.5 Essential Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New session |
| `Cmd+K` | Command palette |
| `Cmd+Enter` | Send message |
| `Cmd+Shift+A` | Accept all diffs |
| `Cmd+Shift+R` | Reject all diffs |
| `Cmd+.` | Stop current generation |
| `Cmd+D` | Toggle diff view (unified/split) |
| `Cmd+1/2/3` | Switch sidebar tabs |

### 10.6 Add Your First Hook

Hooks automate responses to events. Here's a simple example:

1. **Open Settings** (`Cmd+,`) > **Hooks**

2. **Click "Create Hook"**

3. **Configure:**
   ```
   Event: PostToolUse
   Matcher: Write, Edit
   Description: "Run tests after file changes"
   Script: ~/.blaze/hooks/run-tests.sh
   ```

4. **Create the script:**
   ```bash
   mkdir -p ~/.blaze/hooks
   cat > ~/.blaze/hooks/run-tests.sh << 'EOF'
   #!/bin/bash
   cd "$BLAZE_PROJECT_PATH"
   npm test 2>&1 | head -50
   EOF
   chmod +x ~/.blaze/hooks/run-tests.sh
   ```

Now tests run automatically after Claude edits files!

---

## 11. Workspaces & Worktrees Deep Dive

### 11.1 Why Git Worktrees?

Traditional branch switching has friction:

```bash
# The old way (painful)
git stash                    # Save current work
git checkout feature-auth    # Switch branches
# ... work on feature ...
git checkout main            # Switch back
git stash pop                # Restore work (hope for no conflicts!)
```

**Worktrees eliminate this entirely:**

```bash
# The worktree way (smooth)
git worktree add ../feature-auth -b feature-auth
# Now you have TWO working directories, both active simultaneously
```

### 11.2 Blaze Worktree Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PROJECT WITH WORKTREES                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ~/projects/my-app/                    (Main worktree)              │
│  ├── .git/                             Shared Git data              │
│  ├── src/                              main branch files            │
│  └── .blaze/                           Project config               │
│                                                                      │
│  ~/.blaze/worktrees/my-app/                                         │
│  ├── feature-auth/                     (Worktree 1)                 │
│  │   ├── src/                          feature/auth branch          │
│  │   └── .blaze-session/               Session state                │
│  │                                                                   │
│  └── bugfix-login/                     (Worktree 2)                 │
│      ├── src/                          bugfix/login branch          │
│      └── .blaze-session/               Session state                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 11.3 Recommended Layout

For solo developers:

```
~/projects/
  my-app/                     # Main repo (main branch)

~/.blaze/worktrees/my-app/
  feature-auth/               # Feature work
  bugfix-123/                 # Bug fix
  experiment-xyz/             # Experimentation
```

For teams:

```
~/projects/
  my-app/                     # Main repo (main branch)

~/worktrees/my-app/           # Team-visible location
  anthony/feature-auth/       # Your feature
  sarah/refactor-api/         # Teammate's work
```

### 11.4 Creating Worktrees in Blaze

**Via UI:**

1. Right-click project > **New Worktree**
2. Enter branch name: `feature/user-profiles`
3. (Optional) Enter task description
4. Check "Create AI session"
5. Click **Create**

**Via command palette (`Cmd+K`):**

```
> worktree new feature/user-profiles "Add user profiles feature"
```

### 11.5 Parallel Agents

Each worktree can run its own AI session simultaneously:

```
┌─────────────────────────────────────────────────────────────────────┐
│  PARALLEL WORKTREE SESSIONS                                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─ Worktree: feature-auth ────────────────────────────────────┐    │
│  │  Session: "Implement OAuth"                                  │    │
│  │  Engine: Claude Code                                         │    │
│  │  Status: Working on token refresh...                         │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ Worktree: bugfix-login ────────────────────────────────────┐    │
│  │  Session: "Fix login timeout"                                │    │
│  │  Engine: Claude Code                                         │    │
│  │  Status: Running tests...                                    │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─ Main ──────────────────────────────────────────────────────┐    │
│  │  Session: "Code review"                                      │    │
│  │  Engine: Gemini CLI                                          │    │
│  │  Status: Idle                                                │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Benefits:**

- Work on multiple features simultaneously
- Each agent has isolated context (no cross-contamination)
- Merge when ready, discard experiments freely
- Context inheritance from main worktree (optional)

### 11.6 Merging Worktree Changes

When your feature is ready:

1. **Ensure clean state** (commit or stash changes)
2. Click **Merge** in the worktree status bar
3. Choose merge strategy:
   - **Merge commit** (preserves history)
   - **Squash** (single commit)
   - **Rebase** (linear history)
4. Resolve any conflicts via the built-in resolver
5. **Cleanup** (delete worktree and branch)

### 11.7 Worktree Best Practices

| Practice | Why |
|----------|-----|
| One task per worktree | Clean separation of concerns |
| Descriptive branch names | `feature/user-auth` not `fix1` |
| Delete after merge | Avoid worktree sprawl |
| Use session descriptions | "Implement OAuth flow" helps resume work |
| Inherit policies | Consistency across worktrees |

---

## 12. Hooks Workflow Builder Deep Dive

### 12.1 What Are Hooks?

Hooks are automations that trigger on specific events in the AI session lifecycle:

```
EVENT occurs --> Hook matches --> Action executes --> Optional result
```

### 12.2 Hook Events Reference

| Event | When It Fires | Can Block? | Common Uses |
|-------|--------------|------------|-------------|
| `SessionStart` | Session begins/resumes | No | Load context, set env vars |
| `SessionEnd` | Session terminates | No | Cleanup, export logs |
| `PreToolUse` | Before tool executes | Yes | Block dangerous ops, transform input |
| `PostToolUse` | After tool completes | No | Log results, run validators |
| `UserPromptSubmit` | User sends message | Yes | Sanitize input, inject context |
| `Stop` | Agent finishes turn | Yes | Enforce "definition of done" |
| `PreCompact` | Before context compaction | No | Save state, export summary |
| `Notification` | CLI sends notification | No | Alerts, desktop notifications |

### 12.3 Hook Cookbook

#### Recipe 1: Auto-Run Tests After File Changes

**Goal:** Run tests whenever Claude edits code.

```json
{
  "id": "auto-test",
  "event": "PostToolUse",
  "matcher": ["Write", "Edit"],
  "type": "post",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/run-tests.sh"
  }
}
```

**Script (`~/.blaze/hooks/run-tests.sh`):**

```bash
#!/bin/bash
cd "$BLAZE_PROJECT_PATH"

# Run tests and capture result
OUTPUT=$(npm test 2>&1)
EXIT_CODE=$?

# Return structured JSON for context injection
if [ $EXIT_CODE -eq 0 ]; then
  echo '{"additionalContext": "Tests passed."}'
else
  # Include failure summary
  FAILURES=$(echo "$OUTPUT" | grep -A5 "FAIL\|Error" | head -20)
  cat << EOF
{
  "additionalContext": "Tests failed. Summary:\n$FAILURES",
  "decision": "block",
  "reason": "Tests are failing. Please fix before continuing."
}
EOF
fi
```

#### Recipe 2: Block Destructive Commands

**Goal:** Prevent `rm -rf`, force pushes, and other dangerous operations.

```json
{
  "id": "block-dangerous",
  "event": "PreToolUse",
  "matcher": ["Bash"],
  "type": "pre",
  "canBlock": true,
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/check-dangerous.sh"
  }
}
```

**Script (`~/.blaze/hooks/check-dangerous.sh`):**

```bash
#!/bin/bash

# Read event from stdin
EVENT=$(cat)
COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // empty')

# Dangerous patterns
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \*"
  "git push.*--force"
  "git reset --hard"
  "chmod -R 777"
  "> /dev/sd"
  "mkfs\."
  "dd if="
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    cat << EOF
{
  "block": true,
  "reason": "Blocked dangerous command matching: $pattern"
}
EOF
    exit 0
  fi
done

# Allow
echo '{"block": false}'
```

#### Recipe 3: Require Approval for Writes Outside Safe Paths

**Goal:** Allow writes to `src/` and `tests/` without approval; require approval elsewhere.

```json
{
  "id": "path-gating",
  "event": "PreToolUse",
  "matcher": ["Write", "Edit"],
  "type": "pre",
  "canBlock": true,
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/check-write-path.sh"
  }
}
```

**Script (`~/.blaze/hooks/check-write-path.sh`):**

```bash
#!/bin/bash

EVENT=$(cat)
FILE_PATH=$(echo "$EVENT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Safe paths (relative to project)
SAFE_PATHS=("src/" "tests/" "docs/")

# Check if path is safe
for safe in "${SAFE_PATHS[@]}"; do
  if [[ "$FILE_PATH" == *"$safe"* ]]; then
    echo '{"permissionDecision": "allow"}'
    exit 0
  fi
done

# Require approval for other paths
cat << EOF
{
  "permissionDecision": "ask",
  "permissionDecisionReason": "File is outside safe directories: $FILE_PATH"
}
EOF
```

#### Recipe 4: Update Session Heartbeat After Tool Use

**Goal:** Track session activity for monitoring.

```json
{
  "id": "heartbeat",
  "event": "PostToolUse",
  "type": "observer",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/heartbeat.sh"
  }
}
```

**Script (`~/.blaze/hooks/heartbeat.sh`):**

```bash
#!/bin/bash

# Write heartbeat to coordination file
echo "{\"session\": \"$BLAZE_SESSION_ID\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"event\": \"$BLAZE_EVENT_TYPE\"}" >> ~/.blaze/heartbeats.jsonl
```

#### Recipe 5: Load Project Context on Session Start

**Goal:** Automatically inject project-specific context when a session begins.

```json
{
  "id": "load-context",
  "event": "SessionStart",
  "matcher": ["startup", "resume"],
  "type": "post",
  "action": {
    "type": "script",
    "command": "~/.blaze/hooks/load-context.sh"
  }
}
```

**Script (`~/.blaze/hooks/load-context.sh`):**

```bash
#!/bin/bash

cd "$BLAZE_PROJECT_PATH"

# Gather context
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log -1 --oneline 2>/dev/null || echo "no commits")
TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l | tr -d ' ')

# Inject as system context
cat << EOF
{
  "additionalContext": "Project context: Branch '$BRANCH', last commit: $LAST_COMMIT, $TODO_COUNT TODOs in src/"
}
EOF
```

### 12.4 Node Types in Visual Builder

| Node Type | Purpose | Example |
|-----------|---------|---------|
| **Event** | Trigger point | `PreToolUse`, `SessionStart` |
| **Matcher** | Filter events | `["Write", "Bash"]`, regex |
| **Command** | Run script | `~/.blaze/hooks/my-hook.sh` |
| **Decision** | Block/allow | `allow`, `deny`, `ask` |
| **Transform** | Modify data | `updatedInput`, `additionalContext` |
| **Logger** | Write logs | Structured output |

### 12.5 Debugging Hooks

**Enable verbose logging:**

```json
{
  "hooks": {
    "debug": true,
    "logLevel": "verbose"
  }
}
```

**Test a hook manually:**

```bash
# Simulate PreToolUse event
echo '{"tool_name": "Bash", "tool_input": {"command": "rm -rf test/"}}' | \
  ~/.blaze/hooks/check-dangerous.sh

# Check output
# {"block": true, "reason": "Blocked dangerous command..."}
```

**View hook execution logs:**

```bash
# Recent hook activity
tail -f ~/.blaze/logs/hooks.log

# Filter by hook ID
grep "auto-test" ~/.blaze/logs/hooks.log
```

### 12.6 Hook Best Practices

| Practice | Reason |
|----------|--------|
| Keep hooks fast (<5s) | Slow hooks block the AI |
| Use structured JSON output | Enables UI integration |
| Log failures | Debug issues later |
| Test locally first | `echo '{}' \| ./hook.sh` |
| Use `observer` for async | Don't block main flow |
| Add descriptions | Distinguish similar hooks |
| Version control hooks | Track changes |

### 12.7 Migrating from Claude Code Hooks

If you have existing Claude Code hooks in `~/.claude/settings.json`:

```bash
# Blaze includes a migration tool
blaze hooks migrate ~/.claude/settings.json

# This creates:
# ~/.blaze/hooks/hooks.json (hook definitions)
# ~/.blaze/hooks/migrated/ (copied scripts)
```

**Event mapping:**

| Claude Code | Blaze |
|-------------|-------|
| `PreToolUse` | `PreToolUse` (pre) |
| `PostToolUse` | `PostToolUse` (post) |
| `UserPromptSubmit` | `UserPromptSubmit` (pre) |
| `PreCompact` | `PreCompact` (post) |
| `SessionStart` | `SessionStart` (post) |
| `Stop` | `Stop` (pre, can block) |
## Configuration & Settings

Blaze settings are divided into two categories: **App Settings** (appearance, typography, behavior) and **Claude Code Settings** (CLI integration, permissions, hooks).

Access settings via `Blaze > Settings...` or `Cmd + ,`

### Theme & Appearance

| Setting | Options | Default |
|---------|---------|---------|
| Color Scheme | System, Light, Dark | System |
| Accent Color | System Blue, Purple, Pink, Red, Orange, Yellow, Green, Custom | System Blue |
| Window Vibrancy | Enable glass effect | Enabled |
| Sidebar Style | Default, Compact, Minimal | Default |

### Typography

**UI Fonts:**

| Setting | Range | Default |
|---------|-------|---------|
| UI Font Family | System, SF Pro, Custom | System |
| UI Font Size | 11-18pt | 13pt |

**Code Fonts:**

| Setting | Range | Default |
|---------|-------|---------|
| Code Font Family | SF Mono, JetBrains Mono, Fira Code, Menlo | SF Mono |
| Code Font Size | 10-20pt | 12pt |
| Enable Ligatures | On/Off | Enabled |
| Tab Width | 2, 4, 8 | 4 |

### Chat Display

| Setting | Options | Default |
|---------|---------|---------|
| Message Bubbles | Rounded, Square, Minimal | Rounded |
| Show Timestamps | Always, Hover, Never | Hover |
| Timestamp Format | Relative, Absolute | Relative |
| Message Spacing | Compact, Comfortable, Spacious | Comfortable |

### Tool Cards & Diffs

| Setting | Description | Default |
|---------|-------------|---------|
| Default State | Expanded or Collapsed | Collapsed |
| Show Duration | Display execution time | Enabled |
| Syntax Highlighting | Code coloring | Enabled |
| Max Output Height | Truncation threshold | 300px |
| Diff View Mode | Unified, Side-by-Side, Inline | Unified |
| Show Line Numbers | In diff viewer | Enabled |

### Terminal Backend

Blaze uses SwiftTerm for terminal emulation when needed. Configuration:

| Setting | Description | Default |
|---------|-------------|---------|
| Shell | Shell for bash commands | /bin/zsh |
| Environment Passthrough | Variables to forward | PATH, HOME |
| Working Directory | Project root override | Auto-detect |

### Permission Modes

Three security modes control tool permissions:

| Mode | File Writes | Shell Commands | Network | Use Case |
|------|-------------|----------------|---------|----------|
| **Review** (default) | Require approval | Require approval | Gated | Daily development |
| **Trusted** | Auto-approve | Auto-approve | Allowed | Experienced users |
| **Sandbox** | Blocked | Blocked | Blocked | Exploration only |

### Tools Configuration

Configure which tools are available:

```
Core Tools:     Read, Write, Edit, Glob, Grep, Bash, WebFetch
MCP Tools:      Per-server enablement
Dangerous:      Pattern-based restrictions on Bash
```

**Bash Restrictions Example:**

```json
{
  "blocked_patterns": ["rm -rf /", "git push --force"],
  "require_confirm": ["rm", "git push", "npm publish"]
}
```

### Auto-Approve Patterns

Skip approval for known-safe operations:

```json
{
  "auto_approve": {
    "bash": ["git status", "git diff", "npm test", "swift build"],
    "write": ["**/*.test.ts", "**/tests/**"],
    "read": ["**/*"]
  }
}
```

### Settings Storage

| Type | Location | Format |
|------|----------|--------|
| App Settings | `~/Library/Preferences/com.cogit0.blaze.plist` | Property List |
| Claude Code Settings | `~/.cogit0-blaze/settings.json` | JSON |
| Hooks | `~/.cogit0-blaze/hooks/` | JSON + Scripts |
| Skills | `~/.cogit0-blaze/skills/` | Markdown |

---

## Architecture Overview

Blaze is a native macOS SwiftUI application that serves as a "harness" for agentic coding CLIs. It spawns CLI processes, parses their structured streaming output (NDJSON), and renders a polished desktop experience.

### System Diagram

```
+--------------------------- macOS App (SwiftUI) ---------------------------+
|                                                                            |
|  +----------------+  +------------------+  +------------------+            |
|  |   GUI Layer    |  |  Orchestration   |  |     Storage      |            |
|  |  (SwiftUI)     |  |  Layer           |  |  Layer           |            |
|  +-------+--------+  +--------+---------+  +--------+---------+            |
|          |                    |                     |                      |
|  - Chat Timeline      - SessionStore        - SQLite (sessions)            |
|  - Tool Cards         - EngineManager       - JSONL (events)               |
|  - Diff Viewer        - HookRunner          - Memory Layer                 |
|  - Settings UI        - PolicyEngine        - Preferences                  |
|  - Command Palette    - ProcessRunner                                      |
|                                                                            |
+----------------------------------+-----------------------------------------+
                                   |
                                   | spawn child process / pipes
                                   v
+--------------------------------------------------------------------------+
|                        Provider CLIs (unmodified)                          |
|  +------------------+  +------------------+  +------------------+          |
|  | ClaudeCodeAdapter|  | GeminiCliAdapter |  | CodexCliAdapter  |          |
|  +------------------+  +------------------+  +------------------+          |
+--------------------------------------------------------------------------+
                                   |
                                   | HTTPS (CLI handles auth)
                                   v
+--------------------------------------------------------------------------+
|                         AI Provider APIs                                   |
|           Anthropic API  |  Google AI API  |  OpenAI API                   |
+--------------------------------------------------------------------------+
```

### Key Components

| Component | Responsibility | Key Files |
|-----------|----------------|-----------|
| **EngineAdapter** | Protocol for CLI invocation, auth, streaming | `Blaze/Sources/Engine/` |
| **NormalizedEvent** | Unified event schema across providers | `Blaze/Sources/Core/` |
| **SessionStore** | SQLite + JSONL for crash-safe persistence | `Blaze/Sources/Data/` |
| **HookRunner** | Event-triggered automation | `Blaze/Sources/Core/` |
| **ProcessRunner** | Child process management with pipes | `Blaze/Sources/Engine/` |
| **PolicyEngine** | Permission enforcement | `Blaze/Sources/Security/` |
| **DesignSystem** | Shared UI components, colors, typography | `Blaze/Sources/DesignSystem/` |

### Execution Lifecycle

```
1. User sends prompt
   |
2. SessionStore creates turn, persists to JSONL
   |
3. EngineManager selects adapter (Claude/Gemini/Codex)
   |
4. Adapter spawns CLI with --output-format stream-json
   |
5. ProcessRunner reads stdout via pipe
   |
6. Events parsed as NDJSON -> NormalizedEvent
   |
7. Pre-hooks fire (can block)
   |
8. UI renders streaming delta
   |
9. Tool calls go through PolicyEngine
   |
10. Post-hooks fire
   |
11. Turn completes, SessionStore persists
```

### Data Flow

```
User Input -> Blaze UI -> Prompt Construction -> CLI Process
                                                      |
                                                      v
                                              AI Provider API
                                                      |
                                                      v
NDJSON Stream <- stdout/stderr <- CLI Process Response
      |
      v
Event Processing -> Tool Execution -> Filesystem Changes
                         |
                         v
                  (bash, file edits, etc.)
```

### Golden Constraints

1. **Never impersonate provider auth** - Only invoke each vendor's CLI login flow
2. **Never parse ANSI terminal output** - Always use structured JSON output modes
3. **Clean boundary** - Engine state and UI state are strictly separated
4. **Security paranoia** - File access, sandbox, approvals, secrets must be explicit

---

## Performance Notes

Blaze is built with the philosophy that **performance is a feature**. A native macOS app must feel instantaneous to justify its existence over web alternatives.

### Performance Budgets

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| App Launch (cold) | < 1.0s | < 2.0s |
| App Launch (warm) | < 0.3s | < 0.5s |
| Command Palette Open | < 50ms | < 100ms |
| First Token Render | < 100ms | < 200ms |
| Tool Card Render | < 50ms | < 100ms |
| Diff Render (1K lines) | < 100ms | < 300ms |
| Diff Render (10K lines) | < 500ms | < 1s |
| Message Send | < 30ms | < 100ms |
| Scroll (60fps) | 16.6ms/frame | 33ms/frame |

### Memory Budgets

| State | Target | Critical |
|-------|--------|----------|
| Idle | < 150 MB | < 300 MB |
| Active Session | < 300 MB | < 500 MB |
| Large Session (1000 events) | < 400 MB | < 600 MB |
| Memory Growth/Hour | < 10 MB | < 50 MB |

### Known Bottlenecks

| Area | Issue | Mitigation |
|------|-------|------------|
| Large diffs | Rendering 10K+ line diffs | Virtualization, lazy loading |
| Long sessions | Memory growth over time | Event pruning, compaction |
| Streaming | High token rate rendering | Batched UI updates at 60fps |
| Database | Large session queries | Pagination, indexed queries |

### Benchmark Plan

TBD - Automated benchmarks run on every PR via GitHub Actions:

```bash
# Run benchmark suite
make benchmark

# Compare to baseline
./scripts/compare-benchmarks.sh
```

---

## Troubleshooting

### Installation Issues

**"Blaze can't be opened because it is from an unidentified developer"**

```bash
# Option 1: Right-click > Open (first time)
# Option 2: System Settings > Privacy & Security > Open Anyway
# Option 3: Remove quarantine
xattr -d com.apple.quarantine /Applications/Blaze.app
```

**"Blaze is damaged and can't be opened"**

This usually means the app wasn't properly notarized. Re-download from the official source.

**Missing CLI binary**

```bash
# Verify Claude Code is installed
which claude

# If not found, install via npm
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

### Authentication Issues

**"Not logged in" error**

```bash
# Re-authenticate with Claude Code
claude login

# Verify auth status
claude auth status
```

**Token expired**

```bash
# Force re-authentication
claude logout && claude login
```

### Tool Permission Issues

**Tool calls being blocked unexpectedly**

1. Check current permission mode: `Settings > Claude Code > Permission Modes`
2. Review blocked patterns: `Settings > Claude Code > Allowed Tools`
3. Check hook logs for pre-hook vetoes

**"Permission denied" for file operations**

1. Grant Full Disk Access: `System Settings > Privacy & Security > Full Disk Access`
2. Add Blaze.app to the list
3. Restart Blaze

### Hooks Not Firing

**Hook registered but not executing**

1. Check hook is enabled in Settings
2. Verify event type matches (e.g., `tool.calling` vs `tool.completed`)
3. Check hook timeout (default 10s)
4. Review hook logs:

```bash
# View hook execution logs
tail -f ~/.cogit0-blaze/logs/hooks.log
```

**Hook timing out**

Increase timeout in hook configuration or optimize hook script.

### Diagnostics

**Generate debug bundle**

```
Settings > Claude Code > Advanced > Export Debug Bundle
```

**Enable debug mode**

```
Settings > Claude Code > Advanced > Show Raw Events: ON
```

**View logs**

```bash
# Application logs
tail -f ~/Library/Logs/com.cogit0.blaze/blaze.log

# CLI interaction logs
tail -f ~/.cogit0-blaze/logs/cli.log
```

**Reset to defaults**

```bash
# Reset all settings (destructive)
rm -rf ~/.cogit0-blaze/settings.json
rm ~/Library/Preferences/com.cogit0.blaze.plist
```

---

## FAQ

### Is it safe?

**Q: Can Claude/Gemini/Codex delete my files?**

A: Only if you approve it. By default, Blaze runs in **Review Mode** where:
- All file writes require your explicit approval
- All shell commands require confirmation
- Dangerous patterns (like `rm -rf`) are blocked entirely

You can enable Trusted Mode if you prefer autonomous operation, but that's your choice.

**Q: What about prompt injection attacks?**

A: Blaze inherits the security properties of the underlying CLIs. We add an additional layer via the PolicyEngine that can block suspicious patterns. However, AI systems are fundamentally unpredictable - always review before approving.

### Does it send data to the cloud?

**Q: Does Blaze phone home?**

A: Blaze itself sends zero data to any server. Your conversations go only to the AI provider you choose (Anthropic, Google, or OpenAI) via their official CLI tools.

**Q: Is telemetry enabled?**

A: Optional and disabled by default. If enabled, only anonymous usage stats (no conversation content) are collected.

**Q: Where is my data stored?**

A: Everything stays local:
- Sessions: `~/.cogit0-blaze/sessions/`
- Logs: `~/.cogit0-blaze/logs/`
- Settings: `~/.cogit0-blaze/settings.json`

### Can it delete files?

**Q: What if Claude tries to `rm -rf /`?**

A: The PolicyEngine blocks dangerous patterns by default. Even in Trusted Mode, certain patterns are hardcoded as blocked.

### Where do API keys go?

**Q: Do I need an API key?**

A: Blaze uses each provider's CLI login flow. For Claude Code, you authenticate via `claude login` which opens a browser flow. No raw API keys are stored in Blaze.

**Q: How does authentication work?**

A: Each CLI manages its own authentication:
- Claude: OAuth via browser, tokens stored in system keychain
- Gemini: Google account OAuth
- Codex: OpenAI API key or OAuth

Blaze never sees or stores your credentials directly.

### Does it work offline?

**Q: Can I use Blaze without internet?**

A: No. Blaze requires internet access because:
1. AI inference happens on provider servers
2. The CLIs call provider APIs

Local LLM support is on the roadmap (see below).

### How does it compare to alternatives?

| Feature | Blaze | Web UI | Terminal | VS Code Extension |
|---------|-------|--------|----------|-------------------|
| Native macOS | Yes | No | Partial | No |
| Unified multi-CLI | Yes | No | No | No |
| Visual diff review | Yes | Limited | No | Yes |
| Custom hooks | Yes | No | Manual | Limited |
| Offline history | Yes | No | Manual | Limited |
| Glass UI | Yes | No | No | No |

---

## Roadmap

### Now (In Progress)

- Multi-CLI support (Claude + Gemini + Codex)
- Hook system with visual builder
- Streaming UI polish
- Session continuity across restarts

### Next (30-90 days)

- Worktree-per-task isolation
- Multi-agent orchestration
- MCP server management UI
- Voice dictation mode
- Branch conversations (fork sessions)

### Later (3-6 months)

- Plugin/extension system
- Policy templates marketplace
- Team collaboration features
- Local LLM support (Ollama, LM Studio)
- Windows/Linux versions (evaluating)

### What We're NOT Building

- **A terminal emulator** - Use iTerm2 or Terminal.app for that
- **An IDE** - Use VS Code, Cursor, or Xcode
- **A web wrapper** - We're native macOS, not Electron
- **Our own AI model** - We orchestrate existing CLIs

---

## Contributing

We welcome contributions. Here's how to get started.

### Development Setup

**Prerequisites:**
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- Claude Code CLI installed (`npm install -g @anthropic-ai/claude-code`)

**Clone and build:**

```bash
git clone https://github.com/cogit0/blaze.git
cd blaze

# Build with Swift Package Manager
cd Blaze
swift build

# Or open in Xcode
open Blaze/Package.swift
```

**Run tests:**

```bash
cd Blaze
swift test
```

### Repository Layout

```
cogit0-blaze/
|-- Blaze/                    # Main Swift package
|   |-- Sources/
|   |   |-- App/              # App entry point, delegates
|   |   |-- Core/             # Models, events, adapters
|   |   |-- Data/             # Database, migrations, persistence
|   |   |-- DesignSystem/     # Shared UI components
|   |   |-- Engine/           # CLI adapters, process runner
|   |   |-- Onboarding/       # First-run experience
|   |   |-- Registry/         # Model registry
|   |   |-- Security/         # Policy engine
|   |   |-- Services/         # Background services
|   |   |-- Settings/         # Settings UI
|   |   |-- Terminal/         # Terminal emulation
|   |   |-- UI/               # Main UI views
|   |   +-- Views/            # Reusable view components
|   |-- Tests/                # Unit tests
|   +-- Resources/            # Assets, images
|
|-- docs/
|   |-- atoms/                # Feature roadmap (JSONL)
|   |-- roadmap/              # Generated roadmap (do not edit)
|   +-- specs/                # Technical specifications
|
|-- scripts/                  # Build and validation scripts
+-- thoughts/                 # Design notes, decisions
```

### Tests

```bash
# Run all tests
make test

# Run specific test file
swift test --filter BlazeTests.AIProviderTests

# Run with verbose output
swift test --verbose
```

### Code Style

- **Swift:** Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **Formatting:** Use `swift-format` with default settings
- **Naming:** Match existing conventions (grep before inventing)
- **Files:** Keep under 500 LOC, split as needed

### PR Guidelines

1. **One feature per PR** - Keep PRs focused and reviewable
2. **Tests required** - Add tests for new functionality
3. **Update docs** - If behavior changes, update inline docs
4. **Conventional commits** - Use `feat|fix|refactor|docs|test|chore` prefixes
5. **No breaking changes** - Without discussion first

**PR Template:**

```markdown
## Summary
[1-3 bullet points]

## Test Plan
- [ ] Unit tests pass
- [ ] Manual testing completed
- [ ] Docs updated if needed

## Screenshots
[If UI changes]
```

### Atoms System

Features are tracked via the atoms system:

```bash
# Validate atoms
make validate-atoms

# Render roadmap
make render-roadmap

# Both (run before commit)
make atoms
```

Never edit `docs/roadmap/feature-roadmap.md` directly - it's generated.

---

## License

This project is licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later).
See the LICENSE (and COPYING) file(s) for details.

---

## Decision Tree: Should You Use Blaze?

```
                        Do you use AI coding assistants?
                                    |
                   +----------------+----------------+
                   |                                 |
                  Yes                               No
                   |                                 |
        Are you on macOS?                    Blaze isn't for you
                   |                         (try Claude web UI)
          +--------+--------+
          |                 |
         Yes               No
          |                 |
   Do you want a GUI?   Windows/Linux not
          |             supported yet
     +----+----+
     |         |
    Yes       No
     |         |
     |    Use CLI directly
     |    (claude, gemini, codex)
     |
Do you need multi-CLI support?
     |
+----+----+
|         |
Yes       No
|         |
|    Consider Blaze or
|    provider's native app
|
+-> Blaze is for you
```

---

## User Stories

### The Security-Conscious Developer

> "I want to use Claude for coding, but I don't trust giving an AI full access to my filesystem."

**How Blaze helps:** Review Mode requires explicit approval for every file write and shell command. You see exactly what's being modified before it happens. The PolicyEngine blocks dangerous patterns automatically.

### The Multi-Tool User

> "I use Claude for some tasks, Gemini for others, and want to try Codex. Managing three different tools is annoying."

**How Blaze helps:** Blaze provides a unified interface for all three CLIs. Same keyboard shortcuts, same diff viewer, same session history - regardless of which AI you're talking to.

### The Automation Enthusiast

> "I want to run tests automatically after Claude edits code, and notify Slack when sessions complete."

**How Blaze helps:** The Hook System lets you trigger custom scripts on any event. Set up a post-hook on `file.written` to run tests, and a session.ended hook to call a Slack webhook.

---

*Last updated: January 2026*

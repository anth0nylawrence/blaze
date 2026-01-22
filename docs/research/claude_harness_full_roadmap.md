# Claude Harness (working title)
## Native macOS “Raycast + Linear + Zed” frontend for Claude Code CLI — Full Roadmap (MVP → 30 days → 3 months → 6 months)

**Purpose of this document:** A hyper-detailed product + engineering roadmap for a native macOS app that uses **Claude Code CLI** as the backend “engine” (no direct Anthropic API integration), while delivering a **buttery, modern desktop UX**: streaming, tool cards, timeline, diff review, workspace tabs, command palette, policies, and automation.

**Distribution:** Not App Store. Signed + notarized `.dmg` hosted on your site, gated behind email + marketing consent.

**Core thesis:** Most existing “web UI wrappers” feel clunky because they inherit browser constraints and/or treat Claude Code as a terminal transcript. A native harness becomes *meaningfully better* when it acts as:
- a **structured event renderer** (not a terminal emulator),
- a **governance layer** (policies, permissions, review gates),
- a **productivity cockpit** (timeline, tasks, multi-file workspace),
- and a **concurrency orchestrator** (background work + hooks + daemons).

---

## 0) Summary (one page)

### What you ship
A native macOS application that:
1) Runs `claude` headlessly and consumes **streamed structured output** (NDJSON / stream-json) to render:
   - assistant tokens streaming into message bubbles,
   - tool calls as collapsible cards with durations/failures,
   - diffs inline with accept/reject workflows,
   - multi-file workspace tabs (Zed-like).
2) Uses **Claude Code hooks** as “middleware” for deterministic logging, enforcement, and automation.
3) Maintains local-first state: sessions, events, diffs, policies, and optional memory index.

### MVP differentiation vs “chat UI for a CLI”
- **Trust**: review gates and policy enforcement around file edits + shell commands.
- **Speed**: instant UI updates; background workers do heavy tasks asynchronously.
- **Control**: command palette acts as an orchestrator of agent loops, not just a UI convenience.
- **Operator view**: timeline, context budget, and failure handling are first-class.

### End-state (6 months)
A full “Claude IDE Harness”:
- Workspace + editor + diff review + LSP intelligence
- Multi-agent lanes + worktrees per task
- Policy packs + permissions autopilot + audit trails
- Context intelligence + local-only memory layer + explainability
- Auto-updates, crash-safe journaling, high performance

---

## 1) Product positioning & goals

### 1.1 Target users
**Primary:** power users already using Claude Code CLI heavily:
- founders / solo builders
- senior engineers / “agentic coding” users
- operators building plugins, local memory layers, automation

**Secondary:** teams who want a safer agent workflow:
- “we want Claude to help, but we want controls, approvals, and audit logs”
- “we want consistency across repos and users”

### 1.2 Jobs-to-be-done
1) “I want to use Claude Code all day, but in a UI that feels like a modern app.”
2) “I want a timeline I can trust: what happened, when, why.”
3) “I want to approve risky changes before they land.”
4) “I want a workspace that makes multi-file work obvious and fast.”
5) “I want guardrails so the agent doesn’t do something stupid at 3am.”
6) “I want my own local memory layer / context control to integrate cleanly.”

### 1.3 Product principles
- **Structured-first:** never parse ANSI terminal output; consume structured events.
- **Local-first:** everything works offline (except Claude’s model), with transparent storage.
- **Safety by default:** risky operations require explicit confirmation and have explainable rules.
- **Latency is UX:** streaming and responsiveness are features, not polish.
- **Composable:** hooks + policies + recipes are “small building blocks” users can share.

### 1.4 Non-goals (initially)
- Re-implementing a full cloud IDE.
- Replacing GitHub/CI; integrate lightly.
- Shipping on Windows/Linux (until macOS is excellent).
- Depending on Anthropic API directly (your stated constraint).

---

## 2) System architecture (end-state)

### 2.1 High-level components
1) **UI Shell (SwiftUI):**
   - NavigationSplitView layout (Sessions / Main / Sidebar)
   - Command palette
   - Editor + diff viewer
   - Timeline + activity feed
   - Policy editor UI

2) **Engine Runner:**
   - Spawns Claude Code CLI (`Process` + pipes)
   - Supports streaming NDJSON decode
   - Session lifecycle manager (resume, continue, new)
   - Tool permission mode integration (safe vs permissive)

3) **Event Bus + Storage Layer:**
   - “Single source of truth” event journal
   - Stores:
     - session metadata
     - prompt/response events
     - tool events
     - file diffs
     - hook events
     - diagnostics
   - Backed by **SQLite** + **append-only JSONL** (for crash safety)

4) **Hook Orchestrator:**
   - Manages hook config templates
   - Installs/uninstalls hook packs per repo/profile
   - Validates hooks for safety (lint + allowlist)
   - Streams hook events into journal

5) **Background Workers (local daemons):**
   - file snapshots + diffs
   - repo indexing + search
   - test/lint orchestration
   - context budgeting + compaction warnings
   - (optional) local embedding + vector search for memory

6) **Update/Distribution:**
   - Developer ID signing + notarization
   - `.dmg` build pipeline
   - auto-update framework (e.g., Sparkle) optional by month 3–6

### 2.2 Process model (recommended)
- The app runs as the **primary process**.
- Each “turn” starts a **Claude CLI process** in the selected repo directory:
  - headless prompt invocation
  - stream events back to UI
- A local **daemon** (Swift or Node) runs continuously for heavy tasks:
  - tail hook event stream
  - run indexing / diffs / tests
- Communication:
  - append-only JSONL files OR
  - Unix domain socket OR
  - local HTTP loopback (only if needed; keep minimal)

### 2.3 Data storage model
**SQLite tables (conceptual):**
- `sessions(id, name, repo_path, created_at, last_used_at, engine_version, settings_json)`
- `events(id, session_id, ts, type, payload_json, seq)`
- `files(id, repo_path, rel_path, last_hash, last_seen_at)`
- `diffs(id, session_id, ts, rel_path, before_hash, after_hash, unified_diff, stats_json)`
- `policies(id, name, scope, rules_json, enabled, created_at, updated_at)`
- `recipes(id, name, steps_json, enabled)`
- `pins(id, session_id, kind, ref, content, created_at)`

**Append-only JSONL:**
- `events.jsonl` per session for crash-proof ingestion
- rehydrated into SQLite asynchronously

### 2.4 Core event schema
#### 2.4.1 Claude stream event (normalized)
```json
{
  "source": "claude",
  "session_id": "…",
  "ts": "2025-12-24T12:34:56.789Z",
  "seq": 123,
  "type": "assistant_delta | assistant_final | tool_start | tool_end | error | status",
  "payload": { "…": "…" }
}
```

#### 2.4.2 Hook event (normalized)
```json
{
  "source": "hook",
  "hook_event": "PreToolUse | PostToolUse | SessionStart | Stop | PreCompact | …",
  "session_id": "…",
  "repo_path": "…",
  "ts": "…",
  "payload": { "tool": "bash", "args": "…", "exit": 0, "summary": "…" }
}
```

#### 2.4.3 Worker event (normalized)
```json
{
  "source": "worker",
  "kind": "diff_ready | index_ready | test_result | lint_result | context_warning",
  "session_id": "…",
  "ts": "…",
  "payload": { "…": "…" }
}
```

### 2.5 Security model (critical)
Define 3 user-selectable modes:

1) **Review Mode (default)**
- risky tools are gated
- file writes require review
- shell commands require confirmation for patterns
- best for broad distribution

2) **Trusted Mode**
- minimal gates
- for experienced users who want speed

3) **Sandbox Mode**
- restrict to read-only + safe tools
- prevent all writes unless explicitly enabled

**Never store secrets** from prompts unless explicitly user-approved.
Provide “private mode” / “do not log” toggles.

---

## 3) MVP (7 days) — detailed build spec (re-stated + expanded)

### Day 0 (setup)
- Install Xcode toolchain
- Validate Claude Code CLI works
- Create repo + initial SwiftUI app scaffold

**Acceptance criteria**
- `xcodebuild` works locally
- app runs and shows 3-pane layout

### Day 1 (skeleton UI + engine runner)
**Features**
- NavigationSplitView:
  - left: Sessions list (dummy)
  - center: Chat timeline
  - right: Sidebar tabs placeholder
- Process runner:
  - run `claude` with a fixed prompt
  - stream stdout line by line
  - append to a simple message model

**Acceptance criteria**
- “Run” triggers Claude CLI
- UI stays responsive while output streams

### Day 2 (streaming renderer)
**Features**
- NDJSON decoding
- incremental assistant token streaming into a bubble
- basic error handling (process exit, parse errors)
- store raw stream to per-session log file

**Acceptance criteria**
- long responses stream smoothly with no UI freezing
- raw event log persists on disk

### Day 3 (tool cards + timeline)
**Features**
- tool cards:
  - name, inputs, outputs summary, duration
- timeline view in sidebar:
  - events grouped by type
- “copy payload” actions for debugging

**Acceptance criteria**
- at least bash/file tools appear as cards
- durations computed reliably

### Day 4 (hook-fed telemetry)
**Features**
- a minimal hook pack (scripts) that:
  - logs `PreToolUse` and `PostToolUse` events to JSONL
  - logs `SessionStart` repo state
- app tails hook JSONL and merges into timeline

**Acceptance criteria**
- hook events appear even if Claude stream omits details
- hooks must be fast (no noticeable added latency)

### Day 5 (diff viewer MVP)
**Features**
- worker snapshots “before/after” for changed files
- unified diff generation
- open diff inline from tool card
- open file read-only view in a tab

**Acceptance criteria**
- can review file changes in-app after a run

### Day 6 (command palette + session persistence)
**Features**
- command palette:
  - new session
  - open repo
  - rerun last prompt
  - open last diff
  - toggle safe mode
- session persistence:
  - store sessions in SQLite or JSON

**Acceptance criteria**
- restart app and sessions remain
- palette launches in <100ms

### Day 7 (ship pipeline: signing/notarization stub)
**Features**
- `release.sh` script:
  - build release
  - codesign (if cert exists)
  - package DMG
  - notarize + staple (if credentials exist)
- if no Dev ID yet: build unsigned DMG for internal testers

**Acceptance criteria**
- reproducible build artifact produced
- documented steps to set up Developer ID signing

---

## 4) 30-day build (Weeks 2–5) — “MVP → daily driver”

### Theme
Turn the MVP into a **reliable daily driver** with:
- robust session model
- real workspace tabs
- diff review upgraded
- policy rules that matter
- performance and stability
- onboarding + configuration experience

### Week 2 — Session system + project profiles
**Epics**
1) **Session library**
- list/grid view with search
- tags (e.g., “work”, “side project”)
- pin favorite sessions
- per-session transcript viewer

2) **Project profiles**
- per-repo config: hooks enabled, safe mode defaults, ignore patterns
- profile import/export (JSON)

3) **Resuming + continuity**
- “Continue session” UX
- “Fork session” → new thread with same repo context

**Acceptance criteria**
- 100 sessions manageable with search and tags
- switching sessions does not lose UI state

### Week 3 — Workspace & editor foundations
**Epics**
1) **File tree + quick open**
- fuzzy search for files
- recently opened
- tabs bar

2) **Read-only editor + syntax highlighting**
- SwiftUI + TextKit 2 or embedded editor component
- highlight common languages
- “open in external editor” action

3) **Diff viewer upgrade**
- side-by-side and unified modes
- per-hunk copy
- “apply patch” (manual) for one file

**Acceptance criteria**
- open large files (1–3MB) without stutter
- diff viewer handles >2000-line diffs

### Week 4 — Policies & permission harness (real guardrails)
**Epics**
1) **Policy packs**
- built-in presets:
  - “Paranoid”
  - “Safe default”
  - “Fast/trusted”
- UI rule editor:
  - allowlist/denylist file globs
  - bash command pattern blocks
  - git command restrictions (push requires confirm)

2) **PreToolUse gating**
- implement policy engine that returns allow/deny
- show “blocked tool” UI card with explanation and override option

3) **Approval workflow**
- for blocked actions:
  - approve once
  - approve for session
  - approve always (adds allowlist rule)

**Acceptance criteria**
- user can prevent `.env` edits reliably
- tool blocks are explainable and overrideable

### Week 5 — Observability + “Linear feel”
**Epics**
1) **Timeline = first-class**
- filters (tools, diffs, errors)
- durations histogram (simple)
- failure cluster view

2) **Task/checkpoint panel**
- parse “plan” outputs into checklist
- allow manual tasks
- “done when” gates

3) **Crash-proof journaling**
- append-only event ingestion with replay
- safe recovery after hard kill

**Acceptance criteria**
- app never loses a session transcript
- timeline can be exported as a report

---

## 5) 3-month build (Months 2–3) — “genuinely superior to web UIs”

### Theme
Make the harness feel like:
- Raycast: command palette + workflows
- Linear: structured activity + tasks
- Zed: multi-file workspace + performance

…and add “secret sauce” features:
- parallel worktrees per task
- automation recipes
- local memory integration
- better diff gates

### Month 2 — Editor + automation workflows
#### Epic A: True editing (not just read-only)
- embedded editor with:
  - edit buffer
  - autosave optional
  - formatting
  - diagnostics display
- integrate LSP for:
  - go-to definition
  - find references
  - basic completions (optional)

#### Epic B: Recipes (macro actions)
A “recipe” is a deterministic workflow executed by the harness:
- Example: “Refactor flow”
  1) create branch/worktree
  2) ask Claude for plan
  3) run unit tests
  4) apply edits with review
  5) run lint/tests
  6) generate summary + PR description

UI:
- recipes list
- run recipe
- observe step progress
- pause/resume

#### Epic C: Worktree-per-task
- create git worktree for each task card
- show “task lanes” in UI
- switch lanes quickly

**Acceptance criteria**
- user can run 3 tasks in parallel safely
- tasks produce separate branches/worktrees without conflict

### Month 3 — Memory, context intelligence, explainability
#### Epic D: Local memory layer integration
- pluggable “memory providers”:
  - plain pins
  - vector store (optional)
  - file-level summaries

Features:
- “Pin this” from any message/diff/file
- Retrieval view:
  - why each item was retrieved
  - score
  - source link
- “memory writeback” summaries after sessions

#### Epic E: Context budgeting and compaction control
- estimate context pressure
- warnings: “compaction imminent”
- pre-compact snapshot:
  - auto-generate recap
  - store to memory
- “context pack” builder:
  - choose key files
  - choose pinned messages
  - generate a compact primer

#### Epic F: Tool explanation & forensics
- “Explain last tool run” button on tool cards:
  - ask Claude to justify step-by-step *with references to payload*
- blame mapping:
  - “which tool call produced this diff?”
- “replay”:
  - rerun last tool with same args (if safe)

**Acceptance criteria**
- user can understand and audit changes quickly
- memory retrieval is transparent (no mystery context)

---

## 6) 6-month build (Months 4–6) — “full product”

### Theme
Now you’re building a platform:
- extensibility
- team policies
- collaboration (optional)
- update infrastructure
- performance at scale

### Month 4 — Extensibility & marketplace patterns
#### Epic G: Hook/Policy marketplace (local packs)
- import/export packs
- signature verification (optional)
- pack linting (security checks)
- “safe pack” badge system

#### Epic H: Plugin integrations
- install/uninstall Claude Code plugins from within UI (shells out to `/plugin`)
- show plugin status, version, conflicts
- allow per-project enable/disable sets

#### Epic I: Diagnostics + support bundle
- “Export support bundle”:
  - session logs (redacted)
  - app logs
  - system info
- “privacy scrubber”:
  - deterministic redaction of secrets patterns

**Acceptance criteria**
- users can share packs safely
- bug reports are actionable without leaking secrets

### Month 5 — Collaboration (optional) & team governance
If you want a team edition later, design now:

#### Epic J: Team policy distribution (still local-first)
- policies stored in repo (`.claude-harness/policy.json`)
- enforced consistently across machines
- audit: policy changes require review

#### Epic K: Shared session artifacts (optional)
- export session to a “bundle” file
- import bundle on another machine
- comment/annotation on diffs and tool cards (local)

#### Epic L: Role-based permissions (future)
- “junior dev mode” vs “admin mode”
- policy authorship restrictions

**Acceptance criteria**
- policies can be standardized across repos
- session artifacts can be reviewed by others

### Month 6 — Productionization, performance, update system
#### Epic M: Auto-update
- integrate Sparkle or custom updater
- staged rollouts
- release channels (stable/beta/nightly)

#### Epic N: Performance hardening
- profiling + optimization
- event ingestion backpressure
- large-repo scaling:
  - indexing strategies
  - lazy loading
  - incremental diffs

#### Epic O: Reliability and safety hardening
- strong sandbox options
- optional “run tools in container” mode for dangerous repos
- secret detection (gitleaks-like heuristics)
- ensure hooks cannot trivially exfiltrate by default (opt-in)

**Acceptance criteria**
- handles very large repos without beachball
- safe defaults make public distribution comfortable

---

## 7) Detailed engineering plan by area (hyper detailed)

### 7.1 UI/UX system
**Design system**
- typography scale
- spacing tokens
- color roles (light/dark)
- card component library:
  - tool card
  - diff card
  - error card
  - timeline item

**Key UX patterns**
- command palette always available (⌘K)
- “focus modes”:
  - Chat focus
  - Review focus (diffs)
  - Timeline focus (audit)
- “one-click continue” buttons after failures (“Fix tests”, “Revert last change”, “Explain”)

### 7.2 Engine runner details
- spawn with repo cwd
- environment control:
  - sanitize env
  - allow user-specified env vars per profile
- robust stream handling:
  - parse NDJSON lines
  - handle partial lines
  - enforce max line size
- cancellation:
  - user stops run
  - send SIGINT then SIGKILL
  - ensure log flush

### 7.3 Hooks and policies
**Hook pack format**
- `hooks/` scripts
- `manifest.json` with:
  - name, version
  - hook events used
  - permissions required
  - safe defaults

**Policy engine**
- rules as JSON:
  - file patterns:
    - deny write to `**/.env*`
    - deny write to `**/prod/**`
  - command patterns:
    - deny `rm -rf`
    - require confirm for `git push`
- decisions produce:
  - allow/deny
  - reason
  - override options

### 7.4 Background workers
**Core jobs**
- file snapshot/diff:
  - on tool end, detect changed files
  - store before/after hash
  - compute unified diff
- indexing:
  - build file list
  - (optional) embeddings
- tests/lint:
  - run via known scripts
  - parse results
  - show in timeline

**Implementation choices**
- Option 1: Swift worker (single binary, simplest distribution)
- Option 2: Node worker (faster dev iteration; more packaging complexity)

### 7.5 Packaging and release
**Release pipeline**
- build: `xcodebuild -configuration Release`
- sign: `codesign --deep --force --options runtime`
- notarize: `xcrun notarytool submit … --wait`
- staple: `xcrun stapler staple`
- package DMG: `hdiutil create`
- verify: `spctl --assess --type execute`

**Key constraint**
- Developer ID + notarization is essential for frictionless public downloads.

---

## 8) Product growth & lead magnet mechanics (ethical + effective)
Since this app is a freebie for email capture:

### Onboarding flow
- “Connect Claude Code” (detect binary)
- “Select a repo”
- “Choose safety mode”
- “Install recommended hook pack” (optional)
- Ask for email + consent
  - store in your backend via a minimal endpoint
  - never block app usage for non-consent (optional)

### Viral loops
- “Share session bundle” (export)
- “Share policy pack” (export)
- “Public template packs” (curated)
- “Open issues in GitHub from a diff” (optional)

### Metrics (privacy-conscious)
- activation: first successful run
- retention: sessions/week
- value: diffs reviewed, time saved (self-reported), tool failures resolved
- opt-in telemetry only (strong default privacy stance)

---

## 9) Risk register (unpriced risks you must plan for)

### R1: CLI/engine behavior changes over time
**Mitigation**
- pin supported Claude Code versions
- feature-detect capabilities
- robust parser with fallbacks
- provide “engine diagnostics” panel

### R2: Hooks inconsistencies / event availability
**Mitigation**
- don’t depend on a single hook event for safety
- prefer `PreToolUse` gating for MVP
- treat missing events as “degrade gracefully”
- maintain your own timeline from stream-json + file snapshots

### R3: Security: hooks are code execution
**Mitigation**
- ship only minimal safe hook packs
- show warnings before enabling packs
- sandbox options
- pack signature + linting by Month 4

### R4: Performance on large repos
**Mitigation**
- incremental indexing
- throttle file watchers
- background worker with priority control
- lazy UI rendering + pagination

### R5: User trust: “did this app leak my code?”
**Mitigation**
- extremely clear privacy policy
- local-first storage
- opt-in telemetry
- transparent logs and “what was sent to Claude” viewer

---

## 10) Hyper-detailed milestone table

### MVP (7 days)
- D0 toolchain
- D1 skeleton + runner
- D2 streaming render
- D3 tool cards + timeline
- D4 hook telemetry
- D5 diff viewer
- D6 command palette + sessions
- D7 release pipeline stub

### +30 days (Weeks 2–5)
- W2 session library + profiles + resume/fork
- W3 workspace tabs + quick open + read-only editor + diff upgrade
- W4 policy packs + PreToolUse gating + approval flows
- W5 timeline filters + checklist/tasks + crash-proof journaling

### +3 months
- M2 editor editing + recipes + worktree-per-task
- M3 local memory layer + context intelligence + explainability + replay

### +6 months
- M4 extensibility + pack marketplace + plugin management + diagnostics bundles
- M5 team policy distribution + shared artifacts
- M6 auto-update + performance hardening + sandbox/container modes

---

## 11) Appendices

### Appendix A — “MVP spec” prompt you can paste into Claude Code
(Use this to generate files and structure quickly.)

**Project goal:** Implement a macOS SwiftUI app that runs Claude Code CLI headlessly and renders the stream-json output into a modern UI.

**Must-have:**
- NavigationSplitView (sessions | chat | sidebar)
- Process runner that executes `claude -p <prompt> --output-format stream-json`
- Parse NDJSON line-by-line into typed events
- Streaming assistant output rendered incrementally
- Tool calls rendered as collapsible cards with duration
- Session persistence and event log to disk

**Deliverables:**
- Swift package / Xcode project
- `ClaudeRunner.swift`
- `EventModels.swift`
- `EventStore.swift` (JSONL + SQLite)
- `MainView.swift` (3-pane UI)
- `CommandPalette.swift`
- `DiffViewer.swift` (initial)
- `release.sh` placeholder

### Appendix B — Suggested “hook telemetry” JSONL line
```json
{"source":"hook","hook_event":"PreToolUse","ts":"2025-12-24T12:34:56Z","session_id":"abc","payload":{"tool":"bash","args":"git status"}}
```

### Appendix C — Suggested policy rules examples
```json
{
  "name": "Safe Default",
  "rules": [
    {"type":"deny_file_write","glob":"**/.env*","reason":"Secrets file"},
    {"type":"deny_file_write","glob":"**/prod/**","reason":"Production config"},
    {"type":"require_confirm_bash","pattern":"git push","reason":"Network side effect"},
    {"type":"deny_bash","pattern":"rm -rf","reason":"Destructive"}
  ]
}
```

### Appendix D — Release checklist (public download readiness)
- Developer ID certificate present
- codesign passes
- notarization accepted
- stapled ticket verified
- DMG passes Gatekeeper checks on a clean Mac VM
- privacy policy published
- website download + email capture flow ready

---

## 12) What I recommend you do next (immediate)
1) Create the Xcode project scaffold (10 minutes).
2) Use Claude Code to generate the runner + NDJSON decoding + UI skeleton.
3) Ship a “private alpha” DMG unsigned to yourself and a few friends.
4) Enroll in Apple Developer Program when the UX is already lovable (so you don’t pay $99 while you’re still experimenting).
5) Iterate on “Review Mode” policies early — that’s your moat.


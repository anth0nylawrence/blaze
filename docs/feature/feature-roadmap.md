# Blaze Feature Roadmap (CLI-First, UX-First)

This roadmap is written for a junior developer. It is intentionally detailed and step-by-step. It assumes we stay CLI-based for now and avoid heavy animation dependencies.

---

## Assumptions & Constraints (Read First)

- **Primary engine is Claude Code CLI**. We will push as far as possible without switching to the Agent SDK.
- **AskUserQuestion tooling is “good enough”** for now; do not spend more time on it unless explicitly requested.
- **No Lottie/heavy animation deps**. Only lightweight SwiftUI animations.
- **Right panel is the fidelity sink**: full details live there; chat stays summary-first.
- **We already have**: `NDJSONParser`, `ClaudeEventMapper`, `SessionOrchestrator`, `TerminalManager`, `DiffService`, `EnhancedContextSidebarView`, `TokensSidebarView`.

> SDK note (from `docs/claude-agentsdk.md`): Agent SDK appears to support Claude Max for **personal/internal** use but not for third‑party distribution. Treat this as **tentative** and schedule a validation task.

---

## CLI-First Capability Boundary (What We Can/Can’t Do Without SDK)

**We can do well (CLI-only):**
- Summary-first chat UI with full-fidelity right panel (Timeline/Tools/Context).
- Tool grouping, command cards, diff cards, and terminal sessions.
- Context window visualization and token budgeting (estimated + CLI usage from `TokenUsage`).
- Session replay (based on stored `EventEnvelope` data).
- Undo last turn (if we capture diffs or snapshots per turn).

**We cannot do fully (CLI-only):**
- Real interactive AskUserQuestion tool_result round-trips (headless CLI limitation).
- Dynamic tool permissions (SDK `canUseTool` only).
- Rich session controls like fork/resume-at-message (SDK only).

**Design rule:** Build features that do not require SDK-only callbacks first. Where CLI limits exist, provide best-effort UX and clear in-app explanation.

---

## Planning Approach (How to Execute)

1) **Stabilize source-of-truth events**
   - Use fixtures under `Blaze/Tests/Fixtures/NDJSON/` to validate parsing and data models.
   - Add minimal unit tests for each new event mapping.

2) **Create a render pipeline before new UI**
   - Implement a `RenderIntent` model so UI can evolve without rewriting the event stream.
   - Only after routing is stable, build cards and polish.

3) **Ship in thin slices**
   - Each phase below should produce a visible user-facing improvement with acceptance criteria.
   - Avoid large “rewrite all UI” PRs.

4) **Document internal limits**
   - If the CLI does not support a behavior (e.g., interactive tool results), we document it in-app and in docs.

---

## Roadmap (Ordered by Dependency and User Value)

### Phase 0 — Prep & Spec Consolidation (1–2 days)

**Goal (user perspective):** The team has a single, clear source of truth for UI behavior.

**Why this matters:** Two near-duplicate specs cause drift and rework.

**Implementation steps (do these in order):**
1. Consolidate `docs/feature/blaze-chat-ui-polish-spec (1).md` and `(2).md` into one canonical doc.
   - Keep the newest content, remove duplicates.
   - Add a “CLI-first constraints” note at the top.
2. Add a short README section stating “CLI-first, SDK optional; AskUserQuestion is best-effort.”
3. Add a checklist in the new doc with acceptance criteria for each phase.

**Verification**
- Only one polish spec exists in `docs/feature/`.
- README references the canonical spec.

---

### Phase 1 — Runtime Environment & MCP Visibility (Source: `system.init`)

**Goal (user perspective):** On session start, the right panel shows the *actual* CLI environment (tools, MCP servers, CLI version, model, permission mode).

**User flow (what they see):**
- They open a session and immediately see “Connection” and “MCP” status populated from the actual CLI runtime.
- They can copy session ID and see tool availability without scanning chat logs.

**Implementation steps:**
1. **Create a shared runtime model**
   - Add a `ClaudeRuntimeInfo` struct to a shared file (suggest `Blaze/Sources/Core/RuntimeInfo.swift`).
   - Fields: `claudeCodeVersion`, `model`, `permissionMode`, `cwd`, `sessionId`, `tools`, `mcpServers`, `lastUpdated`.
2. **Capture `system.init`**
   - In `ClaudeEventMapper` or `SessionOrchestrator`, when you see a `system.init` event, parse its fields and update `AppState.runtimeInfo`.
   - Keep **exact** values; do not infer or “clean.”
3. **Replace MCP sidebar data source**
   - Update `MCPSidebarView` to read from `appState.runtimeInfo` instead of `.claude/settings.json`.
   - Keep the old settings.json code behind a debug flag or remove it entirely.
4. **Add “Environment ready” signal**
   - Add a small chip or banner in the right panel or chat header that appears once runtime info is received.
   - Clicking it should open the MCP/Connection panel.

**Verification**
- MCP list and tool list exactly match `system.init` tools and mcp_servers arrays.
- No demo/mock data shown if runtime info exists.

---

### Phase 2 — RenderIntent Routing & Activity Bundling (Foundation)

**Goal (user perspective):** Chat is clean and narrative, but nothing is lost because details are in the right panel.

**User flow:**
- They see one assistant response bubble, with an attached activity strip summarizing what happened.
- They can expand the strip to see details or open the right panel for full logs.

**Implementation steps:**
1. **Define `RenderIntent`**
   - Create a new module/file (suggest `Blaze/Sources/Render/RenderIntent.swift`).
   - Include intent types: `assistantMessage`, `commandCard`, `diffCard`, `toolRunGroup`, `errorCard`, `warningCard`.
2. **Create `RenderIntentRouter`**
   - New file `Blaze/Sources/Render/RenderIntentRouter.swift`.
   - Input: `NormalizedEvent` stream.
   - Output: `RenderIntent` objects targeted to Chat, Terminal, RightPanel.
3. **Activity Bundling**
   - Maintain a current “assistant bundle” while streaming assistant text.
   - Tool calls during this window attach to the bundle (stored as intents).
4. **Noise Gate**
   - Add a `NoiseGateSetting` in AppState (Minimal / Normal / Verbose).
   - `RenderIntentRouter` decides which tool intents bubble into chat.

**Verification**
- Chat shows a single assistant bubble with an attached activity strip.
- Right panel still shows full event timeline.
- Switching Noise Gate changes chat density without affecting right panel.

---

### Phase 3 — Tool Run Group (Non-command tools)

**Goal (user perspective):** Routine tools don’t spam the chat. The user sees a compact “Ran N tools” group with expandable details.

**User flow:**
- After a response, a line like “Ran 6 tools (1.8s): Read×3, Glob×2, Grep×1” appears.
- Clicking it expands the list (tool name, duration, status).

**Implementation steps:**
1. Build `ToolRunGroupCard` in `Blaze/Sources/UI/`.
2. Update `RenderIntentRouter` to aggregate non-command tools into this group.
3. Ensure failures are always shown (failures should still bubble into chat even on Minimal).

**Verification**
- `Read`, `Glob`, `Grep` collapse by default.
- Failures show in chat even on Minimal mode.

---

### Phase 4 — Command Card + Terminal Sessions

**Goal (user perspective):** Commands are readable and link to clean terminal output, without flooding the chat.

**User flow:**
- A command card shows “Running … / Success / Failed” with exit code and duration.
- Clicking “Open Terminal” shows the exact output.

**Implementation steps:**
1. **Model**
   - Create `TerminalSession` model that links a tool call ID to a terminal tab ID and captures exit code + duration.
   - Store in `AppState` or `TerminalManager` with lookup by tool call ID.
2. **Command Card**
   - Build `CommandCard` UI with status, duration, and action buttons.
   - Include a small output preview (first ~10 lines) if available.
3. **Terminal sessions**
   - Modify `TerminalManager` to record output per command (can be per-tool session or “segment” within the Claude terminal tab).
   - At minimum, store a snapshot of output lines for the command in a buffer linked to the tool call.

**Verification**
- Chat does not show raw terminal output.
- Each command card can open its specific output session.

---

### Phase 5 — Diff Card + Undo Turn (Core Differentiator)

**Goal (user perspective):** File edits are summarized in a clean card, and the user can undo the last turn.

**User flow:**
- After a tool writes files, they see “Edited 3 files (+45/‑12)”.
- Clicking “Undo Last Turn” restores files to the previous state.

**Implementation steps:**
1. **Diff Card**
   - Build `DiffCard` with per-file rows and +/- counts.
   - Use existing `FileDiff` and `DiffService`.
2. **Turn-level diff tracking**
   - Define a `TurnRecord` data structure with `turnId`, `assistantMessageId`, and `fileDiffs`.
   - When `fileDiffProduced` events occur, attach them to the current turn.
3. **Undo last turn**
   - Add a button (e.g., in the activity strip or a small toolbar).
   - Revert each `FileDiff` via `DiffService.rejectDiff`.
   - If a file has uncommitted changes, show a confirmation and skip that file.

**Verification**
- Diff card appears for any file write/edit.
- Undo reverts files for the last turn and marks the turn as “Undone”.

---

### Phase 6 — Session Replay & Context Diff Between Turns

**Goal (user perspective):** Users can scrub back in time and see what changed in each turn.

**User flow:**
- A “Replay” drawer shows Turn 1–N. Clicking a turn highlights its tool cards and diffs.
- A “Context changes” box shows added/removed context items per turn.

**Implementation steps:**
1. **Define turn boundaries**
   - Start a turn when a user message is sent.
   - End the turn when `assistantComplete` or `result` event arrives.
2. **Store turn records**
   - Record start/end timestamps, event IDs, tool calls, diffs, token usage snapshots.
3. **Replay UI**
   - Add a list or scrubber UI in the right panel.
   - Selecting a turn filters the timeline and highlights associated cards.
4. **Context diff**
   - Track context changes (files pinned/unpinned, CLAUDE.md loaded, etc.).
   - Show “Pinned: X” and “Dropped: Y” for each turn.

**Verification**
- Selecting a turn filters/spotlights only that turn’s events.
- Context diff shows additions/removals clearly.

---

### Phase 7 — Context Window & Token Usage (Deep Visibility)

**Goal (user perspective):** Users can quickly see how full the context window is and what is consuming it.

**User flow:**
- The Tokens panel shows total usage vs model limit, plus breakdowns.
- The Context panel shows “In Context Now” with per-item token counts.

**Implementation steps:**
1. **Expand token breakdown**
   - Update `TokensSidebarView` to include: base system prompt, CLAUDE.md, MCP injection (if known), conversation, tool outputs, and “residual budget”.
   - Use `TokenEstimator` for estimates and `TokenUsage` events when available.
2. **MCP injection visibility**
   - If `system.init` doesn’t include exact prompt injection sizes, mark as “unknown” and display an estimate with a tooltip.
3. **Context list with token counts**
   - Extend `EnhancedContextSidebarView` to show each context item’s token estimate.
   - Allow pin/unpin actions and show updated totals immediately.

**Verification**
- User can answer “What is the model seeing?” within 5 seconds.
- Token budget clearly indicates when to compact/clear.

---

### Phase 8 — Dry Run / Preview Impact & Rerun with Context Fixes

**Goal (user perspective):** Users can safely preview impact before applying changes and quickly rerun with corrections.

**User flow:**
- Before applying risky edits, they can preview the diff without modifying files.
- If a tool run failed due to missing context, they can attach files and rerun in one click.

**Implementation steps:**
1. **Preview impact**
   - Add a “Preview” button for risky tools (Edit/Write/Bash).
   - Use a dry‑run mode if available; otherwise, run in a scratch worktree and compute diff.
2. **Rerun with context fixes**
   - Provide a UI flow that lets users attach missing files or notes.
   - Re-run the last user prompt with the adjusted context.

**Verification**
- Preview shows diffs without applying to disk.
- Rerun executes with added context and creates a new turn record.

---

### Phase 9 — Diagnostics & Error UX

**Goal (user perspective):** When something fails, the UI is clear and provides a quick fix path.

**User flow:**
- Errors appear as a compact card with “What happened” and “Fix suggestion”.
- There is a “Copy diagnostics bundle” action.

**Implementation steps:**
1. Implement `ErrorCard` and `WarningCard` with a minimal detail disclosure.
2. Add a “Copy diagnostics bundle” action that collects:
   - last N `EventEnvelope`s
   - trace folder path
   - CLI stderr (if captured)
3. Update the right panel to show the full error payload.

**Verification**
- Errors are visible and actionable.
- Diagnostics are easy to share.

---

### Phase 10 — Polish Pass (Final)

**Goal (user perspective):** Everything feels “premium” and stable.

**Implementation steps:**
1. Add hover affordances & pressed feedback to cards and buttons.
2. Add smooth expand/collapse animations (no spring chaos).
3. Add keyboard shortcuts for navigation (open terminal, open tools panel).
4. Run a performance audit (no re-render storms in long sessions).

**Verification**
- UI feels responsive and clean in long sessions.

---

## Optional Track: Agent SDK Exploration (Non‑blocking, detailed)

**Goal:** Verify if Claude Max subscriptions can be used directly with the SDK for Blaze in personal/internal use.

**Step-by-step plan:**
1. **Local SDK probe (no UI integration yet)**
   - Create a temporary folder `scripts/sdk_probe/`.
   - Add a minimal Python or Node script that calls the Agent SDK with a simple prompt.
   - Use the local Claude CLI credentials (if supported) and document the result.
2. **Authentication validation**
   - If the SDK requires `ANTHROPIC_API_KEY`, log that as a blocker.
   - If it accepts Claude Max auth, capture the exact steps and any environment variables used.
3. **Policy compliance check**
   - Read `docs/claude-agentsdk.md` and summarize compliance implications in a short note.
   - Decision: “Personal use only” vs “distribution requires API billing.”
4. **Decision memo**
   - Summarize: Does SDK work with Max locally? Is it legally acceptable for distribution?
   - If yes for personal use, mark as optional path.

**Outcome**
- If validated, plan a later SDK integration phase. If not validated, remain CLI-first.

---

## Feature Tradeoffs (Explicit “No” for Now)

- No Lottie or heavy animation dependencies.
- No deep AskUserQuestion rework unless SDK becomes the default.
- No git staging/commit UX until diff + undo is stable.

---

## Final Notes for Junior Dev

- Keep changes small and visible.
- Always tie UI changes back to `NormalizedEvent` and `RenderIntent`.
- If you can’t prove a feature with a fixture or test, do not ship it.

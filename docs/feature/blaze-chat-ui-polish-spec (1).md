# Blaze “Joy-to-Use” Chat Output UI: Production Spec + Phase Plan (No Blockers)

You are implementing UI polish that makes Blaze **strictly better** than Claude Code CLI:
- **Zero clutter** in main chat
- **Full fidelity** preserved (nothing lost)
- **Buttery smooth** interactions + gorgeous visuals
- **Fast scanning**: users immediately understand what happened and what to do next
- **Drill-down**: power users can inspect raw payloads, tokens, timings, diffs, and logs instantly

This doc is a build spec. Do exactly what it says. Do not “sort of” implement.

---

## North Star UX

### “Every event has a home”
- **Main Chat (center)**: narrative, decisions, compact summaries, interactive prompts. NEVER raw spam.
- **Terminal (bottom)**: live streaming output, interactive shells, long stdout/stderr.
- **Right Panel (Timeline / Tools / Context)**: full-fidelity audit trail + drill-down: raw tool inputs/outputs, tokens, durations, raw NDJSON, trace links.

### Golden rules
1. **Summary-first UI**: chat shows cards with meaningful summaries + actions. Full details are collapsible or moved to right panel/terminal.
2. **No fidelity loss**: every tool event is accessible somewhere (Timeline/Tools) with raw payload and timestamps.
3. **No surprise state**: user can always see (a) what is running now, (b) what changed, (c) what requires input.
4. **Consistent affordances**: every card has predictable actions (Open, Copy, Reveal, Pin, Expand).
5. **Fast + smooth**: streaming is stable, no layout jank, animations are subtle and responsive.

---

## Visual polish requirements (non-negotiable)

### Design language: “macOS glass + pro tooling”
- Use existing Blaze design system tokens if present (dsGlassPanel, typography, spacing).
- Add/ensure:
  - **Glass blur & layered depth**
  - **Soft shadows** + subtle borders
  - **Hover micro-interactions** (highlight row, show controls)
  - **Motion**: 120Hz-friendly, easeInOut, no spring chaos
  - **Typography**: monospaced for commands/diffs, readable body for narrative
  - **Color semantics**: success/warn/error states must be instantly readable

### Suggested UI building blocks (choose what fits existing codebase)
- Prefer native SwiftUI components + your design system wrappers.
- For diff rendering:
  - Build a custom SwiftUI diff viewer (recommended) OR embed a performant text view with syntax highlighting.
- For syntax highlighting:
  - If you already have a highlighter, use it.
  - If not, implement a simple token-based highlight for diff markers first; evolve later.

### Motion + feedback
- Streaming indicator: subtle “Now writing…” shimmer/ellipsis
- Cards animate in/out with **opacity + slight scale** (no bounce)
- Terminal open/close: smooth height transition
- Buttons: hover glow + pressed feedback

---

## Output taxonomy: everything that can appear, and how to render it

### A) Assistant text (assistant_delta / assistant_complete)
**Main Chat**
- Render markdown in a stable bubble.
- Streaming deltas must append without reflow-jank.
- If message is mostly status, collapse into a small line:
  - “Working… running tools…” with a spinner.

**Right Panel**
- Model name, token usage, duration, cache hits (if available).
- Raw message JSON (dev mode only).

Actions:
- Copy, Quote, Pin-to-Context.

Acceptance:
- No jitter while streaming.
- Copy copies full message, not partial.

---

### B) Code changes (Edit/Write / file diffs)
**Main Chat**
- NEVER dump raw patch as text by default.
- Show a **Diff Card**:
  - Header: “Edited N files” + total (+/-)
  - Per-file rows: path, +/-, quick actions
  - If patch tiny (< ~20 lines), allow inline preview collapsed by default.

Diff Card actions:
- Preview diff (inline viewer)
- Open file
- Copy patch
- Revert local changes (if you track)
- Stage/apply (optional, but planned)

**Right Panel**
- Full patch text
- Tool input/output payloads
- Parse warnings (“patch didn’t apply cleanly”)

Acceptance:
- Diff card visible in chat for any file write/edit tool event.
- Full patch always retrievable from Tools/Timeline.

---

### C) Commands & shells (Bash / Task / TaskOutput / KillShell)
**Main Chat**
- Show a **Command Card**:
  - Monospaced command (single line)
  - Status: running / success / failed / killed
  - Duration + exit code
  - Buttons: View output, Open terminal, Rerun (policy-gated)

**Terminal**
- All streaming output goes here.
- If command output is short, show a small preview in Command Card (first ~10–20 lines max) with “Expand”.

**Right Panel**
- Full stdout/stderr artifacts
- Tool metadata: cwd, env, runner type (PTY), etc.

Acceptance:
- Streaming never appears as huge spam in chat.
- Terminal view always shows the true stream.

---

### D) Tool calls (Glob / Grep / Read / WebFetch / WebSearch / Skill / etc.)
**Main Chat**
- Do NOT print each tool call as a separate bubble.
- Instead attach a **Tool Run Group** to the assistant message:
  - “Ran 7 tools (2.1s): Glob×2, Read×3, Grep×2”
  - Expand shows the list of tool calls.

**Right Panel**
- Timeline tab: every tool call row with icon + duration + tokens
- Tools tab: grouped by tool name with last N runs; pin capability

Noise Gate:
- Minimal: only failures + user-relevant
- Normal: grouped summary + expandable detail
- Verbose: show every tool call expanded

Acceptance:
- Routine tools are collapsed by default.
- Failures are always surfaced.

---

### E) File reads (Read tool / file preview)
**Main Chat**
- If assistant quotes file content: show a **File Snippet Card**
  - Path, line range, excerpt (short), Open/Copy/Pin actions

**Right Panel**
- Full read payload + metadata (line ranges)

Acceptance:
- Clicking path opens viewer/editor.
- Pin adds it to Context tab.

---

### F) Interactive questions & tool prompts (AskUserQuestion)

**Goal:** Make *blocking* questions feel effortless and “native”—fast to answer, impossible to miss, and never confusing. This must be **better than Claude Code**: clearer affordances, richer context, and fewer “where do I click?” moments.

#### F1. Unified model
Treat **all interactive prompts** as the same UX primitive: a `ToolPromptEvent` rendered by `ToolPromptCard`.

Sources that create a `ToolPromptEvent`:
- `AskUserQuestion` tool_use (options + optional descriptions + multiSelect)
- “Tool approval” prompts (permission / safety gates)
- Any unknown tool that appears interactive (schema markers → free-text fallback)

#### F2. Where it appears
- **Main chat timeline:** inline `ToolPromptCard` at the point the model asked (so context stays in place).
- **Right tools sidebar:** a compact “Prompts” pill/section showing:
  - count of pending prompts (FIFO)
  - latest prompt title
  - submission status badges (idle/submitting/failed)
- **Terminal view:** never used for interactive questions (unless the user explicitly opens a raw trace/TTY log).

#### F3. Interaction rules (flow, focus, keyboard)
When a prompt is pending:
- **Lock step (default):** disable sending a *new* user message until the prompt is answered (prevents confusing model state).
  - Exception: allow “Add note” or “Cancel/Stop” if you support that.
- **Auto-focus:** focus the first option / text field immediately when the card appears.
- **Keyboard-first:** this must be buttery fast.
  - `1…9` selects option 1…9
  - `↑/↓` moves selection
  - `Space` toggles (multi-select)
  - `Enter` submits
  - `Esc` dismisses card only if you support deferral (otherwise show “Answer required”)
- **Mouse/touch:** option rows have large hit targets, subtle hover, and clear selected state.

#### F4. Rendering polish (make it feel premium)
ToolPromptCard should support:
- **Option search** when options > 8 (local filter with instant results)
- **Descriptions** as secondary text (smaller, higher line-height)
- **Multi-select chips** preview above the list once selected
- **Inline errors** (submission failed) with retry + “View details” (expands raw JSON and last stdin line)
- **Subtle animation:**
  - insertion: fade + small scale (already in plan)
  - selection: spring
  - submit: progress overlay, then checkmark

Recommended SwiftUI tech (no heavy deps required):
- Use your existing design system (glass panels, spacing, typography).
- Add tiny helpers:
  - `@FocusState` for focus management
  - `matchedGeometryEffect` for selection highlight
  - `withAnimation(.spring(...))` for state transitions
- If you want extra delight: **Lottie** (optional) for micro-animations (success/check), but keep it tasteful.

#### F5. Protocol → UI mapping (exact behavior)
On `assistant.message.content[]` with `{ type: "tool_use", name: "AskUserQuestion", input: … }`:
1. Decode input as:
   - `questions[0].question` → card title
   - `questions[0].header` → body (or subtitle)
   - `questions[0].options[]` → `ToolPromptOption(label, description)`
   - `questions[0].multiSelect` → response type
2. Enqueue into FIFO prompt queue (AppState/Orchestrator)
3. Render as `ToolPromptCard` in timeline + show “Prompts (n)” in right sidebar

On submit:
1. Immediately set state → **submitting** (disable UI controls)
2. Send `tool_result` via `StdinWriter` using the empirically validated envelope:
   - `session_id` required
   - `parent_tool_use_id: null`
   - `content`:
     - single select: the selected option **label**
     - multi-select: JSON string `{"selected":[<labels>]}` (exact)
     - free-text: raw user text
3. Await continuation:
   - If any `assistant` event arrives within N seconds, mark **submitted** and pop the prompt from queue.
   - If no continuation, mark **failed** with retry CTA.

**Performance target:** From prompt appearance → tool_result sent in **<250ms** on a normal machine (excluding human reaction time). Keep send path off the main thread, but UI state updates must stay smooth.

#### F6. Handling edge cases (must not degrade UX)
- **Tool denied (non-interactive / permission denial):**
  - Show a compact banner inside the card: “Claude couldn’t accept interactive answers in this session.”
  - Offer “Rerun with interactive tools enabled” (if your app can restart the turn) or explain the fix.
- **Multiple prompts back-to-back:**
  - FIFO queue with a visible “1 of N” indicator
  - Optional “View all prompts” drawer in sidebar
- **Unknown interactive tool:**
  - Render free-text input with tool name badge + raw input disclosure
- **Long-running submit:**
  - If submitting > 2s, show “Still sending…” and keep spinner (no UI freeze)
- **Idempotency:**
  - Disable double-submit; allow retry only after failure.

#### F7. Safety & policy (PromptPolicy integration)
Before sending tool_result:
- Evaluate `PromptPolicy`.
- If flagged:
  - show warning banner + require explicit confirmation (“I understand” toggle)
  - optionally require a second click (“Confirm & Send”)
- Log policy decision as a visible “Safety” chip in sidebar (for transparency).

#### F8. Acceptance criteria
- Prompt appears inline **every time** `AskUserQuestion` tool_use is emitted (no missed prompts).
- User can answer with keyboard-only in <2 seconds.
- Tool_result is sent with correct envelope; continuation arrives; prompt disappears; queue advances.
- No clutter: prompts never spam the main chat (single card + concise status updates).
- Unknown tools never crash the UI (always free-text fallback).
### G) TodoWrite / task list
**Main Chat**
- Never spam full todo list.
- Show a toast/mini-card: “Todo updated: +2 / -1” (click opens Todo panel)

**Right Panel**
- Dedicated Todo panel or Context tab widget:
  - Sections: Now / Next / Later
  - Each item links back to originating message/tool call
  - Clear completed toggle

Acceptance:
- Todo always accessible in 1 click.
- Every item has provenance.

---

### H) Errors & warnings (parse_error, permission_denials, tool failures)
**Main Chat**
- Show **Error Card** ONLY when actionable:
  - What happened (1–2 lines)
  - Recommended fix (1–2 lines)
  - Show details (expands)
- Permission denials should show as **Warning Card** with explanation and next action.

**Right Panel**
- Full diagnostics: raw JSON, stderr, traces

Acceptance:
- No silent failures.
- “Copy diagnostics bundle” exports trace folder path or zip if implemented.

---

### I) WebSearch / WebFetch results
**Main Chat**
- Render a **Results Card**:
  - 3–5 bullets
  - Source list (click to open)
  - “Open sources” / “View extraction” actions

**Right Panel**
- Full fetched content + extraction logs

Acceptance:
- No huge HTML in chat.
- Sources are easy to open.

---

### J) Context management (what is in-context right now)
**Right Panel (Context tab)**
- “In context now” list:
  - pinned files/notes + line ranges
  - system prompt / output style used
  - token estimate breakdown (by item)
- Pin/unpin actions.

**Main Chat**
- Only surface context changes when they matter:
  - “Pinned: architecture.md”
  - “Dropped: old logs (too large)”

Acceptance:
- User can answer: “What is the model seeing?” within 5 seconds.

---

## Routing engine requirements (technical)

### NormalizedEvent → RenderIntent mapping
Implement an internal mapping layer:
- Input: NormalizedEvent stream
- Output: RenderIntent objects routed to:
  - ChatTimeline
  - TerminalStream
  - RightPanelTimeline/Tools/Context
- RenderIntent must include:
  - stable IDs for grouping
  - severity (info/warn/error)
  - summary payload
  - detail payload pointers

### Grouping logic (critical)
- Each assistant message becomes a “bundle”:
  - assistant bubble + an attached expandable “Activity strip”
- Tool calls occurring between assistant start and completion should be grouped under that assistant message.
- Command output is streamed to terminal; chat gets summary card with pointer to terminal output session.

### Fidelity guarantee
- Every event is persisted to:
  - Right panel timeline (structured)
  - Traces (raw jsonl)
- Chat is a curated view, not a log.

---

## Policy gating & safety UX (PromptPolicy integration)
- If a Command Card includes dangerous patterns (delete/execute/deploy/overwrite):
  - Require a confirmation step (modal or inline confirm state)
  - Show why it’s risky
  - Allow “Always allow for this repo” only if you have a trust model (otherwise omit)

---

# Phase Plan (dependency-clean; no blockers)

## Phase 1 — UI Plumbing: RenderIntents + Routing (FOUNDATION)
Dependencies: None (use existing event stream + right panel).
Deliverables:
1. Define `RenderIntent` model + routing targets.
2. Implement `RenderIntentRouter`:
   - routes to Chat/Terminal/RightPanel
3. Implement Activity Bundling:
   - assistant bubble + attached activity strip
4. Add Noise Gate setting (Minimal/Normal/Verbose).

Acceptance:
- Existing Timeline stays full-fidelity.
- Chat becomes summary-first with expandable activity strip.

---

## Phase 2 — Cards: CommandCard + DiffCard + ToolRunGroup (CORE VALUE)
Dependencies: Phase 1.
Deliverables:
1. CommandCard:
   - status, duration, exit code, open terminal, rerun gated
2. DiffCard:
   - per-file summary + inline diff preview viewer
3. ToolRunGroup:
   - summary chips + expandable tool list

Acceptance:
- No command/tool spam in chat.
- Diffs never dumped as raw blocks by default.

---

## Phase 3 — Terminal Experience: buttery streaming + sessions (DELIGHT)
Dependencies: Phase 2 (CommandCard references terminal).
Deliverables:
1. Terminal session model:
   - one session per command
   - ability to reopen past session
2. Streaming UX:
   - stable scroll handling
   - “follow tail” toggle
   - search within output
3. Inline preview in CommandCard for short outputs.

Acceptance:
- Smooth streaming, no UI blocking.
- Past command outputs accessible.

---

## Phase 4 — Context Tab Power Features (DIFFERENTIATOR)
Dependencies: Phase 1.
Deliverables:
1. Context inspector:
   - pinned items list + token estimate
   - pin/unpin actions
2. Provenance linking:
   - any pinned item links back to its originating message/tool event
3. “Why is this in context?” tooltip (dev mode).

Acceptance:
- User can see and control what’s in context quickly.

---

## Phase 5 — Todo System UX (FOCUS)
Dependencies: Phase 1.
Deliverables:
1. Todo panel in right side (Context or new tab).
2. TodoWrite integration:
   - toast/mini-card in chat “Todo updated”
3. Link todos to originating events.

Acceptance:
- Todo never clutters chat.
- Todo always 1 click away.

---

## Phase 6 — Error & Diagnostics UX (TRUST)
Dependencies: Phase 1.
Deliverables:
1. Error Card + Warning Card components
2. Right panel diagnostics drill-down
3. Diagnostics bundle export (at least: copy trace dir path; optional zip)

Acceptance:
- Failures are visible and actionable.
- Full details preserved.

---

## Phase 7 — Polish pass (JOY)
Dependencies: Phases 1–6.
Deliverables:
1. Micro-interactions:
   - hover controls reveal
   - subtle animations
2. Keyboard shortcuts:
   - tool prompt selection (1/2/3), submit (Enter)
   - open terminal (⌘J), open tools panel (⌘K) if you have shortcuts system
3. Performance:
   - avoid re-render storms
   - efficient diff rendering
4. Theming:
   - perfect glass aesthetic, consistent spacing, typography polish

Acceptance:
- App feels “premium” within 30 seconds of use.
- Smooth on large sessions.

---

## Implementation notes (do not skip)

### Main Chat rendering rules
- Default collapsed: tool call spam, big diffs, large outputs
- Default visible: decisions, prompts, summaries, errors

### Right panel rules
- Timeline is canonical log
- Tools tab is grouped power view
- Context tab is “what model sees” + control plane

### Terminal rules
- Streaming always routed here
- Provide “Open terminal” from any command card

---

## Success criteria (what “better than Claude Code” means)
1. A new user can connect Claude Code and immediately understand:
   - what is running
   - what changed
   - where output went
2. Chat stays readable after 200+ events.
3. Full fidelity is preserved (raw NDJSON, tool payloads, diffs, logs).
4. The UI feels delightful: smooth, polished, consistent, responsive.

---

## What to build first (strict order)
1) Phase 1 Routing + Activity Bundles + Noise Gate
2) Phase 2 CommandCard + DiffCard + ToolRunGroup
3) Phase 3 Terminal sessions + streaming polish
Then continue through Phase 4–7.

Do not start Phase 2 until Phase 1 is solid and tested.
Do not add more visual flourish until routing is correct and fidelity is preserved.

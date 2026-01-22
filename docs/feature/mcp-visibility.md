# MCP Visibility (UI + Engine Wiring)

## Goal
Expose the *actual* Claude Code environment (tools + MCP servers) in Blaze with higher fidelity than Claude Code CLI:
- show which MCP servers are connected
- show which tools are available
- surface CLI version + model + permissionMode
- keep it non-cluttered (main chat stays clean; details live in the right-side tool panel)

---

## 1) Source of truth: `system.init` event
From your fixture, `system.init` contains:
- `claude_code_version`
- `tools: [String]`
- `mcp_servers: [{name,status}]`
- `model`
- `permissionMode`
- `cwd`
- `session_id`

---

## 2) Data model (AppState)
Add a simple “Runtime Environment” state:

### Suggested structs
- `ClaudeRuntimeInfo`
  - `claudeCodeVersion: String?`
  - `model: String?`
  - `permissionMode: String?`
  - `cwd: String?`
  - `sessionId: String?`
  - `tools: [String]`
  - `mcpServers: [MCPServerInfo]`
  - `lastUpdated: Date`

- `MCPServerInfo`
  - `name: String`
  - `status: String`  (e.g. "connected", "disconnected", "error")

Store it on AppState:
- `@Published var runtimeInfo: ClaudeRuntimeInfo?`

---

## 3) Engine mapping
When your NDJSON parser yields `system.init`:
- parse `tools` and `mcp_servers`
- populate/refresh `runtimeInfo`
- also persist `session_id` already used for envelope sending

Key rule:
- **Do not rely on assumptions** (e.g., “MCP should be present”) — display exactly what init says.

---

## 4) UI placement (Right-hand tool panel)

### Panel sections (collapsed by default, expandable)

1) **Connection**
- Claude CLI version (e.g. 2.0.76)
- Model (e.g. claude-opus-4-5-20251101)
- Permission mode
- CWD
- Session ID (copy button)

2) **MCP Servers**
- list of servers with status pill (Connected / Disconnected / Error)
- a “Refresh” button (just restarts a run or re-reads init; no magic)
- optional: show count + last updated timestamp

3) **Available Tools**
- searchable list (typeahead filter)
- show “interactive” tools badge for AskUserQuestion
- show “dangerous” tools badge (Bash/KillShell/Edit/Write) to align with PromptPolicy

---

## 5) Main chat: keep it clean
Main chat should not spam environment metadata.
Instead:
- show a subtle “Environment ready” chip once per session
- clicking it opens the right panel at the Connection section

---

## 6) UX polish details (what makes this feel premium)
- Status pills with icons (dot + label)
- Copy buttons for session_id / cwd
- Quick filter for tools list
- “Connected MCPs: N / Total: M” at top of MCP section
- Animations: smooth expand/collapse, no layout jump

---

## 7) Acceptance criteria
- [ ] On session start, Blaze shows connected MCP servers exactly as `system.init` reports
- [ ] Tools list matches `system.init` tools array
- [ ] UI lives in right-hand panel; main chat remains uncluttered
- [ ] Session ID is visible + copyable
- [ ] If MCP disconnects mid-run (future event), panel updates without crashing (unknown events allowed)

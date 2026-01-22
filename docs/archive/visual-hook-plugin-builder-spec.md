# Visual Hook & Plugin Builder Spec (Claude Code CLI semantics)

> Goal: a visual, node-based builder that lets users compose **hooks** and bundle them into **plugins**, with first-class tooltips and a safe save/discard workflow. The builder launches from **Settings** as an overlay via the button **“Open visual builder”**.

---

## 0) Terminology (the words your UI should use)

### Hook event
A named lifecycle moment when the CLI invokes hooks (e.g., `PreToolUse`, `UserPromptSubmit`).

### Hook matcher
A filter string that selects *which* event instances trigger a hook group.
- For tool-related events, the matcher commonly targets tool names (e.g., `Write|Edit`).
- For `Notification`, matchers filter by notification type (e.g., `permission_prompt`, `idle_prompt`).
- For `PreCompact`, matchers filter by trigger (`manual` vs `auto`).
- For `SessionStart`, matchers filter by source (`startup`, `resume`, `clear`, `compact`).

> Implementation detail: matchers are treated as regex-like selectors in configuration; your builder should present them as **Tool / Event Filters** with both a **simple picker** and an **advanced regex** mode.

### Hook action
What runs when a hook matches:
- **Command action**: execute a local script/command.
- **Prompt action**: evaluate an LLM prompt (with `$ARGUMENTS` placeholder in plugins).
- **Agent action** (plugins): run an “agentic verifier” with tools for complex verification tasks.

### Hook input payload
JSON provided to the hook via stdin with common fields (session info) + event-specific fields.

### Hook output
How the hook returns control/feedback:
- **Exit code + stdout/stderr**
- **Structured JSON on stdout** (only processed when exit code is `0`)

### Plugin
A distributable package that can bundle hooks (and other components like skills, MCP servers, etc.). Hooks live at `hooks/hooks.json` (or inline in plugin config) and share the same overall structure.

---

## 1) Mental model (what the visual builder is “doing”)

1. A **Hook Event** fires.
2. The runtime forms a **Hook Input** JSON payload.
3. The runtime selects **matching hook groups** by matcher.
4. **All matched hooks execute in parallel** (unless your product deliberately serializes; default should mirror CLI behavior).
5. Each hook returns output; the runtime merges/apply output according to event-specific rules (decision control, context injection, etc.).

Your builder therefore needs to help users:
- pick the **event**
- define **filters/matchers**
- add **actions**
- define **decision control / transformations** (when supported)
- test/trace the workflow and view an **execution trace**

---

## 2) Hook configuration (what your builder compiles to)

### 2.1 Canonical structure (conceptual)
```json
{
  "hooks": {
    "<HookEventName>": [
      {
        "matcher": "<optional matcher>",
        "hooks": [
          { "type": "command", "command": "/path/to/script.sh" }
        ]
      }
    ]
  }
}
```

### 2.2 Environment variables you must model in tooltips
- `CLAUDE_PROJECT_DIR`: project directory path; useful for project-relative scripts.
- `CLAUDE_PLUGIN_ROOT`: plugin root path; used for plugin-relative scripts like `${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh`.
- `CLAUDE_ENV_FILE`: **SessionStart-only** env file path where a hook can persist environment variables for later bash commands.

> Your builder should show these as “Available variables” in a tooltip for any **Command** node, and enforce `CLAUDE_ENV_FILE` visibility only on `SessionStart` flows.

---

## 3) Hook input payloads (event-by-event)

All hook inputs share common fields:

- `session_id`: string
- `transcript_path`: string (path to conversation json/jsonl)
- `cwd`: string (current working directory)
- `permission_mode`: string (e.g., `default`, `plan`, `acceptEdits`, `dontAsk`, `bypassPermissions`)
- `hook_event_name`: string (the event name)

### Important version drift note
Official docs disagree slightly across surfaces (CLI docs vs SDK types) on a few fields (e.g., notification fields, tool use id). **Your schema should accept a superset**, treating those “extra” fields as optional.

---

## 4) Hook output (how your nodes should map to runtime behavior)

### 4.1 Exit code (simple mode)
- `0`: success; stdout is shown only in verbose mode, **except**:
  - `UserPromptSubmit` and `SessionStart`: stdout is injected into context.
- `2`: blocking error; behavior varies per event (see below).
- other non-zero: non-blocking error; continues execution.

### 4.2 Structured JSON output (advanced mode)
Only processed when exit code is `0`.

Common JSON fields (any event):
```json
{
  "continue": true,
  "stopReason": "string",
  "suppressOutput": false,
  "systemMessage": "string"
}
```

Event-specific structured output lives in `hookSpecificOutput`.

---

## 5) Hooks: complete per-event specification (with suggested tooltips)

Below is what your builder should show for **each hook event**:

- **What triggers it**
- **Recommended use**
- **Input payload fields**
- **Supported decision control (if any)**
- **Builder tooltip text** (short + long)

### 5.1 `PreToolUse`
**Trigger:** After tool parameters are created but before the tool executes.

**Common matcher values:** `Task`, `Bash`, `Glob`, `Grep`, `Read`, `Edit`, `Write`, `WebFetch`, `WebSearch`.

**Input (minimum):**
- `tool_name`: string
- `tool_input`: object (tool-dependent)
- (CLI docs also show) `tool_use_id`: string (optional)

**Decision control (structured JSON):**
- `permissionDecision`: `allow | deny | ask`
- `permissionDecisionReason`: string
- Optional `updatedInput` to modify tool input (most useful with `allow`)

**Tooltip (short):** “Intercept tool calls before they run; allow/deny/ask or rewrite tool input.”  
**Tooltip (long):** “Runs after Claude drafts the tool arguments but before execution. Use it to enforce guardrails, rewrite risky commands, or auto-approve safe operations.”

---

### 5.2 `PermissionRequest`
**Trigger:** When a permission dialog is shown to the user.

**Matcher:** same tool-name matchers as `PreToolUse`.

**Input (minimum):**
- `tool_name`: string
- `tool_input`: object
- `permission_suggestions?`: array (SDK surface)

**Decision control (structured JSON):**
- `decision.behavior`: `allow | deny`
- Optional `updatedInput` (when allowing)
- Optional `message` + `interrupt` (when denying) — message explains the denial to the model; interrupt can stop Claude

**Tooltip (short):** “Auto-respond to permission dialogs; allow/deny on behalf of the user.”  
**Tooltip (long):** “Use when you want hands-free operation with policy. Pair with PreToolUse: pre-screen the call, then auto-accept the dialog.”

---

### 5.3 `PostToolUse`
**Trigger:** Immediately after a tool completes successfully.

**Matcher:** same tool-name matchers as `PreToolUse`.

**Input (minimum):**
- `tool_name`: string
- `tool_input`: object
- `tool_response`: object
- (CLI docs also show) `tool_use_id`: string (optional)

**Decision control:**
- `decision: "block"` + `reason` will automatically prompt Claude with the reason.
- `hookSpecificOutput.additionalContext` adds context for Claude to consider.

**Tooltip (short):** “Run after a tool succeeds: validate, annotate, lint, or add context.”  
**Tooltip (long):** “Use as a verifier. If output violates policy, return decision=block with a reason to force corrective action.”

---

### 5.4 `PostToolUseFailure` (extended event; present in Plugins + SDK)
**Trigger:** After a tool execution fails.

**Matcher:** tool-name matchers as above.

**Input (SDK):**
- `tool_name`: string
- `tool_input`: object
- `error`: string
- `is_interrupt?`: boolean

**Decision control (recommended):**
- Treat like a “failure-handling” verifier: add context, notify, or force continuation stop via `continue=false`.

**Tooltip (short):** “Handle failed tool runs: alert, retry policy, or capture error context.”  
**Tooltip (long):** “Best for improving reliability: on failures, log structured traces and nudge Claude toward recovery paths.”

---

### 5.5 `Notification`
**Trigger:** When the CLI sends a notification.

**Matcher:** notification types such as:
- `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog`

**Input (CLI docs):**
- `message`: string
- `notification_type`: string

**Input (SDK surface):**
- `message`: string
- `title?`: string

**Decision control:** none (don’t block execution; use for side effects like alerts).

**Tooltip (short):** “React to UI/runtime notifications (idle, permission prompt, auth success).”  
**Tooltip (long):** “Use for ‘out-of-band’ automation: desktop notifications, Slack pings, or sound/vibration.”

---

### 5.6 `UserPromptSubmit`
**Trigger:** When the user submits a prompt, before the model processes it.

**Input:**
- `prompt`: string

**Decision control:**
- **Inject context** (exit code 0): either plain stdout text OR JSON `additionalContext`
- **Block prompt**: `decision="block"` with `reason` (prompt erased from context)

**Tooltip (short):** “Validate or enrich user prompts before they run.”  
**Tooltip (long):** “Add project state, enforce prompt hygiene, or prevent sensitive requests. Use blocking sparingly: it removes the prompt from context.”

---

### 5.7 `Stop`
**Trigger:** When the main agent has finished responding (does not run on user interrupt).

**Input:**
- `stop_hook_active`: boolean (true if already continuing due to a stop hook)

**Decision control:**
- `decision="block"` with `reason` prevents stopping and forces continued work.

**Tooltip (short):** “Stop gate: prevent stopping until criteria are satisfied.”  
**Tooltip (long):** “Use as a ‘definition of done’ enforcer: run tests, check diffs, verify formatting. Beware infinite loops—respect stop_hook_active.”

---

### 5.8 `SubagentStart` (extended event; present in Plugins + SDK)
**Trigger:** When a subagent is started.

**Input (SDK):**
- `agent_id`: string
- `agent_type`: string

**Decision control:** treat as context injector or policy setter for subagent work.

**Tooltip (short):** “Subagent boot hook: set context/policy before delegated work begins.”  
**Tooltip (long):** “Great for multi-agent coordination: inject guardrails, repo scope, or task-specific conventions.”

---

### 5.9 `SubagentStop`
**Trigger:** When a subagent attempts to stop (after finishing its response).

**Input:**
- `stop_hook_active`: boolean

**Decision control:**
- `decision="block"` with `reason` prevents stopping (subagent continues)

**Tooltip (short):** “Stop gate for subagents.”  
**Tooltip (long):** “Enforce tests/verification inside delegated tasks. Guard against endless retries via stop_hook_active.”

---

### 5.10 `PreCompact`
**Trigger:** Before the runtime compacts conversation history.

**Matcher:** `manual` (invoked by `/compact`) or `auto` (context full).

**Input:**
- `trigger`: `manual | auto`
- `custom_instructions`: string (manual) or empty (auto)

**Decision control:** none (use for logging, exporting summaries, etc.).

**Tooltip (short):** “Before history compaction: export/annotate context.”  
**Tooltip (long):** “Use to snapshot state, write summaries to disk, or tag the transcript for later retrieval.”

---

### 5.11 `SessionStart`
**Trigger:** When a new session starts or an existing session is resumed.

**Matcher / source:** `startup | resume | clear | compact`.

**Input:**
- `source`: string (above)

**Decision control:**
- `hookSpecificOutput.additionalContext` injects context.
- Can write env exports to `CLAUDE_ENV_FILE` (SessionStart only).

**Tooltip (short):** “Session bootstrap: load context, set env, prepare workspace.”  
**Tooltip (long):** “Ideal for auto-installing deps, reading issues/PRs, loading a repo map, and persisting environment variables for later bash tools.”

---

### 5.12 `SessionEnd`
**Trigger:** When the session ends.

**Input:**
- `reason`: exit reason (e.g., clear/logout/prompt_input_exit/other; SDK uses an ExitReason enum)

**Decision control:** cannot block termination; use for cleanup/logging.

**Tooltip (short):** “Session teardown: cleanup and write logs.”  
**Tooltip (long):** “Use to flush traces, upload telemetry, or snapshot workspace state.”

---

## 6) Example compositions: how hooks combine into “plugins”

### Example plugin A — “Autofmt + Lint Gate”
**Goal:** Always format after edits, and refuse to stop until lint passes.

**Hook graph:**
1. `PreToolUse (Write|Edit)` → rewrite risky edits or auto-approve safe edits (`updatedInput`)
2. `PostToolUse (Write|Edit)` → run formatter, then add `additionalContext` if changes were made
3. `Stop` → run lint/tests; if failing, `decision="block"` with next-step reason

**Plugin layout:**
```
my-plugin/
  plugin.json
  hooks/hooks.json
  scripts/format.sh
  scripts/lint.sh
```

**hooks/hooks.json (sketch):**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/lint.sh" }]
      }
    ]
  }
}
```

---

### Example plugin B — “Secrets Sentinel”
**Goal:** Prevent accidental secret exfiltration and block risky shell commands.

**Hook graph:**
- `UserPromptSubmit` → block prompts that request secret disclosure; inject policy reminders for borderline prompts
- `PreToolUse (Bash)` → deny if command resembles secret dumping (`cat ~/.ssh`, `printenv`, etc.)
- `PostToolUse (Write)` → scan diffs for secret patterns; if found, `decision="block"` with remediation steps
- `Notification (permission_prompt)` → send a desktop/slack alert when a sensitive permission prompt occurs

---

### Example plugin C — “Subagent Governance”
**Goal:** Multi-agent workflows must comply with repo conventions and never skip tests.

**Hook graph:**
- `SubagentStart` → inject context: “Allowed directories”, “Definition of Done”, “Preferred commands”
- `SubagentStop` → block stopping until evidence is present in transcript (tests run, etc.)
- `PostToolUseFailure` → on subagent tool failures, log a structured error bundle

---

## 7) Appendix A — Visual Builder UX spec (overlay inside Settings)

### A.1 Entry point
- Settings screen contains a primary button: **Open visual builder**
- Clicking opens a full-height **overlay** (sheet) on top of Settings.
- Closing overlay returns to Settings without navigating away.

### A.2 Overlay layout
- Left: **Node palette** (Events, Filters, Actions, Utilities)
- Center: **Canvas** (pan/zoom, grid)
- Right: **Inspector panel** (selected node properties + tooltips + validation)
- Top bar: “Back”, “Save”, “Discard”, “Test run”, “Export”

### A.3 States & transitions
1. **Idle (saved)** → no unsaved changes
2. **Dirty** → changes exist (shows dot on title + Save enabled)
3. **Validating** → runs schema + semantic validation
4. **Error** → validation errors exist (Save disabled; click errors to focus nodes)
5. **Saving** → persist graph + compiled artifacts
6. **Saved** → success toast
7. **Discard confirm** → appears if Dirty and user hits Back/close

### A.4 Save/Discard flows
- **Save**:
  - Validate → if OK, compile graph → write outputs:
    1) `graph.json` (source-of-truth)
    2) `hooks.json` (compiled)
    3) any generated scripts (optional stubs)
- **Discard**:
  - Revert to last saved `graph.json`
- **Back/close**:
  - If Dirty → modal: “Save changes?”, actions: Save / Discard / Cancel

### A.5 Tooltips requirement (non-negotiable)
Every interactive UI element must have:
- **Hover tooltip** (1–2 sentences)
- “Learn more” expansion in Inspector (long form)
- “Examples” (at least 1) for nodes that can block/allow/transform

### A.6 Keyboard shortcuts
- Canvas navigation: `Space+Drag` pan, `Cmd/Ctrl+Scroll` zoom
- Node ops: `Cmd/Ctrl+C/V` copy/paste, `Delete` remove
- Quick add: `A` open palette search, `Enter` place selected node
- Save: `Cmd/Ctrl+S`
- Test run: `Cmd/Ctrl+Enter`
- Undo/redo: `Cmd/Ctrl+Z`, `Cmd/Ctrl+Shift+Z`
- Focus inspector: `Cmd/Ctrl+I`
- Toggle minimap: `M`

---

## 8) Appendix B — Node taxonomy (what nodes exist in your builder)

### B.1 Event nodes (triggers)
One per hook event:
- Tool lifecycle: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`
- Prompt lifecycle: `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`
- Session lifecycle: `SessionStart`, `SessionEnd`, `PreCompact`
- UI notifications: `Notification`

### B.2 Filter nodes
- **Matcher** (regex / picker): tool names, notification types, compact triggers, session sources
- **Predicate** (optional): JSONPath-like condition over input payload (advanced)

### B.3 Action nodes
- **Command**: runs a script/command
- **Prompt**: runs an LLM prompt (plugin-only, or for your own runtime)
- **Agent**: runs an agentic verifier (plugin-only in official plugin ref)

### B.4 Control nodes
- **Decision (Allow/Deny/Ask)** for `PreToolUse`
- **Permission Decision** for `PermissionRequest`
- **Block w/ Reason** for `Stop/SubagentStop` and other “blockable” decisions
- **Continue/Stop** (`continue=false` with `stopReason`) as a global hard stop

### B.5 Transformation nodes
- **Updated Input**: constructs `updatedInput` object
- **Additional Context**: constructs `additionalContext` string
- **System Message**: sets `systemMessage`

### B.6 Utility nodes
- **Logger**: write structured logs
- **Export Trace**: persist execution traces
- **Rate limit / Debounce**: for noisy notifications and prompt submit

---

## 9) Appendix C — JSON schema for representing the graph (nodes, ports, edges, validation, execution trace)

> This schema is for **your product**. It is intentionally explicit and versioned to tolerate upstream drift.

### C.1 Graph model (high-level)
- `graph`: metadata + arrays of `nodes` and `edges`
- `node`: typed object with `inputs`, `outputs`, and `config`
- `edge`: connects `from.nodeId:portId` → `to.nodeId:portId`
- `validation`: stored results with node pointers
- `executionTrace`: per-run events, timings, and outputs

### C.2 JSON Schema (Draft 2020-12)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://example.com/schemas/visual-hook-graph.schema.json",
  "title": "Visual Hook Graph",
  "type": "object",
  "required": ["version", "graphId", "nodes", "edges"],
  "properties": {
    "version": { "type": "string", "pattern": "^v\\d+\\.\\d+\\.\\d+$" },
    "graphId": { "type": "string" },
    "name": { "type": "string" },
    "description": { "type": "string" },
    "createdAt": { "type": "string", "format": "date-time" },
    "updatedAt": { "type": "string", "format": "date-time" },

    "nodes": {
      "type": "array",
      "items": { "$ref": "#/$defs/node" }
    },
    "edges": {
      "type": "array",
      "items": { "$ref": "#/$defs/edge" }
    },

    "validation": { "$ref": "#/$defs/validationReport" },
    "executionTraces": {
      "type": "array",
      "items": { "$ref": "#/$defs/executionTrace" }
    }
  },
  "$defs": {
    "hookEventName": {
      "type": "string",
      "enum": [
        "PreToolUse",
        "PostToolUse",
        "PostToolUseFailure",
        "PermissionRequest",
        "UserPromptSubmit",
        "Notification",
        "Stop",
        "SubagentStart",
        "SubagentStop",
        "PreCompact",
        "SessionStart",
        "SessionEnd"
      ]
    },

    "node": {
      "type": "object",
      "required": ["id", "type", "position", "ports", "config"],
      "properties": {
        "id": { "type": "string" },
        "type": { "type": "string" },
        "label": { "type": "string" },
        "position": {
          "type": "object",
          "required": ["x", "y"],
          "properties": {
            "x": { "type": "number" },
            "y": { "type": "number" }
          }
        },
        "ports": {
          "type": "array",
          "items": { "$ref": "#/$defs/port" }
        },
        "config": { "type": "object" },
        "ui": {
          "type": "object",
          "properties": {
            "collapsed": { "type": "boolean" },
            "color": { "type": "string" },
            "icon": { "type": "string" }
          },
          "additionalProperties": true
        }
      },
      "additionalProperties": false
    },

    "port": {
      "type": "object",
      "required": ["id", "direction", "dataType"],
      "properties": {
        "id": { "type": "string" },
        "direction": { "type": "string", "enum": ["in", "out"] },
        "name": { "type": "string" },
        "dataType": { "type": "string" },
        "required": { "type": "boolean" }
      },
      "additionalProperties": false
    },

    "edge": {
      "type": "object",
      "required": ["id", "from", "to"],
      "properties": {
        "id": { "type": "string" },
        "from": {
          "type": "object",
          "required": ["nodeId", "portId"],
          "properties": {
            "nodeId": { "type": "string" },
            "portId": { "type": "string" }
          }
        },
        "to": {
          "type": "object",
          "required": ["nodeId", "portId"],
          "properties": {
            "nodeId": { "type": "string" },
            "portId": { "type": "string" }
          }
        },
        "enabled": { "type": "boolean", "default": true }
      },
      "additionalProperties": false
    },

    "validationReport": {
      "type": "object",
      "properties": {
        "status": { "type": "string", "enum": ["ok", "warning", "error"] },
        "issues": {
          "type": "array",
          "items": { "$ref": "#/$defs/validationIssue" }
        }
      },
      "additionalProperties": false
    },

    "validationIssue": {
      "type": "object",
      "required": ["severity", "message", "nodeId"],
      "properties": {
        "severity": { "type": "string", "enum": ["warning", "error"] },
        "message": { "type": "string" },
        "nodeId": { "type": "string" },
        "portId": { "type": "string" },
        "code": { "type": "string" },
        "help": { "type": "string" }
      },
      "additionalProperties": false
    },

    "executionTrace": {
      "type": "object",
      "required": ["traceId", "startedAt", "event", "nodeRuns"],
      "properties": {
        "traceId": { "type": "string" },
        "startedAt": { "type": "string", "format": "date-time" },
        "endedAt": { "type": "string", "format": "date-time" },
        "event": {
          "type": "object",
          "required": ["hook_event_name", "input"],
          "properties": {
            "hook_event_name": { "$ref": "#/$defs/hookEventName" },
            "input": { "type": "object" }
          },
          "additionalProperties": false
        },
        "nodeRuns": {
          "type": "array",
          "items": { "$ref": "#/$defs/nodeRun" }
        },
        "finalHookOutputs": {
          "type": "array",
          "items": { "type": "object" }
        }
      },
      "additionalProperties": false
    },

    "nodeRun": {
      "type": "object",
      "required": ["nodeId", "status", "startedAt"],
      "properties": {
        "nodeId": { "type": "string" },
        "status": { "type": "string", "enum": ["success", "error", "skipped"] },
        "startedAt": { "type": "string", "format": "date-time" },
        "endedAt": { "type": "string", "format": "date-time" },
        "input": { "type": "object" },
        "output": { "type": "object" },
        "logs": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["ts", "level", "msg"],
            "properties": {
              "ts": { "type": "string", "format": "date-time" },
              "level": { "type": "string", "enum": ["debug", "info", "warn", "error"] },
              "msg": { "type": "string" },
              "data": { "type": "object" }
            }
          }
        }
      },
      "additionalProperties": false
    }
  }
}
```

### C.3 Semantic validation (beyond JSON Schema)
Your validator should also enforce:
- **Event-node uniqueness**: at least one event node; optionally only one per graph.
- **Decision compatibility**:
  - `UpdatedInput` nodes only permitted under `PreToolUse` and `PermissionRequest` when behavior/permissionDecision is allow.
  - `Stop gate` decisions only valid under `Stop` and `SubagentStop`.
- **Loop safety**:
  - For `Stop/SubagentStop`, ensure a loop breaker is present (e.g., “max retries” guard or `stop_hook_active` check).
- **Parallel merge rules**:
  - If multiple nodes produce conflicting decisions, apply precedence:
    1) `continue=false` wins globally
    2) explicit `deny` beats `allow`
    3) `ask` beats `allow` when both present
    4) for `PostToolUse`, any `decision=block` forces remediation

---

## 10) Sources (official docs you should mirror)
- Hooks reference (CLI): https://code.claude.com/docs/en/hooks
- Plugins reference: https://code.claude.com/docs/en/plugins-reference
- Agent SDK (TypeScript) hook input/output types: https://platform.claude.com/docs/en/agent-sdk/typescript

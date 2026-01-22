# Claude Agent SDK vs CLI: Complete Comparison

> Research date: 2026-01-03
> Context: Evaluating Agent SDK for Blaze app to resolve AskUserQuestion limitation

## Executive Summary

The **Claude Agent SDK** (TypeScript/Python) provides programmatic access to the same capabilities as Claude Code CLI, but with native callbacks for interactive tools like `AskUserQuestion`. Our current CLI-based implementation cannot support AskUserQuestion because the headless CLI auto-denies interactive prompts before reading stdin.

**Key finding**: Agent SDK enables AskUserQuestion via `canUseTool` callback, but **does NOT officially support Claude Max subscription** - it requires API key billing.

---

## Table of Contents

1. [Authentication: Max Subscription vs API Key](#1-authentication-max-subscription-vs-api-key)
2. [User Experience Differences](#2-user-experience-differences)
3. [Feature Set Comparison](#3-feature-set-comparison)
4. [Implementation Complexity](#4-implementation-complexity)
5. [Our Current Gap](#5-our-current-gap)
6. [Recommendation](#6-recommendation)
7. [Sources](#7-sources)

---

## 1. Authentication: Max Subscription vs API Key

### Official Position

**The Agent SDK supports Max subscription for personal/internal use, but third-party products require API billing.**

From [Claude Support](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan):
> "With Pro and Max plans, you now have access to both Claude on the web, desktop, and mobile apps and Claude Code in your terminal with one unified subscription."

However, for **third-party products**, from [Anthropic's SDK documentation](https://platform.claude.com/docs/en/agent-sdk/overview):
> "Unless previously approved, we do not allow third party developers to offer Claude.ai login or rate limits for their products, including agents built on the Claude Agent SDK."

### Authentication Methods

| Method | CLI (Interactive) | CLI (Headless `-p`) | Agent SDK |
|--------|-------------------|---------------------|-----------|
| Claude Max/Pro OAuth | ✅ Native | ✅ Via saved auth | ✅ Personal use* |
| API Key (`ANTHROPIC_API_KEY`) | ✅ | ✅ | ✅ |
| Bedrock | ✅ | ✅ | ✅ |
| Vertex AI | ✅ | ✅ | ✅ |
| Foundry | ✅ | ✅ | ✅ |

*SDK supports Max subscription for personal/internal apps. Third-party products must use API billing.

### Workaround (Unsupported)

Some users have found that `CLAUDE_CODE_OAUTH_TOKEN` works with the SDK:

```bash
# Generate long-lived token
claude setup-token

# Use in SDK (UNSUPPORTED - may break)
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
```

**Caveats:**
- Not officially supported - may break at any time
- Anthropic explicitly prohibits third-party apps using Max subscription rates
- Token expires and requires refresh (~6 hours for standard credentials)
- Mixing `ANTHROPIC_API_KEY` and `CLAUDE_CODE_OAUTH_TOKEN` causes conflicts

**Source:** [GitHub Issue #11](https://github.com/anthropics/claude-agent-sdk-typescript/issues/11), [GitHub Issue #6536](https://github.com/anthropics/claude-code/issues/6536)

### Cost Implications

| Plan | Monthly Cost | Usage Model |
|------|--------------|-------------|
| Claude Max 20x | $200/month | ~200-800 prompts per 5 hours (shared with web/mobile) |
| Claude Max 5x | $100/month | ~50-200 prompts per 5 hours |
| API Key (Opus 4.5) | Pay-as-you-go | $5/MTok input, $25/MTok output |
| API Key (Sonnet 4.5) | Pay-as-you-go | $3-6/MTok input, $15-22.50/MTok output |

**Note:** API pricing is for current Opus 4.5/Sonnet 4.5 models (as of Jan 2026). Legacy Opus 4.1 was $15/$75 MTok.

---

## 2. User Experience Differences

### AskUserQuestion Handling

| Aspect | Current CLI Implementation | Agent SDK Implementation |
|--------|---------------------------|--------------------------|
| **Interactive prompts** | ❌ Auto-denied immediately in headless mode | ✅ Native `canUseTool` callback handles questions |
| **UI flow** | ToolPromptCard appears but Submit fails (EPIPE) | Callback receives `input.questions`, returns `updatedInput.answers` |
| **Multi-select questions** | ❌ Cannot function | ✅ Fully supported (comma-separated answers) |
| **Custom UI** | N/A | ✅ Full control - can render SwiftUI, web forms, etc. |
| **Response timing** | CLI doesn't wait for stdin | SDK waits for callback Promise/async return |

### Session Management

| Aspect | CLI Headless | Agent SDK |
|--------|--------------|-----------|
| **Continue most recent** | ✅ `--continue` flag | ✅ `continue: true` option |
| **Resume by session ID** | ✅ `--resume <session_id>` | ✅ `resume: sessionId` option |
| **Session forking** | ❌ Not available | ✅ `forkSession: true` to branch |
| **Resume at specific message** | ❌ Not available | ✅ `resumeSessionAt: messageUuid` |
| **Session lifecycle hooks** | Shell scripts only | ✅ Native `SessionStart`, `SessionEnd` callbacks |

**CLI session continuity example:**
```bash
# Continue most recent conversation
claude -p "Review this codebase" --output-format stream-json
claude -p "Now focus on the database queries" --continue

# Resume specific session by ID
session_id=$(claude -p "Start a review" --output-format json | jq -r '.session_id')
claude -p "Continue that review" --resume "$session_id"
```

### Permission Control

| Aspect | Current CLI | Agent SDK |
|--------|-------------|-----------|
| **Runtime approval** | `--allowedTools` only (static) | `canUseTool` callback (dynamic, per-request) |
| **Modified inputs** | ❌ Cannot modify tool inputs | ✅ Return `updatedInput` to change parameters |
| **Permission suggestions** | ❌ N/A | ✅ Receive `suggestions` array for "always allow" |
| **Granular Bash** | `Bash(git:*)` pattern | Same + callback inspection |
| **Dynamic mode changes** | ❌ Set at start only | ✅ `setPermissionMode()` during streaming |

### Real-time Streaming

| Aspect | Current CLI | Agent SDK |
|--------|-------------|-----------|
| **Message types** | NDJSON parsing required | Native typed objects (`SDKMessage` union) |
| **Partial messages** | ❌ Not available in `stream-json` | ✅ `includePartialMessages: true` |
| **Streaming input** | ❌ Single prompt only | ✅ `AsyncIterable<SDKUserMessage>` |
| **Interruption** | SIGINT to process | ✅ `query.interrupt()` method |

### Error Handling & Recovery

| Aspect | Current CLI | Agent SDK |
|--------|-------------|-----------|
| **Structured errors** | Parse from stderr | Typed error objects |
| **File checkpointing** | ❌ N/A | ✅ `enableFileCheckpointing` + `rewindFiles()` |
| **Budget limits** | ❌ N/A | ✅ `maxBudgetUsd`, `maxTurns` options |
| **Graceful degradation** | ❌ N/A | ✅ `fallbackModel` option |

### Subagents

| Aspect | Current CLI | Agent SDK |
|--------|-------------|-----------|
| **Custom agents** | ❌ CLI doesn't support programmatic definition | ✅ `agents: { "my-agent": AgentDefinition }` |
| **Agent tracking** | ❌ N/A | ✅ `parent_tool_use_id` in messages |
| **Agent lifecycle** | ❌ N/A | ✅ `SubagentStart`, `SubagentStop` hooks |

### UI Feedback

| Aspect | Current CLI | Agent SDK |
|--------|-------------|-----------|
| **Progress updates** | Parse tool_use events | Same + typed objects |
| **Cost tracking** | Manual calculation | ✅ `total_cost_usd`, `modelUsage` in result |
| **Token usage** | Manual extraction | ✅ Structured `usage` object |
| **Permission denials** | Parse from result | ✅ `permission_denials[]` array |

---

## 3. Feature Set Comparison

### Core Capabilities

| Feature | CLI (Terminal) | CLI (Headless `-p`) | Agent SDK |
|---------|---------------|---------------------|-----------|
| Interactive conversation | ✅ Full | ✅ Via `--continue`/`--resume` | ✅ Streaming input |
| Slash commands (`/commit`) | ✅ Works | ❌ Not supported | ✅ Via hooks/plugins |
| CLAUDE.md loading | ✅ Automatic | ✅ With settings | ✅ `settingSources: ['project']` |
| MCP servers | ✅ From config | ✅ From config | ✅ Programmatic + config |
| Hooks | ✅ Shell commands | ✅ Shell commands | ✅ **Native callbacks** |
| Web search | ✅ | ✅ | ✅ |
| WebFetch | ✅ | ✅ | ✅ |

### Tool Availability

| Tool | CLI Terminal | CLI Headless | Agent SDK |
|------|--------------|--------------|-----------|
| Read, Write, Edit | ✅ | ✅ | ✅ |
| Bash | ✅ | ✅ (allowedTools) | ✅ |
| Glob, Grep | ✅ | ✅ | ✅ |
| WebSearch, WebFetch | ✅ | ✅ | ✅ |
| TodoWrite | ✅ | ✅ | ✅ |
| Task (subagents) | ✅ | ✅ | ✅ |
| **AskUserQuestion** | ✅ Interactive | ❌ **Auto-denied** | ✅ **canUseTool** |
| NotebookEdit | ✅ | ✅ | ✅ |
| ExitPlanMode | ✅ | ✅ | ✅ |
| MCP tools | ✅ | ✅ | ✅ |

### Advanced Configuration

| Feature | CLI | Agent SDK |
|---------|-----|-----------|
| **Sandbox mode** | ✅ `-sb` flag, `/sandbox` | ✅ `sandbox: SandboxSettings` |
| **Network restrictions** | ✅ Via sandbox config | ✅ `NetworkSandboxSettings` |
| **Excluded commands** | ✅ Via sandbox config | ✅ `excludedCommands[]` |
| **Unix socket access** | ✅ Via sandbox config | ✅ `allowUnixSockets[]` |
| **Structured output** | ✅ `--json-schema` | ✅ `outputFormat: { type: 'json_schema' }` |
| **Beta features** | ❌ | ✅ `betas: ['context-1m-2025-08-07']` |
| **Custom system prompt** | ✅ `--system-prompt` | ✅ `systemPrompt` option |
| **Tool presets** | ❌ | ✅ `tools: { type: 'preset', preset: 'claude_code' }` |

### Hook System Comparison

| Hook Event | CLI Hooks | SDK Hooks |
|------------|-----------|-----------|
| PreToolUse | ✅ Shell script | ✅ **Async callback** |
| PostToolUse | ✅ Shell script | ✅ **Async callback** |
| PostToolUseFailure | ✅ | ✅ |
| UserPromptSubmit | ✅ | ✅ |
| SessionStart | ✅ | ✅ |
| SessionEnd | ✅ | ✅ |
| Stop | ✅ | ✅ |
| SubagentStart | ✅ | ✅ |
| SubagentStop | ✅ | ✅ |
| PreCompact | ✅ | ✅ |
| **PermissionRequest** | ❌ Limited | ✅ **Full control** |
| **Notification** | ✅ | ✅ |

### Output & Debugging

| Feature | CLI | Agent SDK |
|---------|-----|-----------|
| **Result format** | `text`, `json`, `stream-json` | Native typed objects |
| **Partial streaming** | ❌ | ✅ `includePartialMessages` |
| **stderr callback** | ❌ | ✅ `stderr: (data) => {}` |
| **Account info** | ❌ | ✅ `query.accountInfo()` |
| **MCP status** | ❌ | ✅ `query.mcpServerStatus()` |
| **Model info** | ❌ | ✅ `query.supportedModels()` |
| **Compact boundaries** | ❌ | ✅ `SDKCompactBoundaryMessage` |

---

## 4. Implementation Complexity

### Architecture Comparison

| Aspect | CLI Approach (Current) | SDK Approach |
|--------|------------------------|--------------|
| **Language** | Spawn process (Swift → `claude`) | Embed runtime (Swift → Node.js/Python → SDK) |
| **Binary dependency** | `claude` CLI only | `claude` CLI + SDK package + Node.js/Python |
| **Process model** | Child process management | Subprocess with IPC or FFI |
| **Memory isolation** | Separate process | Shared via bridge |
| **Error boundaries** | Process exit codes | Exception handling across boundary |
| **Startup time** | Process spawn (~100ms) | Runtime initialization (~500ms+) |

### Swift Integration Options

| Approach | Complexity | Performance | Maintenance |
|----------|------------|-------------|-------------|
| **Embed Node.js** | High | Good | Medium |
| **Spawn Python subprocess** | Medium | Good | Low |
| **Swift-Python bridge (PythonKit)** | High | Best | High |
| **HTTP bridge (local server)** | Medium | Overhead | Low |
| **Keep CLI + accept limitation** | None | Best | None |

### Estimated Effort

| Approach | Effort | Risk |
|----------|--------|------|
| Option A: Embed TypeScript SDK via Node.js subprocess | 2-3 weeks | Medium |
| Option B: Embed Python SDK via subprocess | 1-2 weeks | Low |
| Option C: HTTP bridge to Python/TS SDK server | 1 week | Low |
| Option D: Accept CLI limitation | 0 | None |

---

## 5. Our Current Gap

### What We Have

| Component | Status |
|-----------|--------|
| Spawn `claude -p` with PTY | ✅ Working |
| NDJSONParser for stream-json | ✅ Working |
| Session continuity (`--continue`/`--resume`) | ✅ Available (CLI native) |
| ToolPromptCard UI | ✅ Appears correctly |
| Chat message rendering | ✅ Working |
| File click handlers | ✅ Working |

### What's Broken

| Component | Issue |
|-----------|-------|
| AskUserQuestion Submit | ❌ EPIPE - CLI auto-denies before reading stdin |
| Interactive tool responses | ❌ CLI doesn't wait for stdin in headless mode |

### Root Cause

The Claude CLI in headless mode (`-p` flag) immediately auto-denies AskUserQuestion with an error tool_result:

```json
{"type":"user","content":"Answer questions?","is_error":true}
```

This happens before any stdin can be processed. The SDK solves this with the `canUseTool` callback which is invoked synchronously and awaited.

---

## 6. Recommendation

### Decision Matrix

| Option | Enables AskUserQuestion | Uses Max Sub | Complexity | Recommendation |
|--------|-------------------------|--------------|------------|----------------|
| **A: SDK via subprocess** | ✅ Yes | ✅ Yes (personal use) | Medium | ✅ **Best for Blaze** |
| **B: CLI + accept limitation** | ❌ No | ✅ Yes | None | ⚠️ Limits functionality |
| **C: New-turn workaround** | ⚠️ Partial | ✅ Yes | Low | ⚠️ Hacky but functional |

**Key insight from cross-validation:** SDK DOES support Max subscription for personal/internal apps like Blaze. The restriction only applies to third-party products distributed to others.

### Recommended Path

**For Blaze (personal/internal app):**

Since SDK supports Max subscription for personal use, the recommended path is:

1. **Implement SDK integration** via Python/TypeScript subprocess
2. Use `canUseTool` callback for AskUserQuestion handling
3. Authenticate with Max subscription (no API costs)
4. Enable `enableFileCheckpointing` for safety

**Implementation options (ranked):**

| Approach | Effort | Notes |
|----------|--------|-------|
| Python SDK subprocess | 1-2 weeks | Simplest, `pip install claude-agent-sdk` |
| HTTP bridge to SDK server | 1 week | Decoupled, easier debugging |
| TypeScript SDK via Node.js | 2-3 weeks | More complex Swift-Node bridge |

**If distributing Blaze to others:**

Third-party distribution requires API billing. In that case:
1. Users must provide their own `ANTHROPIC_API_KEY`
2. Add `maxBudgetUsd` option for cost control
3. Consider `fallbackModel` for reliability

---

## 7. Sources

### Official Documentation
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [TypeScript SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
- [Python SDK Reference](https://platform.claude.com/docs/en/agent-sdk/python)
- [Handling Permissions](https://platform.claude.com/docs/en/agent-sdk/permissions)
- [Headless Mode](https://code.claude.com/docs/en/headless)

### GitHub Issues
- [Claude Max Usage - Issue #11](https://github.com/anthropics/claude-agent-sdk-typescript/issues/11)
- [SDK OAuth Token Support - Issue #6536](https://github.com/anthropics/claude-code/issues/6536)

### Community Resources
- [claude_max Library](https://idsc2025.substack.com/p/how-i-built-claude_max-to-unlock) - Workaround for Max subscription
- [OAuth Demo](https://github.com/weidwonder/claude_agent_sdk_oauth_demo) - Community OAuth example

---

## Appendix: SDK Code Examples

### AskUserQuestion Handler (TypeScript)

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Help me configure the database",
  options: {
    canUseTool: async (toolName, input) => {
      if (toolName === "AskUserQuestion") {
        // Render UI, collect answers
        const answers = await showQuestionDialog(input.questions);

        return {
          behavior: "allow",
          updatedInput: {
            questions: input.questions,
            answers: answers // { "Which DB?": "PostgreSQL" }
          }
        };
      }
      return { behavior: "allow", updatedInput: input };
    }
  }
})) {
  console.log(message);
}
```

### Session Resume (Python)

```python
from claude_agent_sdk import query, ClaudeAgentOptions

# First turn
session_id = None
async for message in query(
    prompt="Analyze the codebase",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Glob"])
):
    if hasattr(message, 'subtype') and message.subtype == 'init':
        session_id = message.session_id

# Resume later
async for message in query(
    prompt="Now fix the bug we discussed",
    options=ClaudeAgentOptions(resume=session_id)
):
    print(message.result if hasattr(message, 'result') else '')
```

---

## Appendix A: Error Corrections (Cross-Validation Report)

> **Validation date:** 2026-01-03
> **Methodology:** Assumed all claims incorrect; sought evidence to disprove each claim against official documentation.

### Summary of Errors Found

| # | Original Claim | Verdict | Correction Required |
|---|----------------|---------|---------------------|
| 1 | SDK doesn't support Max subscription | **INCORRECT** | SDK supports Max/Pro for personal use |
| 2 | Opus pricing $15/$75 MTok | **INCORRECT** | Current Opus 4.5 is $5/$25 MTok |
| 3 | Sandbox is SDK-only | **INCORRECT** | CLI has `-sb` flag and `/sandbox` command |
| 4 | AskUserQuestion "auto-denied" | **PARTIALLY CORRECT** | More nuanced behavior |

---

### Error 1: SDK Max Subscription Support

**Original claim:**
> "The Agent SDK does NOT officially support Claude Max subscription authentication."

**Evidence found:**

From [Claude Support](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan):
> "With Pro and Max plans, you now have access to both Claude on the web, desktop, and mobile apps and Claude Code in your terminal with one unified subscription."

The Agent SDK uses Claude Code as its runtime, so Max subscription authentication works.

**Nuanced correction:**

The SDK documentation states:
> "Unless previously approved, we do not allow third party developers to offer Claude.ai login or rate limits for their products, including agents built on the Claude Agent SDK."

This means:
- **Personal/internal use with Max subscription:** ✅ Supported
- **Third-party products using Max subscription:** ❌ Prohibited without approval

**Corrected statement:**
> "The Agent SDK supports Max subscription for personal/internal use. Third-party products must use API key billing unless pre-approved by Anthropic."

---

### Error 2: API Pricing (Outdated)

**Original claim:**
> "~$15/MTok input, $75/MTok output (Opus)"

**Current pricing (from [claude.com/pricing](https://claude.com/pricing)):**

| Model | Input | Output |
|-------|-------|--------|
| **Opus 4.5** (current) | **$5/MTok** | **$25/MTok** |
| Opus 4.1 (legacy) | $15/MTok | $75/MTok |
| **Sonnet 4.5** | $3-6/MTok | $15-22.50/MTok |
| **Haiku 4.5** | $1/MTok | $5/MTok |

**Corrected statement:**
> "Current Opus 4.5 pricing: $5/MTok input, $25/MTok output (3x cheaper than legacy Opus 4.1)"

---

### Error 3: Sandbox Availability

**Original claim:**
> "Sandbox mode: ❌ CLI / ✅ SDK"

**Evidence found (from [code.claude.com/docs/en/sandboxing](https://code.claude.com/docs/en/sandboxing)):**

CLI sandbox features:
- `-sb` flag for command-line sandboxing
- `/sandbox` slash command for interactive mode
- Docker integration with automatic permission bypass
- Open source [sandbox-runtime npm package](https://github.com/anthropic-experimental/sandbox-runtime)

**Corrected statement:**
> "Sandbox mode is available in BOTH CLI and SDK. CLI uses `-sb` flag or `/sandbox` command. SDK uses `sandbox: SandboxSettings` option."

---

### Error 4: AskUserQuestion Behavior

**Original claim:**
> "CLI headless mode auto-denies AskUserQuestion immediately"

**Evidence found:**

The headless documentation states interactive prompts are "not available" rather than explicitly "auto-denied." Additionally, the CLI provides `--permission-prompt-tool` flag to specify an MCP tool for handling permission prompts in non-interactive mode.

**Open question:** What exactly happens when AskUserQuestion is invoked WITHOUT `--permission-prompt-tool`? Our testing showed auto-denial with "Answer questions?" error, but this may be configurable.

**Corrected statement:**
> "In headless mode, AskUserQuestion cannot receive terminal input. Without `--permission-prompt-tool`, it fails with an error. The SDK's `canUseTool` callback provides the proper handling mechanism."

---

### Verified Claims (No Errors)

The following claims were verified as correct:

| Claim | Source |
|-------|--------|
| `--continue` continues most recent | [CLI Reference](https://code.claude.com/docs/en/cli-reference) |
| `--resume <session_id>` works | [Headless docs](https://code.claude.com/docs/en/headless) |
| `forkSession: true` exists | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| `resumeSessionAt: messageUuid` exists | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| Permission modes (4 types) | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| `canUseTool` callback signature | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| `includePartialMessages` exists | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| `maxBudgetUsd` exists | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |
| `fallbackModel` exists | [TS SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) |

---

### Implications for Blaze

Given the corrections:

1. **Max subscription IS usable** with SDK for personal/internal apps like Blaze
2. **Cost analysis was wrong** - API costs are 3x lower than stated
3. **Sandbox works in CLI** - not a differentiator for SDK

**Revised decision matrix:**

| Option | Enables AskUserQuestion | Uses Max Sub | API Cost (Opus 4.5) |
|--------|-------------------------|--------------|---------------------|
| **CLI approach** | ❌ No | ✅ Yes | N/A (subscription) |
| **SDK + Max (personal)** | ✅ Yes | ✅ Yes | N/A (subscription) |
| **SDK + API key** | ✅ Yes | ❌ No | $5/$25 MTok |

---

  1. Interactive Prompts Auto-Denied in Headless Mode

  Based on the documentation, the tools that require user interaction and cannot function in headless CLI mode without special handling:

  | Tool               | What it does                          | Headless behavior                 |
  |--------------------|---------------------------------------|-----------------------------------|
  | AskUserQuestion    | Claude asks user clarifying questions | Auto-denied (returns error)       |
  | Permission prompts | "Allow Bash command X?"               | Auto-denied unless --allowedTools |
  | ExitPlanMode       | User approves/rejects plan            | Behavior unclear in headless      |

  SDK solution: All of these go through the canUseTool callback, where your code can handle them programmatically.

  ---
  2. Runtime Approval Differences (ELI5)

  CLI approach:
  "Here's a list of tools you're allowed to use. If it's not on the list, the answer is NO."

  You set --allowedTools "Read,Edit,Bash" at startup. Claude can only use those. If Claude wants to use something else mid-conversation, too bad.

  SDK approach:
  "Every time Claude wants to use a tool, ask me first. I'll decide right then."

  Your code gets called for EVERY tool request. You can:
  - Check what Claude wants to do
  - Ask the user "Is this OK?"
  - Say yes/no based on current context
  - Even CHANGE what Claude is about to do

  Why it matters: Imagine Claude wants to delete a file. With CLI, it's either always allowed or never allowed. With SDK, you can pop up a dialog: "Claude wants to delete important.txt. Allow?" and decide in the moment.

  ---
  3. Modified Tool Inputs (ELI5)

  What this means: With SDK, when Claude wants to use a tool, you can CHANGE what it's about to do before it happens.

  Example - AskUserQuestion:

  Claude sends:
  {
    "questions": [{"question": "Which database?", "options": [...]}]
  }

  Your SDK code can return:
  {
    "behavior": "allow",
    "updatedInput": {
      "questions": [...],
      "answers": {"Which database?": "PostgreSQL"}  // YOU added this!
    }
  }

  Why it matters (ELI5):
  CLI: "Claude asked a question. Too bad, no one's there to answer."
  SDK: "Claude asked a question. Let me show a popup, get the user's answer, and hand it back to Claude."

  Other examples where modification helps:
  - Sanitize file paths before Write operations
  - Add safety flags to Bash commands
  - Inject credentials into API calls
  - Redact sensitive info from searches

  ---
  4. NDJSON Parsing vs Native Typed Objects (ELI5)

  CLI (NDJSON parsing):
  Claude sends: {"type":"assistant","message":{"content":"Hello"}}
  Your code:    Parse JSON string → Check if valid → Check type field → Cast to right shape → Hope you didn't miss a field

  It's like getting a letter in an envelope. You have to:
  1. Open the envelope
  2. Read what's inside
  3. Figure out what kind of letter it is
  4. Hope you understand the format

  SDK (Native typed objects):
  for await (const message of query({...})) {
    if (message.type === "assistant") {
      console.log(message.message.content);  // TypeScript knows this exists!
    }
  }

  It's like getting a phone call where the person introduces themselves: "Hi, I'm an AssistantMessage with content 'Hello'."

  Why it matters:
  - Compile-time errors - SDK tells you if you use wrong field names BEFORE running
  - Autocomplete - Your editor shows you what fields exist
  - No parsing bugs - Can't accidentally parse JSON wrong
  - Cleaner code - No manual type checking

  ---
  5. File Checkpointing (ELI5)

  What it is: SDK takes "snapshots" of files before Claude edits them.

  Like this:
  1. Claude is about to edit auth.py
  2. SDK saves a copy: "auth.py at 2:30 PM"
  3. Claude edits the file
  4. Claude edits 5 more files
  5. Oh no, something broke!
  6. You call query.rewindFiles("message-uuid-from-2:30")
  7. All files go back to how they were at 2:30 PM

  Why it matters: It's an UNDO button for Claude's changes. If Claude makes a mess, you can roll back.

  Enable with: enableFileCheckpointing: true

  ---
  6. Graceful Degradation (ELI5)

  What it is: If Claude's brain (the model) is too busy, automatically use a simpler brain instead.

  Like this:
  options: {
    model: "opus",           // Try the smart model first
    fallbackModel: "sonnet"  // If Opus is overloaded, use Sonnet
  }

  Real-world analogy:
  "I want to talk to the senior doctor."
  "Sorry, Dr. Opus is in surgery."
  "OK, I'll talk to Dr. Sonnet instead."

  Why it matters: Your app doesn't crash or hang when Anthropic's servers are busy. It gracefully falls back to a model that's available.

  ---
  7. Partial Streaming, stderr Callback, Compact Boundaries (ELI5)

  Partial Streaming (includePartialMessages: true)

  Without it: You get complete sentences after Claude finishes thinking.

  With it: You get Claude's words AS they're being typed.

  Without: [wait 5 seconds] "Here's my complete analysis of the bug..."
  With:    "Here's" ... "my" ... "complete" ... "analysis" ... (typing indicator!)

  Why it matters: Makes your app feel responsive. Users see Claude "typing" instead of staring at a blank screen.

  ---
  stderr Callback (stderr: (data) => {})

  What it is: A way to see Claude's "thinking out loud" and error messages.

  Like this:
  options: {
    stderr: (data) => {
      console.log("Claude's internal log:", data);
      // Shows things like: "Searching 1,523 files..."
    }
  }

  Why it matters: Debugging! If something goes wrong, you can see what Claude was doing internally.

  ---
  Compact Boundaries (SDKCompactBoundaryMessage)

  What it is: SDK tells you when Claude's memory got compressed.

  Context: Claude has limited memory (context window). When it fills up, old stuff gets summarized/compressed.

  The message:
  {
    "type": "system",
    "subtype": "compact_boundary",
    "compact_metadata": {
      "trigger": "auto",
      "pre_tokens": 180000
    }
  }

  Why it matters: You know when Claude "forgot" older details. You might want to:
  - Re-inject important context
  - Log that this happened
  - Warn the user: "Claude's memory was compressed"

  ---
  8. Can SDK Work Without API Key? (Max Subscription)

  YES, for personal use.

  From https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan:
  "With Pro and Max plans, you now have access to both Claude on the web, desktop, and mobile apps and Claude Code in your terminal with one unified subscription."

  How it works:
  1. The SDK uses Claude Code as its runtime
  2. Claude Code supports Max subscription authentication
  3. Therefore, SDK inherits this capability

  Setup:
  # Authenticate with your Max subscription (one time)
  claude login

  # SDK will use your saved credentials
  # No ANTHROPIC_API_KEY needed

  Caveat for distribution:
  If you're building an app for OTHERS to use, Anthropic requires API billing unless you get pre-approval. But for YOUR personal use, Max subscription works fine.







### Validation Sources

1. [TypeScript SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
2. [Claude Code Headless Mode](https://code.claude.com/docs/en/headless)
3. [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
4. [Claude Pricing](https://claude.com/pricing)
5. [Using Claude Code with Pro/Max](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan)
6. [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing)

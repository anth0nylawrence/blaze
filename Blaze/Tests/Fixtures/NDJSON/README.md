# NDJSON Fixtures

This directory contains captured NDJSON fixtures from Claude CLI for testing and protocol validation.

## Directory Layout

```
NDJSON/
├── README.md                           # This file
├── latest                              # Pointer file to current version (e.g., "v1.0.24")
└── v<claude_version>/                  # Version-specific fixtures
    ├── meta.json                       # Capture metadata
    ├── ask_user_question_tool_use.json # Raw tool_use event from Claude
    ├── ask_user_question_tool_result.json  # The tool_result we sent via stdin
    └── ask_user_question_continuation.json # Assistant continuation after tool_result
```

## Generating Fixtures

### Prerequisites

1. Claude CLI installed and authenticated (`claude --version` works)
2. Swift 5.9+ installed

### Capture Command

From the repository root:

```bash
# Compile the script first
swiftc -parse-as-library Blaze/Scripts/capture_tool_prompt_fixture.swift -o /tmp/capture_fixture

# Basic capture
/tmp/capture_fixture

# With partial messages (for delta events)
/tmp/capture_fixture --include-partial-messages

# Custom output directory
/tmp/capture_fixture --output-dir /path/to/output
```

### What the Script Does

1. **Runs `claude --version`** to determine CLI version
2. **Spawns Claude CLI** with:
   - `--output-format stream-json`
   - `--input-format stream-json`
   - `--verbose`
   - (optional) `--include-partial-messages`
3. **Tries prompt variants** (3 variants, 3 retries each) until `AskUserQuestionTool` is triggered
4. **Records all I/O** to `.blaze-traces/<timestamp>/`:
   - `claude.stdout.jsonl` - stdout from CLI
   - `claude.stdin.jsonl` - stdin we sent
   - `claude.stderr.jsonl` - stderr from CLI
5. **Sends tool_result** via stdin when `tool_use` is detected
6. **Waits for continuation** (assistant response after tool_result)
7. **Saves fixtures** to `Tests/Fixtures/NDJSON/v<version>/`

### Regenerating Fixtures

After a Claude CLI upgrade:

```bash
# Check current version
claude --version

# Regenerate fixtures
swift Blaze/Scripts/capture_tool_prompt_fixture.swift

# Verify new version directory exists
ls Blaze/Tests/Fixtures/NDJSON/
```

## Fixture Files

### meta.json

Contains capture metadata:

```json
{
  "claude_version": "1.0.24",
  "capture_date": "2026-01-02T12:00:00Z",
  "flags": ["--output-format", "stream-json", "--input-format", "stream-json", "--verbose"],
  "round_trip_success": true,
  "prompt_variant_index": 0,
  "attempt_number": 1,
  "prompt_hash": "base64:...",
  "tool_use_id": "toolu_...",
  "session_id": "...",
  "trace_dir": "/path/to/.blaze-traces/2026-01-02T..."
}
```

### ask_user_question_tool_use.json

Raw NDJSON line from Claude containing `tool_use` block with `AskUserQuestionTool`:

```json
{"type":"assistant","session_id":"...","message":{"content":[{"type":"tool_use","id":"toolu_...","name":"AskUserQuestionTool","input":{...}}]}}
```

### ask_user_question_tool_result.json

The `tool_result` envelope we sent via stdin:

```json
{"type":"user","session_id":"...","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_...","content":"Option A"}]}}
```

### ask_user_question_continuation.json

Assistant's response after receiving `tool_result`:

```json
{"type":"assistant","session_id":"...","message":{"content":[{"type":"text","text":"Great, I'll proceed with..."}]}}
```

## Using Fixtures in Tests

```swift
// Load fixture
func loadFixture(_ name: String) -> Data {
    let fixturesURL = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
    let latestPath = fixturesURL.appendingPathComponent("NDJSON/latest")
    let version = try! String(contentsOf: latestPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    let fixtureURL = fixturesURL
        .appendingPathComponent("NDJSON/\(version)")
        .appendingPathComponent(name)
    return try! Data(contentsOf: fixtureURL)
}

// In tests
func testDecodeToolUse() {
    let data = loadFixture("ask_user_question_tool_use.json")
    let event = try! decoder.decode(ClaudeStreamEvent.self, from: data)
    // Assert...
}
```

## Troubleshooting

### "No AskUserQuestionTool use" Error

The prompt variants may not trigger `AskUserQuestionTool` reliably. Try:
1. Running multiple times (the script retries automatically)
2. Modifying prompt variants in the script
3. Checking Claude CLI version compatibility

### Timeout Errors

The script waits 30 seconds for continuation. If timeout occurs:
1. Check `.blaze-traces/<timestamp>/` for partial output
2. Verify Claude CLI is responding
3. Check for API/network issues

### Version Mismatch

If tests fail after CLI upgrade:
1. Regenerate fixtures with the new version
2. Update `latest` pointer if needed
3. Check for schema changes in fixture files

## Important Notes

1. **Fixtures are version-specific**: Each CLI version may have different schemas
2. **Don't manually edit fixtures**: Always regenerate from live CLI
3. **Keep old versions**: Useful for compatibility testing
4. **Check `meta.json`**: Verify `round_trip_success: true` before trusting fixtures

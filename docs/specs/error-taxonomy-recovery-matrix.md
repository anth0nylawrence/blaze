# Cogit0 Blaze - Error Taxonomy & Recovery Matrix

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Status:** Draft

---

## Design Philosophy

Error messages in Blaze are:
1. **Informative** - Tell users what went wrong
2. **Actionable** - Provide clear recovery steps
3. **Human** - Use friendly, occasionally witty language
4. **Dynamic** - Rotate through multiple phrasings to avoid staleness
5. **Referential** - Include tasteful geek/pop culture references

---

## Table of Contents

1. [Error Classification](#1-error-classification)
2. [Error Taxonomy](#2-error-taxonomy)
3. [Recovery Matrix](#3-recovery-matrix)
4. [User-Facing Messages](#4-user-facing-messages)
5. [Implementation Guide](#5-implementation-guide)

---

## 1. Error Classification

### 1.1 Severity Levels

| Level | Icon | Color | Behavior |
|-------|------|-------|----------|
| **Critical** | `exclamationmark.triangle.fill` | Red | Block operation, require user action |
| **Error** | `xmark.circle.fill` | Orange | Show alert, offer retry |
| **Warning** | `exclamationmark.circle.fill` | Yellow | Show inline, continue if possible |
| **Info** | `info.circle.fill` | Blue | Toast notification only |

### 1.2 Recovery Categories

| Category | Description | Auto-Retry |
|----------|-------------|------------|
| **Transient** | Temporary issues that resolve themselves | Yes, with backoff |
| **Retryable** | User can retry with same inputs | Yes, on user action |
| **Fixable** | User can fix and retry | No, guidance provided |
| **Terminal** | Cannot be recovered without intervention | No, escalation path |

---

## 2. Error Taxonomy

### 2.1 Engine Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E1001` | `ENGINE_NOT_FOUND` | Terminal | CLI binary not found in PATH |
| `E1002` | `ENGINE_CRASH` | Retryable | CLI process exited unexpectedly |
| `E1003` | `ENGINE_TIMEOUT` | Retryable | No response within timeout |
| `E1004` | `ENGINE_AUTH_FAILED` | Fixable | Authentication invalid/expired |
| `E1005` | `ENGINE_AUTH_REQUIRED` | Fixable | Not authenticated |
| `E1006` | `ENGINE_VERSION_UNSUPPORTED` | Terminal | CLI version too old |
| `E1007` | `ENGINE_RATE_LIMITED` | Transient | API rate limit hit |
| `E1008` | `ENGINE_OVERLOADED` | Transient | Server overloaded |
| `E1009` | `ENGINE_MAINTENANCE` | Transient | Scheduled maintenance |
| `E1010` | `ENGINE_QUOTA_EXCEEDED` | Terminal | Usage quota exceeded |

### 2.2 Stream Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E2001` | `STREAM_PARSE_ERROR` | Retryable | Invalid JSON in stream |
| `E2002` | `STREAM_INCOMPLETE` | Retryable | Stream ended without result event |
| `E2003` | `STREAM_TIMEOUT` | Retryable | No events received within timeout |
| `E2004` | `STREAM_CANCELLED` | Info | User cancelled stream |
| `E2005` | `STREAM_BUFFER_OVERFLOW` | Warning | Event too large, truncated |

### 2.3 Tool Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E3001` | `TOOL_EXECUTION_FAILED` | Retryable | Tool returned non-zero exit |
| `E3002` | `TOOL_TIMEOUT` | Retryable | Tool exceeded timeout |
| `E3003` | `TOOL_PERMISSION_DENIED` | Fixable | Insufficient permissions |
| `E3004` | `TOOL_NOT_FOUND` | Terminal | Required tool not available |
| `E3005` | `TOOL_INVALID_INPUT` | Fixable | Invalid arguments to tool |
| `E3006` | `TOOL_BLOCKED_BY_POLICY` | Fixable | Policy prevented execution |

### 2.4 File System Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E4001` | `FILE_NOT_FOUND` | Fixable | File does not exist |
| `E4002` | `FILE_ACCESS_DENIED` | Fixable | No read/write permission |
| `E4003` | `FILE_TOO_LARGE` | Warning | File exceeds size limit |
| `E4004` | `FILE_ENCODING_ERROR` | Warning | Cannot decode file encoding |
| `E4005` | `FILE_CONFLICT` | Fixable | File changed since read |
| `E4006` | `DISK_FULL` | Terminal | No space left on device |

### 2.5 Network Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E5001` | `NETWORK_OFFLINE` | Transient | No network connectivity |
| `E5002` | `NETWORK_TIMEOUT` | Transient | Connection timed out |
| `E5003` | `NETWORK_DNS_FAILURE` | Transient | DNS resolution failed |
| `E5004` | `NETWORK_TLS_ERROR` | Terminal | Certificate/TLS error |
| `E5005` | `NETWORK_PROXY_ERROR` | Fixable | Proxy configuration issue |

### 2.6 Session Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E6001` | `SESSION_NOT_FOUND` | Terminal | Session no longer exists |
| `E6002` | `SESSION_CORRUPTED` | Fixable | Session data corrupted |
| `E6003` | `SESSION_LOCKED` | Retryable | Session in use by another process |
| `E6004` | `SESSION_MIGRATION_FAILED` | Fixable | Schema migration failed |

### 2.7 Policy Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E7001` | `POLICY_DENIED` | Fixable | Action blocked by policy |
| `E7002` | `POLICY_INVALID` | Fixable | Policy configuration invalid |
| `E7003` | `POLICY_CONFLICT` | Warning | Conflicting policies |

### 2.8 Application Errors

| Code | Name | Category | Description |
|------|------|----------|-------------|
| `E8001` | `APP_INTERNAL_ERROR` | Retryable | Unexpected internal error |
| `E8002` | `APP_STATE_INVALID` | Retryable | Invalid application state |
| `E8003` | `APP_RESOURCE_EXHAUSTED` | Warning | Memory/resource pressure |
| `E8004` | `APP_UPDATE_REQUIRED` | Terminal | App version too old |

---

## 3. Recovery Matrix

### 3.1 Automatic Recovery

| Error Code | Retry Strategy | Max Attempts | Backoff |
|------------|---------------|--------------|---------|
| `E1007` | Exponential | 5 | 1s, 2s, 4s, 8s, 16s |
| `E1008` | Exponential | 3 | 5s, 15s, 45s |
| `E1009` | Fixed interval | 10 | 30s |
| `E2003` | Linear | 3 | 10s |
| `E5001` | Exponential | ∞ | 1s, 2s, 4s... (max 60s) |
| `E5002` | Exponential | 5 | 2s, 4s, 8s, 16s, 32s |
| `E6003` | Linear | 5 | 1s |

### 3.2 User-Initiated Recovery

| Error Code | Primary Action | Secondary Action |
|------------|---------------|------------------|
| `E1001` | Show install instructions | Open documentation |
| `E1002` | Retry session | Export session for support |
| `E1004` | Trigger re-auth flow | Clear credentials |
| `E1006` | Show update instructions | Check CLI version |
| `E3003` | Show permission request | Adjust policy |
| `E3006` | Show policy override dialog | Edit policy |
| `E4001` | Show file picker | Create file |
| `E4002` | Request permission | Open in Finder |
| `E4005` | Show diff merge UI | Force overwrite |

### 3.3 Escalation Paths

| Severity | First Response | Escalation | Final |
|----------|---------------|------------|-------|
| Critical | Modal dialog | Support bundle | Contact support |
| Error | Alert + retry | Settings check | Export logs |
| Warning | Toast | Documentation | Dismiss |
| Info | Toast | - | Auto-dismiss |

---

## 4. User-Facing Messages

### 4.1 Message Structure

```swift
struct ErrorMessage {
    let title: String           // Short, bold headline
    let description: String     // Friendly explanation
    let technicalDetail: String? // For "Show Details"
    let actions: [ErrorAction]  // Recovery buttons
    let reference: String?      // Pop culture reference (optional)
}
```

### 4.2 Engine Error Messages

#### E1001: ENGINE_NOT_FOUND

**Titles (rotate randomly):**
```
"Houston, We Have a Problem"
"These Aren't the Droids You're Looking For"
"404: Engine Not Found"
"The CLI Is a Lie"
"I've Got a Bad Feeling About This"
```

**Descriptions:**
```
"We couldn't find Claude Code on your system. It's like trying to make the Kessel Run without a hyperdrive."

"The Claude Code CLI seems to have pulled a Houdini. Let's get it installed so you can get back to coding."

"Looks like Claude Code isn't installed yet. Don't worry, we'll have you up and running faster than you can say 'Expelliarmus'."
```

**Actions:** `[Install Claude Code] [Check PATH] [I'll handle it]`

---

#### E1002: ENGINE_CRASH

**Titles:**
```
"Unexpected Turbulence"
"Well, That Escalated Quickly"
"Claude Has Left the Building"
"Task Failed Successfully... Wait, No"
"I Am Inevitable... To Crash"
```

**Descriptions:**
```
"Claude Code crashed unexpectedly. Even the best of us have bad days - just ask the Death Star."

"The engine took an unscheduled vacation. We've saved your work, so no need to panic like C-3PO."

"Something went sideways. Don't worry, your session is safe and we can try again."
```

**Actions:** `[Retry] [View Crash Log] [Report Issue]`

---

#### E1004: ENGINE_AUTH_FAILED

**Titles:**
```
"You Shall Not Pass!"
"Access Denied, Mr. Anderson"
"Authentication? I Hardly Know Her"
"Your Credentials Have Expired Like Milk"
"The Secret Handshake Was Wrong"
```

**Descriptions:**
```
"Your authentication credentials seem to have expired. Even Gandalf had to say the magic words."

"Claude doesn't recognize you anymore. Time to re-authenticate and remind it who's boss."

"Your session token has gone the way of Thanos - snapped out of existence. Let's get you logged back in."
```

**Actions:** `[Sign In Again] [Clear Credentials] [Get Help]`

---

#### E1007: ENGINE_RATE_LIMITED

**Titles:**
```
"Slow Down There, Speedster"
"You're Too Powerful for Your Own Good"
"The API Needs a Breather"
"Rate Limited: Not a Band Name"
"Pump the Brakes, Maverick"
```

**Descriptions:**
```
"You've been coding so fast, the API needs a moment to catch up. Even The Flash takes water breaks."

"Rate limit hit! We're automatically retrying in {seconds}s. Grab a coffee - you've earned it."

"The servers are asking for a brief intermission. We'll resume automatically, like a good TV show after commercials."
```

**Dynamic variables:** `{seconds}` = retry countdown

**Actions:** `[Retry Now] [Reduce Speed] [View Usage]`

---

#### E1010: ENGINE_QUOTA_EXCEEDED

**Titles:**
```
"You've Hit the Wall, Neo"
"Your Tokens Are in Another Castle"
"Budget? What Budget?"
"The Well Has Run Dry"
"All Used Up Like Pizza at a LAN Party"
```

**Descriptions:**
```
"You've used all your available tokens. Like Pac-Man eating all the dots, there's nothing left to consume."

"Your usage quota is exhausted. Time to either wait for the reset or level up your plan."

"You've been incredibly productive! So productive that you've hit your limit. That's... actually impressive."
```

**Actions:** `[View Usage] [Upgrade Plan] [Set Alert]`

---

### 4.3 Tool Error Messages

#### E3001: TOOL_EXECUTION_FAILED

**Titles:**
```
"Tool Time Trouble"
"That Command Didn't Spark Joy"
"Exit Code: Nope"
"The Tool Has Spoken (and it said no)"
"Computer Says No"
```

**Descriptions:**
```
"The {tool_name} command failed with exit code {exit_code}. Even Batman's gadgets malfunction sometimes."

"Command failed. The good news? We captured the error. The bad news? It's not happy about it."

"Something went wrong with {tool_name}. Let's check the stderr - it usually has strong opinions."
```

**Dynamic variables:** `{tool_name}`, `{exit_code}`

---

#### E3006: TOOL_BLOCKED_BY_POLICY

**Titles:**
```
"Policy Says No"
"Blocked by the Rules You Made"
"Safety First, Chaos Second"
"The Bouncer Won't Let This In"
"Your Past Self Was Cautious"
```

**Descriptions:**
```
"This action was blocked by your '{policy_name}' policy. Your past self was looking out for you."

"Policy '{policy_name}' prevented this. Like Dumbledore's protective spells, but for your codebase."

"A policy blocked this action. You can override it if you're feeling brave (and authorized)."
```

**Dynamic variables:** `{policy_name}`, `{rule_description}`

**Actions:** `[Allow This Once] [Allow for Session] [Edit Policy] [Deny]`

---

### 4.4 File System Error Messages

#### E4001: FILE_NOT_FOUND

**Titles:**
```
"File Not Found: The Sequel"
"The File Is a Lie"
"Gone Without a Trace"
"Have You Checked Behind the Couch?"
"It's Not You, It's the Filesystem"
```

**Descriptions:**
```
"We couldn't find '{file_path}'. It's like trying to find Waldo, but Waldo never existed."

"File '{filename}' seems to have vanished. Did it get snapped by Thanos, or just moved?"

"That file isn't where we expected it. Files are notoriously bad at staying put."
```

**Dynamic variables:** `{file_path}`, `{filename}`

---

#### E4005: FILE_CONFLICT

**Titles:**
```
"Merge Conflict Detected"
"The File Has Changed"
"Time Travel Paradox"
"Someone Else Got There First"
"Git Is Judging You"
```

**Descriptions:**
```
"This file was modified since Claude read it. It's like a text message that got edited after you saw it."

"File conflict detected! The file changed while you were working. Let's figure out what happened."

"'{filename}' has been altered by forces unknown (probably you in another window)."
```

**Actions:** `[Show Diff] [Use Mine] [Use Theirs] [Merge]`

---

### 4.5 Network Error Messages

#### E5001: NETWORK_OFFLINE

**Titles:**
```
"You're Flying Solo"
"The Internet Has Left the Chat"
"Offline Mode: Engaged"
"No Signal, No Problem... Actually, Yes Problem"
"WiFi? Why-Not-Fi"
```

**Descriptions:**
```
"No network connection detected. We'll keep trying, like a loyal droid waiting for its master."

"You appear to be offline. We'll automatically reconnect when the internet decides to cooperate."

"Network's down. Your session is safe locally - we'll sync when you're back online."
```

**Actions:** `[Retry Connection] [Work Offline] [Check Settings]`

---

### 4.6 Session Error Messages

#### E6002: SESSION_CORRUPTED

**Titles:**
```
"Session.exe Has Stopped Working"
"Data Corruption: The Horror Movie"
"The Session Needs CPR"
"Bits Gone Bad"
"Your Save File Is Corrupted"
```

**Descriptions:**
```
"This session's data got scrambled. Like a VHS tape left on a speaker, something went wrong."

"Session data corruption detected. We can try to recover what we can, or start fresh."

"The session file is corrupted. We have backups, though - we're not amateurs."
```

**Actions:** `[Attempt Recovery] [Restore from Backup] [Start New Session]`

---

### 4.7 Policy Error Messages

#### E7001: POLICY_DENIED

**Titles:**
```
"Policy: Access Denied"
"The Rules Have Spoken"
"Blocked for Your Protection"
"Computer Says No (Respectfully)"
"Your Guardrails Are Working"
```

**Descriptions:**
```
"This action was denied by policy '{policy_name}'. Reason: {reason}"

"Your safety policy blocked this. Like a good friend stopping you from texting your ex at 2am."

"Policy violation detected. The rule '{rule_name}' prevented: {action_description}"
```

---

### 4.8 Application Error Messages

#### E8001: APP_INTERNAL_ERROR

**Titles:**
```
"Oops, We Did It Again"
"This Shouldn't Happen™"
"Internal Error: The Mystery Box"
"Something Went Boom"
"Error 8001: The One That Got Away"
```

**Descriptions:**
```
"Something unexpected happened inside Blaze. We've logged it and are probably already working on a fix."

"Internal error detected. This is on us, not you. Mind sending us the crash report?"

"Well, that wasn't supposed to happen. Our engineers will be very interested in this."
```

**Actions:** `[Send Report] [Retry] [Restart App]`

---

## 5. Implementation Guide

### 5.1 Error Message Registry

```swift
enum ErrorCode: String, CaseIterable {
    case engineNotFound = "E1001"
    case engineCrash = "E1002"
    case engineTimeout = "E1003"
    // ... etc

    var category: ErrorCategory { ... }
    var severity: ErrorSeverity { ... }
    var isRetryable: Bool { ... }
    var defaultRetryStrategy: RetryStrategy? { ... }
}

struct ErrorMessageSet {
    let code: ErrorCode
    let titles: [String]
    let descriptions: [String]
    let actions: [ErrorAction]

    func randomized(with context: ErrorContext) -> ErrorMessage {
        let title = titles.randomElement()!
        let description = descriptions.randomElement()!
            .replacing(context.variables)

        return ErrorMessage(
            title: title,
            description: description,
            technicalDetail: context.technicalDetail,
            actions: actions
        )
    }
}
```

### 5.2 Dynamic Variable Substitution

```swift
extension String {
    func replacing(_ variables: [String: String]) -> String {
        var result = self
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}

// Usage
let context = ErrorContext(
    variables: [
        "filename": "Login.swift",
        "exit_code": "1",
        "seconds": "30"
    ],
    technicalDetail: "SIGTERM received"
)
```

### 5.3 Message Rotation

```swift
class ErrorMessageRotator {
    private var usedMessages: [ErrorCode: Set<Int>] = [:]

    func selectMessage(for code: ErrorCode, from set: ErrorMessageSet) -> Int {
        var used = usedMessages[code] ?? []

        // Reset if all messages used
        if used.count >= set.titles.count {
            used = []
        }

        // Pick unused index
        let available = Set(0..<set.titles.count).subtracting(used)
        let index = available.randomElement()!

        used.insert(index)
        usedMessages[code] = used

        return index
    }
}
```

### 5.4 Localization Keys

```swift
// Localizable.strings structure
"error.E1001.title.0" = "Houston, We Have a Problem";
"error.E1001.title.1" = "These Aren't the Droids You're Looking For";
"error.E1001.description.0" = "We couldn't find Claude Code...";
"error.E1001.action.install" = "Install Claude Code";
```

### 5.5 Analytics Integration

```swift
struct ErrorAnalytics {
    func track(error: AppError, context: ErrorContext) {
        Analytics.track("error_occurred", properties: [
            "code": error.code.rawValue,
            "category": error.code.category.rawValue,
            "severity": error.code.severity.rawValue,
            "is_retryable": error.code.isRetryable,
            "retry_count": context.retryCount,
            "session_id": context.sessionId,
            // Never log user content or file paths
        ])
    }

    func trackRecovery(error: AppError, action: ErrorAction, success: Bool) {
        Analytics.track("error_recovery", properties: [
            "code": error.code.rawValue,
            "action": action.id,
            "success": success
        ])
    }
}
```

---

## Appendix A: Full Message Catalog

### A.1 All Titles by Category

#### Sci-Fi References
- "Houston, We Have a Problem" (Apollo 13)
- "These Aren't the Droids You're Looking For" (Star Wars)
- "I've Got a Bad Feeling About This" (Star Wars)
- "Resistance Is Futile" (Star Trek)
- "Make It So... Or Not" (Star Trek)
- "The Spice Must Flow... But It Didn't" (Dune)
- "I Am Inevitable... To Crash" (Marvel)
- "Access Denied, Mr. Anderson" (The Matrix)
- "You're in the Upside Down" (Stranger Things)
- "Winter Is Coming for Your Session" (Game of Thrones)

#### Fantasy References
- "You Shall Not Pass!" (LOTR)
- "It's Dangerous to Go Alone" (Zelda)
- "Your Princess Is in Another Castle" (Mario)
- "Expecto Patronum... Error" (Harry Potter)
- "One Does Not Simply Write Bug-Free Code" (LOTR)
- "The Cake Is a Lie" (Portal)

#### Meme/Internet Culture
- "This Is Fine" (Dog in fire meme)
- "Well, That Escalated Quickly" (Anchorman)
- "Task Failed Successfully... Wait, No"
- "Computer Says No" (Little Britain)
- "Error 404: Patience Not Found"
- "All Your Base Are Belong to Us"

#### Tech Humor
- "Have You Tried Turning It Off and On Again?"
- "Works on My Machine™"
- "It's Not a Bug, It's a... Wait, No, It's a Bug"
- "git commit -m 'Fixed everything' (Narrator: It didn't)"
- "Segmentation Fault: The Musical"

### A.2 Tone Guidelines

| Situation | Tone | Avoid |
|-----------|------|-------|
| User-caused error | Supportive, helpful | Blame, condescension |
| System error | Apologetic, reassuring | Technical jargon |
| Transient issue | Light, patient | Urgency, alarm |
| Critical failure | Calm, informative | Jokes, minimizing |
| Security issue | Serious, clear | Humor, ambiguity |

### A.3 Accessibility Notes

- All error messages must work without relying on color alone
- Icon + text required for severity indication
- Screen reader announces: "{severity}: {title}. {description}"
- Don't use puns that don't translate well
- Cultural references should have fallback plain-English versions

---

## Appendix B: Recovery Flow Diagrams

### B.1 Standard Error Recovery

```
Error Occurs
     │
     ▼
┌─────────────────┐
│ Is Auto-Retry?  │
└────────┬────────┘
    Yes  │  No
         │
    ▼    ▼
┌───────────┐  ┌───────────────┐
│   Retry   │  │  Show Error   │
│  (async)  │  │    Dialog     │
└─────┬─────┘  └───────┬───────┘
      │                │
      ▼                ▼
┌───────────┐  ┌───────────────┐
│  Success? │  │  User Action  │
└─────┬─────┘  └───────┬───────┘
 Yes  │  No           │
      │               ▼
      ▼         ┌───────────┐
  Continue      │  Execute  │
                │  Action   │
                └───────────┘
```

### B.2 Escalation Path

```
Error (Info)
     │
     ▼
Toast (3s auto-dismiss)
     │
     │ Recurs
     ▼
Error (Warning)
     │
     ▼
Persistent Toast + Action
     │
     │ Recurs
     ▼
Error (Error)
     │
     ▼
Alert Dialog + Retry
     │
     │ Fails 3x
     ▼
Error (Critical)
     │
     ▼
Modal + Support Bundle + Contact
```

---

**End of Document**

# Support Runbook

> Cogit0 Blaze - Operational Support Guide

## Overview

This runbook provides step-by-step procedures for handling common support scenarios, troubleshooting issues, and escalating problems appropriately.

---

## 1. Quick Reference

### 1.1 Key Locations

| Item | Location |
|------|----------|
| **App Logs** | `~/Library/Logs/Blaze/` |
| **Crash Reports** | `~/Library/Logs/DiagnosticReports/Blaze*` |
| **Preferences** | `~/Library/Preferences/com.cogit0.blaze.plist` |
| **Application Support** | `~/Library/Application Support/Blaze/` |
| **Database** | `~/Library/Application Support/Blaze/data.lancedb` |
| **Sessions** | `~/Library/Application Support/Blaze/sessions/` |
| **Cache** | `~/Library/Caches/com.cogit0.blaze/` |

### 1.2 Common Commands

```bash
# View recent logs
log show --predicate 'subsystem == "com.cogit0.blaze"' --last 1h

# Check if Blaze is running
pgrep -l Blaze

# Force quit Blaze
pkill -9 Blaze

# Clear all Blaze data (nuclear option)
rm -rf ~/Library/Application\ Support/Blaze/*
rm -rf ~/Library/Caches/com.cogit0.blaze

# Check Claude Code CLI version
claude --version

# Verify CLI authentication
claude auth status
```

---

## 2. Troubleshooting Flowcharts

### 2.1 App Won't Launch

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        APP WON'T LAUNCH                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Start                                                                  │
│    │                                                                    │
│    ▼                                                                    │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ Does app bounce  │────────────▶│ Check Gatekeeper:                │ │
│  │ in dock?         │             │ Right-click → Open → Open        │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ Yes                                                        │
│           ▼                                                            │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ Does window      │────────────▶│ Check crash logs:                │ │
│  │ appear?          │             │ ~/Library/Logs/DiagnosticReports │ │
│  └────────┬─────────┘             │ Collect & escalate to Tier 2     │ │
│           │ Yes                   └──────────────────────────────────┘ │
│           ▼                                                            │
│  ┌──────────────────┐     Yes     ┌──────────────────────────────────┐ │
│  │ Is window blank/ │────────────▶│ Reset preferences:               │ │
│  │ frozen?          │             │ defaults delete com.cogit0.blaze │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ No                                                         │
│           ▼                                                            │
│       App working!                                                     │
│                                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 CLI Connection Issues

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CLI CONNECTION ISSUES                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  "No CLI detected"                                                      │
│    │                                                                    │
│    ▼                                                                    │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ Is CLI installed?│────────────▶│ Install CLI:                     │ │
│  │ (which claude)   │             │ npm i -g @anthropic/claude-code  │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ Yes                                                        │
│           ▼                                                            │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ Version ≥ 2.0.62?│────────────▶│ Update CLI:                      │ │
│  │ (claude --version│             │ npm update -g @anthropic/...     │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ Yes                                                        │
│           ▼                                                            │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ In PATH from app?│────────────▶│ Add to Blaze settings:           │ │
│  │                  │             │ Settings → CLI → Custom Path     │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ Yes                                                        │
│           ▼                                                            │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ CLI authenticated│────────────▶│ Run: claude auth login           │ │
│  │ (claude auth     │             │ in Terminal                      │ │
│  │  status)         │             └──────────────────────────────────┘ │
│  └────────┬─────────┘                                                  │
│           │ Yes                                                        │
│           ▼                                                            │
│       Escalate to Tier 2                                               │
│                                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Streaming Issues

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     STREAMING ISSUES                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  "Response never arrives" / "Stuck streaming"                           │
│    │                                                                    │
│    ▼                                                                    │
│  ┌──────────────────┐     No      ┌──────────────────────────────────┐ │
│  │ Internet working?│────────────▶│ Check network connection         │ │
│  │                  │             │                                   │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ Yes                                                        │
│           ▼                                                            │
│  ┌──────────────────┐     Yes     ┌──────────────────────────────────┐ │
│  │ API status page  │────────────▶│ Wait for Anthropic to resolve    │ │
│  │ shows issues?    │             │ status.anthropic.com             │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ No                                                         │
│           ▼                                                            │
│  ┌──────────────────┐     Yes     ┌──────────────────────────────────┐ │
│  │ Works in CLI     │────────────▶│ Blaze issue - collect logs       │ │
│  │ directly?        │             │ and escalate to Tier 2           │ │
│  └────────┬─────────┘             └──────────────────────────────────┘ │
│           │ No                                                         │
│           ▼                                                            │
│       CLI/API issue - refer to                                         │
│       Anthropic support                                                │
│                                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Common Issues & Solutions

### 3.1 Performance Issues

**Symptom:** App feels slow, laggy scrolling, high CPU usage

**Diagnostic Steps:**
```bash
# Check CPU usage
top -pid $(pgrep Blaze)

# Check memory
leaks Blaze --exclude __CFDictionary

# Check database size
du -sh ~/Library/Application\ Support/Blaze/data.lancedb

# Check session count
ls -la ~/Library/Application\ Support/Blaze/sessions/ | wc -l
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Database > 1GB | Archive old sessions in Settings |
| > 100 sessions | Archive or delete old sessions |
| Memory leak | Restart app, collect logs, report bug |
| Large session (10K+ events) | Expected - suggest splitting sessions |

### 3.2 Session Data Loss

**Symptom:** Sessions missing, messages disappeared

**Diagnostic Steps:**
```bash
# Check if database exists
ls -la ~/Library/Application\ Support/Blaze/data.lancedb

# Check for backup
ls -la ~/Library/Application\ Support/Blaze/backups/

# Check session files
ls -la ~/Library/Application\ Support/Blaze/sessions/
```

**Recovery Procedure:**
1. Check for automatic backup in `backups/` folder
2. If backup exists, restore: `cp backups/data.lancedb.bak data.lancedb`
3. If no backup, check Time Machine
4. If unrecoverable, collect forensics and escalate

### 3.3 Authentication Errors

**Symptom:** "Not authenticated", "API key invalid"

**Solutions:**

| Error | Solution |
|-------|----------|
| Not authenticated | Run `claude auth login` in Terminal |
| API key invalid | Check Anthropic console for key status |
| Token expired | Re-authenticate: `claude auth logout && claude auth login` |
| Wrong account | Verify account in Anthropic console |

### 3.4 Diff Viewer Issues

**Symptom:** Diff not rendering, wrong content, crashes on large files

**Solutions:**

| Issue | Solution |
|-------|----------|
| Blank diff | Check if file exists on disk |
| Wrong base content | Refresh session, may need to restart CLI |
| Crash on large file | Known limitation, file bug for files > 50K lines |
| Encoding issues | Ensure file is UTF-8 encoded |

---

## 4. Escalation Procedures

### 4.1 Tier Definitions

| Tier | Scope | SLA |
|------|-------|-----|
| **Tier 1** | FAQ, common issues, basic troubleshooting | 4 business hours |
| **Tier 2** | Complex issues, log analysis, workarounds | 1 business day |
| **Tier 3** | Engineering team, code fixes, investigations | 3 business days |

### 4.2 Escalation Criteria

**Escalate to Tier 2 when:**
- Basic troubleshooting fails
- Issue requires log analysis
- Multiple users reporting same issue
- Security concern

**Escalate to Tier 3 when:**
- Confirmed bug requiring code fix
- Data corruption
- Security vulnerability
- Performance regression affecting many users

### 4.3 Escalation Template

```markdown
## Escalation Request

**Date:** [date]
**Priority:** P0 / P1 / P2 / P3
**Affected Users:** [count or "single"]

### Summary
[One sentence description]

### User Environment
- Blaze version:
- macOS version:
- CLI version:
- Hardware:

### Steps to Reproduce
1.
2.
3.

### Expected vs Actual Behavior

### Troubleshooting Attempted
- [ ] Checked logs
- [ ] Verified CLI version
- [ ] Restarted app
- [ ] Reset preferences
- [ ] Other: ________

### Attachments
- [ ] App logs
- [ ] Crash reports
- [ ] Screenshots
- [ ] Screen recording

### Impact
[Describe business/workflow impact]
```

---

## 5. Log Collection

### 5.1 Essential Logs

```bash
# Create support bundle
mkdir ~/Desktop/blaze-support-$(date +%Y%m%d)
cd ~/Desktop/blaze-support-$(date +%Y%m%d)

# App logs
cp -r ~/Library/Logs/Blaze/*.log .

# Crash reports
cp ~/Library/Logs/DiagnosticReports/Blaze* .

# System log entries
log show --predicate 'subsystem == "com.cogit0.blaze"' \
    --last 24h > system.log

# App info
defaults read com.cogit0.blaze > preferences.txt

# Environment
sw_vers > system-info.txt
echo "---" >> system-info.txt
system_profiler SPHardwareDataType >> system-info.txt

# CLI info
which claude >> cli-info.txt
claude --version >> cli-info.txt
claude auth status >> cli-info.txt 2>&1

# Create archive
cd ..
zip -r blaze-support-$(date +%Y%m%d).zip blaze-support-$(date +%Y%m%d)
```

### 5.2 Log Interpretation Guide

**Log Levels:**
- `ERROR` - Something broke, needs attention
- `WARN` - Potential issue, may indicate problem
- `INFO` - Normal operation, useful for context
- `DEBUG` - Detailed info, only in debug builds

**Common Patterns:**

| Pattern | Meaning |
|---------|---------|
| `[CLI] spawn failed` | CLI process couldn't start |
| `[Parser] invalid JSON` | Malformed CLI output |
| `[Storage] write failed` | Database issue |
| `[Stream] timeout` | CLI not responding |
| `[Auth] token refresh` | Normal re-authentication |

---

## 6. Known Issues & Workarounds

### 6.1 Current Known Issues

| ID | Issue | Workaround | Target Fix |
|----|-------|------------|------------|
| BLZ-101 | Large diffs (>50K lines) cause hang | Split into smaller files | v1.1 |
| BLZ-102 | Copy from diff viewer loses formatting | Use "Copy as Markdown" | v1.0.1 |
| BLZ-103 | Session search slow with >1000 sessions | Archive old sessions | v1.1 |
| BLZ-104 | Gatekeeper warning on first launch | Right-click → Open | Expected |

### 6.2 FAQ

**Q: Why doesn't Blaze show in the App Store?**
A: Blaze is distributed via direct download with Developer ID signing, not through the Mac App Store.

**Q: Can I use Blaze without an Anthropic account?**
A: No, Blaze requires Claude Code CLI which needs Anthropic authentication.

**Q: Does Blaze work offline?**
A: You can view past sessions offline, but cannot send new prompts without internet.

**Q: Where is my data stored?**
A: All data is stored locally in `~/Library/Application Support/Blaze/`. Nothing is sent to Cogit0 servers.

**Q: Can I export my sessions?**
A: Yes, use File → Export Session to save as JSON or Markdown.

---

## 7. Emergency Procedures

### 7.1 Security Incident

1. **Immediate:** Isolate affected systems
2. **Assess:** Determine scope and impact
3. **Notify:** Security team and management
4. **Document:** Record all actions taken
5. **Remediate:** Apply fixes
6. **Review:** Post-incident analysis

### 7.2 Data Breach Response

1. **Contain:** Stop data exfiltration
2. **Assess:** What data was exposed
3. **Notify:** Legal, compliance, affected users
4. **Remediate:** Close vulnerability
5. **Report:** Regulatory notification if required

### 7.3 Mass Incident

When many users affected:

1. **Acknowledge:** Post status update
2. **War room:** Assemble response team
3. **Communicate:** Regular updates every 30 min
4. **Fix:** Deploy emergency patch
5. **Post-mortem:** Document and prevent recurrence

---

## 8. Contact Information

### 8.1 Internal

| Role | Contact |
|------|---------|
| Support Lead | support-lead@cogit0.com |
| Engineering On-Call | eng-oncall@cogit0.com |
| Security Team | security@cogit0.com |

### 8.2 External

| Service | Contact |
|---------|---------|
| Anthropic Support | support@anthropic.com |
| Apple Developer | developer.apple.com/contact |
| Status Page | status.cogit0.com |

---

## 9. Appendix

### 9.1 Useful Scripts

```bash
# blaze-doctor.sh - Diagnose common issues
#!/bin/bash

echo "=== Blaze Doctor ==="
echo ""

echo "Checking Blaze installation..."
if [ -d "/Applications/Blaze.app" ]; then
    echo "✅ Blaze installed"
    VERSION=$(/Applications/Blaze.app/Contents/MacOS/Blaze --version 2>/dev/null || echo "unknown")
    echo "   Version: $VERSION"
else
    echo "❌ Blaze not found in /Applications"
fi

echo ""
echo "Checking Claude Code CLI..."
if command -v claude &> /dev/null; then
    echo "✅ Claude Code CLI found"
    echo "   Version: $(claude --version)"
    echo "   Path: $(which claude)"
else
    echo "❌ Claude Code CLI not found"
fi

echo ""
echo "Checking authentication..."
if claude auth status 2>&1 | grep -q "authenticated"; then
    echo "✅ CLI authenticated"
else
    echo "❌ CLI not authenticated - run: claude auth login"
fi

echo ""
echo "Checking data directory..."
DATA_DIR="$HOME/Library/Application Support/Blaze"
if [ -d "$DATA_DIR" ]; then
    echo "✅ Data directory exists"
    echo "   Size: $(du -sh "$DATA_DIR" | cut -f1)"
    echo "   Sessions: $(ls "$DATA_DIR/sessions" 2>/dev/null | wc -l | xargs)"
else
    echo "⚠️  Data directory not found (first run?)"
fi

echo ""
echo "=== End Diagnostic ==="
```

### 9.2 Glossary

| Term | Definition |
|------|------------|
| **CLI** | Command Line Interface (Claude Code, Gemini, Codex) |
| **NDJSON** | Newline Delimited JSON - streaming format |
| **LanceDB** | Vector database for session storage |
| **Tool** | CLI capability (Read, Write, Bash, etc.) |
| **Session** | Single conversation with the AI |
| **Branch** | Fork of conversation from a specific point |

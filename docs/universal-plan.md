# Plan: Enable Universal Builds (Intel + Apple Silicon)

## Goal
Modify release scripts to produce universal binaries that run natively on both Intel (x86_64) and Apple Silicon (arm64) Macs, with optional code signing and notarization.

## Status: ✅ Implemented

## Changes Required

### 1. `scripts/release-macos.sh`

| Line | Current | Change To |
|------|---------|-----------|
| 15 | `MIN_MACOS="13.0"` | `MIN_MACOS="14.0"` (align with Package.swift) |
| 21 | `swift build -c release` | `swift build -c release --arch arm64 --arch x86_64` |
| 82 | `...-arm64.zip` | `...-universal.zip` |
| 88 | `...-arm64.zip` | `...-universal.zip` |

**Note on bin path:** Universal builds still output to the same `--show-bin-path` location. SwiftPM creates a fat binary at the same path, so lines 23-24 don't need changes.

### 2. `scripts/make-dmg.sh`

| Line | Current | Change To |
|------|---------|-----------|
| 19 | `...-arm64.dmg` | `...-universal.dmg` |
| 20 | `...-arm64.dmg` | `...-universal.dmg` |

### 3. `Blaze/Package.swift`
No changes needed - already `.macOS(.v14)`.

## Files to Modify
- `scripts/release-macos.sh` (4 edits)
- `scripts/make-dmg.sh` (2 edits)

## Verification

1. **Build the release:**
   ```bash
   ./scripts/release-macos.sh v0.1.1
   ```

2. **Verify universal binary:**
   ```bash
   lipo -info dist/Blaze.app/Contents/MacOS/Blaze
   # Expected: "Architectures in the fat file are: x86_64 arm64"
   ```

3. **Check artifacts exist:**
   ```bash
   ls -la dist/*.zip dist/*.dmg
   # Should see -universal.zip and -universal.dmg
   ```

4. **Verify Info.plist version:**
   ```bash
   /usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" dist/Blaze.app/Contents/Info.plist
   # Should output: 14.0
   ```

---

## Implementation Todo List

### Phase 1: Script Modifications
| # | Task | Agent | Files |
|---|------|-------|-------|
| 1.1 | Update `MIN_MACOS` from "13.0" to "14.0" | `spark` | `scripts/release-macos.sh:15` |
| 1.2 | Add universal arch flags to build command | `spark` | `scripts/release-macos.sh:21` |
| 1.3 | Rename ZIP artifacts from `arm64` to `universal` | `spark` | `scripts/release-macos.sh:82,88` |
| 1.4 | Rename DMG artifacts from `arm64` to `universal` | `spark` | `scripts/make-dmg.sh:19,20` |

**Agent rationale:** `spark` - these are small, targeted edits (quick fixes).

### Phase 2: Build & Verify
| # | Task | Agent | Command |
|---|------|-------|---------|
| 2.1 | Run release build | `arbiter` | `./scripts/release-macos.sh v0.1.1` |
| 2.2 | Verify universal binary with lipo | `arbiter` | `lipo -info dist/Blaze.app/Contents/MacOS/Blaze` |
| 2.3 | Verify artifacts named correctly | `arbiter` | `ls -la dist/*.zip dist/*.dmg` |
| 2.4 | Verify Info.plist MIN_MACOS | `arbiter` | `PlistBuddy -c "Print :LSMinimumSystemVersion"` |

**Agent rationale:** `arbiter` - validation and test execution.

### Phase 3: Documentation & Commit
| # | Task | Agent | Notes |
|---|------|-------|-------|
| 3.1 | Update README release instructions (if needed) | `scribe` | Only if README mentions arm64 |
| 3.2 | Create commit | `/commit` | Conventional: `build: enable universal binary (arm64 + x86_64)` |

---

## Agent Execution Plan

```
┌─────────────────────────────────────────────────────────┐
│  Phase 1: Implementation                                │
│  Agent: spark                                           │
│  ├── Edit release-macos.sh (4 changes)                  │
│  └── Edit make-dmg.sh (2 changes)                       │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Phase 2: Verification                                  │
│  Agent: arbiter                                         │
│  ├── Run release build                                  │
│  ├── lipo -info (confirm x86_64 + arm64)                │
│  ├── Check artifact names                               │
│  └── Verify Info.plist                                  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Phase 3: Finalize                                      │
│  Skill: /commit                                         │
│  └── Commit changes                                     │
└─────────────────────────────────────────────────────────┘
```

## Estimated Time
- Phase 1: ~2 minutes (simple edits)
- Phase 2: ~5-10 minutes (build time, 2x for universal)
- Phase 3: ~1 minute

**Total: ~15 minutes**

---

## Code Signing & Notarization Setup

### One-Time Setup

#### 1. Find your signing identity
```bash
security find-identity -v -p codesigning
# Look for: "Developer ID Application: Your Name (TEAMID)"
```

#### 2. Create app-specific password
- Go to [appleid.apple.com](https://appleid.apple.com) → Security → App-Specific Passwords
- Generate one named "notarytool"

#### 3. Store credentials in Keychain
```bash
xcrun notarytool store-credentials "blaze-notarize" \
  --apple-id "your@apple.id" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

#### 4. Set environment variables
```bash
export BLAZE_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export BLAZE_NOTARIZE_PROFILE="blaze-notarize"
```

### Usage

**With signing + notarization:**
```bash
export BLAZE_SIGNING_IDENTITY="Developer ID Application: ..."
export BLAZE_NOTARIZE_PROFILE="blaze-notarize"
./scripts/release-macos.sh v0.1.0
```

**Without signing (for local dev):**
```bash
./scripts/release-macos.sh v0.1.0
# Scripts gracefully skip signing when env vars not set
```

### Files Created

- `Blaze/Resources/Blaze.entitlements` - Hardened runtime entitlements

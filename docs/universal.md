# Universal Build Analysis for Blaze

> Research conducted: 2026-01-22
> Purpose: Assess effort to support Intel Macs and older macOS versions

## Executive Summary

| Requirement | Feasibility | Effort |
|-------------|-------------|--------|
| **Intel Mac (x86_64) support** | ✅ Easy | ~30 minutes |
| **macOS 14 (Sonoma) - Current** | ✅ Works | No changes |
| **macOS 13 (Ventura) backport** | ⚠️ Moderate | 2-3 days |
| **macOS 12 (Monterey) backport** | ❌ Not recommended | 1-2 weeks |

**Bottom line:** Universal binary (Intel + Apple Silicon) is trivial. Lowering macOS version below 14 requires significant refactoring due to `@Observable` usage.

---

## Part 1: Intel Mac (x86_64) Support

### Current State
- Build scripts produce **arm64-only** binaries
- Artifact names hardcoded to `arm64`
- No architecture-specific code in the codebase

### All Dependencies Support Intel

| Dependency | Intel x86_64 | Min macOS | Status |
|------------|--------------|-----------|--------|
| GRDB 6.24+ | ✅ Yes | 10.15 | No action needed |
| swift-async-algorithms 1.0+ | ✅ Yes | 10.15 | No action needed |
| swift-collections 1.1+ | ✅ Yes | 10.14.4 | No action needed |
| SwiftUIX (master) | ✅ Yes | 11 | No action needed |
| SwiftTerm 1.0+ | ✅ Yes | 13 | No action needed |
| Inject 1.5.2+ | ✅ Yes | 10.15 | No action needed |

All dependencies are pure Swift and compile from source for any architecture.

### Changes Required for Universal Build

#### 1. Update `scripts/release-macos.sh`

**Line 21 - Build command:**
```bash
# Current:
swift build -c release

# Change to:
swift build -c release --arch arm64 --arch x86_64
```

**Line 23-24 - Binary path:**
```bash
# Current assumes single-arch output:
BIN_DIR="$(swift build -c release --show-bin-path)"

# Universal builds output to .build/apple/Products/Release/
# Need to update path handling
```

**Lines 82, 88 - Artifact naming:**
```bash
# Current:
ZIP="$DIST/${APP_NAME}-macOS-${VER}-arm64.zip"
LATEST_ZIP="$DIST/${APP_NAME}-latest-macOS-arm64.zip"

# Change to:
ZIP="$DIST/${APP_NAME}-macOS-${VER}-universal.zip"
LATEST_ZIP="$DIST/${APP_NAME}-latest-macOS-universal.zip"
```

#### 2. Update `scripts/make-dmg.sh`

**Lines 19-20:**
```bash
# Current:
DMG_VERSIONED="$DIST/${APP_NAME}-macOS-${VER}-arm64.dmg"
DMG_LATEST="$DIST/${APP_NAME}-latest-macOS-arm64.dmg"

# Change to:
DMG_VERSIONED="$DIST/${APP_NAME}-macOS-${VER}-universal.dmg"
DMG_LATEST="$DIST/${APP_NAME}-latest-macOS-universal.dmg"
```

### Verification

After building, verify with:
```bash
lipo -info dist/Blaze.app/Contents/MacOS/Blaze
# Expected: "Architectures in the fat file are: x86_64 arm64"
```

### Trade-offs

| Factor | Impact |
|--------|--------|
| Build time | ~2x longer (compiles twice) |
| Binary size | ~2x larger |
| Testing | Should test x86_64 slice under Rosetta 2 |

---

## Part 2: macOS Version Compatibility

### Current Configuration

| Setting | Value |
|---------|-------|
| Package.swift platform | `.macOS(.v14)` (Sonoma) |
| Info.plist MIN_MACOS | `13.0` (mismatch!) |
| Swift tools version | 5.9 |

**Note:** There's a version mismatch - `MIN_MACOS` in release script says 13.0 but Package.swift requires 14. Should align to 14.

### macOS 14+ APIs in Use (Blockers for Backport)

#### Critical: @Observable Pattern (macOS 14+)

Deeply integrated throughout the app:

| File | Line |
|------|------|
| `Onboarding/OnboardingViewModel.swift` | 314 |
| `Onboarding/TutorialOverlay.swift` | 177 |
| `Registry/RegistryCoordinator.swift` | 11 |
| `Settings/SettingsSearchViewModel.swift` | 10 |
| `Settings/Hooks/HookGanttViewModel.swift` | 30 |
| `Core/Theme/ThemeManager.swift` | 10 |
| `Core/CLI/CLISetupViewModel.swift` | 15 |

**Fallback:** Replace with `ObservableObject` + `@Published`
**Effort:** High - affects state management patterns throughout app

#### @Bindable (macOS 14+)

Used with `@Observable` properties:

| File | Line |
|------|------|
| `Onboarding/PluginsRecommendationsView.swift` | 68 |
| `Onboarding/OnboardingRootView.swift` | 238 |
| `Onboarding/UserProfileView.swift` | 20 |
| `Settings/Hooks/HookGanttView.swift` | 8 |

**Fallback:** Replace with `@ObservedObject`

#### Other macOS 14+ APIs

| API | Files | Fallback |
|-----|-------|----------|
| `UnevenRoundedRectangle` | `ChatTimelineView.swift:360,387,606` | Custom Shape |
| `.symbolEffect(.pulse)` | `EnginesSettingsView.swift:123` | Opacity animation |
| `.scrollContentBackground(.hidden)` | `ContentView.swift:358`, `ToolPromptCard.swift:333` | `.listRowBackground(Color.clear)` |
| `.scrollDismissesKeyboard` | `ChatTimelineView.swift:143` | Remove (no-op on macOS) |
| `.onKeyPress` | `SidebarContainer.swift:67` | NSEvent monitor |

### macOS Version Support Matrix

#### macOS 14 (Sonoma) - Current ✅
- All APIs work as-is
- Supports Intel Macs from 2018+ (8th-gen Coffee Lake)
- **Recommendation:** Stay here

#### macOS 13 (Ventura) - Moderate Effort ⚠️

Would require:
1. Replace all `@Observable` → `ObservableObject` (~7 files)
2. Replace all `@Bindable` → `@ObservedObject` (~4 files)
3. Create custom `UnevenRoundedRectangle` Shape
4. Remove/replace `.symbolEffect`, `.scrollContentBackground`, `.onKeyPress`

**Estimated effort:** 2-3 days
**Additional Intel Macs supported:** 2017 models (Kaby Lake)

#### macOS 12 (Monterey) - Not Recommended ❌

Would additionally require:
- Replace `NavigationSplitView` with deprecated `NavigationView`
- Rewrite `.formStyle` usage
- Fork or downgrade `swift-async-algorithms`
- Many more SwiftUI compatibility shims

**Estimated effort:** 1-2 weeks
**Not worth it** - diminishing user base on macOS 12

---

## Part 3: Notarization (Pending)

### Current State
- App is **not notarized** - users see Gatekeeper warnings
- Apple Developer ID application submitted (2-day wait)

### Integration Steps (Once Approved)

1. **Store credentials** in Keychain or CI secrets:
   ```bash
   APPLE_ID="your@email.com"
   APPLE_TEAM_ID="XXXXXXXXXX"
   APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # From appleid.apple.com
   ```

2. **Update `release-macos.sh`** to notarize after signing:
   ```bash
   # Sign the app
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: Your Name ($APPLE_TEAM_ID)" \
     --options runtime \
     "$APP_BUNDLE"

   # Create ZIP for notarization
   ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"

   # Submit for notarization
   xcrun notarytool submit "$NOTARIZE_ZIP" \
     --apple-id "$APPLE_ID" \
     --team-id "$APPLE_TEAM_ID" \
     --password "$APP_SPECIFIC_PASSWORD" \
     --wait

   # Staple the ticket
   xcrun stapler staple "$APP_BUNDLE"
   ```

3. **Hardened Runtime** requirements:
   - Enable in build settings or via `--options runtime` in codesign
   - May need entitlements for certain features (file access, network, etc.)

---

## Recommendations

### Immediate Actions (Do Now)

1. **Fix version mismatch** - Align `MIN_MACOS` in release script with Package.swift (both should be 14.0)

2. **Enable universal build** - ~30 minutes of script changes to support Intel Macs on macOS 14

### Short-term (Once Developer ID Arrives)

3. **Add notarization** to release pipeline

### Deferred (Low Priority)

4. **macOS 13 backport** - Only if significant user demand. The `@Observable` refactor is substantial.

---

## Appendix: Intel Mac Compatibility by macOS Version

| macOS Version | Intel Macs Supported |
|---------------|---------------------|
| macOS 14 (Sonoma) | 2018+ MacBooks, 2019+ iMacs/Mac Pro |
| macOS 13 (Ventura) | 2017+ MacBooks, 2017+ iMacs |
| macOS 12 (Monterey) | 2015+ MacBooks, 2015+ iMacs |

Staying on macOS 14 still supports a substantial Intel Mac user base (2018-2020 models before Apple Silicon transition).

---

## References

- [Building Swift Packages as a Universal Binary](https://liamnichols.eu/2020/08/01/building-swift-packages-as-a-universal-binary.html)
- [Apple: macOS Sonoma Compatible Computers](https://support.apple.com/en-us/105113)
- [Apple: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

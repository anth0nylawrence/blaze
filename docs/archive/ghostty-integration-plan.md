# Plan: Ghostty Terminal Backend Integration

**Created**: 2026-01-04
**Status**: Draft - Pending User Approval
**Estimated Effort**: 5-8 engineering days (when libghostty available)

---

## Executive Summary

Add Ghostty as an optional terminal backend alongside SwiftTerm. The current architecture is already well-abstracted with a `TerminalBackend` protocol and factory pattern. Ghostty will be available as a settings dropdown option, with SwiftTerm remaining the default.

---

## User Requirements (Captured)

| Requirement | Decision |
|-------------|----------|
| **Primary motivation** | Performance, Terminal compatibility, Future-proofing |
| **Strategy** | Design abstraction now, implement when libghostty ships |
| **Default backend** | SwiftTerm (stable, proven) |
| **User selection** | Settings dropdown to choose terminal backend |
| **Transition** | Feature flag not needed; direct settings toggle |

---

## Current Architecture Assessment

### Strengths (Already Ready)

| Component | Status | Notes |
|-----------|--------|-------|
| `TerminalBackend` protocol | ✅ Excellent | Fully backend-agnostic interface |
| `TerminalBackendFactory` | ✅ Ready | Factory pattern supports multiple backends |
| `TerminalManager` | ✅ Decoupled | Uses `any TerminalBackend`, no SwiftTerm refs |
| Scrollback management | ✅ Separate | Handled by `ScrollbackBuffer`, not backend |
| State tracking | ✅ Generic | `TerminalBackendState` enum works for any backend |
| Async streams | ✅ Modern | Output/state via `AsyncStream<Data>` |

### Current File Structure

```
Sources/Terminal/
├── TerminalBackend.swift      # Protocol + Factory + Types
├── SwiftTermBackend.swift     # SwiftTerm implementation (360 lines)
├── TerminalManager.swift      # Orchestrator (uses any backend)
├── TerminalModels.swift       # Shared models
└── ScrollbackBuffer.swift     # Backend-agnostic scrollback
```

### What Ghostty Would Replace

```
SwiftTermBackend.swift (current)          GhosttyBackend.swift (new)
├── LocalProcess (SwiftTerm PTY)    →     ├── libghostty process spawning
├── Terminal (ANSI emulation)       →     ├── Ghostty VT parsing
├── ProcessDelegate                 →     ├── Ghostty callbacks/events
└── TerminalDelegate                →     └── Ghostty output bridge
```

---

## Ghostty Technical Analysis

### What Is Ghostty?

Ghostty is a terminal emulator written in Zig by Mitchell Hashimoto (HashiCorp founder). Key characteristics:

| Aspect | Details |
|--------|---------|
| **Language** | Zig (with C ABI for interop) |
| **Rendering** | Metal on macOS (GPU-accelerated) |
| **VT Compliance** | Modern VT implementation, high compatibility |
| **Performance** | Designed for speed; competitive with Alacritty/Kitty |
| **License** | MIT License |
| **Status** | Open source since December 2024 |

### libghostty Status

Mitchell Hashimoto announced `libghostty` is coming - an embeddable library version:

- **ghostty-vt**: VT parsing only (already available in ghostty repo)
- **libghostty**: Full embeddable terminal (announced, not yet shipped)

From [mitchellh.com/writing/libghostty-is-coming](https://mitchellh.com/writing/libghostty-is-coming):
> "libghostty will be a C library with stable ABI for embedding Ghostty's terminal emulator in other applications."

### Integration Options

| Option | Availability | Complexity | Capabilities |
|--------|--------------|------------|--------------|
| **ghostty-vt** | Now | Medium | VT parsing only, no rendering |
| **libghostty** | Coming | Low-Medium | Full terminal with rendering |
| **Vendor + build** | Now | High | Full capabilities, maintenance burden |

---

## Comparison: SwiftTerm vs Ghostty

| Feature | SwiftTerm | Ghostty |
|---------|-----------|---------|
| **Language** | Swift | Zig (C ABI) |
| **Rendering** | Custom AppKit/UIKit | Metal (GPU) |
| **Performance** | Good | Excellent |
| **VT Compatibility** | Good | Excellent |
| **Memory** | Moderate | Low |
| **Maintenance** | Active (Miguel de Icaza) | Very Active |
| **Integration** | Native Swift | C FFI required |
| **macOS Support** | Native | Native |
| **Scrollback** | External (our code) | Built-in option |
| **Font rendering** | System | Custom (superior) |

### When to Choose Each

| Use Case | Recommendation |
|----------|----------------|
| Standard terminal sessions | Either works |
| Heavy output (builds, logs) | Ghostty (GPU) |
| Complex ANSI (ncurses apps) | Ghostty (better VT) |
| Minimal dependencies | SwiftTerm |
| Cutting-edge features | Ghostty |
| Stability priority | SwiftTerm |

---

## Implementation Strategy

### Phase 1: Abstraction Preparation (1 day) ✅ ALREADY DONE

The architecture is already abstracted. No changes needed.

### Phase 2: Settings UI (1 day)

**File to modify**: `Sources/UI/Settings/TerminalSettingsView.swift`

```swift
struct TerminalSettingsView: View {
    @AppStorage("terminalBackend") private var backendType: TerminalBackendType = .swiftTerm

    var body: some View {
        Form {
            Section("Terminal Backend") {
                Picker("Default Terminal", selection: $backendType) {
                    Text("SwiftTerm (Stable)").tag(TerminalBackendType.swiftTerm)
                    Text("Ghostty (Experimental)").tag(TerminalBackendType.ghostty)
                }
                .pickerStyle(.menu)

                if backendType == .ghostty {
                    Label("Ghostty requires macOS 14.0+ and Metal GPU", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

### Phase 3: Stub Backend (1 day)

Create placeholder that throws until libghostty available:

**New file**: `Sources/Terminal/GhosttyBackend.swift`

```swift
import Foundation

/// Ghostty terminal backend - STUB until libghostty is available
public actor GhosttyBackend: TerminalBackend {
    public let id = UUID()

    private var _state: TerminalBackendState = .idle
    public var state: TerminalBackendState {
        get async { _state }
    }

    public init() {}

    public func spawn(shell: String, cwd: URL, env: [String: String], size: TerminalSize) async throws {
        throw GhosttyError.notYetAvailable
    }

    public func write(_ data: Data) async {
        // No-op until implemented
    }

    public func write(_ string: String) async {
        await write(string.data(using: .utf8) ?? Data())
    }

    public func resize(_ size: TerminalSize) async {
        // No-op until implemented
    }

    public var output: AsyncStream<Data> {
        get async {
            AsyncStream { _ in }  // Empty stream
        }
    }

    public var stateChanges: AsyncStream<TerminalBackendState> {
        get async {
            AsyncStream { continuation in
                continuation.yield(.terminated(exitCode: nil))
                continuation.finish()
            }
        }
    }

    public func terminate(timeout: TimeInterval) async {
        _state = .terminated(exitCode: nil)
    }

    public func forceTerminate() async {
        _state = .terminated(exitCode: nil)
    }

    public var exitCode: Int32? {
        get async { nil }
    }
}

enum GhosttyError: LocalizedError {
    case notYetAvailable

    var errorDescription: String? {
        switch self {
        case .notYetAvailable:
            return "Ghostty backend is not yet available. libghostty has been announced but not released. Please use SwiftTerm for now."
        }
    }
}
```

### Phase 4: Factory Extension (0.5 day)

**File to modify**: `Sources/Terminal/TerminalBackend.swift`

```swift
public enum TerminalBackendType: String, CaseIterable, Codable {
    case swiftTerm = "SwiftTerm"
    case ghostty = "Ghostty"

    public var displayName: String {
        switch self {
        case .swiftTerm: return "SwiftTerm (Stable)"
        case .ghostty: return "Ghostty (Experimental)"
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .swiftTerm: return true
        case .ghostty: return GhosttyBackend.isAvailable  // Check at runtime
        }
    }
}

public enum TerminalBackendFactory {
    public static func create(type: TerminalBackendType) -> any TerminalBackend {
        switch type {
        case .swiftTerm:
            return SwiftTermBackend()
        case .ghostty:
            return GhosttyBackend()
        }
    }
}
```

### Phase 5: Full Implementation (When libghostty ships) (4-5 days)

**File to modify**: `Sources/Terminal/GhosttyBackend.swift`

```swift
import Foundation
// import libghostty  // When available

public actor GhosttyBackend: TerminalBackend {
    public static var isAvailable: Bool {
        // Check if libghostty is linked
        #if canImport(libghostty)
        return true
        #else
        return false
        #endif
    }

    public let id = UUID()
    private var ghosttyTerminal: OpaquePointer?  // libghostty handle
    private var ptyMaster: Int32 = -1
    private var _state: TerminalBackendState = .idle

    private var outputContinuation: AsyncStream<Data>.Continuation?
    private var stateContinuation: AsyncStream<TerminalBackendState>.Continuation?

    public var state: TerminalBackendState {
        get async { _state }
    }

    public init() {}

    public func spawn(
        shell: String,
        cwd: URL,
        env: [String: String],
        size: TerminalSize
    ) async throws {
        _state = .spawning
        stateContinuation?.yield(.spawning)

        // Initialize libghostty terminal
        // ghosttyTerminal = ghostty_terminal_create(...)

        // Spawn PTY process
        // Use forkpty() similar to PtyProcessRunner
        // Connect PTY to ghostty terminal

        _state = .running(pid: pid)
        stateContinuation?.yield(.running(pid: pid))

        // Start output reading task
        Task { await readOutput() }
    }

    private func readOutput() async {
        // Read from PTY, feed to ghostty, emit rendered output
        while ptyMaster >= 0 {
            // var buffer = [UInt8](repeating: 0, count: 4096)
            // let bytesRead = read(ptyMaster, &buffer, buffer.count)
            // if bytesRead > 0 {
            //     ghostty_terminal_feed(ghosttyTerminal, buffer, bytesRead)
            //     let rendered = ghostty_terminal_get_output(ghosttyTerminal)
            //     outputContinuation?.yield(rendered)
            // }
        }
    }

    public func write(_ data: Data) async {
        guard ptyMaster >= 0 else { return }
        data.withUnsafeBytes { ptr in
            _ = Darwin.write(ptyMaster, ptr.baseAddress, data.count)
        }
    }

    public func resize(_ size: TerminalSize) async {
        // ghostty_terminal_resize(ghosttyTerminal, size.cols, size.rows)
        // Send SIGWINCH to PTY
    }

    public var output: AsyncStream<Data> {
        get async {
            AsyncStream { continuation in
                self.outputContinuation = continuation
            }
        }
    }

    public var stateChanges: AsyncStream<TerminalBackendState> {
        get async {
            AsyncStream { continuation in
                self.stateContinuation = continuation
            }
        }
    }

    public func terminate(timeout: TimeInterval) async {
        // Graceful shutdown
        // ghostty_terminal_destroy(ghosttyTerminal)
        close(ptyMaster)
        ptyMaster = -1
        _state = .terminated(exitCode: 0)
        stateContinuation?.yield(.terminated(exitCode: 0))
    }

    public func forceTerminate() async {
        // Force kill
        close(ptyMaster)
        ptyMaster = -1
        _state = .terminated(exitCode: -9)
        stateContinuation?.yield(.terminated(exitCode: -9))
    }

    public var exitCode: Int32? {
        get async {
            if case .terminated(let code) = _state {
                return code
            }
            return nil
        }
    }
}
```

---

## Build Integration

### When libghostty Ships

1. **Add as Swift Package dependency** (if distributed as SPM):
   ```swift
   // Package.swift
   dependencies: [
       .package(url: "https://github.com/ghostty-org/libghostty", from: "1.0.0")
   ]
   ```

2. **Or vendor as submodule** (if C library):
   ```bash
   git submodule add https://github.com/ghostty-org/ghostty vendor/ghostty
   ```

3. **Create module map** (if C library):
   ```modulemap
   module libghostty {
       header "ghostty.h"
       link "ghostty"
       export *
   }
   ```

---

## Files Summary

### New Files (2)
1. `Sources/Terminal/GhosttyBackend.swift` - Backend implementation
2. `Sources/UI/Settings/TerminalSettingsView.swift` - Settings UI (if not exists)

### Modified Files (2)
1. `Sources/Terminal/TerminalBackend.swift` - Add enum case + factory
2. `Sources/UI/Settings/SettingsView.swift` - Add terminal section

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| libghostty never ships | Low | Medium | SwiftTerm works fine; stub stays |
| libghostty API changes | Medium | Medium | Wait for stable release before integrating |
| Zig/C FFI complexity | Medium | Medium | Use Swift's C interop, create thin wrapper |
| Performance regression | Low | High | Benchmark before shipping; keep SwiftTerm |
| Metal not available | Low | Low | Fall back to SwiftTerm on older GPUs |

---

## Testing Strategy

### Unit Tests
- GhosttyBackend: spawn, write, resize, terminate
- Factory: correct backend returned for each type
- Settings: persistence of backend choice

### Integration Tests
- Switch backend mid-session: graceful handling
- Run same command in both backends: output parity
- Heavy output: performance comparison

### Comparison Tests
- Run `ls -la /` in both backends, compare output
- Run `htop` in both backends, verify ANSI rendering
- Run `git log --graph --oneline` for complex ANSI

---

## Success Criteria

- [ ] Settings UI shows backend dropdown
- [ ] SwiftTerm remains default
- [ ] Ghostty stub throws informative error when selected
- [ ] When libghostty ships: full implementation works
- [ ] Performance equal or better than SwiftTerm
- [ ] No regressions in terminal compatibility
- [ ] Scrollback works identically in both backends

---

## Timeline

| Phase | Status | When |
|-------|--------|------|
| Abstraction ready | ✅ Done | Now |
| Settings UI | Ready to implement | 1 day |
| Stub backend | Ready to implement | 1 day |
| Full implementation | Blocked on libghostty | TBD |

**Recommendation**: Implement phases 2-4 now (2 days), wait for libghostty for phase 5.

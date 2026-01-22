# Cogit0 Blaze Cross-Platform Research

**Date:** 2025-12-25
**Status:** Research Complete (Updated with 2025 Data)
**Author:** CTO/Architect

---

## 2025 Data Update

### Stack Overflow 2025 Developer Survey (49,000+ responses)

| Platform | Usage |
|----------|-------|
| **Windows** | ~48% professional use |
| **macOS** | ~33% professional use |
| **Ubuntu** | ~28% |
| **Android** | 29% personal use (+11% YoY) |

**Source:** [Stack Overflow 2025 Survey](https://survey.stackoverflow.co/2025/technology)

### Claude Code 2025 Statistics

| Metric | Value | Change |
|--------|-------|--------|
| **Active User Growth** | +300% | Since Claude 4 launch (May 2025) |
| **Run-rate Revenue Growth** | 5.5x | Since Claude 4 launch |
| **Windows Support** | Native | No longer requires WSL |
| **Web Version** | Beta | Launched November 2025 |

**Source:** [The New Stack - Claude Code Enterprise Dashboard](https://thenewstack.io/claude-code-user-base-grows-300-as-anthropic-launches-enterprise-analytics-dashboard/)

### AI Coding Tool Market 2025

| Tool | Paying Users | ARR | Valuation |
|------|--------------|-----|-----------|
| **Cursor** | 360,000+ | $200M (Q1 2025) | $9B |
| **Windsurf** | 1M+ developers | ~$30M | Acquired by OpenAI ($3B) |
| **GitHub Copilot** | 1.8M paid | $500M | (Microsoft) |

**Key development:** OpenAI acquired Windsurf for $3 billion, signaling strategic expansion in AI coding.

**Sources:** [DEV Community - Cursor vs Windsurf](https://dev.to/blamsa0mine/cursor-vs-windsurf-2025-a-deep-dive-into-the-two-fastest-growing-ai-ides-2112)

### Tauri 2.0 (Late 2024 - 2025)

| Metric | Tauri 2.0 | Electron |
|--------|-----------|----------|
| **Bundle Size** | 2-10 MB | 85-150 MB |
| **Memory (Idle)** | 30-40 MB | 200-400 MB |
| **Startup Time** | <500ms | 1-2s |
| **Adoption Growth** | +35% YoY | Stable |

**New in Tauri 2.0:**
- Mobile support (Android/iOS)
- Rewritten IPC layer for performance
- Granular permissions system
- Plugin architecture

**Source:** [Tauri 2.0 Official](https://tauriapp.com/)

### SwiftUI macOS 2025 (macOS 26)

- **List performance:** Now handles 10,000+ items smoothly (previously ~3,000 limit)
- **Industry adoption:** 70-80% of iOS jobs still require UIKit, but SwiftUI gaining fast
- **Cross-platform potential:** SwiftUI remains Apple-only, but architecture could theoretically sit above GTK/Qt

**Source:** [SwiftUI for Mac 2025 - TrozWare](https://troz.net/post/2025/swiftui-mac-2025/)

---

## Recommended Approach: SwiftUI (macOS) → Tauri (Windows/Linux)

### Validation: This is the RIGHT approach

Your proposed strategy—**SwiftUI for macOS first, then Tauri for Windows/Linux**—is strongly validated by the 2025 data:

#### Why This Works

| Factor | Evidence | Implication |
|--------|----------|-------------|
| **Target market concentration** | 33% of professional devs on macOS; Claude Code power users over-index here | Launch where your best customers are |
| **Native performance moat** | SwiftUI lists now handle 10K+ items; Cursor/Windsurf are Electron-based | Native SwiftUI is a genuine differentiator |
| **Tauri maturity** | 2.0 released late 2024; +35% YoY adoption; IPC rewritten for performance | Tauri is production-ready for Phase 2 |
| **Claude Code momentum** | +300% user growth; native Windows support added | Growing market to serve |
| **Competitive timing** | OpenAI just acquired Windsurf for $3B; market is consolidating | Ship macOS fast, expand methodically |

#### Architecture Advantages

```
Phase 1: macOS Native                    Phase 2: Cross-Platform
┌────────────────────────┐              ┌────────────────────────┐
│   SwiftUI UI Layer     │              │   Tauri (Web UI)       │
│   (Best-in-class UX)   │              │   (Windows/Linux)      │
├────────────────────────┤              ├────────────────────────┤
│   Pure Swift Modules   │ ──────────▶  │   Rust Core (ported)   │
│   - ProcessRunner      │   Port to    │   or Swift (if mature) │
│   - EventStore         │    Rust      ├────────────────────────┤
│   - PolicyEngine       │              │   Keep SwiftUI for Mac │
│   - EngineAdapters     │              │   (Premium experience) │
└────────────────────────┘              └────────────────────────┘
```

#### Execution Timeline

| Phase | Timeline | Platform | Key Milestone |
|-------|----------|----------|---------------|
| **1. Ship macOS** | Months 1-6 | SwiftUI | MVP → Daily Driver |
| **2. Stabilize & Extract** | Months 6-9 | SwiftUI | Extract pure Swift modules, define FFI boundaries |
| **3. Port Core to Rust** | Months 9-12 | Rust | ProcessRunner, EventStore, PolicyEngine |
| **4. Build Tauri Windows** | Months 10-14 | Tauri | Windows app with Rust core |
| **5. Add Linux** | Months 14-18 | Tauri | Complete platform coverage |

#### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| **SwiftUI not portable** | This is expected—UI is ~30-40% of code; business logic (60-70%) is portable |
| **Tauri learning curve** | Rust core can be developed incrementally while macOS ships |
| **Windows users waiting** | Public roadmap with waitlist; beta access for early adopters |
| **Two codebases** | Worth it—native macOS UX is the competitive moat |

#### Why NOT Alternatives

| Alternative | Reason to Reject |
|-------------|------------------|
| **Electron everywhere** | Conflicts with "native performance" positioning; Cursor/Windsurf already use it |
| **Flutter everywhere** | Desktop deprioritized by Flutter team; requires Dart expertise |
| **Cross-platform from Day 1** | Delays launch, compromises macOS UX, premature optimization |
| **Skip Tauri, use Swift everywhere** | Swift cross-platform UI (Swift Cross UI) is too immature |

### Bottom Line

**Your instinct is correct.** SwiftUI → Tauri is the optimal path because:

1. **Ship fast on macOS** where your best customers are
2. **Native SwiftUI performance** is a real moat against Electron-based competitors
3. **Tauri 2.0 is mature enough** for production Windows/Linux apps
4. **Business logic is portable** (60-70%), so you're not throwing away work
5. **Two UIs is worth it** for best-in-class experience on each platform

---

## Executive Summary

This document analyzes cross-platform options for Cogit0 Blaze and provides market research on Claude Code's user base to inform the platform strategy decision.

**Key Findings:**

1. **macOS-first is the right initial strategy** - Developer tool market data strongly supports this approach, with ~32% of professional developers on macOS and even higher concentration among "power developers" who are the primary target audience.

2. **Cross-platform Swift is not viable** - SwiftUI does not work on Windows/Linux. Swift-based alternatives (Skip, Swift Cross UI) are either Android-only or immature.

3. **Tauri is the recommended cross-platform path** - If/when we expand beyond macOS, Tauri (Rust + web frontend) offers the best performance, smallest bundle size, and allows sharing core logic across platforms.

4. **Architecture changes now can ease future porting** - ProcessRunner, EventStore, and engine adapters can be designed with portability in mind. The UI layer is inherently non-portable.

5. **Windows expansion timing: 6-12 months post-launch** - Based on market data and competitive analysis, expanding to Windows when macOS product is "excellent" (per PRD) is the right call.

---

## Part 1: Cross-Platform Technical Options

### 1.1 Swift-Based Approaches

#### Swift Language Cross-Platform Status (2024-2025)

Swift 6 (released September 2024) significantly improved cross-platform support:

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | Stable | First-class support |
| Linux | Stable | Ubuntu, Debian, Fedora, Red Hat, Amazon Linux supported |
| Windows | Stable | x86_64 and arm64 architectures |
| Android | In Progress | Swift-Android Working Group launched June 2025 |

**Sources:**
- [Swift 6 Officially Available - InfoQ](https://www.infoq.com/news/2024/09/swift-6-officially-available/)
- [Apple's Swift Working to Support Android - MacRumors](https://www.macrumors.com/2025/06/27/swift-to-support-android-app-development/)

#### SwiftUI Cross-Platform Limitations

**Critical Finding: SwiftUI is NOT cross-platform.**

SwiftUI is not part of the Open Source Swift Project. Apple ships the APIs needed for SwiftUI to function in the OS itself. Unless someone reverse-engineers all features and ships them as a cross-platform library, SwiftUI apps cannot run natively on Windows or Linux.

This means **Cogit0 Blaze's SwiftUI-based UI cannot be ported to Windows/Linux** without a complete rewrite.

**Sources:**
- [SwiftUI for non-Apple platforms - Swift Forums](https://forums.swift.org/t/swiftui-for-non-apple-platforms-like-android-web-windows/25455)
- [Cross-platform UI for Swift - Swift Forums](https://forums.swift.org/t/a-cross-platform-ui-for-swift/59787)

#### Skip.tools (Swift to Kotlin Transpiler)

Skip transpiles Swift/SwiftUI code to Kotlin/Jetpack Compose for Android:

| Aspect | Assessment |
|--------|------------|
| **Target** | Android only (not Windows/Linux) |
| **UI Approach** | Transpiles SwiftUI to Jetpack Compose |
| **Maturity** | Production-ready as of December 2024 |
| **Ejectability** | Can "eject" and maintain Kotlin separately |
| **Limitations** | Desktop platforms not supported |

**December 2024 Update:** Skip released native compiled Swift technology preview, allowing native Swift packages in Android apps via SkipFuse framework.

**Verdict:** Skip is excellent for iOS-to-Android, but **does not help with Windows/Linux desktop**.

**Sources:**
- [Skip.tools Documentation](https://skip.tools/docs/modes/)
- [Skip December 2024 Newsletter](https://skip.tools/blog/newsletter-december-2024/)
- [SkipUI on GitHub](https://github.com/skiptools/skip-ui)

#### Swift Cross UI

An open-source SwiftUI-like framework for cross-platform Swift:

| Platform | Backend |
|----------|---------|
| macOS | AppKitBackend |
| Windows | WinUIBackend |
| Linux | GtkBackend |
| iOS/tvOS | UIKitBackend |

**Limitations:**
- Does not replicate SwiftUI API perfectly
- "Built-in views and scenes share much of their API surface" but not identical
- Would require significant code changes from SwiftUI
- Less mature ecosystem than native SwiftUI

**Verdict:** Possible but requires significant rewrite. Not recommended for production app.

**Source:** [Swift Cross UI on GitHub](https://github.com/stackotter/swift-cross-ui)

### 1.2 Cogit0 Blaze Component Portability Analysis

Based on the PRD architecture, here's what's portable vs macOS-specific:

| Component | Portability | Notes |
|-----------|-------------|-------|
| **ProcessRunner** | High | Process spawning is cross-platform in Swift |
| **NDJSON Parser** | High | Pure Swift, no platform dependencies |
| **EventStore (SQLite)** | High | SQLite works everywhere |
| **EventStore (JSONL)** | High | File I/O is cross-platform |
| **NormalizedEvent Types** | High | Pure Swift data types |
| **EngineAdapter Protocol** | High | Protocol + logic is portable |
| **ClaudeCodeAdapter** | Medium | CLI invocation portable, but paths differ |
| **PolicyEngine** | High | Pure logic, no UI dependencies |
| **HookRunner** | Medium | Process spawning portable, sandbox differs |
| **SwiftUI Views** | None | macOS-only, requires complete rewrite |
| **Command Palette** | None | SwiftUI component |
| **Diff Viewer** | None | SwiftUI component |
| **Sparkle Auto-Updates** | None | macOS-only framework |

**Key Insight:** ~60-70% of the business logic is portable. The entire UI layer (30-40% of code) requires rewriting for any non-macOS platform.

### 1.3 Alternative Cross-Platform Frameworks

#### Tauri (Rust + Web Frontend)

**Architecture:** Rust backend + web frontend (HTML/CSS/JS) using OS-native webview.

| Metric | Tauri | Electron |
|--------|-------|----------|
| **Installer Size** | ~2.5-10 MB | ~85-120 MB |
| **Memory (Idle)** | 30-40 MB | 200-400 MB |
| **Startup Time** | <0.5s | 1-2s |
| **Rendering** | Native webview (WebView2/WebKit/WebKitGTK) | Bundled Chromium |

**Advantages:**
- Smallest bundle size and memory footprint
- Rust backend for performance-critical operations
- OS-native webview means consistent behavior (mostly)
- 35% YoY adoption growth after Tauri 2.0 (late 2024)

**Disadvantages:**
- WebView differences between platforms (some API inconsistencies)
- Steeper learning curve (Rust + web + platform knowledge)
- Smaller ecosystem than Electron

**Productivity app case study:** Switching from Electron to Tauri reduced installer from 120MB to 8MB and cut cold-start time by 70%.

**Verdict:** **Best choice for cross-platform if we move away from native SwiftUI.** Aligns with PRD's performance requirements.

**Sources:**
- [Tauri vs Electron - Levminer](https://www.levminer.com/blog/tauri-vs-electron)
- [Tauri vs Electron - gethopp.app](https://www.gethopp.app/blog/tauri-vs-electron)
- [Tauri vs Electron 2025 - Codeology](https://codeology.co.nz/articles/tauri-vs-electron-2025-desktop-development.html)

#### Electron

**Architecture:** Bundled Chromium + Node.js + custom backend.

| Aspect | Assessment |
|--------|------------|
| **Market Share** | 60% of cross-platform apps (2024 Stack Overflow) |
| **Ecosystem** | Massive - VS Code, Slack, Discord built on it |
| **Performance** | Higher memory, slower startup |
| **Bundle Size** | 85-150 MB typical |

**Advantages:**
- Proven at scale (VS Code handles large codebases)
- Massive npm ecosystem
- Consistent rendering across platforms
- Extensive documentation and community

**Disadvantages:**
- Memory hungry (each app bundles full Chromium)
- Slower startup times
- Contradicts PRD principle: "Native macOS performance: 60fps scrolling, instant command palette, no Electron overhead"

**Verdict:** Viable but **conflicts with PRD's native performance positioning**. Would undermine competitive moat vs Cursor/Windsurf (both are VS Code/Electron forks).

**Sources:**
- [Tauri vs Electron - DEV Community](https://dev.to/vorillaz/tauri-vs-electron-a-technical-comparison-5f37)
- [LogRocket Tauri vs Electron](https://blog.logrocket.com/tauri-electron-comparison-migration-guide/)

#### Flutter Desktop

**Architecture:** Dart language + Skia rendering engine.

| Aspect | Assessment |
|--------|------------|
| **Platform Support** | Windows, macOS, Linux (stable since 2022) |
| **Adoption** | macOS: 24.1%, Windows: 20.1%, Linux: 11.2% |
| **Rendering** | GPU-driven via Impeller (stable 2025) |
| **Desktop Priority** | Lower than mobile (Flutter team deprioritized desktop) |

**Advantages:**
- Single Dart codebase
- Hot reload for fast development
- Good performance via native compilation
- Growing plugin ecosystem for desktop

**Disadvantages:**
- Desktop not prioritized by Flutter team (per 2024 roadmap)
- Platform views (embedding native views) not stable on desktop
- Would require learning Dart and rewriting everything
- Smaller desktop-specific ecosystem

**Verdict:** Good option but **team bandwidth required for Dart expertise**. Desktop deprioritization is concerning for long-term.

**Sources:**
- [Flutter Desktop Documentation](https://docs.flutter.dev/platform-integration/desktop)
- [Flutter Roadmap 2025](https://dev.to/bestaoui_aymen/flutter-roadmap-2025-what-you-should-learn-to-stay-ahead-3b18)
- [Flutter Desktop 2024 - Medium](https://medium.com/@Kevin_Finnerty_Gabagool/flutter-desktop-apps-in-2024-099e94b40962)

#### .NET MAUI vs Avalonia UI

| Framework | Windows | macOS | Linux | Verdict |
|-----------|---------|-------|-------|---------|
| **.NET MAUI** | Good | Poor (Mac Catalyst) | None | Not recommended |
| **Avalonia UI** | Good | Good | Good | Better .NET option |

**MAUI Issues:**
- macOS uses Mac Catalyst (iOS app shoehorned to desktop) - "performance was horrible"
- No Linux support planned
- 3-6x slower than Avalonia on benchmarks

**Avalonia Advantages:**
- True cross-platform rendering (like Qt/Flutter)
- 1.8M LOLs/sec on macOS vs MAUI's 212K
- Full Linux support
- Used by JetBrains tools

**Verdict:** If considering .NET, use Avalonia. But **requires .NET/C# expertise and complete rewrite**.

**Sources:**
- [Avalonia vs MAUI - Avalonia UI](https://avaloniaui.net/maui-compare)
- [.NET Cross-Platform Showdown - DEV Community](https://dev.to/biozal/the-net-cross-platform-showdown-maui-vs-uno-vs-avalonia-and-why-avalonia-won-ian)

#### Compose Multiplatform (Kotlin)

**Status:** Stable for Android, iOS, and Desktop as of 2024-2025.

| Aspect | Assessment |
|--------|------------|
| **Desktop Support** | Stable (Windows, macOS, Linux) |
| **iOS Support** | Stable as of May 2025 (Compose 1.8.0) |
| **Production Use** | Netflix, BiliBili, Wrike using in production |
| **Tooling** | IntelliJ IDEA, Android Studio |

**Advantages:**
- Kotlin is pleasant to use
- JetBrains backing
- Shared UI across all platforms
- Good interop with Java ecosystem

**Disadvantages:**
- Requires Kotlin expertise
- Complete rewrite from Swift
- JVM overhead on desktop

**Verdict:** Viable if team has Kotlin expertise. Otherwise, significant learning curve.

**Sources:**
- [Compose Multiplatform - JetBrains](https://www.jetbrains.com/compose-multiplatform/)
- [KMP Production Ready 2025 - Volpis](https://volpis.com/blog/is-kotlin-multiplatform-production-ready/)

### 1.4 Hybrid Approaches

#### Option A: Keep macOS Native, Build Separate Windows App

| Approach | Effort | Consistency | Maintenance |
|----------|--------|-------------|-------------|
| SwiftUI (macOS) + Tauri (Windows/Linux) | High | Low | 2 codebases |
| SwiftUI (macOS) + Electron (Windows/Linux) | High | Low | 2 codebases |
| SwiftUI (macOS) + Flutter (Windows/Linux) | High | Low | 2 codebases |

**Pros:**
- Best possible macOS experience (native SwiftUI)
- Can optimize each platform independently
- No compromises on macOS performance

**Cons:**
- Double maintenance burden
- Feature parity challenges
- Different bugs on different platforms

#### Option B: Shared Rust Core + Platform-Specific UIs

**Architecture Pattern:** Crux framework or custom UniFFI-based approach.

```
+------------------+     +------------------+     +------------------+
|   SwiftUI UI     |     |   Tauri/Web UI   |     |   GTK/Qt UI      |
|   (macOS)        |     |   (Windows)      |     |   (Linux)        |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         v                        v                        v
+------------------------------------------------------------------------+
|                    Shared Rust Core (via FFI)                          |
|  - ProcessRunner                                                        |
|  - EventStore                                                           |
|  - NDJSON Parser                                                        |
|  - PolicyEngine                                                         |
|  - EngineAdapters                                                       |
+------------------------------------------------------------------------+
```

**Crux Framework:**
- Splits app into Rust Core (business logic) and Shell (platform UI)
- Core is side-effect free, making it portable and testable
- Type-safe FFI with generated Swift/Kotlin/TypeScript bindings
- Used by Mozilla and Lyft in production mobile apps

**Pros:**
- Maximum code reuse for business logic (~60-70% of app)
- Best-in-class UI on each platform
- Rust core is fast and memory-safe
- Clear separation of concerns

**Cons:**
- Highest initial investment
- Requires Rust expertise
- Still need to build 3 different UIs
- FFI complexity

**Verdict:** **Best long-term architecture** if cross-platform is certain. High upfront cost but scales well.

**Sources:**
- [Crux Framework](https://redbadger.github.io/crux/)
- [Mobile App Core in Rust](https://typester.dev/blog/2024/11/14/mobile-app-development-with-rust)

#### Option C: Full Rewrite in Tauri

**Approach:** Rebuild entire app in Tauri from start.

**Pros:**
- Single codebase for all platforms
- Excellent performance (Rust backend)
- Small bundle size
- Web frontend skills are common

**Cons:**
- Loses native SwiftUI advantages on macOS
- Delays macOS launch significantly
- Web UI may not match native "buttery" feel

**Verdict:** Only consider if cross-platform is Day 1 requirement. **Not recommended given PRD's macOS-first strategy.**

### 1.5 Recommended Architecture Strategy

**Short-term (0-6 months):** Ship macOS-native SwiftUI app as planned.

**Medium-term (6-12 months):** Refactor core components for portability:
1. Extract ProcessRunner, EventStore, PolicyEngine into pure Swift modules
2. Define clear FFI boundary for future Rust port
3. Add comprehensive test coverage to core logic

**Long-term (12-18 months):** When expanding to Windows:
1. Port core logic to Rust (or keep Swift with cross-platform Swift)
2. Build Tauri-based UI for Windows/Linux
3. Maintain SwiftUI for macOS (best-in-class experience)

**Rationale:** This preserves the PRD's competitive moat ("Native macOS performance") while preparing for future expansion without premature optimization.

---

## Part 2: Claude Code Market Research

### 2.1 Developer Platform Statistics

#### Stack Overflow 2024 Developer Survey

Survey of 65,437 developers (May-June 2024):

| Platform | Personal Use | Professional Use |
|----------|--------------|------------------|
| **Windows** | 59.2% | 47.6% |
| **macOS** | 31.8% | 33.2% |
| **Ubuntu** | 27.7% | 27.7% |
| **Debian** | 9.8% | ~10% |
| **Arch Linux** | 8.0% | ~8% |
| **WSL** | 17.1% | 16.8% |

**Key Insights:**
- Windows dominates overall but drops 11.6% from personal to professional use
- macOS is slightly higher for professional developers (33.2%)
- Linux (all distros combined) roughly matches macOS at ~30%
- Many Windows developers use WSL, indicating Linux toolchain preference

**Sources:**
- [Stack Overflow 2024 Survey - Technology](https://survey.stackoverflow.co/2024/technology)
- [Developer OS Preference Statistics](https://commandlinux.com/statistics/developer-os-preference-stack-overflow-survey/)

#### JetBrains 2024 Developer Ecosystem Survey

Survey of 23,262 developers (May-June 2024):

The JetBrains survey covered 672 questions with participants spending ~30 minutes on average. Key findings about AI adoption:
- 4 out of 5 companies use third-party AI tools in development
- 18% of developers incorporate AI capabilities into their products

**Note:** Specific OS breakdown percentages were not included in available search results.

**Source:** [JetBrains Developer Ecosystem 2024](https://www.jetbrains.com/lp/devecosystem-2024/)

#### Power Developer / AI-Focused Developer Segment

Based on available data, "power developers" (senior engineers, AI-focused developers, startup founders) skew toward macOS:

| Indicator | Data Point |
|-----------|------------|
| Professional dev macOS usage | 33.2% (vs 31.8% personal) |
| AI coding tool early adopters | Heavily macOS-based (Cursor, Claude Code CLI) |
| CLI tool preference | Homebrew (macOS) leading distribution method |

**Inference:** Cogit0 Blaze's target users (per PRD: "Power users already using Claude Code CLI heavily") likely over-index on macOS relative to general developer population.

### 2.2 Claude Code Specific Data

#### Claude Code Adoption & Revenue

| Metric | Value | Date |
|--------|-------|------|
| **Run-rate Revenue** | $1 billion | November 2025 |
| **Revenue Growth** | 5.5x since Claude 4 launch | May-August 2025 |
| **AI Coding Market Share** | >50% | 2025 |
| **Code Generation Preference** | 42% market share | 2025 |

**Enterprise Clients:** Netflix, Spotify, KPMG, L'Oreal, Salesforce

**Partnership:** 30,000 Accenture professionals being trained on Claude

**Sources:**
- [Claude AI Statistics - SEO Sandwitch](https://seosandwitch.com/claude-ai-statistics/)
- [Anthropic Enterprise Market Share - Technology.org](https://www.technology.org/2025/08/02/anthropic-claude-models-capture-32-enterprise-market-share-overtaking-openai-in-business-ai-adoption/)

#### CLI Tool Adoption Patterns

| Distribution Method | Ecosystem | User Type |
|--------------------|-----------|-----------|
| **Homebrew** | macOS/Linux | Power users, developers |
| **npm** | Cross-platform | Node.js developers |
| **Direct download** | Cross-platform | Enterprise, offline |

Claude Code CLI is distributed via npm (`npm install -g @anthropic-ai/claude-code`), which works cross-platform but requires Node.js.

**Inference:** npm distribution supports all platforms equally, but early adopters and power users trend toward macOS (Homebrew culture, Unix toolchain preference).

#### Anthropic Target Audience

From Anthropic's positioning:
- Claude Code targets developers who want "agentic command line tool that enables developers to delegate coding tasks directly from their terminal"
- Focus on professional/enterprise developers
- Terminal-first users (comfortable with CLI)

**Inference:** This audience profile aligns with macOS power users (developers comfortable with Unix terminal, CLI tools, modern dev workflows).

### 2.3 Competitive Analysis

#### Platform Support Comparison

| Tool | macOS | Windows | Linux | Launch Strategy |
|------|-------|---------|-------|-----------------|
| **Cursor** | Yes | Yes | Yes | Cross-platform from start (VS Code fork) |
| **Windsurf** | Yes | Yes | Yes | Cross-platform from start (VS Code fork) |
| **Continue.dev** | Yes | Yes | Yes | VS Code extension (cross-platform) |
| **GitHub Copilot** | Yes | Yes | Yes | VS Code extension first, then IDE expansion |
| **Claude Code CLI** | Yes | Yes | Yes | npm (cross-platform) |
| **Zed** | Yes | Yes | In progress | macOS-first, then Windows, Linux coming |

**Key Observation:** Most AI coding tools launched cross-platform because they're VS Code forks or extensions. Zed (native editor) launched macOS-first, similar to Blaze's strategy.

#### Market Share Data

| Tool | Market Share | Users | Growth |
|------|--------------|-------|--------|
| **GitHub Copilot** | ~42% | 20M total, 1.8M paid | Dominant but share declining |
| **Cursor** | ~18% | 500K+ active | Fastest growing (was near-zero in 2024) |
| **Claude Code** | ~42% (code gen preference) | N/A | Rapidly growing |
| **Amazon Q** | ~11% | N/A | AWS-centric |

**Shift in 2025:** Copilot's share of AI-assisted PRs dropped from 80% (January) to 60% (October). Cursor grew from 20% to 40% in same period.

**Sources:**
- [GitHub Copilot Statistics 2025](https://www.secondtalent.com/resources/github-copilot-statistics/)
- [AI Coding Assistants 2026 Enterprise Guide](https://axis-intelligence.com/ai-coding-assistants-2026-enterprise-guide/)
- [Jellyfish 2025 AI Metrics](https://jellyfish.co/blog/2025-ai-metrics-in-review/)

#### Cursor and Windsurf Deep Dive

Both are VS Code forks with AI features:

| Aspect | Cursor | Windsurf |
|--------|--------|----------|
| **Valuation** | $9B (Dec 2024) | $2.75B |
| **ARR** | $200M (Q1 2025) | $30M (early 2025) |
| **Users** | 360K+ paying | 800K+ (Codeium base) |
| **Model** | Claude 3.5 Sonnet under hood | Claude 3.5 Sonnet under hood |
| **Focus** | Developer productivity | Enterprise (SOC 2, self-host) |

**Insight:** Both use Claude under the hood. Blaze could complement these tools (governance layer for Claude Code) rather than compete directly.

**Sources:**
- [Windsurf vs Cursor - Builder.io](https://www.builder.io/blog/windsurf-vs-cursor)
- [Cursor vs Windsurf 2025 - DEV Community](https://dev.to/blamsa0mine/cursor-vs-windsurf-2025-a-deep-dive-into-the-two-fastest-growing-ai-ides-2112)

### 2.4 Strategic Analysis

#### Should Blaze Stay macOS-Only Longer?

**Arguments FOR staying macOS-only:**

1. **Target audience concentration:** Power developers and Claude Code early adopters over-index on macOS (~33% of professional devs)

2. **PRD alignment:** "Windows/Linux support (until macOS is excellent)" - validates focus

3. **Competitive differentiation:** Native performance is a moat. Cursor/Windsurf are Electron-based; native SwiftUI is genuinely faster.

4. **Resource efficiency:** Single platform = faster iteration, fewer bugs, better UX

5. **Precedent:** Zed (successful native editor) launched macOS-first, now expanding

**Arguments AGAINST staying macOS-only:**

1. **Market size:** Windows has 47.6% of professional developers vs macOS's 33.2%

2. **Enterprise requirements:** Many enterprises are Windows-dominant

3. **Claude Code is cross-platform:** Users may expect Blaze to be too

4. **Competitive pressure:** Cursor/Windsurf are already cross-platform

#### Recommended Timing for Platform Expansion

| Phase | Timeline | Platform | Rationale |
|-------|----------|----------|-----------|
| **Launch** | Months 1-6 | macOS only | Validate product-market fit with power users |
| **Stabilize** | Months 6-9 | macOS only | Polish UX, build policy/hook ecosystem |
| **Expand** | Months 9-12 | + Windows | 47.6% market, enterprise demand |
| **Complete** | Months 12-18 | + Linux | Developer completeness, 27% market |

#### Cost/Benefit Analysis

| Approach | Development Cost | Market Reach | UX Quality | Risk |
|----------|------------------|--------------|------------|------|
| **macOS-only (current)** | 1x | 33% | Excellent | Low |
| **+ Windows (Tauri)** | 1.5x | 80% | Good | Medium |
| **+ Linux (Tauri)** | 1.7x | ~100% | Good | Medium |
| **Cross-platform from start** | 2x | ~100% | Compromised | High |

**Recommendation:** macOS-first for 6-9 months, then Windows via Tauri, then Linux. This maximizes quality while eventually addressing the full market.

---

## Part 3: Recommendations

### 3.1 Technical Architecture Recommendations

1. **Keep SwiftUI for macOS** - Do not compromise native experience to chase cross-platform prematurely

2. **Design for portability now:**
   - Keep business logic in pure Swift modules (no UIKit/AppKit/SwiftUI imports)
   - Use dependency injection for platform-specific features
   - Document FFI boundaries for future Rust port

3. **Prepare for Tauri-based Windows/Linux:**
   - When ready, build Tauri app with TypeScript/React frontend
   - Port core logic to Rust or use Swift cross-platform (if mature enough)
   - Accept that Windows/Linux UX will be "good" not "excellent"

4. **Do NOT use:**
   - Electron (conflicts with native performance positioning)
   - .NET MAUI (poor macOS support)
   - Full cross-platform rewrite now (delays launch, reduces quality)

### 3.2 Market Strategy Recommendations

1. **Launch macOS-only** - Target market (Claude Code power users) is concentrated here

2. **Validate with early adopters** - 6 months of feedback before expanding

3. **Windows at month 9-12** - Large market (47.6%), enterprise demand

4. **Linux at month 12-18** - Developer completeness, lower priority than Windows

5. **Marketing positioning:**
   - Phase 1: "The premium native experience for Claude Code on Mac"
   - Phase 2: "Now available everywhere, best on Mac"

### 3.3 Risk Mitigation

| Risk | Mitigation |
|------|------------|
| **macOS market too small** | 33% is substantial; Claude Code users over-index here |
| **Windows users demand support** | Publicly commit to roadmap, offer waitlist |
| **Competitors beat us to cross-platform** | They're already there (Electron); native quality is our moat |
| **Architecture not portable** | Invest in clean module boundaries now |

---

## Appendix A: Framework Comparison Matrix

| Framework | Performance | Bundle Size | macOS UX | Windows UX | Linux UX | Learning Curve | Recommendation |
|-----------|-------------|-------------|----------|------------|----------|----------------|----------------|
| **SwiftUI** | Excellent | Small | Excellent | N/A | N/A | Low (for Swift devs) | macOS only |
| **Tauri** | Excellent | Small (2-10MB) | Good | Good | Good | High (Rust + Web) | Windows/Linux |
| **Electron** | Good | Large (85MB+) | Good | Good | Good | Medium | Not recommended |
| **Flutter** | Good | Medium | Good | Good | Good | Medium (Dart) | Alternative |
| **Avalonia** | Good | Medium | Good | Good | Good | Medium (.NET) | Alternative |
| **Compose MP** | Good | Medium | Good | Good | Good | Medium (Kotlin) | Alternative |

## Appendix B: Sources

### Cross-Platform Technology
- [Swift 6 Officially Available - InfoQ](https://www.infoq.com/news/2024/09/swift-6-officially-available/)
- [Skip.tools Documentation](https://skip.tools/docs/modes/)
- [Tauri vs Electron - gethopp.app](https://www.gethopp.app/blog/tauri-vs-electron)
- [Flutter Desktop Documentation](https://docs.flutter.dev/platform-integration/desktop)
- [Avalonia vs MAUI](https://avaloniaui.net/maui-compare)
- [Crux Framework](https://redbadger.github.io/crux/)
- [Compose Multiplatform](https://www.jetbrains.com/compose-multiplatform/)

### Market Research
- [Stack Overflow 2024 Developer Survey](https://survey.stackoverflow.co/2024/technology)
- [JetBrains Developer Ecosystem 2024](https://www.jetbrains.com/lp/devecosystem-2024/)
- [GitHub Copilot Statistics 2025](https://www.secondtalent.com/resources/github-copilot-statistics/)
- [Claude AI Statistics](https://seosandwitch.com/claude-ai-statistics/)
- [Anthropic Enterprise Market Share](https://www.technology.org/2025/08/02/anthropic-claude-models-capture-32-enterprise-market-share-overtaking-openai-in-business-ai-adoption/)

### Competitive Analysis
- [Windsurf vs Cursor - Builder.io](https://www.builder.io/blog/windsurf-vs-cursor)
- [AI Coding Assistants Enterprise Guide](https://axis-intelligence.com/ai-coding-assistants-2026-enterprise-guide/)
- [Jellyfish 2025 AI Metrics](https://jellyfish.co/blog/2025-ai-metrics-in-review/)

---

**Document End**

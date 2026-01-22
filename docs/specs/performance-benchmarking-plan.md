# Cogit0 Blaze - Performance Benchmarking Plan

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Status:** Draft

---

## Executive Summary

This document defines how we measure, track, and optimize performance in Cogit0 Blaze. Performance is a feature - a native macOS app must feel instantaneous to justify its existence over web alternatives.

---

## Table of Contents

1. [Performance Budgets](#1-performance-budgets)
2. [Key Metrics](#2-key-metrics)
3. [Measurement Infrastructure](#3-measurement-infrastructure)
4. [Benchmarking Procedures](#4-benchmarking-procedures)
5. [Automated Testing](#5-automated-testing)
6. [Profiling Tools](#6-profiling-tools)
7. [Optimization Guidelines](#7-optimization-guidelines)

---

## 1. Performance Budgets

### 1.1 Core Budgets

| Metric | Target | Critical | Measurement |
|--------|--------|----------|-------------|
| **App Launch (cold)** | < 1.0s | < 2.0s | Time to interactive |
| **App Launch (warm)** | < 0.3s | < 0.5s | Time to interactive |
| **Command Palette Open** | < 50ms | < 100ms | Keypress to visible |
| **First Token Render** | < 100ms | < 200ms | Event received to pixel |
| **Tool Card Render** | < 50ms | < 100ms | Event to visible |
| **Diff Render (1K lines)** | < 100ms | < 300ms | Data to painted |
| **Diff Render (10K lines)** | < 500ms | < 1s | Data to painted |
| **Session List Load** | < 50ms | < 150ms | Panel visible to populated |
| **Message Send** | < 30ms | < 100ms | Enter to CLI spawn |
| **Scroll (60fps)** | 16.6ms/frame | 33ms/frame | Frame time |

### 1.2 Memory Budgets

| State | Target | Critical | Notes |
|-------|--------|----------|-------|
| **Idle** | < 150 MB | < 300 MB | App open, no session |
| **Active Session** | < 300 MB | < 500 MB | Streaming response |
| **Large Session (1000 events)** | < 400 MB | < 600 MB | Loaded history |
| **Heavy Use (10 sessions)** | < 500 MB | < 800 MB | Multiple tabs |
| **Memory Growth/Hour** | < 10 MB | < 50 MB | Leak detection |

### 1.3 Battery/CPU Budgets

| State | CPU Target | CPU Critical | Notes |
|-------|------------|--------------|-------|
| **Idle** | < 1% | < 3% | Background, no activity |
| **Streaming** | < 15% | < 30% | Receiving tokens |
| **Tool Execution** | < 5% | < 15% | Waiting for CLI |
| **Scrolling** | < 20% | < 40% | Animation active |

---

## 2. Key Metrics

### 2.1 User-Facing Metrics

```swift
enum PerformanceMetric: String, CaseIterable {
    // Launch
    case coldLaunchTime = "launch.cold"
    case warmLaunchTime = "launch.warm"
    case timeToInteractive = "launch.tti"

    // UI Responsiveness
    case commandPaletteOpen = "ui.palette.open"
    case sidebarToggle = "ui.sidebar.toggle"
    case tabSwitch = "ui.tab.switch"
    case scrollFrameTime = "ui.scroll.frametime"

    // Streaming
    case timeToFirstToken = "stream.ttft"
    case tokenRenderLatency = "stream.token.render"
    case streamingFrameRate = "stream.fps"

    // Tool Cards
    case toolCardRender = "tool.card.render"
    case toolCardExpand = "tool.card.expand"

    // Diff Viewer
    case diffParseTime = "diff.parse"
    case diffRenderTime = "diff.render"
    case diffScrollFrameTime = "diff.scroll.frametime"

    // Session Management
    case sessionListLoad = "session.list.load"
    case sessionLoad = "session.load"
    case sessionSave = "session.save"

    // Database
    case dbQueryTime = "db.query"
    case dbInsertTime = "db.insert"
    case dbVectorSearch = "db.vector.search"
}
```

### 2.2 System Metrics

```swift
struct SystemMetrics {
    let cpuUsage: Double           // 0-100%
    let memoryUsage: UInt64        // Bytes
    let memoryPressure: MemoryPressure
    let diskReadBytes: UInt64
    let diskWriteBytes: UInt64
    let networkBytesIn: UInt64
    let networkBytesOut: UInt64
    let thermalState: ProcessInfo.ThermalState
    let batteryLevel: Double?
    let isPluggedIn: Bool?
}

enum MemoryPressure {
    case normal
    case warning
    case critical
}
```

### 2.3 Derived Metrics

| Metric | Formula | Purpose |
|--------|---------|---------|
| **Jank Rate** | Frames > 16.6ms / Total Frames | Smoothness |
| **P50 Latency** | 50th percentile of operation times | Typical experience |
| **P95 Latency** | 95th percentile | Worst-case experience |
| **P99 Latency** | 99th percentile | Tail latency |
| **Memory Growth Rate** | (MemNow - MemStart) / Time | Leak indicator |
| **Crash-Free Rate** | Sessions without crash / Total | Stability |

---

## 3. Measurement Infrastructure

### 3.1 Performance Monitor

```swift
actor PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var measurements: [PerformanceMetric: [Measurement]] = [:]
    private let maxMeasurementsPerMetric = 1000

    struct Measurement {
        let timestamp: Date
        let value: Double  // milliseconds or percentage
        let context: [String: String]
    }

    func measure<T>(_ metric: PerformanceMetric, context: [String: String] = [:], operation: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            record(metric, value: elapsed, context: context)
        }
        return try await operation()
    }

    func record(_ metric: PerformanceMetric, value: Double, context: [String: String] = [:]) {
        var measurements = self.measurements[metric] ?? []
        measurements.append(Measurement(timestamp: Date(), value: value, context: context))

        // Keep only recent measurements
        if measurements.count > maxMeasurementsPerMetric {
            measurements.removeFirst(measurements.count - maxMeasurementsPerMetric)
        }

        self.measurements[metric] = measurements

        // Check against budget
        checkBudget(metric, value: value)
    }

    private func checkBudget(_ metric: PerformanceMetric, value: Double) {
        if value > metric.criticalThreshold {
            Logger.performance.warning("Critical threshold exceeded: \(metric.rawValue) = \(value)ms")
        } else if value > metric.targetThreshold {
            Logger.performance.info("Target threshold exceeded: \(metric.rawValue) = \(value)ms")
        }
    }

    func statistics(for metric: PerformanceMetric) -> MetricStatistics? {
        guard let measurements = measurements[metric], !measurements.isEmpty else {
            return nil
        }

        let values = measurements.map(\.value).sorted()
        return MetricStatistics(
            count: values.count,
            min: values.first!,
            max: values.last!,
            mean: values.reduce(0, +) / Double(values.count),
            p50: percentile(values, 0.50),
            p95: percentile(values, 0.95),
            p99: percentile(values, 0.99)
        )
    }
}
```

### 3.2 Frame Rate Monitor

```swift
class FrameRateMonitor: ObservableObject {
    @Published var currentFPS: Double = 60
    @Published var droppedFrames: Int = 0

    private var displayLink: CVDisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    func start() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        guard let displayLink else { return }

        CVDisplayLinkSetOutputHandler(displayLink) { [weak self] _, inNow, _, _, _ in
            self?.handleFrame(timestamp: inNow.pointee)
            return kCVReturnSuccess
        }

        CVDisplayLinkStart(displayLink)
    }

    private func handleFrame(timestamp: CVTimeStamp) {
        let currentTime = Double(timestamp.videoTime) / Double(timestamp.videoTimeScale)

        if lastTimestamp > 0 {
            let frameDuration = currentTime - lastTimestamp
            let expectedDuration = 1.0 / 60.0  // 16.6ms

            if frameDuration > expectedDuration * 1.5 {
                droppedFrames += Int(frameDuration / expectedDuration) - 1
            }

            frameCount += 1
            if frameCount >= 60 {
                currentFPS = Double(frameCount) / (currentTime - lastTimestamp)
                frameCount = 0
            }
        }

        lastTimestamp = currentTime
    }
}
```

### 3.3 Memory Monitor

```swift
class MemoryMonitor: ObservableObject {
    @Published var currentMemory: UInt64 = 0
    @Published var peakMemory: UInt64 = 0
    @Published var memoryPressure: MemoryPressure = .normal

    private var timer: Timer?
    private var initialMemory: UInt64 = 0
    private var startTime: Date = Date()

    func start() {
        initialMemory = currentMemoryUsage()
        startTime = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sample()
        }

        // Register for memory pressure notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: NSNotification.Name("NSProcessInfoPowerStateDidChangeNotification"),
            object: nil
        )
    }

    private func sample() {
        currentMemory = currentMemoryUsage()
        peakMemory = max(peakMemory, currentMemory)

        // Log if growing too fast
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 60 {  // After 1 minute
            let growth = Double(currentMemory - initialMemory)
            let growthRate = growth / elapsed * 3600  // Per hour
            if growthRate > 50 * 1024 * 1024 {  // 50 MB/hour
                Logger.performance.warning("High memory growth rate: \(growthRate / 1024 / 1024) MB/hour")
            }
        }
    }

    private func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
```

---

## 4. Benchmarking Procedures

### 4.1 Pre-Release Benchmark Suite

```swift
struct BenchmarkSuite {
    static func runAll() async -> BenchmarkReport {
        let results = BenchmarkReport()

        // Cold launch
        results.add(await benchmarkColdLaunch())

        // UI responsiveness
        results.add(await benchmarkCommandPalette())
        results.add(await benchmarkScrolling())

        // Streaming
        results.add(await benchmarkStreamingRender())

        // Large data
        results.add(await benchmarkLargeSession())
        results.add(await benchmarkLargeDiff())

        // Database
        results.add(await benchmarkDatabaseQueries())

        return results
    }
}
```

### 4.2 Cold Launch Benchmark

```swift
func benchmarkColdLaunch() async -> BenchmarkResult {
    // Kill app completely
    // Clear file system cache (optional)
    // Measure time from launch to first frame
    // Measure time to interactive (can accept input)

    var measurements: [Double] = []

    for _ in 0..<5 {
        let launchTime = await measureAppLaunch()
        measurements.append(launchTime)
        await terminateApp()
        try? await Task.sleep(for: .seconds(2))
    }

    return BenchmarkResult(
        name: "Cold Launch",
        metric: .coldLaunchTime,
        measurements: measurements,
        budget: 1000,  // 1 second
        unit: "ms"
    )
}
```

### 4.3 Streaming Benchmark

```swift
func benchmarkStreamingRender() async -> BenchmarkResult {
    // Simulate receiving tokens at various rates
    let tokenRates = [10, 50, 100, 200]  // tokens per second
    var measurements: [Double] = []

    for rate in tokenRates {
        let result = await measureStreamingAtRate(tokensPerSecond: rate)
        measurements.append(result.averageFrameTime)
    }

    return BenchmarkResult(
        name: "Streaming Render",
        metric: .streamingFrameRate,
        measurements: measurements,
        budget: 16.6,  // 60fps
        unit: "ms/frame"
    )
}
```

### 4.4 Large Session Benchmark

```swift
func benchmarkLargeSession() async -> BenchmarkResult {
    let sessionSizes = [100, 500, 1000, 5000]  // events
    var measurements: [Double] = []

    for size in sessionSizes {
        let session = generateTestSession(eventCount: size)

        let loadTime = await PerformanceMonitor.shared.measure(.sessionLoad) {
            await sessionStore.load(session.id)
        }

        measurements.append(loadTime)
    }

    return BenchmarkResult(
        name: "Session Load Time",
        metric: .sessionLoad,
        measurements: measurements,
        budget: 200,  // 200ms for 5000 events
        unit: "ms",
        context: ["sizes": sessionSizes.map(String.init).joined(separator: ",")]
    )
}
```

### 4.5 Diff Viewer Benchmark

```swift
func benchmarkLargeDiff() async -> BenchmarkResult {
    let diffSizes = [100, 1000, 5000, 10000]  // lines
    var measurements: [Double] = []

    for size in diffSizes {
        let diff = generateTestDiff(lineCount: size)

        let renderTime = await PerformanceMonitor.shared.measure(.diffRenderTime) {
            await diffViewer.render(diff)
        }

        measurements.append(renderTime)
    }

    return BenchmarkResult(
        name: "Diff Render Time",
        metric: .diffRenderTime,
        measurements: measurements,
        budget: 500,  // 500ms for 10K lines
        unit: "ms"
    )
}
```

---

## 5. Automated Testing

### 5.1 CI Performance Tests

```yaml
# .github/workflows/performance.yml
name: Performance Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  benchmark:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build Release
        run: xcodebuild build -scheme Blaze -configuration Release

      - name: Run Benchmarks
        run: ./scripts/run-benchmarks.sh

      - name: Compare to Baseline
        run: ./scripts/compare-benchmarks.sh

      - name: Fail if Regression
        run: |
          if [ -f benchmark-regression.txt ]; then
            cat benchmark-regression.txt
            exit 1
          fi

      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: benchmark-results.json
```

### 5.2 XCTest Performance Tests

```swift
class PerformanceTests: XCTestCase {

    func testColdLaunchTime() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let app = XCUIApplication()
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 2.0))
            app.terminate()
        }
    }

    func testCommandPaletteOpen() throws {
        let app = XCUIApplication()
        app.launch()

        measure(metrics: [XCTClockMetric()]) {
            app.typeKey("k", modifierFlags: .command)
            XCTAssertTrue(app.popovers["Command Palette"].waitForExistence(timeout: 0.1))
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    func testScrollPerformance() throws {
        let app = XCUIApplication()
        app.launch()

        // Load a session with many messages
        app.buttons["Test Session"].tap()

        let scrollView = app.scrollViews.firstMatch

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) {
            scrollView.swipeUp(velocity: .fast)
            scrollView.swipeDown(velocity: .fast)
        }
    }

    func testLargeDiffRender() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to large diff
        app.buttons["Large Diff Test"].tap()

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            app.buttons["Show Diff"].tap()
            XCTAssertTrue(app.staticTexts["Diff Loaded"].waitForExistence(timeout: 1.0))
        }
    }
}
```

### 5.3 Baseline Management

```swift
struct PerformanceBaseline {
    static let path = "Tests/Baselines/performance-baseline.json"

    struct Baseline: Codable {
        let metric: String
        let p50: Double
        let p95: Double
        let p99: Double
        let timestamp: Date
        let commit: String
    }

    static func load() throws -> [String: Baseline] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let baselines = try JSONDecoder().decode([Baseline].self, from: data)
        return Dictionary(uniqueKeysWithValues: baselines.map { ($0.metric, $0) })
    }

    static func compare(current: MetricStatistics, baseline: Baseline, threshold: Double = 0.10) -> ComparisonResult {
        let p50Regression = (current.p50 - baseline.p50) / baseline.p50
        let p95Regression = (current.p95 - baseline.p95) / baseline.p95

        if p50Regression > threshold || p95Regression > threshold {
            return .regression(p50Delta: p50Regression, p95Delta: p95Regression)
        } else if p50Regression < -threshold || p95Regression < -threshold {
            return .improvement(p50Delta: p50Regression, p95Delta: p95Regression)
        }
        return .noChange
    }
}
```

---

## 6. Profiling Tools

### 6.1 Instruments Templates

| Template | Use Case | Key Metrics |
|----------|----------|-------------|
| **Time Profiler** | CPU hotspots | Call tree, weight |
| **Allocations** | Memory leaks | Growth, transient |
| **Leaks** | Memory leaks | Leaked objects |
| **Core Animation** | Rendering perf | FPS, offscreen |
| **System Trace** | System calls | Syscall time |
| **Network** | API latency | Request timing |
| **File Activity** | Disk I/O | Read/write ops |

### 6.2 Custom Signposts

```swift
import os.signpost

extension OSLog {
    static let performance = OSLog(subsystem: "com.cogit0.blaze", category: "Performance")
    static let streaming = OSLog(subsystem: "com.cogit0.blaze", category: "Streaming")
    static let database = OSLog(subsystem: "com.cogit0.blaze", category: "Database")
}

class StreamingPerformance {
    let log = OSLog.streaming
    var intervalID: OSSignpostID?

    func beginStreaming() {
        intervalID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "StreamingResponse", signpostID: intervalID!)
    }

    func tokenReceived() {
        os_signpost(.event, log: log, name: "TokenReceived", signpostID: intervalID!)
    }

    func endStreaming() {
        os_signpost(.end, log: log, name: "StreamingResponse", signpostID: intervalID!)
    }
}
```

### 6.3 Debug Performance HUD

```swift
#if DEBUG
struct PerformanceHUD: View {
    @ObservedObject var frameMonitor = FrameRateMonitor.shared
    @ObservedObject var memoryMonitor = MemoryMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(Int(frameMonitor.currentFPS))")
                .foregroundColor(frameMonitor.currentFPS < 55 ? .red : .green)

            Text("Memory: \(formatBytes(memoryMonitor.currentMemory))")
                .foregroundColor(memoryMonitor.currentMemory > 500_000_000 ? .red : .green)

            Text("Dropped: \(frameMonitor.droppedFrames)")
                .foregroundColor(frameMonitor.droppedFrames > 0 ? .orange : .green)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
#endif
```

---

## 7. Optimization Guidelines

### 7.1 Common Optimizations

| Area | Optimization | Impact |
|------|-------------|--------|
| **Launch** | Lazy load non-critical views | High |
| **Launch** | Defer database migrations | Medium |
| **Streaming** | Batch UI updates at 60fps | High |
| **Streaming** | Use attributed strings efficiently | Medium |
| **Memory** | Virtualize long lists | High |
| **Memory** | Release resources on low memory | Medium |
| **Database** | Index frequently queried columns | High |
| **Database** | Use pagination for large results | Medium |
| **Rendering** | Avoid re-rendering unchanged views | High |
| **Rendering** | Use drawingGroup() for complex views | Medium |

### 7.2 SwiftUI Optimization Patterns

```swift
// Avoid recomputing views unnecessarily
struct MessageView: View {
    let message: Message

    var body: some View {
        // Use EquatableView to prevent re-render if message unchanged
        EquatableView(content: MessageContent(message: message))
    }
}

// Batch state updates
class StreamingState: ObservableObject {
    @Published var text: String = ""

    private var pendingText: String = ""
    private var updateTask: Task<Void, Never>?

    func appendToken(_ token: String) {
        pendingText += token

        // Batch updates to 60fps
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            self.text = pendingText
        }
    }
}

// Virtualize long lists
struct VirtualizedMessageList: View {
    let messages: [Message]

    var body: some View {
        LazyVStack {
            ForEach(messages) { message in
                MessageRow(message: message)
                    .id(message.id)
            }
        }
    }
}

// Use drawingGroup for complex views
struct ComplexDiffView: View {
    let diff: FileDiff

    var body: some View {
        VStack {
            ForEach(diff.hunks) { hunk in
                HunkView(hunk: hunk)
            }
        }
        .drawingGroup()  // Flatten to single render
    }
}
```

### 7.3 Database Optimization

```swift
// Use indexes for common queries
let indexedQueries = """
CREATE INDEX IF NOT EXISTS idx_events_session_seq ON events(session_id, sequence);
CREATE INDEX IF NOT EXISTS idx_sessions_project_date ON sessions(project_id, last_used_at DESC);
CREATE INDEX IF NOT EXISTS idx_diffs_session_decision ON diffs(session_id, decision);
"""

// Paginate large results
func events(for sessionId: UUID, page: Int, pageSize: Int = 100) async throws -> [Event] {
    try await db.table("events")
        .filter("session_id = ?", [sessionId])
        .orderBy("sequence")
        .offset(page * pageSize)
        .limit(pageSize)
        .execute()
}

// Use projections to reduce data transfer
func sessionSummaries(for projectId: UUID) async throws -> [SessionSummary] {
    try await db.table("sessions")
        .select("id", "name", "last_used_at", "turn_count")  // Only needed columns
        .filter("project_id = ?", [projectId])
        .orderBy("last_used_at", ascending: false)
        .limit(50)
        .execute()
}
```

---

## Appendix A: Benchmark Report Format

```json
{
  "timestamp": "2025-12-25T12:00:00Z",
  "commit": "abc123",
  "environment": {
    "os": "macOS 14.2",
    "chip": "M3 Pro",
    "memory": "18GB",
    "blazeVersion": "1.0.0"
  },
  "results": [
    {
      "name": "Cold Launch",
      "metric": "launch.cold",
      "measurements": [980, 1020, 995, 1010, 990],
      "statistics": {
        "min": 980,
        "max": 1020,
        "mean": 999,
        "p50": 995,
        "p95": 1018,
        "p99": 1020
      },
      "budget": 1000,
      "status": "pass",
      "unit": "ms"
    }
  ],
  "summary": {
    "total": 15,
    "passed": 14,
    "failed": 1,
    "regressions": 1
  }
}
```

---

## Appendix B: Performance Dashboard Metrics

For the observability dashboard:

| Metric | Visualization | Alert Threshold |
|--------|---------------|-----------------|
| Launch Time | Time series | > 2s |
| FPS | Gauge | < 50 |
| Memory | Area chart | > 500 MB |
| TTFT | Histogram | > 200ms |
| Jank Rate | Percentage | > 5% |
| Crash Rate | Counter | > 0.5% |

---

**End of Document**

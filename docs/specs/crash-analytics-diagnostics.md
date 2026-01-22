# Crash Analytics & Diagnostics Specification

> **Status:** `Draft` | **Last Updated:** 2025-12-30 | **Version:** 1.0

---

## Executive Summary

This specification defines how Blaze collects, stores, and reports crash data and diagnostics. It covers crash detection, support bundle generation, privacy-safe data collection, and user-initiated diagnostics.

**Why This Matters:** Fast issue resolution requires good diagnostics. Users need to easily share context without exposing sensitive data.

---

## Table of Contents

1. [Data Collection](#1-data-collection)
2. [Crash Detection](#2-crash-detection)
3. [Support Bundles](#3-support-bundles)
4. [Diagnostics Mode](#4-diagnostics-mode)
5. [Privacy & Sanitization](#5-privacy--sanitization)
6. [Implementation](#6-implementation)

---

## 1. Data Collection

### 1.1 What We Collect

| Category | Data | Purpose | Opt-In? |
|----------|------|---------|---------|
| **Crash Reports** | Stack traces, memory state | Debug crashes | Auto |
| **Session Metrics** | Duration, message count, tool calls | Usage patterns | Opt-in |
| **Performance** | Latency, memory, CPU | Performance issues | Opt-in |
| **Errors** | Error codes, recovery actions | Error patterns | Auto |
| **System Info** | macOS version, hardware | Compatibility | Auto |

### 1.2 What We NEVER Collect

- File contents
- Message content
- API keys or tokens
- User credentials
- Code snippets
- Personal information

### 1.3 Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DIAGNOSTICS DATA FLOW                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   App Runtime                                                        │
│       │                                                              │
│       ├──▶ Crash Handler ──▶ Crash Report (local)                   │
│       │                                                              │
│       ├──▶ Error Logger ──▶ Error Log (local)                       │
│       │                                                              │
│       ├──▶ Metrics Collector ──▶ Metrics DB (local)                 │
│       │                                                              │
│       └──▶ Performance Monitor ──▶ Perf Samples (local)             │
│                                                                      │
│   On User Request                                                    │
│       │                                                              │
│       └──▶ Support Bundle Generator                                 │
│               │                                                      │
│               ├──▶ Collect relevant data                            │
│               ├──▶ Sanitize sensitive info                          │
│               ├──▶ Package as .blazediag                            │
│               └──▶ User shares manually                             │
│                                                                      │
│   On Opt-In                                                          │
│       │                                                              │
│       └──▶ Telemetry Service ──▶ Aggregate analytics                │
│               │                                                      │
│               └──▶ (Privacy-safe, no PII)                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Crash Detection

### 2.1 Crash Types

| Type | Detection | Recovery |
|------|-----------|----------|
| **Swift Exception** | `NSSetUncaughtExceptionHandler` | Capture, save, restart |
| **Signal** | `signal()` handlers | Best-effort save |
| **OOM** | Memory pressure notification | Warn before crash |
| **Watchdog** | App not responding | Force terminate |
| **CLI Crash** | Process exit code | Session recovery |

### 2.2 Crash Handler

```swift
class CrashHandler {
    private let crashLogPath: URL
    private var previousExceptionHandler: NSExceptionHandler?

    init() {
        crashLogPath = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CogitO Blaze")
            .appendingPathComponent("crashes")

        try? FileManager.default.createDirectory(
            at: crashLogPath,
            withIntermediateDirectories: true
        )
    }

    func install() {
        // Swift/Objective-C exceptions
        NSSetUncaughtExceptionHandler { exception in
            CrashHandler.shared.handleException(exception)
        }

        // Signal handlers
        for signal in [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP] {
            Foundation.signal(signal) { sig in
                CrashHandler.shared.handleSignal(sig)
            }
        }

        // Memory pressure
        DispatchSource.makeMemoryPressureSource(
            eventMask: .critical,
            queue: .main
        ).setEventHandler {
            CrashHandler.shared.handleMemoryPressure()
        }
    }

    private func handleException(_ exception: NSException) {
        let report = CrashReport(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason,
            stackTrace: Thread.callStackSymbols,
            timestamp: Date()
        )

        saveCrashReport(report)
    }

    private func handleSignal(_ signal: Int32) {
        let report = CrashReport(
            type: .signal,
            name: signalName(signal),
            reason: "Signal \(signal) received",
            stackTrace: Thread.callStackSymbols,
            timestamp: Date()
        )

        saveCrashReport(report)
    }

    private func handleMemoryPressure() {
        // Save state before potential OOM
        Task {
            await SessionManager.shared.emergencySaveAll()
        }

        // Log memory warning
        let report = DiagnosticEvent(
            type: .memoryWarning,
            data: [
                "footprint": ProcessInfo.processInfo.physicalMemory,
                "available": getAvailableMemory()
            ]
        )
        DiagnosticsLogger.shared.log(report)
    }

    private func saveCrashReport(_ report: CrashReport) {
        let filename = "crash_\(ISO8601DateFormatter().string(from: report.timestamp)).json"
        let filePath = crashLogPath.appendingPathComponent(filename)

        do {
            let data = try JSONEncoder().encode(report)
            try data.write(to: filePath, options: .atomic)
        } catch {
            // Last resort: write to stderr
            fputs("CRASH: \(report.name) - \(report.reason ?? "unknown")\n", stderr)
        }
    }
}
```

### 2.3 Crash Report Format

```swift
struct CrashReport: Codable {
    let id: UUID = UUID()
    let type: CrashType
    let name: String
    let reason: String?
    let stackTrace: [String]
    let timestamp: Date

    // Context
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String

    // State snapshot
    let activeSessionId: UUID?
    let sessionState: String?
    let lastAction: String?
    let memoryUsage: UInt64?

    enum CrashType: String, Codable {
        case exception
        case signal
        case assertion
        case watchdog
        case oom
    }
}
```

### 2.4 Crash Recovery

```swift
func checkForPreviousCrash() async {
    let crashFiles = try? FileManager.default.contentsOfDirectory(
        at: crashLogPath,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }

    guard let crashes = crashFiles, !crashes.isEmpty else {
        return
    }

    // Show recovery UI
    let latestCrash = crashes.max(by: { $0.lastModified < $1.lastModified })

    if let crashFile = latestCrash,
       let data = try? Data(contentsOf: crashFile),
       let report = try? JSONDecoder().decode(CrashReport.self, from: data) {

        await showCrashRecoveryDialog(report)
    }
}

func showCrashRecoveryDialog(_ report: CrashReport) async {
    let action = await CrashRecoveryView.present(
        message: "Blaze crashed unexpectedly",
        crashType: report.name,
        options: [
            .sendReport,
            .viewDetails,
            .dismiss
        ]
    )

    switch action {
    case .sendReport:
        await generateAndShareSupportBundle(includeCrash: report)
    case .viewDetails:
        showCrashDetails(report)
    case .dismiss:
        archiveCrashReport(report)
    }
}
```

---

## 3. Support Bundles

### 3.1 Bundle Contents

```
support_bundle_2025-12-30_143052.blazediag
├── manifest.json           # Bundle metadata
├── system_info.json        # OS, hardware, Blaze version
├── crash_reports/          # Recent crashes (if any)
│   └── crash_*.json
├── error_log.json          # Sanitized error log
├── session_summary.json    # Session metadata (no content)
├── performance_samples.json # Recent perf data
├── settings_snapshot.json  # Sanitized settings
└── cli_diagnostics.json    # CLI version, auth status
```

### 3.2 Bundle Generator

```swift
class SupportBundleGenerator {
    struct BundleOptions {
        var includeCrashReports: Bool = true
        var includeErrorLog: Bool = true
        var includeSessionSummary: Bool = true
        var includePerformance: Bool = true
        var includeSettings: Bool = true
        var includeCLIDiagnostics: Bool = true
        var maxLogEntries: Int = 1000
        var logTimeRange: TimeInterval = 24 * 60 * 60 // 24 hours
    }

    func generate(options: BundleOptions = .init()) async throws -> URL {
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("support_bundle_\(timestamp())")

        try FileManager.default.createDirectory(
            at: bundleDir,
            withIntermediateDirectories: true
        )

        // Generate manifest
        let manifest = BundleManifest(
            generatedAt: Date(),
            blazeVersion: Bundle.main.version,
            bundleVersion: "1.0",
            options: options
        )
        try save(manifest, to: bundleDir.appendingPathComponent("manifest.json"))

        // Collect system info
        let systemInfo = collectSystemInfo()
        try save(systemInfo, to: bundleDir.appendingPathComponent("system_info.json"))

        // Collect crash reports
        if options.includeCrashReports {
            let crashDir = bundleDir.appendingPathComponent("crash_reports")
            try FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)
            try copyCrashReports(to: crashDir)
        }

        // Collect error log
        if options.includeErrorLog {
            let errorLog = await collectErrorLog(
                maxEntries: options.maxLogEntries,
                timeRange: options.logTimeRange
            )
            let sanitized = sanitize(errorLog)
            try save(sanitized, to: bundleDir.appendingPathComponent("error_log.json"))
        }

        // Collect session summary
        if options.includeSessionSummary {
            let summary = await collectSessionSummary()
            try save(summary, to: bundleDir.appendingPathComponent("session_summary.json"))
        }

        // Collect performance
        if options.includePerformance {
            let perf = await collectPerformanceSamples()
            try save(perf, to: bundleDir.appendingPathComponent("performance_samples.json"))
        }

        // Collect settings
        if options.includeSettings {
            let settings = collectSettings()
            let sanitized = sanitizeSettings(settings)
            try save(sanitized, to: bundleDir.appendingPathComponent("settings_snapshot.json"))
        }

        // Collect CLI diagnostics
        if options.includeCLIDiagnostics {
            let cliDiag = await collectCLIDiagnostics()
            try save(cliDiag, to: bundleDir.appendingPathComponent("cli_diagnostics.json"))
        }

        // Create zip archive
        let zipPath = bundleDir
            .deletingLastPathComponent()
            .appendingPathComponent("\(bundleDir.lastPathComponent).blazediag")

        try FileManager.default.zipItem(at: bundleDir, to: zipPath)

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: bundleDir)

        return zipPath
    }
}
```

### 3.3 Bundle UI

```swift
struct SupportBundleView: View {
    @StateObject private var generator = SupportBundleGenerator()
    @State private var options = SupportBundleGenerator.BundleOptions()
    @State private var isGenerating = false
    @State private var generatedBundle: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate Support Bundle")
                .font(.headline)

            Text("This bundle helps us diagnose issues. It contains diagnostic data but NO sensitive information like messages, code, or API keys.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GroupBox("Include in Bundle") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Crash reports", isOn: $options.includeCrashReports)
                    Toggle("Error log (24 hours)", isOn: $options.includeErrorLog)
                    Toggle("Session summary (metadata only)", isOn: $options.includeSessionSummary)
                    Toggle("Performance data", isOn: $options.includePerformance)
                    Toggle("Settings (sanitized)", isOn: $options.includeSettings)
                    Toggle("CLI diagnostics", isOn: $options.includeCLIDiagnostics)
                }
            }

            if isGenerating {
                HStack {
                    ProgressView()
                    Text("Generating bundle...")
                }
            } else if let bundle = generatedBundle {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Bundle ready")
                    Spacer()
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(bundle.path, inFileViewerRootedAtPath: "")
                    }
                    ShareLink(item: bundle)
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Generate Bundle") {
                    generateBundle()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            }
        }
        .padding()
        .frame(width: 450)
    }

    private func generateBundle() {
        isGenerating = true
        Task {
            do {
                generatedBundle = try await generator.generate(options: options)
            } catch {
                // Show error
            }
            isGenerating = false
        }
    }
}
```

---

## 4. Diagnostics Mode

### 4.1 Verbose Logging

```swift
class DiagnosticsMode {
    static var isEnabled: Bool = false

    static func enable(duration: TimeInterval = 300) { // 5 minutes default
        isEnabled = true
        Logger.logLevel = .debug

        // Schedule auto-disable
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            disable()
        }

        Logger.info("Diagnostics mode enabled for \(Int(duration))s")
    }

    static func disable() {
        isEnabled = false
        Logger.logLevel = .info
        Logger.info("Diagnostics mode disabled")
    }
}

// Usage throughout codebase
func someFunction() {
    if DiagnosticsMode.isEnabled {
        Logger.debug("Detailed info: \(debugData)")
    }
}
```

### 4.2 Real-Time Diagnostics Panel

```swift
struct DiagnosticsPanelView: View {
    @StateObject private var monitor = SystemMonitor.shared
    @State private var selectedTab = DiagnosticsTab.performance

    var body: some View {
        TabView(selection: $selectedTab) {
            PerformanceTab(monitor: monitor)
                .tabItem { Label("Performance", systemImage: "speedometer") }
                .tag(DiagnosticsTab.performance)

            MemoryTab(monitor: monitor)
                .tabItem { Label("Memory", systemImage: "memorychip") }
                .tag(DiagnosticsTab.memory)

            ProcessesTab()
                .tabItem { Label("Processes", systemImage: "terminal") }
                .tag(DiagnosticsTab.processes)

            LogsTab()
                .tabItem { Label("Logs", systemImage: "doc.text") }
                .tag(DiagnosticsTab.logs)
        }
        .frame(width: 600, height: 400)
    }
}

struct PerformanceTab: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // CPU usage graph
            VStack(alignment: .leading) {
                Text("CPU Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SparklineView(data: monitor.cpuHistory, color: .blue)
                    .frame(height: 40)
                Text("\(Int(monitor.cpuUsage * 100))%")
                    .font(.headline)
            }

            // Memory usage
            VStack(alignment: .leading) {
                Text("Memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: monitor.memoryUsage)
                Text("\(formatBytes(monitor.memoryUsed)) / \(formatBytes(monitor.memoryTotal))")
                    .font(.caption)
            }

            // Event loop latency
            VStack(alignment: .leading) {
                Text("Event Loop Latency")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SparklineView(data: monitor.latencyHistory, color: .orange)
                    .frame(height: 40)
                Text("\(Int(monitor.eventLoopLatency * 1000))ms")
                    .font(.headline)
            }
        }
        .padding()
    }
}
```

### 4.3 CLI Diagnostics

```swift
struct CLIDiagnostics: Codable {
    let claudeCode: CLIStatus
    let geminiCli: CLIStatus
    let codexCli: CLIStatus

    struct CLIStatus: Codable {
        let installed: Bool
        let version: String?
        let path: String?
        let authenticated: Bool
        let lastError: String?
    }
}

func collectCLIDiagnostics() async -> CLIDiagnostics {
    async let claudeStatus = checkCLI("claude", versionArg: "--version")
    async let geminiStatus = checkCLI("gemini", versionArg: "--version")
    async let codexStatus = checkCLI("codex", versionArg: "--version")

    return CLIDiagnostics(
        claudeCode: await claudeStatus,
        geminiCli: await geminiStatus,
        codexCli: await codexStatus
    )
}

func checkCLI(_ name: String, versionArg: String) async -> CLIDiagnostics.CLIStatus {
    // Check if installed
    guard let path = try? await which(name) else {
        return CLIDiagnostics.CLIStatus(
            installed: false,
            version: nil,
            path: nil,
            authenticated: false,
            lastError: "CLI not found in PATH"
        )
    }

    // Get version
    let version = try? await run([path, versionArg])

    // Check auth status
    let authStatus = try? await run([path, "auth", "status"])
    let authenticated = authStatus?.contains("authenticated") ?? false

    return CLIDiagnostics.CLIStatus(
        installed: true,
        version: version?.trimmingCharacters(in: .whitespacesAndNewlines),
        path: path,
        authenticated: authenticated,
        lastError: nil
    )
}
```

---

## 5. Privacy & Sanitization

### 5.1 Sanitization Rules

```swift
struct Sanitizer {
    static let sensitivePatterns: [(pattern: String, replacement: String)] = [
        // API keys
        (#"sk-[a-zA-Z0-9]{32,}"#, "[ANTHROPIC_KEY]"),
        (#"AIza[a-zA-Z0-9_-]{35}"#, "[GOOGLE_KEY]"),
        (#"sk-proj-[a-zA-Z0-9-]{48,}"#, "[OPENAI_KEY]"),

        // Tokens
        (#"ghp_[a-zA-Z0-9]{36}"#, "[GITHUB_TOKEN]"),
        (#"gho_[a-zA-Z0-9]{36}"#, "[GITHUB_OAUTH]"),

        // Passwords in URLs
        (#"://[^:]+:[^@]+@"#, "://[REDACTED]@"),

        // Email addresses
        (#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, "[EMAIL]"),

        // File paths (user home)
        (#"/Users/[^/]+"#, "/Users/[USER]"),
        (#"C:\\Users\\[^\\]+"#, "C:\\Users\\[USER]"),

        // IP addresses
        (#"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#, "[IP]"),
    ]

    static func sanitize(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in sensitivePatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return result
    }

    static func sanitize(_ data: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]

        for (key, value) in data {
            // Skip sensitive keys entirely
            if sensitiveKeys.contains(key.lowercased()) {
                result[key] = "[REDACTED]"
                continue
            }

            // Recursively sanitize
            if let stringValue = value as? String {
                result[key] = sanitize(stringValue)
            } else if let dictValue = value as? [String: Any] {
                result[key] = sanitize(dictValue)
            } else if let arrayValue = value as? [Any] {
                result[key] = arrayValue.map { item in
                    if let str = item as? String {
                        return sanitize(str)
                    }
                    return item
                }
            } else {
                result[key] = value
            }
        }

        return result
    }

    private static let sensitiveKeys: Set<String> = [
        "password", "passwd", "pwd",
        "secret", "token", "key",
        "apikey", "api_key", "api-key",
        "auth", "authorization",
        "cookie", "session",
        "credential", "credentials"
    ]
}
```

### 5.2 Settings Sanitization

```swift
func sanitizeSettings(_ settings: [String: Any]) -> [String: Any] {
    var safe = settings

    // Remove all authentication-related settings
    safe.removeValue(forKey: "authTokens")
    safe.removeValue(forKey: "apiKeys")

    // Redact paths but keep structure
    if var paths = safe["recentProjects"] as? [String] {
        paths = paths.map { Sanitizer.sanitize($0) }
        safe["recentProjects"] = paths
    }

    // Keep non-sensitive settings as-is
    // (theme, shortcuts, preferences, etc.)

    return safe
}
```

### 5.3 Privacy Notice

```swift
struct PrivacyNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Privacy Notice", systemImage: "lock.shield")
                .font(.headline)

            Text("""
            The support bundle contains:
            - Crash reports and error logs
            - Performance metrics
            - System information
            - Sanitized settings

            It does NOT contain:
            - Your messages or code
            - API keys or tokens
            - Personal information
            - File contents
            """)
            .font(.caption)

            Link("View our Privacy Policy", destination: URL(string: "https://cogit0.com/privacy")!)
                .font(.caption)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

## 6. Implementation

### 6.1 System Monitor

```swift
@MainActor
@Observable
final class SystemMonitor {
    static let shared = SystemMonitor()

    private(set) var cpuUsage: Double = 0
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryUsed: UInt64 = 0
    private(set) var memoryTotal: UInt64 = 0
    private(set) var memoryUsage: Double = 0
    private(set) var eventLoopLatency: TimeInterval = 0
    private(set) var latencyHistory: [Double] = []

    private var timer: Timer?

    func startMonitoring(interval: TimeInterval = 1.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        // CPU usage
        cpuUsage = getCPUUsage()
        cpuHistory.append(cpuUsage)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }

        // Memory
        let memInfo = getMemoryInfo()
        memoryUsed = memInfo.used
        memoryTotal = memInfo.total
        memoryUsage = Double(memoryUsed) / Double(memoryTotal)

        // Event loop latency
        let start = CFAbsoluteTimeGetCurrent()
        DispatchQueue.main.async { [weak self] in
            let latency = CFAbsoluteTimeGetCurrent() - start
            self?.eventLoopLatency = latency
            self?.latencyHistory.append(latency)
            if self?.latencyHistory.count ?? 0 > 60 {
                self?.latencyHistory.removeFirst()
            }
        }
    }

    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory)
    }
}
```

### 6.2 Error Logger

```swift
actor DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private var entries: [LogEntry] = []
    private let maxEntries = 10_000

    struct LogEntry: Codable {
        let timestamp: Date
        let level: LogLevel
        let category: String
        let message: String
        let metadata: [String: String]?
    }

    enum LogLevel: String, Codable {
        case debug, info, warning, error, critical
    }

    func log(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func getEntries(
        level: LogLevel? = nil,
        category: String? = nil,
        since: Date? = nil,
        limit: Int = 1000
    ) -> [LogEntry] {
        var filtered = entries

        if let level = level {
            filtered = filtered.filter { $0.level >= level }
        }
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        if let since = since {
            filtered = filtered.filter { $0.timestamp >= since }
        }

        return Array(filtered.suffix(limit))
    }

    func clear() {
        entries.removeAll()
    }
}

// Convenience extensions
extension DiagnosticsLogger {
    func debug(_ message: String, category: String = "general", metadata: [String: String]? = nil) {
        log(LogEntry(timestamp: Date(), level: .debug, category: category, message: message, metadata: metadata))
    }

    func error(_ message: String, category: String = "general", error: Error? = nil) {
        var metadata: [String: String]? = nil
        if let error = error {
            metadata = ["error": String(describing: error)]
        }
        log(LogEntry(timestamp: Date(), level: .error, category: category, message: message, metadata: metadata))
    }
}
```

### 6.3 Telemetry (Opt-In)

```swift
actor TelemetryService {
    static let shared = TelemetryService()

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "telemetryEnabled")
    }

    func track(_ event: TelemetryEvent) async {
        guard isEnabled else { return }

        // Validate no PII
        guard !containsPII(event) else {
            assertionFailure("Telemetry event contains PII")
            return
        }

        // Queue for batch upload
        await eventQueue.append(event)

        // Flush if queue is large enough
        if await eventQueue.count >= 50 {
            await flush()
        }
    }

    private func containsPII(_ event: TelemetryEvent) -> Bool {
        let json = try? JSONEncoder().encode(event)
        let string = json.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Check for PII patterns
        for (pattern, _) in Sanitizer.sensitivePatterns {
            if string.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }
}

struct TelemetryEvent: Codable {
    let name: String
    let timestamp: Date
    let properties: [String: String]

    // Pre-defined safe events
    static func sessionStarted(engine: String, duration: TimeInterval) -> TelemetryEvent {
        TelemetryEvent(
            name: "session_started",
            timestamp: Date(),
            properties: [
                "engine": engine,
                "duration_bucket": bucketDuration(duration)
            ]
        )
    }

    static func featureUsed(feature: String) -> TelemetryEvent {
        TelemetryEvent(
            name: "feature_used",
            timestamp: Date(),
            properties: ["feature": feature]
        )
    }

    private static func bucketDuration(_ duration: TimeInterval) -> String {
        switch duration {
        case ..<60: return "<1m"
        case ..<300: return "1-5m"
        case ..<900: return "5-15m"
        case ..<3600: return "15-60m"
        default: return ">1h"
        }
    }
}
```

---

## Acceptance Criteria

- [ ] Crashes detected and reports saved
- [ ] Support bundle generates correctly
- [ ] All sensitive data sanitized
- [ ] Diagnostics panel shows real-time data
- [ ] CLI diagnostics check all engines
- [ ] Telemetry is opt-in only
- [ ] No PII in any collected data
- [ ] Bundle can be shared via system share sheet

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-30 | Initial specification |

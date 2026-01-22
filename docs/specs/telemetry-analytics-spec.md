# Cogit0 Blaze - Telemetry & Analytics Specification

**Version:** 1.0.0
**Last Updated:** 2025-12-25
**Privacy Framework:** GDPR, CCPA Compliant
**Status:** Draft

---

## Executive Summary

This document specifies the telemetry and analytics system for Cogit0 Blaze. We follow a **privacy-by-design** approach with:

- **Opt-out by default** for all non-essential telemetry
- **Local-first processing** - no raw data leaves the device
- **Anonymization** at the point of collection
- **Transparency** - users can see exactly what's collected
- **Data minimization** - only collect what's necessary

---

## Table of Contents

1. [Privacy Principles](#1-privacy-principles)
2. [Data Classification](#2-data-classification)
3. [Consent Management](#3-consent-management)
4. [Event Taxonomy](#4-event-taxonomy)
5. [Implementation](#5-implementation)
6. [Data Flow](#6-data-flow)
7. [User Controls](#7-user-controls)
8. [Compliance](#8-compliance)
9. [Security](#9-security)

---

## 1. Privacy Principles

### 1.1 Core Commitments

| Principle | Implementation |
|-----------|----------------|
| **Data Minimization** | Only collect what's necessary for product improvement |
| **Purpose Limitation** | Data used only for stated purposes |
| **Storage Limitation** | Aggregated data retained max 2 years |
| **Transparency** | Users can view all collected data |
| **User Control** | Opt-out with one click, data deletion on request |
| **Security** | Encryption in transit and at rest |
| **Local Processing** | Sensitive processing happens on-device |

### 1.2 What We NEVER Collect

| Category | Examples | Reason |
|----------|----------|--------|
| **User Content** | Prompts, responses, code | User IP, privacy |
| **File Contents** | Source code, documents | User IP, security |
| **File Paths** | Full paths to files | Can contain PII |
| **Session Content** | Conversation text | User privacy |
| **API Keys** | Any credentials | Security |
| **Personal Info** | Name, email (unless provided) | GDPR minimization |
| **Precise Location** | GPS coordinates | Not needed |
| **Device Identifiers** | UDID, MAC address | Privacy regulations |

### 1.3 Data We MAY Collect (with consent)

| Category | Purpose | Anonymization |
|----------|---------|---------------|
| **Aggregate Usage** | Feature popularity, UX improvement | Fully anonymized |
| **Performance Metrics** | App optimization | No PII |
| **Error Reports** | Bug fixing | Stripped of paths |
| **Feature Adoption** | Product decisions | Aggregated only |

---

## 2. Data Classification

### 2.1 Classification Levels

| Level | Description | Collection | Storage |
|-------|-------------|------------|---------|
| **Essential** | Required for core functionality | Always | Local only |
| **Functional** | Improves user experience | Opt-in | Local + anonymized remote |
| **Analytics** | Product improvement | Opt-in | Anonymized remote |
| **Diagnostic** | Debugging and support | Opt-in | Encrypted remote |

### 2.2 Essential Data (Always Collected, Local Only)

```swift
struct EssentialTelemetry {
    // App lifecycle - for crash recovery
    let appVersion: String
    let osVersion: String
    let launchCount: Int
    let lastLaunchDate: Date

    // Session state - for resume
    let activeSessionId: UUID?
    let lastProjectPath: String?  // Hashed, not actual path

    // Preferences
    let settings: [String: Any]
}
```

### 2.3 Functional Data (Opt-in, Anonymized)

```swift
struct FunctionalTelemetry {
    // Feature usage (no content)
    let commandPaletteOpened: Int
    let engineSwitches: Int
    let sessionCount: Int

    // UI preferences
    let preferredLayout: String
    let darkModeEnabled: Bool
    let sidebarWidth: Int
}
```

### 2.4 Analytics Data (Opt-in, Anonymized)

```swift
struct AnalyticsTelemetry {
    // Aggregate metrics
    let avgSessionDuration: TimeInterval
    let avgTurnsPerSession: Double
    let toolUsageDistribution: [String: Int]
    let featureAdoptionFlags: [String: Bool]

    // Performance (no PII)
    let avgLaunchTime: TimeInterval
    let avgResponseLatency: TimeInterval
    let memoryPressureEvents: Int
}
```

### 2.5 Diagnostic Data (Opt-in, Encrypted)

```swift
struct DiagnosticTelemetry {
    // Crash information
    let crashCount: Int
    let lastCrashDate: Date?
    let crashSymbolicatedStack: String?  // No file paths

    // Error patterns
    let errorCounts: [String: Int]  // By error code only
    let recoverySuccessRate: Double
}
```

---

## 3. Consent Management

### 3.1 Consent Levels

```swift
struct TelemetryConsent: Codable {
    var essential: Bool = true       // Cannot be disabled
    var functional: Bool = false     // Default off
    var analytics: Bool = false      // Default off
    var diagnostic: Bool = false     // Default off

    var consentDate: Date?
    var consentVersion: String?      // Track consent version

    static var defaultConsent: TelemetryConsent {
        TelemetryConsent()  // Everything except essential is off
    }
}
```

### 3.2 First-Run Consent Flow

```
┌────────────────────────────────────────────────────┐
│                                                     │
│  Help Us Improve Blaze                              │
│                                                     │
│  We'd love to learn how you use Blaze to make it   │
│  better. All data is anonymous and you can change  │
│  your mind anytime in Settings.                    │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │ ☐ Share usage analytics                     │   │
│  │   Help us understand which features matter   │   │
│  │                                              │   │
│  │ ☐ Send crash reports                        │   │
│  │   Help us fix bugs faster                    │   │
│  │                                              │   │
│  │ ☐ Share performance data                    │   │
│  │   Help us optimize for your hardware         │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  [What data is collected?]  [Privacy Policy]        │
│                                                     │
│        [Skip]            [Continue]                 │
│                                                     │
└────────────────────────────────────────────────────┘
```

### 3.3 Consent Versioning

When our data collection practices change:

```swift
struct ConsentVersion {
    static let current = "1.0"

    // If user's consent version doesn't match, re-prompt
    static func needsReConsent(userVersion: String?) -> Bool {
        guard let userVersion else { return true }
        return userVersion != current
    }
}
```

### 3.4 Consent Storage

```swift
class ConsentManager: ObservableObject {
    @AppStorage("telemetry.consent") private var consentData: Data?

    var consent: TelemetryConsent {
        get {
            guard let data = consentData else { return .defaultConsent }
            return (try? JSONDecoder().decode(TelemetryConsent.self, from: data))
                ?? .defaultConsent
        }
        set {
            consentData = try? JSONEncoder().encode(newValue)
            applyConsent(newValue)
        }
    }

    private func applyConsent(_ consent: TelemetryConsent) {
        TelemetryEngine.shared.setEnabled(
            analytics: consent.analytics,
            diagnostics: consent.diagnostic
        )
    }
}
```

---

## 4. Event Taxonomy

### 4.1 Event Categories

| Category | Prefix | Purpose | Consent Required |
|----------|--------|---------|------------------|
| App Lifecycle | `app_` | Launch, crash, update | Essential |
| Session | `session_` | Session management | Functional |
| UI Interaction | `ui_` | Feature usage | Analytics |
| Performance | `perf_` | Timing, resources | Analytics |
| Error | `error_` | Error tracking | Diagnostic |

### 4.2 Event Schema

```typescript
interface TelemetryEvent {
  // Required fields
  event_name: string;           // e.g., "session_started"
  timestamp: string;            // ISO 8601
  event_id: string;             // UUID, generated per event

  // Context (anonymized)
  app_version: string;          // e.g., "1.0.0"
  os_version: string;           // e.g., "14.2"
  device_type: string;          // "mac_arm64" | "mac_x64"
  locale: string;               // e.g., "en-US"

  // Event-specific properties
  properties: Record<string, any>;

  // Session context (if applicable)
  session_id?: string;          // Anonymized session ID (not the real one)
}
```

### 4.3 App Lifecycle Events

```swift
// App launched
TelemetryEvent(
    name: "app_launched",
    properties: [
        "launch_type": "cold" | "warm",
        "launch_duration_ms": 1200,
        "is_first_launch": true,
        "days_since_last_launch": 3
    ]
)

// App updated
TelemetryEvent(
    name: "app_updated",
    properties: [
        "previous_version": "1.0.0",
        "current_version": "1.1.0",
        "update_source": "sparkle" | "manual"
    ]
)

// App terminated
TelemetryEvent(
    name: "app_terminated",
    properties: [
        "session_duration_seconds": 3600,
        "reason": "user" | "system" | "crash"
    ]
)
```

### 4.4 Session Events

```swift
// Session started (anonymized)
TelemetryEvent(
    name: "session_started",
    properties: [
        "engine": "claude" | "gemini" | "codex",
        "is_new_session": true,
        "is_resumed": false
    ]
)

// Session completed
TelemetryEvent(
    name: "session_completed",
    properties: [
        "duration_seconds": 1800,
        "turn_count": 15,
        "tool_call_count": 25,
        "diff_count": 8,
        "diffs_accepted_ratio": 0.75
    ]
)

// Session branched
TelemetryEvent(
    name: "session_branched",
    properties: [
        "branch_point_turn": 5,
        "parent_duration_before_branch": 600
    ]
)
```

### 4.5 UI Interaction Events

```swift
// Feature used
TelemetryEvent(
    name: "ui_feature_used",
    properties: [
        "feature": "command_palette" | "diff_viewer" | "timeline",
        "action": "opened" | "closed" | "used"
    ]
)

// Setting changed
TelemetryEvent(
    name: "ui_setting_changed",
    properties: [
        "setting": "theme" | "trust_mode" | "default_engine",
        "new_value": "dark"  // Only for non-sensitive settings
    ]
)

// Keyboard shortcut used
TelemetryEvent(
    name: "ui_shortcut_used",
    properties: [
        "shortcut": "cmd_k" | "cmd_enter" | "cmd_period"
    ]
)
```

### 4.6 Performance Events

```swift
// Performance metric
TelemetryEvent(
    name: "perf_metric",
    properties: [
        "metric": "ttft" | "launch_time" | "memory_peak",
        "value_ms": 150,
        "context": "large_session"  // Optional context
    ]
)

// Resource pressure
TelemetryEvent(
    name: "perf_resource_pressure",
    properties: [
        "resource": "memory" | "cpu" | "disk",
        "level": "normal" | "warning" | "critical"
    ]
)
```

### 4.7 Error Events

```swift
// Error occurred
TelemetryEvent(
    name: "error_occurred",
    properties: [
        "error_code": "E1002",
        "error_category": "engine",
        "is_recoverable": true,
        "recovery_attempted": true,
        "recovery_succeeded": true
    ]
    // NEVER include: error messages, stack traces with paths, user content
)

// Crash occurred (post-crash on next launch)
TelemetryEvent(
    name: "error_crash",
    properties: [
        "crash_type": "signal" | "exception",
        "signal": "SIGSEGV",  // If signal crash
        "exception_type": "NSInvalidArgumentException",  // If exception
        // Stack trace hash for grouping, not actual trace
        "stack_hash": "a1b2c3d4"
    ]
)
```

---

## 5. Implementation

### 5.1 Telemetry Engine

```swift
actor TelemetryEngine {
    static let shared = TelemetryEngine()

    private var isAnalyticsEnabled = false
    private var isDiagnosticsEnabled = false
    private var eventQueue: [TelemetryEvent] = []
    private let batchSize = 50
    private let flushInterval: TimeInterval = 60  // 1 minute

    func track(_ event: TelemetryEvent) {
        guard shouldCollect(event) else { return }

        let anonymized = anonymize(event)
        eventQueue.append(anonymized)

        if eventQueue.count >= batchSize {
            Task { await flush() }
        }
    }

    private func shouldCollect(_ event: TelemetryEvent) -> Bool {
        switch event.category {
        case .essential:
            return true
        case .functional, .analytics:
            return isAnalyticsEnabled
        case .diagnostic:
            return isDiagnosticsEnabled
        }
    }

    private func anonymize(_ event: TelemetryEvent) -> TelemetryEvent {
        var anonymized = event

        // Remove or hash any potentially identifying information
        anonymized.properties = anonymized.properties.mapValues { value in
            if let path = value as? String, path.contains("/Users/") {
                return hashPath(path)
            }
            return value
        }

        return anonymized
    }

    private func hashPath(_ path: String) -> String {
        // Hash to remove user directory info
        let data = Data(path.utf8)
        return SHA256.hash(data: data).prefix(8).hexString
    }

    func flush() async {
        guard !eventQueue.isEmpty else { return }

        let batch = eventQueue
        eventQueue = []

        // Send to analytics backend
        do {
            try await AnalyticsClient.shared.send(batch)
        } catch {
            // Re-queue on failure (with limit)
            eventQueue = batch + eventQueue
            eventQueue = Array(eventQueue.prefix(500))  // Limit queue size
        }
    }
}
```

### 5.2 Anonymous Session ID

```swift
struct AnonymousSessionID {
    // Generate a random ID for each session
    // NOT linked to the actual session UUID
    static func generate() -> String {
        UUID().uuidString.prefix(8).lowercased()
    }

    // Rotating ID - changes periodically
    static func rotating(interval: TimeInterval = 86400) -> String {
        let epoch = Date().timeIntervalSince1970
        let period = Int(epoch / interval)
        let seed = "\(period)_\(installID)"
        return SHA256.hash(data: Data(seed.utf8)).prefix(8).hexString
    }

    // Install ID - persists across sessions but not linked to user
    private static var installID: String {
        if let id = UserDefaults.standard.string(forKey: "analytics.installId") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "analytics.installId")
        return id
    }
}
```

### 5.3 Local Aggregation

```swift
// Aggregate metrics locally before sending
class LocalAggregator {
    private var sessionDurations: [TimeInterval] = []
    private var turnCounts: [Int] = []
    private var featureUsage: [String: Int] = [:]

    func recordSession(duration: TimeInterval, turns: Int) {
        sessionDurations.append(duration)
        turnCounts.append(turns)

        // Keep only last 100 sessions for aggregation
        if sessionDurations.count > 100 {
            sessionDurations.removeFirst()
            turnCounts.removeFirst()
        }
    }

    func recordFeatureUsage(_ feature: String) {
        featureUsage[feature, default: 0] += 1
    }

    func getAggregatedMetrics() -> [String: Any] {
        return [
            "avg_session_duration": sessionDurations.average,
            "avg_turns_per_session": turnCounts.average,
            "feature_usage_distribution": featureUsage,
            "sample_size": sessionDurations.count
        ]
    }

    // Called periodically to send aggregated metrics
    func flushAggregates() async {
        let metrics = getAggregatedMetrics()
        await TelemetryEngine.shared.track(
            TelemetryEvent(name: "aggregated_usage", properties: metrics)
        )

        // Reset after sending
        featureUsage = [:]
    }
}
```

---

## 6. Data Flow

### 6.1 Collection Pipeline

```
User Action
    │
    ▼
Event Created
    │
    ▼
┌─────────────────────┐
│ Consent Check       │
│ - Is event allowed? │
└──────────┬──────────┘
           │ Yes
           ▼
┌─────────────────────┐
│ Anonymization       │
│ - Remove PII        │
│ - Hash identifiers  │
│ - Strip paths       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Local Queue         │
│ - Batch events      │
│ - Aggregate metrics │
└──────────┬──────────┘
           │ Periodic flush
           ▼
┌─────────────────────┐
│ Encryption          │
│ - TLS in transit    │
│ - Encrypted payload │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Analytics Backend   │
│ - cogit0.com/api    │
└─────────────────────┘
```

### 6.2 Data Retention

| Data Type | Retention Period | Storage Location |
|-----------|------------------|------------------|
| Raw events | 30 days | Encrypted cloud |
| Aggregated metrics | 2 years | Analytics database |
| Crash reports | 90 days | Encrypted cloud |
| User preferences | Until deletion | Local device |

### 6.3 Data Deletion

```swift
class DataDeletionManager {
    // Delete all analytics data for this installation
    func deleteAllData() async throws {
        // 1. Delete local data
        UserDefaults.standard.removeObject(forKey: "analytics.installId")
        UserDefaults.standard.removeObject(forKey: "telemetry.consent")

        // 2. Request server-side deletion
        let installId = AnonymousSessionID.installID  // Get before deleting
        try await AnalyticsClient.shared.requestDeletion(installId: installId)

        // 3. Generate new install ID
        _ = AnonymousSessionID.installID  // Regenerates

        // 4. Confirm deletion
        NotificationCenter.default.post(name: .analyticsDataDeleted, object: nil)
    }
}
```

---

## 7. User Controls

### 7.1 Privacy Settings Panel

```swift
struct PrivacySettingsView: View {
    @ObservedObject var consentManager = ConsentManager.shared

    var body: some View {
        Form {
            Section {
                Text("Blaze collects anonymous usage data to improve the app. No personal information, code, or prompts are ever collected.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            Section("Data Collection") {
                Toggle("Usage Analytics", isOn: $consentManager.consent.analytics)
                Text("Helps us understand which features are popular")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Crash Reports", isOn: $consentManager.consent.diagnostic)
                Text("Helps us fix bugs faster")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Your Data") {
                Button("View Collected Data") {
                    showCollectedData = true
                }

                Button("Export My Data") {
                    exportData()
                }

                Button("Delete All Data", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }

            Section {
                Link("Privacy Policy", destination: URL(string: "https://cogit0.com/privacy")!)
            }
        }
    }
}
```

### 7.2 Data Transparency View

```swift
struct CollectedDataView: View {
    @State private var collectedData: CollectedDataSummary?

    var body: some View {
        List {
            Section("What We Collect") {
                ForEach(collectedData?.eventTypes ?? [], id: \.self) { eventType in
                    HStack {
                        Text(eventType.displayName)
                        Spacer()
                        Text("\(eventType.count) events")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Sample Data") {
                ForEach(collectedData?.sampleEvents ?? [], id: \.id) { event in
                    VStack(alignment: .leading) {
                        Text(event.name)
                            .font(.headline)
                        Text(event.properties.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("What We DON'T Collect") {
                Text("• Your prompts or Claude's responses")
                Text("• Your code or file contents")
                Text("• File paths or project names")
                Text("• Personal information")
                Text("• API keys or credentials")
            }
            .foregroundColor(.secondary)
        }
        .navigationTitle("Collected Data")
    }
}
```

### 7.3 Quick Opt-Out

```swift
// Menu bar item for quick access
struct PrivacyMenuItem: View {
    @ObservedObject var consentManager = ConsentManager.shared

    var body: some View {
        Menu("Privacy") {
            Toggle("Share Analytics", isOn: $consentManager.consent.analytics)
            Toggle("Send Crash Reports", isOn: $consentManager.consent.diagnostic)
            Divider()
            Button("Privacy Settings...") {
                openPrivacySettings()
            }
        }
    }
}
```

---

## 8. Compliance

### 8.1 GDPR Compliance

| Requirement | Implementation |
|-------------|----------------|
| Lawful basis | Consent-based (Art. 6) |
| Right to access | Export data feature |
| Right to erasure | Delete all data feature |
| Data minimization | Only collect necessary data |
| Purpose limitation | Documented purposes only |
| Storage limitation | Defined retention periods |
| Data portability | JSON export |
| Consent withdrawal | One-click opt-out |

### 8.2 CCPA Compliance

| Requirement | Implementation |
|-------------|----------------|
| Right to know | Transparency view shows all data |
| Right to delete | Delete all data feature |
| Right to opt-out | Default opt-out, easy toggle |
| Non-discrimination | No feature gating on consent |
| Notice at collection | First-run consent dialog |

### 8.3 Apple App Privacy

For App Store submission (if applicable):

| Data Type | Collected | Linked to User | Used for Tracking |
|-----------|-----------|----------------|-------------------|
| Crash Data | Yes (opt-in) | No | No |
| Performance Data | Yes (opt-in) | No | No |
| Product Interaction | Yes (opt-in) | No | No |
| Identifiers | No | No | No |
| Usage Data | Yes (opt-in) | No | No |

---

## 9. Security

### 9.1 Data Protection

```swift
struct TelemetrySecurityConfig {
    // TLS 1.3 minimum for transport
    static let minimumTLSVersion = tls_protocol_version_t.TLSv13

    // Certificate pinning for analytics endpoint
    static let pinnedCertificates = [
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    ]

    // Encryption for local queue
    static let localEncryption = true

    // Request signing
    static let signRequests = true
}
```

### 9.2 Secure Transmission

```swift
class AnalyticsClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        config.httpAdditionalHeaders = [
            "X-Client-Version": Bundle.main.appVersion,
            "X-Platform": "macos"
        ]

        self.session = URLSession(
            configuration: config,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
    }

    func send(_ events: [TelemetryEvent]) async throws {
        let payload = try JSONEncoder().encode(events)
        let encrypted = try CryptoKit.encrypt(payload)
        let signed = try sign(encrypted)

        var request = URLRequest(url: analyticsEndpoint)
        request.httpMethod = "POST"
        request.httpBody = signed

        let (_, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AnalyticsError.sendFailed
        }
    }
}
```

### 9.3 Audit Logging

```swift
// Log all telemetry operations for debugging
class TelemetryAuditLog {
    func log(_ action: AuditAction) {
        #if DEBUG
        print("[Telemetry] \(action)")
        #endif

        // Store locally for user inspection
        auditEntries.append(AuditEntry(
            timestamp: Date(),
            action: action.description,
            eventCount: action.eventCount
        ))

        // Keep only last 1000 entries
        if auditEntries.count > 1000 {
            auditEntries.removeFirst(auditEntries.count - 1000)
        }
    }

    enum AuditAction {
        case eventQueued(eventName: String)
        case batchSent(count: Int)
        case consentChanged(analytics: Bool, diagnostic: Bool)
        case dataExported
        case dataDeleted
    }
}
```

---

## Appendix A: Event Reference

### Complete Event List

| Event Name | Category | Properties |
|------------|----------|------------|
| `app_launched` | Essential | launch_type, duration, first_launch |
| `app_terminated` | Essential | session_duration, reason |
| `app_updated` | Essential | previous_version, current_version |
| `session_started` | Functional | engine, is_new, is_resumed |
| `session_completed` | Functional | duration, turns, tools, diffs |
| `session_branched` | Functional | branch_point, parent_duration |
| `ui_feature_used` | Analytics | feature, action |
| `ui_setting_changed` | Analytics | setting, new_value |
| `ui_shortcut_used` | Analytics | shortcut |
| `perf_metric` | Analytics | metric, value, context |
| `perf_resource_pressure` | Analytics | resource, level |
| `error_occurred` | Diagnostic | code, category, recoverable |
| `error_crash` | Diagnostic | type, signal/exception, stack_hash |

---

## Appendix B: Backend Requirements

### API Endpoints

```
POST /api/v1/telemetry/events
  - Receives batched events
  - Returns 200 on success

POST /api/v1/telemetry/delete
  - Requests data deletion
  - Requires install_id
  - Returns 200 on success

GET /api/v1/telemetry/export
  - Exports user data
  - Requires install_id
  - Returns JSON blob
```

### Data Storage Requirements

- Events stored in time-series database (e.g., ClickHouse)
- Personal data (install_id) stored separately with encryption
- Aggregated dashboards use Grafana or similar
- No raw event access without audit trail

---

**End of Document**

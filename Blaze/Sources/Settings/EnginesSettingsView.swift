//
//  EnginesSettingsView.swift
//  Blaze
//
//  Copyright 2025 Cogit0. All rights reserved.
//

import SwiftUI

// MARK: - Engine Environment Variable Definition

/// Represents a known environment variable for an engine
struct EngineEnvVar: Identifiable, Hashable {
    let key: String
    let description: String
    let isSecret: Bool

    var id: String { key }

    init(_ key: String, _ description: String, isSecret: Bool = false) {
        self.key = key
        self.description = description
        self.isSecret = isSecret
    }
}

/// Known environment variables by engine
enum EngineEnvVars {
    static let claude: [EngineEnvVar] = [
        EngineEnvVar("ANTHROPIC_API_KEY", "API key for Anthropic", isSecret: true),
        EngineEnvVar("CLAUDE_CODE_MAX_TOKENS", "Maximum output tokens per response"),
        EngineEnvVar("CLAUDE_CODE_USE_BEDROCK", "Use AWS Bedrock backend (true/false)"),
        EngineEnvVar("CLAUDE_CODE_USE_VERTEX", "Use GCP Vertex backend (true/false)"),
        EngineEnvVar("AWS_REGION", "AWS region for Bedrock (e.g., us-east-1)"),
        EngineEnvVar("AWS_ACCESS_KEY_ID", "AWS access key ID", isSecret: true),
        EngineEnvVar("AWS_SECRET_ACCESS_KEY", "AWS secret access key", isSecret: true),
        EngineEnvVar("GOOGLE_APPLICATION_CREDENTIALS", "Path to GCP service account JSON")
    ]

    static let gemini: [EngineEnvVar] = [
        EngineEnvVar("GOOGLE_API_KEY", "Gemini API key", isSecret: true),
        EngineEnvVar("GEMINI_MODEL", "Model name (e.g., gemini-pro, gemini-ultra)"),
        EngineEnvVar("GOOGLE_APPLICATION_CREDENTIALS", "Path to GCP service account JSON")
    ]

    static let codex: [EngineEnvVar] = [
        EngineEnvVar("OPENAI_API_KEY", "OpenAI API key", isSecret: true),
        EngineEnvVar("OPENAI_ORG_ID", "OpenAI organization ID"),
        EngineEnvVar("CODEX_SANDBOX", "Sandbox mode (true/false)")
    ]

    static func vars(for engine: String) -> [EngineEnvVar] {
        switch engine {
        case "claude": return claude
        case "gemini": return gemini
        case "codex": return codex
        default: return []
        }
    }
}

// MARK: - Engines Settings View

struct EnginesSettingsView: View {
    @AppStorage("defaultEngine") private var engine: String = "claude"
    @State private var envVars: [(key: String, value: String)] = []
    @State private var selectedEnvVar: EngineEnvVar?
    @State private var customKey: String = ""
    @State private var newValue: String = ""
    @State private var useCustomKey: Bool = false

    // MARK: - Codex Auth State
    @State private var codexAuthStatus: CLIAuthStatus = .unknown
    @State private var isAuthenticating: Bool = false
    @State private var authError: String?

    private let engineOptions = [
        ("claude", "Claude Code"),
        ("gemini", "Gemini CLI"),
        ("codex", "Codex CLI")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DSSpacing.xl) {
                // Engine Picker Section
                FormSection(
                    title: "Default Engine",
                    description: "Choose which AI engine to use for new sessions"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Picker("", selection: $engine) {
                            ForEach(engineOptions, id: \.0) { value, label in
                                Text(label).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        // Engine Status
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.ds.positive)
                            Text(engineStatusText)
                                .dsTextStyle(.caption, color: .ds.secondary)
                        }
                    }
                }

                // Codex Authentication Section (shown only when Codex is selected)
                if engine == "codex" {
                    FormSection(
                        title: "OpenAI Authentication",
                        description: "Authenticate with OpenAI to use Codex CLI"
                    ) {
                        VStack(alignment: .leading, spacing: DSSpacing.md) {
                            // Auth Status Row
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: codexAuthStatus.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(codexAuthStatus.isPositive ? Color.ds.positive : Color.ds.secondary)
                                    .symbolEffect(.pulse, isActive: isAuthenticating)

                                Text(codexAuthStatus.displayDescription)
                                    .dsTextStyle(.body, color: codexAuthStatus.isPositive ? .ds.foreground : .ds.secondary)

                                Spacer()

                                if isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                }
                            }

                            // Error message if present
                            if let error = authError {
                                HStack(spacing: DSSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 12))
                                    Text(error)
                                }
                                .dsTextStyle(.caption, color: .ds.negative)
                                .padding(DSSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.ds.negative.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                            }

                            // Auth Buttons
                            HStack(spacing: DSSpacing.sm) {
                                GlassButton(
                                    codexAuthStatus == .authenticated ? "Re-authenticate" : "Authenticate with OpenAI",
                                    icon: "person.badge.key",
                                    style: .primary,
                                    size: .medium,
                                    action: loginCodex
                                )
                                .disabled(isAuthenticating)

                                if codexAuthStatus == .authenticated {
                                    GlassButton(
                                        "Sign Out",
                                        icon: "rectangle.portrait.and.arrow.right",
                                        style: .secondary,
                                        size: .medium,
                                        action: logoutCodex
                                    )
                                    .disabled(isAuthenticating)
                                }
                            }

                            // Help text
                            Text("Opens a browser window to complete OAuth authentication with OpenAI.")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }
                    }
                }

                // Environment Variables Section
                FormSection(
                    title: "Environment Variables",
                    description: "Configure environment variables for \(engineOptions.first(where: { $0.0 == engine })?.1 ?? "engine")"
                ) {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        // Add new env var input
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            // Key picker row
                            HStack(spacing: DSSpacing.sm) {
                                if useCustomKey {
                                    // Custom key text field
                                    GlassTextField("Custom key", text: $customKey)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    // Dropdown for known vars
                                    Menu {
                                        ForEach(availableEnvVars) { envVar in
                                            Button(action: { selectedEnvVar = envVar }) {
                                                VStack(alignment: .leading) {
                                                    Text(envVar.key)
                                                    Text(envVar.description)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        Divider()

                                        Button(action: { useCustomKey = true }) {
                                            Label("Custom Variable", systemImage: "pencil")
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedEnvVar?.key ?? "Select variable")
                                                .font(.system(.body, design: .monospaced))
                                            Spacer()
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.ds.secondary)
                                        }
                                        .padding(.horizontal, DSSpacing.sm)
                                        .padding(.vertical, DSSpacing.xs)
                                        .dsGlassPanel(level: .subtle, cornerRadius: DSRadius.md, elevation: .none, border: .subtle)
                                    }
                                    .frame(maxWidth: .infinity)
                                }

                                // Toggle between custom/picker
                                Button(action: {
                                    useCustomKey.toggle()
                                    if !useCustomKey {
                                        customKey = ""
                                    }
                                }) {
                                    Image(systemName: useCustomKey ? "list.bullet" : "pencil")
                                        .foregroundStyle(Color.ds.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help(useCustomKey ? "Show known variables" : "Enter custom variable")
                            }

                            // Help text for selected variable
                            if let selected = selectedEnvVar, !useCustomKey {
                                HStack(spacing: DSSpacing.xxs) {
                                    if selected.isSecret {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10))
                                    }
                                    Text(selected.description)
                                }
                                .dsTextStyle(.caption, color: .ds.tertiary)
                            }

                            // Value input row
                            HStack(spacing: DSSpacing.sm) {
                                if currentKeyIsSecret {
                                    GlassTextField("Value (secret)", text: $newValue, icon: "lock", isSecure: true)
                                } else {
                                    GlassTextField("Value", text: $newValue)
                                }

                                GlassButton(
                                    "Add",
                                    icon: "plus",
                                    style: .primary,
                                    size: .medium,
                                    action: addEnvironmentVariable
                                )
                                .disabled(currentKey.isEmpty || newValue.isEmpty)
                            }
                        }

                        // Existing env vars list
                        if !envVars.isEmpty {
                            Divider()
                                .padding(.vertical, DSSpacing.xs)

                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                ForEach(Array(envVars.enumerated()), id: \.offset) { index, envVar in
                                    HStack(spacing: DSSpacing.sm) {
                                        // Key with icon if secret
                                        HStack(spacing: DSSpacing.xxs) {
                                            if isSecretKey(envVar.key) {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.ds.tertiary)
                                            }
                                            Text(envVar.key)
                                                .font(.system(.body, design: .monospaced))
                                                .dsTextStyle(.body)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        // Value (masked if secret)
                                        Text(isSecretKey(envVar.key) ? maskValue(envVar.value) : envVar.value)
                                            .font(.system(.body, design: .monospaced))
                                            .dsTextStyle(.body, color: .ds.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button(action: { removeEnvironmentVariable(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(Color.ds.secondary)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(DSSpacing.xs)
                                    .background(Color.ds.surface.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
                                }
                            }
                        } else {
                            Text("No environment variables configured")
                                .dsTextStyle(.caption, color: .ds.tertiary)
                        }
                    }
                }

                // MCP Servers Section
                FormSection(
                    title: "MCP Servers",
                    description: "Model Context Protocol server configuration"
                ) {
                    Text("MCP server configuration coming soon")
                        .dsTextStyle(.caption, color: .ds.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Test Connection Section
                FormSection {
                    GlassButton(
                        "Test Connection",
                        icon: "checkmark.circle",
                        style: .primary,
                        size: .medium,
                        action: testConnection
                    )
                }
            }
            .padding(DSSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Check Codex auth status on appear if Codex is selected
            if engine == "codex" {
                checkCodexAuthStatus()
            }
        }
        .onChange(of: engine) { _, newEngine in
            // Check Codex auth when switching to Codex
            if newEngine == "codex" {
                checkCodexAuthStatus()
            }
        }
    }

    // MARK: - Computed Properties

    private var engineStatusText: String {
        let engineName = engineOptions.first(where: { $0.0 == engine })?.1 ?? "Unknown"
        return "\(engineName) - Ready"
    }

    /// Available env vars for current engine, excluding already-configured ones
    private var availableEnvVars: [EngineEnvVar] {
        let configuredKeys = Set(envVars.map { $0.key })
        return EngineEnvVars.vars(for: engine).filter { !configuredKeys.contains($0.key) }
    }

    /// The current key being entered (from picker or custom input)
    private var currentKey: String {
        useCustomKey ? customKey : (selectedEnvVar?.key ?? "")
    }

    /// Whether the current key is a secret (should use secure field)
    private var currentKeyIsSecret: Bool {
        if useCustomKey {
            // Check if custom key matches a known secret
            return isSecretKey(customKey)
        }
        return selectedEnvVar?.isSecret ?? false
    }

    // MARK: - Actions

    private func addEnvironmentVariable() {
        let key = currentKey
        guard !key.isEmpty, !newValue.isEmpty else { return }
        envVars.append((key: key, value: newValue))
        // Reset inputs
        selectedEnvVar = nil
        customKey = ""
        newValue = ""
        useCustomKey = false
    }

    /// Check if a key is known to be a secret
    private func isSecretKey(_ key: String) -> Bool {
        let allSecretKeys = (EngineEnvVars.claude + EngineEnvVars.gemini + EngineEnvVars.codex)
            .filter { $0.isSecret }
            .map { $0.key }
        return allSecretKeys.contains(key) || key.lowercased().contains("key") || key.lowercased().contains("secret")
    }

    /// Mask a secret value for display
    private func maskValue(_ value: String) -> String {
        guard value.count > 4 else { return String(repeating: "*", count: value.count) }
        let visibleCount = min(4, value.count / 4)
        return String(value.prefix(visibleCount)) + String(repeating: "*", count: value.count - visibleCount)
    }

    private func removeEnvironmentVariable(at index: Int) {
        guard index < envVars.count else { return }
        envVars.remove(at: index)
    }

    private func testConnection() {
        print("Test Connection clicked for engine: \(engine)")
    }

    // MARK: - Codex Auth Actions

    private func checkCodexAuthStatus() {
        Task {
            codexAuthStatus = .checking
            let status = await CLIAuthService.shared.checkCodexAuth()
            await MainActor.run {
                codexAuthStatus = status
            }
        }
    }

    private func loginCodex() {
        Task {
            isAuthenticating = true
            authError = nil

            do {
                try await CLIAuthService.shared.loginCodex()
                await MainActor.run {
                    codexAuthStatus = .authenticated
                    isAuthenticating = false
                }
            } catch let error as CLIAuthError {
                await MainActor.run {
                    authError = error.localizedDescription
                    isAuthenticating = false
                }
                // Re-check status in case partial success
                checkCodexAuthStatus()
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    isAuthenticating = false
                }
            }
        }
    }

    private func logoutCodex() {
        Task {
            isAuthenticating = true
            authError = nil

            do {
                try await CLIAuthService.shared.logoutCodex()
                await MainActor.run {
                    codexAuthStatus = .notAuthenticated
                    isAuthenticating = false
                }
            } catch let error as CLIAuthError {
                await MainActor.run {
                    authError = error.localizedDescription
                    isAuthenticating = false
                }
            } catch {
                await MainActor.run {
                    authError = error.localizedDescription
                    isAuthenticating = false
                }
            }
        }
    }
}

#Preview {
    EnginesSettingsView()
        .frame(width: 600, height: 700)
}

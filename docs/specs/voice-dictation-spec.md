# Voice & Dictation Mode Spec

> "Open the pod bay doors, Claude." — Every developer trying voice coding for the first time

## Overview

Voice & Dictation Mode transforms Blaze into a hands-free coding assistant. Developers can speak naturally to Claude, dictate code, navigate the interface, and control their entire workflow without touching the keyboard. This isn't just speech-to-text—it's a fully voice-native development experience.

## Core Concepts

### Why Voice?

1. **Accessibility**: Essential for developers with RSI, mobility limitations, or temporary injuries
2. **Multitasking**: Code while walking, stretching, or resting your hands
3. **Natural Expression**: Complex ideas often easier to explain verbally than type
4. **Speed**: Natural speech averages 150 WPM vs. 40-80 WPM typing
5. **Reduced Strain**: Alternating between voice and keyboard reduces fatigue

### Three Voice Modes

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Voice Modes                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  🎙️ Dictation Mode           💬 Conversation Mode                   │
│  ─────────────────           ──────────────────────                 │
│  Speak → Text                Speak → Claude understands             │
│  "function hello world"      "Create a function that greets"        │
│  Literal transcription       Intent interpretation                  │
│                                                                     │
│  🎛️ Command Mode                                                    │
│  ────────────────                                                   │
│  Voice controls the app                                             │
│  "Open settings" "Next file" "Approve all"                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Model

### Voice Session

```swift
/// Represents an active voice session
struct VoiceSession: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var mode: VoiceMode
    var utterances: [Utterance]
    var transcriptionConfig: TranscriptionConfig
    var commandHistory: [VoiceCommand]
    var stats: VoiceStats
}

enum VoiceMode: String, Codable {
    case dictation      // Literal transcription
    case conversation   // Natural language to Claude
    case command        // App control
    case hybrid         // Auto-detect mode based on content
}

struct TranscriptionConfig: Codable {
    var language: String           // e.g., "en-US"
    var alternativeLanguages: [String]
    var profanityFilter: Bool
    var punctuationMode: PunctuationMode
    var numberFormat: NumberFormat
    var vocabularyBoost: [String]  // Technical terms to recognize
    var customPhrases: [CustomPhrase]
}

enum PunctuationMode: String, Codable {
    case automatic              // AI adds punctuation
    case spoken                 // User says "period" "comma"
    case none                   // No punctuation
}

enum NumberFormat: String, Codable {
    case words                  // "forty two"
    case digits                 // "42"
    case auto                   // Context-dependent
}

struct CustomPhrase: Codable {
    let spoken: String          // What user says
    let written: String         // What gets typed
    let context: PhraseContext? // When to apply
}

enum PhraseContext: String, Codable {
    case code
    case prose
    case command
    case always
}
```

### Utterance

```swift
/// A single spoken segment
struct Utterance: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let startTime: Date
    var endTime: Date?
    var transcript: String
    var confidence: Float
    var alternatives: [TranscriptAlternative]
    var words: [WordTiming]
    var interpretation: Interpretation?
    var action: VoiceAction?
}

struct TranscriptAlternative: Codable {
    let transcript: String
    let confidence: Float
}

struct WordTiming: Codable {
    let word: String
    let startOffset: TimeInterval
    let endOffset: TimeInterval
    let confidence: Float
    let speakerTag: Int?        // For multi-speaker detection
}

/// What we think the user meant
struct Interpretation: Codable {
    let type: InterpretationType
    let intent: String
    let entities: [Entity]
    let confidence: Float
}

enum InterpretationType: String, Codable {
    case command                // App control
    case codeRequest            // Ask Claude to code
    case question               // Ask Claude a question
    case dictation              // Literal text
    case correction             // Fix previous utterance
    case navigation             // Move around the app
}

struct Entity: Codable {
    let type: String            // "file", "function", "variable", etc.
    let value: String
    let position: Range<Int>    // Position in transcript
}
```

### Voice Commands

```swift
/// A recognized voice command
struct VoiceCommand: Identifiable, Codable {
    let id: UUID
    let utteranceId: UUID
    let command: CommandType
    let parameters: [String: Any]
    let executedAt: Date
    let result: CommandResult
}

enum CommandType: String, Codable {
    // Navigation
    case openFile
    case closeFile
    case nextFile
    case previousFile
    case goToLine
    case goToFunction
    case scrollUp
    case scrollDown

    // Editing
    case selectLine
    case selectWord
    case selectAll
    case copy
    case paste
    case undo
    case redo
    case deleteLine

    // Claude Interaction
    case sendMessage
    case stopGeneration
    case approveChange
    case rejectChange
    case approveAll
    case rejectAll

    // App Control
    case openSettings
    case toggleVoice
    case switchMode
    case openSearch
    case togglePreview
    case toggleTerminal

    // Session
    case newSession
    case newBranch
    case switchSession
}

enum CommandResult: Codable {
    case success
    case failed(reason: String)
    case ambiguous(options: [String])
    case needsConfirmation(action: String)
}
```

## Speech Recognition

### Recognition Engine

```swift
@MainActor
class VoiceRecognitionEngine: ObservableObject {
    @Published var isListening = false
    @Published var currentTranscript = ""
    @Published var audioLevel: Float = 0
    @Published var error: VoiceError?

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    private let commandInterpreter = CommandInterpreter()
    private let vocabularyManager = VocabularyManager()

    /// Start listening with specified configuration
    func startListening(config: TranscriptionConfig) async throws {
        // Request permissions
        guard await requestPermissions() else {
            throw VoiceError.permissionDenied
        }

        // Initialize recognizer for language
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: config.language))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }

        // Apply vocabulary boost
        if !config.vocabularyBoost.isEmpty {
            await vocabularyManager.setContextualPhrases(config.vocabularyBoost)
        }

        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false // Use cloud for better accuracy
        request.addsPunctuation = config.punctuationMode == .automatic

        // Start audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode

        let recordingFormat = inputNode?.outputFormat(forBus: 0)
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateAudioLevel(buffer)
        }

        audioEngine?.prepare()
        try audioEngine?.start()

        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }

        isListening = true
    }

    /// Handle recognition results
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        guard let result = result else {
            if let error = error {
                self.error = VoiceError.recognitionFailed(error)
            }
            return
        }

        let transcript = result.bestTranscription.formattedString
        currentTranscript = transcript

        // Detect if this is a command
        if result.isFinal {
            Task {
                await processCompletedUtterance(
                    transcript: transcript,
                    confidence: result.bestTranscription.segments.map(\.confidence).average(),
                    alternatives: result.transcriptions.map { $0.formattedString }
                )
            }
        }
    }

    /// Process completed utterance and determine action
    private func processCompletedUtterance(
        transcript: String,
        confidence: Float,
        alternatives: [String]
    ) async {
        // Check for wake words / command triggers
        if let command = await commandInterpreter.interpret(transcript) {
            await executeCommand(command)
            return
        }

        // Determine if this is for Claude or dictation
        let mode = await determineMode(transcript)

        switch mode {
        case .command:
            // Re-interpret as command with looser matching
            if let command = await commandInterpreter.interpretLoose(transcript) {
                await executeCommand(command)
            }

        case .conversation:
            // Send to Claude as natural language
            await sendToClaudeAsConversation(transcript)

        case .dictation:
            // Insert as literal text
            await insertText(transcript)

        case .hybrid:
            // Let context decide
            await handleHybridMode(transcript)
        }
    }

    /// Calculate audio level for visual feedback
    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength

        var sum: Float = 0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frames))
        let db = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (db + 60) / 60)) // Normalize to 0-1

        DispatchQueue.main.async {
            self.audioLevel = normalizedLevel
        }
    }
}
```

### Command Interpretation

```swift
class CommandInterpreter {

    private let commandPatterns: [CommandPattern] = [
        // Navigation
        CommandPattern(
            patterns: ["open file *", "open *", "switch to *"],
            command: .openFile,
            extractors: [.fileName]
        ),
        CommandPattern(
            patterns: ["close file", "close this", "close"],
            command: .closeFile,
            extractors: []
        ),
        CommandPattern(
            patterns: ["go to line *", "line *", "jump to line *"],
            command: .goToLine,
            extractors: [.lineNumber]
        ),
        CommandPattern(
            patterns: ["go to function *", "find function *", "jump to *"],
            command: .goToFunction,
            extractors: [.functionName]
        ),

        // Claude interaction
        CommandPattern(
            patterns: ["approve", "approve this", "accept", "looks good", "ship it", "LGTM"],
            command: .approveChange,
            extractors: []
        ),
        CommandPattern(
            patterns: ["reject", "reject this", "no", "revert", "undo this"],
            command: .rejectChange,
            extractors: []
        ),
        CommandPattern(
            patterns: ["approve all", "accept all", "approve everything"],
            command: .approveAll,
            extractors: []
        ),
        CommandPattern(
            patterns: ["stop", "stop generating", "cancel", "nevermind", "hold on"],
            command: .stopGeneration,
            extractors: []
        ),

        // Editing
        CommandPattern(
            patterns: ["select line", "select this line"],
            command: .selectLine,
            extractors: []
        ),
        CommandPattern(
            patterns: ["select all", "select everything"],
            command: .selectAll,
            extractors: []
        ),
        CommandPattern(
            patterns: ["copy", "copy that", "copy this"],
            command: .copy,
            extractors: []
        ),
        CommandPattern(
            patterns: ["paste", "paste that"],
            command: .paste,
            extractors: []
        ),
        CommandPattern(
            patterns: ["undo", "undo that", "go back"],
            command: .undo,
            extractors: []
        ),

        // App control
        CommandPattern(
            patterns: ["open settings", "settings", "preferences"],
            command: .openSettings,
            extractors: []
        ),
        CommandPattern(
            patterns: ["dictation mode", "switch to dictation", "just type what I say"],
            command: .switchMode,
            extractors: [.literal("dictation")]
        ),
        CommandPattern(
            patterns: ["conversation mode", "talk to Claude", "chat mode"],
            command: .switchMode,
            extractors: [.literal("conversation")]
        ),
    ]

    /// Interpret transcript as a command
    func interpret(_ transcript: String) async -> VoiceCommand? {
        let normalized = normalizeTranscript(transcript)

        for pattern in commandPatterns {
            if let match = pattern.match(normalized) {
                return VoiceCommand(
                    id: UUID(),
                    utteranceId: UUID(),
                    command: pattern.command,
                    parameters: match.extractedValues,
                    executedAt: Date(),
                    result: .success
                )
            }
        }

        return nil
    }

    /// More flexible interpretation for hybrid mode
    func interpretLoose(_ transcript: String) async -> VoiceCommand? {
        let normalized = normalizeTranscript(transcript)

        // Use embedding similarity for fuzzy matching
        let embedding = await EmbeddingService.embed(normalized)

        for pattern in commandPatterns {
            let patternEmbedding = await pattern.cachedEmbedding()
            let similarity = cosineSimilarity(embedding, patternEmbedding)

            if similarity > 0.85 {
                // Good enough match
                return VoiceCommand(
                    id: UUID(),
                    utteranceId: UUID(),
                    command: pattern.command,
                    parameters: [:],
                    executedAt: Date(),
                    result: .success
                )
            }
        }

        return nil
    }

    private func normalizeTranscript(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
    }
}

struct CommandPattern {
    let patterns: [String]
    let command: CommandType
    let extractors: [ValueExtractor]

    enum ValueExtractor {
        case fileName
        case lineNumber
        case functionName
        case literal(String)
    }

    func match(_ input: String) -> PatternMatch? {
        for pattern in patterns {
            if let match = matchPattern(pattern, against: input) {
                return match
            }
        }
        return nil
    }
}
```

## Code Dictation

### Dictation Engine

```swift
class CodeDictationEngine {

    private let languageModels: [String: CodeLanguageModel]

    /// Convert spoken code to actual code
    func transcribeCode(_ spoken: String, language: String) -> String {
        let model = languageModels[language] ?? languageModels["generic"]!

        var result = spoken

        // Apply language-specific transformations
        result = model.applyTransformations(result)

        // Handle code-specific phrases
        result = expandCodePhrases(result)

        // Format according to conventions
        result = model.formatCode(result)

        return result
    }

    /// Expand spoken code phrases to actual code
    private func expandCodePhrases(_ spoken: String) -> String {
        let expansions: [(pattern: String, replacement: String)] = [
            // Operators
            ("equals equals", "=="),
            ("not equals", "!="),
            ("greater than or equal", ">="),
            ("less than or equal", "<="),
            ("greater than", ">"),
            ("less than", "<"),
            ("plus equals", "+="),
            ("minus equals", "-="),
            ("arrow", "->"),
            ("fat arrow", "=>"),
            ("double colon", "::"),

            // Brackets
            ("open paren", "("),
            ("close paren", ")"),
            ("open bracket", "["),
            ("close bracket", "]"),
            ("open brace", "{"),
            ("close brace", "}"),
            ("open angle", "<"),
            ("close angle", ">"),

            // Keywords (Swift)
            ("var", "var "),
            ("let", "let "),
            ("func", "func "),
            ("struct", "struct "),
            ("class", "class "),
            ("enum", "enum "),
            ("protocol", "protocol "),
            ("extension", "extension "),
            ("guard let", "guard let "),
            ("if let", "if let "),

            // Common patterns
            ("new line", "\n"),
            ("indent", "    "),
            ("space", " "),
            ("tab", "\t"),

            // Boolean
            ("true", "true"),
            ("false", "false"),
            ("nil", "nil"),
            ("null", "null"),
        ]

        var result = spoken.lowercased()
        for (pattern, replacement) in expansions {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }

        return result
    }
}

/// Language-specific code model
protocol CodeLanguageModel {
    var language: String { get }
    func applyTransformations(_ input: String) -> String
    func formatCode(_ input: String) -> String
    var commonKeywords: [String] { get }
    var namingConvention: NamingConvention { get }
}

class SwiftCodeModel: CodeLanguageModel {
    let language = "swift"

    var commonKeywords: [String] {
        ["func", "var", "let", "struct", "class", "enum", "protocol",
         "extension", "guard", "if", "else", "switch", "case", "for",
         "while", "return", "throws", "async", "await", "try", "catch"]
    }

    var namingConvention: NamingConvention { .camelCase }

    func applyTransformations(_ input: String) -> String {
        var result = input

        // "function foo" -> "func foo"
        result = result.replacingOccurrences(of: "function ", with: "func ")

        // "variable" -> "var"
        result = result.replacingOccurrences(of: "variable ", with: "var ")

        // "constant" -> "let"
        result = result.replacingOccurrences(of: "constant ", with: "let ")

        // Handle naming conventions
        result = applyNamingConvention(result)

        return result
    }

    func formatCode(_ input: String) -> String {
        // Apply basic Swift formatting
        var result = input

        // Add space after keywords
        for keyword in commonKeywords {
            result = result.replacingOccurrences(
                of: "\(keyword)([a-zA-Z])",
                with: "\(keyword) $1",
                options: .regularExpression
            )
        }

        return result
    }

    private func applyNamingConvention(_ input: String) -> String {
        // Convert spoken names to camelCase
        // "my variable name" -> "myVariableName"
        let words = input.components(separatedBy: .whitespaces)
        guard words.count > 1 else { return input }

        // Detect if this looks like a variable name (multiple lowercase words)
        let potentialName = words.filter { $0.first?.isLowercase == true }
        if potentialName.count > 1 {
            let camelCase = potentialName.enumerated().map { index, word in
                index == 0 ? word : word.capitalized
            }.joined()
            return input.replacingOccurrences(of: potentialName.joined(separator: " "), with: camelCase)
        }

        return input
    }
}
```

### Dictation UI

```swift
struct DictationOverlay: View {
    @ObservedObject var voice: VoiceRecognitionEngine
    @State private var showTranscript = true

    var body: some View {
        VStack {
            Spacer()

            // Floating dictation panel
            VStack(spacing: 16) {
                // Mode indicator
                HStack {
                    Image(systemName: voice.mode.icon)
                    Text(voice.mode.displayName)
                        .font(.caption)
                }
                .foregroundColor(.secondary)

                // Waveform visualizer
                WaveformView(level: voice.audioLevel)
                    .frame(height: 40)

                // Live transcript
                if showTranscript && !voice.currentTranscript.isEmpty {
                    Text(voice.currentTranscript)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .transition(.opacity)
                }

                // Status
                HStack {
                    Circle()
                        .fill(voice.isListening ? Color.red : Color.gray)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: voice.isListening)

                    Text(voice.isListening ? "Listening..." : "Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Toggle transcript
                    Button(action: { showTranscript.toggle() }) {
                        Image(systemName: showTranscript ? "text.bubble.fill" : "text.bubble")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 10)
            )
            .frame(width: 400)
            .padding()
        }
    }
}

struct WaveformView: View {
    let level: Float
    @State private var bars: [Float] = Array(repeating: 0, count: 20)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 4, height: CGFloat(bars[index]) * 40)
                    .animation(.easeOut(duration: 0.1), value: bars[index])
            }
        }
        .onChange(of: level) { _, newLevel in
            // Shift bars left and add new value
            bars.removeFirst()
            bars.append(newLevel)
        }
    }
}

extension VoiceMode {
    var icon: String {
        switch self {
        case .dictation: return "keyboard"
        case .conversation: return "bubble.left.and.bubble.right"
        case .command: return "command"
        case .hybrid: return "waveform"
        }
    }

    var displayName: String {
        switch self {
        case .dictation: return "Dictation"
        case .conversation: return "Conversation"
        case .command: return "Command"
        case .hybrid: return "Smart Mode"
        }
    }
}
```

## Voice Feedback

### Audio Feedback

```swift
class VoiceFeedbackEngine {
    private var synthesizer = AVSpeechSynthesizer()

    /// Speak response to user
    func speak(_ text: String, priority: SpeechPriority = .normal) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = priority.rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8

        if priority == .interrupt {
            synthesizer.stopSpeaking(at: .immediate)
        }

        synthesizer.speak(utterance)
    }

    /// Provide confirmation sound
    func playConfirmation(_ type: ConfirmationType) {
        let sound: SystemSoundID
        switch type {
        case .success:
            sound = 1004 // System positive sound
        case .error:
            sound = 1006 // System negative sound
        case .attention:
            sound = 1007 // System attention sound
        }
        AudioServicesPlaySystemSound(sound)
    }

    /// Announce command result
    func announceResult(_ command: VoiceCommand) {
        switch command.result {
        case .success:
            playConfirmation(.success)
            // Optionally speak confirmation
            if UserDefaults.standard.bool(forKey: "voiceConfirmations") {
                speak(command.command.confirmationPhrase)
            }

        case .failed(let reason):
            playConfirmation(.error)
            speak("Sorry, \(reason)")

        case .ambiguous(let options):
            speak("Did you mean \(options.joined(separator: " or "))?")

        case .needsConfirmation(let action):
            speak("Should I \(action)?")
        }
    }
}

enum SpeechPriority {
    case low        // Wait for current speech
    case normal     // Queue after current
    case high       // Interrupt non-critical
    case interrupt  // Stop everything

    var rate: Float {
        switch self {
        case .low: return 0.4
        case .normal: return 0.5
        case .high: return 0.55
        case .interrupt: return 0.6
        }
    }
}

enum ConfirmationType {
    case success
    case error
    case attention
}

extension CommandType {
    var confirmationPhrase: String {
        switch self {
        case .openFile: return "File opened"
        case .closeFile: return "File closed"
        case .approveChange: return "Changes approved"
        case .rejectChange: return "Changes rejected"
        case .approveAll: return "All changes approved"
        case .stopGeneration: return "Stopped"
        case .undo: return "Undone"
        case .redo: return "Redone"
        default: return "Done"
        }
    }
}
```

## Privacy & Security

### Privacy Controls

```swift
struct VoicePrivacyConfig: Codable {
    var useOnDeviceOnly: Bool       // Never send audio to cloud
    var storeTranscripts: Bool       // Keep transcript history
    var transcriptRetention: TimeInterval  // How long to keep
    var anonymizeTranscripts: Bool   // Remove identifying info
    var allowCloudProcessing: Bool   // For better accuracy
    var sensitiveDataDetection: Bool // Redact passwords, keys, etc.
}

class VoicePrivacyManager {

    /// Redact sensitive information from transcripts
    func redactSensitive(_ transcript: String) -> String {
        var result = transcript

        // Patterns to redact
        let patterns = [
            // API keys
            "(?i)(api[_-]?key|secret|token)[\\s:=]+[a-z0-9_-]{20,}",
            // Passwords
            "(?i)password[\\s:=]+\\S+",
            // Credit card numbers
            "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b",
            // SSN
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // Email addresses
            "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }

        return result
    }

    /// Delete all voice data
    func clearAllVoiceData() async {
        await VoiceSessionStore.shared.deleteAll()
        UserDefaults.standard.removeObject(forKey: "voiceVocabulary")
        UserDefaults.standard.removeObject(forKey: "voiceCustomPhrases")
    }
}
```

## Keyboard Shortcuts

| Action | Shortcut | Description |
|--------|----------|-------------|
| Toggle Voice | ⌃ + Space | Start/stop voice listening |
| Push-to-Talk | Hold Space | Listen only while held |
| Switch Mode | ⌃ + M | Cycle through voice modes |
| Dictation Mode | ⌃ + D | Switch to dictation |
| Conversation Mode | ⌃ + C | Switch to conversation |
| Command Mode | ⌃ + K | Switch to command |
| Replay Last | ⌃ + R | Re-transcribe last utterance |
| Cancel | Escape | Cancel current voice input |
| Voice Settings | ⌃ + , | Open voice settings |

## Voice Command Reference

### Navigation Commands
```
"Open [filename]"                    Open a file
"Close file" / "Close this"          Close current file
"Next file" / "Next tab"             Switch to next file
"Previous file" / "Previous tab"     Switch to previous file
"Go to line [number]"                Jump to line
"Go to [function/class name]"        Navigate to symbol
"Search for [text]"                  Open search with text
"Find [text]"                        Find in current file
```

### Claude Interaction
```
"Send" / "Send that"                 Send current message
"Stop" / "Stop generating"           Stop Claude's response
"Approve" / "Accept" / "LGTM"        Approve current change
"Reject" / "Revert"                  Reject current change
"Approve all"                        Approve all pending changes
"Reject all"                         Reject all pending changes
"Branch here"                        Create conversation branch
"New session"                        Start new session
```

### Editing Commands
```
"Select line" / "Select this line"   Select current line
"Select all"                         Select entire file
"Copy" / "Copy that"                 Copy selection
"Paste" / "Paste here"               Paste clipboard
"Undo" / "Go back"                   Undo last change
"Redo" / "Go forward"                Redo last undo
"Delete line"                        Delete current line
"Duplicate line"                     Duplicate current line
```

### App Control
```
"Open settings" / "Settings"         Open settings
"Toggle preview"                     Show/hide preview
"Toggle terminal"                    Show/hide terminal
"Toggle sidebar"                     Show/hide sidebar
"Full screen" / "Exit full screen"   Toggle full screen
"Zoom in" / "Zoom out"               Adjust font size
```

## Fun Messages

### Listening Started
```swift
let listeningMessages = [
    // Star Wars
    "\"I'm listening... always.\" — The Force",
    "Ears are open. Midi-chlorians are flowing.",
    "Ready to receive your transmissions, General.",

    // Star Trek
    "Hailing frequencies open.",
    "Voice sensors online. Make it so.",
    "Universal translator engaged. Speak freely.",

    // Marvel
    "\"JARVIS online and ready.\" — Your personal AI",
    "Ears bigger than Rocket's ego. Listening.",
    "\"I understood that reference.\" — Ready to understand more",

    // DC
    "\"I'm vengeance. I'm the night. I'm listening.\" — Batman",
    "Faster than a speeding transcript!",
]
```

### Recognition Success
```swift
let successMessages = [
    "Got it! Crystal clear, like Vibranium.",
    "Message received loud and clear, Captain.",
    "\"I find your voice... acceptable.\" — Darth Vader",
    "Transcribed at Warp 9!",
]
```

### Recognition Failure
```swift
let failureMessages = [
    // Star Wars
    "\"I sense a disturbance in your audio.\" — Obi-Wan",
    "Didn't quite catch that. Even Yoda would struggle.",

    // Star Trek
    "\"I'm giving it all she's got, Captain!\" — Scotty, on your mumbling",
    "Audio interference detected. Rerouting through backup sensors.",

    // Marvel
    "\"I'm sorry, I didn't get that.\" — Vision, confused",
    "Even Daredevil's super hearing couldn't decode that.",

    // DC
    "\"WHERE IS THE CLEAR AUDIO?\" — Batman voice",
    "Superman's super hearing failed. That's saying something.",
]
```

## Testing

```swift
class VoiceRecognitionTests: XCTestCase {

    func testCommandRecognition() async {
        let interpreter = CommandInterpreter()

        // Exact matches
        let openCommand = await interpreter.interpret("open file test.swift")
        XCTAssertEqual(openCommand?.command, .openFile)
        XCTAssertEqual(openCommand?.parameters["fileName"] as? String, "test.swift")

        let approveCommand = await interpreter.interpret("approve")
        XCTAssertEqual(approveCommand?.command, .approveChange)

        // Natural variations
        let lgftmCommand = await interpreter.interpret("looks good to me")
        XCTAssertEqual(lgftmCommand?.command, .approveChange)
    }

    func testCodeDictation() {
        let engine = CodeDictationEngine()

        // Swift code
        let swiftCode = engine.transcribeCode(
            "let my variable equals five",
            language: "swift"
        )
        XCTAssertEqual(swiftCode, "let myVariable = 5")

        // Operators
        let operators = engine.transcribeCode(
            "if x greater than or equal to y",
            language: "swift"
        )
        XCTAssertEqual(operators, "if x >= y")
    }

    func testPrivacyRedaction() {
        let manager = VoicePrivacyManager()

        let sensitive = "my api key is sk-1234567890abcdef and password is hunter2"
        let redacted = manager.redactSensitive(sensitive)

        XCTAssertFalse(redacted.contains("sk-1234567890abcdef"))
        XCTAssertFalse(redacted.contains("hunter2"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testModeDetection() async {
        let engine = VoiceRecognitionEngine()

        // Should be detected as command
        let commandMode = await engine.determineMode("open settings")
        XCTAssertEqual(commandMode, .command)

        // Should be detected as conversation
        let chatMode = await engine.determineMode("hey Claude can you help me with this function")
        XCTAssertEqual(chatMode, .conversation)

        // Should be detected as dictation
        let dictationMode = await engine.determineMode("function calculate total price open paren items close paren")
        XCTAssertEqual(dictationMode, .dictation)
    }
}
```

## Accessibility

- Voice mode designed for hands-free operation
- Compatible with VoiceOver for screen reader users
- Adjustable speech rate and voice selection
- Visual feedback for hearing-impaired users (waveforms, transcript)
- Push-to-talk option for noisy environments
- Customizable wake words
- Low-latency feedback for realtime interaction

---

*"Computer, end program." — Captain Picard, wrapping up a voice session*

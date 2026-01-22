# Voice & Dictation Mode Spec

> Cogit0 Blaze - Code with Your Voice

## Overview

Voice & Dictation Mode enables hands-free interaction with Claude Code through **speech-to-text input**, **text-to-speech output**, and **voice commands**. This accessibility feature also appeals to users who prefer speaking their thoughts or need to multitask while coding.

---

## 1. Core Features

### 1.1 Feature Matrix

| Feature | Description | Priority |
|---------|-------------|----------|
| **Dictation Input** | Speak prompts instead of typing | P0 |
| **Response TTS** | Listen to Claude's responses | P0 |
| **Voice Commands** | Control app via voice | P1 |
| **Wake Word** | "Hey Blaze" activation | P2 |
| **Code Readback** | Spoken code with syntax | P1 |
| **Continuous Mode** | Always-on listening | P2 |
| **Noise Cancellation** | Filter background noise | P2 |

### 1.2 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      VOICE ARCHITECTURE                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌───────────┐   │
│  │  Microphone │──▶│   Speech    │──▶│    Text     │──▶│   Chat    │   │
│  │   Input     │   │ Recognition │   │  Processor  │   │   View    │   │
│  └─────────────┘   └─────────────┘   └─────────────┘   └───────────┘   │
│                                                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌───────────┐   │
│  │   Speaker   │◀──│    TTS      │◀──│  Response   │◀──│   Claude  │   │
│  │   Output    │   │   Engine    │   │  Formatter  │   │   Output  │   │
│  └─────────────┘   └─────────────┘   └─────────────┘   └───────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Speech Recognition

### 2.1 macOS Speech Framework

```swift
// SpeechRecognizer.swift

import Speech

@Observable
final class SpeechRecognizer {
    var isListening = false
    var transcript = ""
    var confidence: Float = 0

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startListening() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Privacy

        // Start recognition task
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                self.confidence = result.bestTranscription.segments.last?.confidence ?? 0

                // Detect end of speech
                if result.isFinal {
                    self.handleFinalTranscript(result.bestTranscription.formattedString)
                }
            }

            if error != nil {
                self.stopListening()
            }
        }

        // Configure microphone input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        transcript = ""
    }

    private func handleFinalTranscript(_ text: String) {
        // Check for voice commands first
        if let command = VoiceCommandParser.parse(text) {
            executeCommand(command)
        } else {
            // Send as chat input
            NotificationCenter.default.post(
                name: .voiceInputReceived,
                object: nil,
                userInfo: ["text": text]
            )
        }
    }
}
```

### 2.2 Voice Command Parser

```swift
// VoiceCommandParser.swift

enum VoiceCommand {
    case send                    // "send" / "submit"
    case cancel                  // "cancel" / "stop"
    case clear                   // "clear" / "delete"
    case newSession              // "new session" / "new chat"
    case approve                 // "approve" / "yes"
    case reject                  // "reject" / "no"
    case readResponse            // "read that" / "read response"
    case stopReading             // "stop reading"
    case scrollUp                // "scroll up"
    case scrollDown              // "scroll down"
    case switchSession(String)   // "switch to [name]"
}

struct VoiceCommandParser {
    static let patterns: [(regex: Regex<Substring>, command: (Regex<Substring>.Match) -> VoiceCommand)] = [
        (#/^(send|submit|go)$/#, { _ in .send }),
        (#/^(cancel|stop|never mind)$/#, { _ in .cancel }),
        (#/^(clear|delete|erase)$/#, { _ in .clear }),
        (#/^new (session|chat|conversation)$/#, { _ in .newSession }),
        (#/^(approve|yes|accept|confirm)$/#, { _ in .approve }),
        (#/^(reject|no|deny|decline)$/#, { _ in .reject }),
        (#/^read (that|response|it)$/#, { _ in .readResponse }),
        (#/^stop reading$/#, { _ in .stopReading }),
        (#/^scroll (up|top)$/#, { _ in .scrollUp }),
        (#/^scroll (down|bottom)$/#, { _ in .scrollDown }),
        (#/^switch to (.+)$/#, { match in .switchSession(String(match.1)) }),
    ]

    static func parse(_ text: String) -> VoiceCommand? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespaces)

        for (pattern, builder) in patterns {
            if let match = normalized.firstMatch(of: pattern) {
                return builder(match)
            }
        }

        return nil
    }
}
```

---

## 3. Text-to-Speech

### 3.1 TTS Engine

```swift
// TextToSpeech.swift

import AVFoundation

@Observable
final class TextToSpeech {
    var isSpeaking = false
    var currentUtterance: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: TTSDelegate?

    var voice: AVSpeechSynthesisVoice? {
        // Prefer premium voices
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.quality == .premium }
            .first { $0.language.starts(with: Locale.current.language.languageCode?.identifier ?? "en") }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    init() {
        delegate = TTSDelegate(tts: self)
        synthesizer.delegate = delegate
    }

    func speak(_ text: String, options: SpeakOptions = .default) {
        // Stop any current speech
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = options.rate
        utterance.pitchMultiplier = options.pitch
        utterance.volume = options.volume
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        currentUtterance = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func speakCode(_ code: String) {
        // Format code for spoken output
        let formatted = CodeSpeaker.format(code)
        speak(formatted, options: .code)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentUtterance = nil
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    struct SpeakOptions {
        var rate: Float        // 0.0 - 1.0
        var pitch: Float       // 0.5 - 2.0
        var volume: Float      // 0.0 - 1.0

        static let `default` = SpeakOptions(rate: 0.5, pitch: 1.0, volume: 1.0)
        static let code = SpeakOptions(rate: 0.4, pitch: 1.1, volume: 1.0) // Slower for code
        static let fast = SpeakOptions(rate: 0.6, pitch: 1.0, volume: 1.0)
    }
}

private class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var tts: TextToSpeech?

    init(tts: TextToSpeech) {
        self.tts = tts
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            tts?.isSpeaking = false
            tts?.currentUtterance = nil
        }
    }
}
```

### 3.2 Code Speaker (Pronunciation)

```swift
// CodeSpeaker.swift

struct CodeSpeaker {
    /// Formats code for spoken output
    static func format(_ code: String) -> String {
        var result = code

        // Replace symbols with words
        let replacements: [(String, String)] = [
            ("->", " arrow "),
            ("=>", " fat arrow "),
            ("==", " equals "),
            ("!=", " not equals "),
            ("===", " triple equals "),
            ("!==", " not triple equals "),
            ("<=", " less than or equal "),
            (">=", " greater than or equal "),
            ("&&", " and "),
            ("||", " or "),
            ("!", " not "),
            ("{", " open brace "),
            ("}", " close brace "),
            ("(", " open paren "),
            (")", " close paren "),
            ("[", " open bracket "),
            ("]", " close bracket "),
            (";", " semicolon "),
            (":", " colon "),
            (",", " comma "),
            (".", " dot "),
            ("?.", " optional dot "),
            ("??", " null coalesce "),
        ]

        for (symbol, word) in replacements {
            result = result.replacingOccurrences(of: symbol, with: word)
        }

        // Handle camelCase and snake_case
        result = result.replacingOccurrences(
            of: #"([a-z])([A-Z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        result = result.replacingOccurrences(of: "_", with: " ")

        // Add pauses for newlines
        result = result.replacingOccurrences(of: "\n", with: ". ")

        return result
    }

    /// Read specific code constructs naturally
    static func describeFunction(_ signature: String) -> String {
        // "func greet(name: String) -> String"
        // becomes: "function greet, takes name as String, returns String"
        // Implementation would parse and transform
        return signature
    }
}
```

---

## 4. UI Components

### 4.1 Voice Input Button

```swift
// VoiceInputButton.swift

struct VoiceInputButton: View {
    @Bindable var recognizer: SpeechRecognizer
    @State private var isPressed = false
    @State private var audioLevel: Float = 0

    var body: some View {
        Button {
            toggleListening()
        } label: {
            ZStack {
                // Audio level visualization
                if recognizer.isListening {
                    Circle()
                        .fill(DarkAccent.primary.opacity(0.2))
                        .scaleEffect(1 + CGFloat(audioLevel) * 0.5)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)
                }

                // Button background
                Circle()
                    .fill(recognizer.isListening ? DarkAccent.error : DarkAccent.primary)
                    .frame(width: 44, height: 44)

                // Icon
                Image(systemName: recognizer.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut("m", modifiers: [.command, .shift])
        .help(recognizer.isListening ? "Stop listening" : "Start voice input")
    }

    private func toggleListening() {
        if recognizer.isListening {
            recognizer.stopListening()
        } else {
            try? recognizer.startListening()
        }
    }
}
```

### 4.2 Live Transcript Display

```swift
// LiveTranscriptView.swift

struct LiveTranscriptView: View {
    @Bindable var recognizer: SpeechRecognizer

    var body: some View {
        if recognizer.isListening {
            VStack(spacing: Spacing.sm) {
                // Waveform visualization
                AudioWaveform(level: recognizer.audioLevel)
                    .frame(height: 40)

                // Transcript
                if !recognizer.transcript.isEmpty {
                    Text(recognizer.transcript)
                        .font(Typography.body)
                        .foregroundStyle(DarkText.primary)
                        .padding(Spacing.sm)
                        .background(DarkBackground.raised)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Confidence indicator
                HStack {
                    Text("Listening...")
                        .font(Typography.caption)
                        .foregroundStyle(DarkText.tertiary)

                    Spacer()

                    if recognizer.confidence > 0 {
                        Text("\(Int(recognizer.confidence * 100))% confident")
                            .font(Typography.caption)
                            .foregroundStyle(confidenceColor)
                    }
                }
            }
            .padding(Spacing.md)
            .background(DarkBackground.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .shadow(DarkShadow.lg)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var confidenceColor: Color {
        if recognizer.confidence > 0.8 {
            return DarkAccent.success
        } else if recognizer.confidence > 0.5 {
            return DarkAccent.warning
        } else {
            return DarkAccent.error
        }
    }
}

struct AudioWaveform: View {
    let level: Float
    let barCount = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DarkAccent.primary)
                    .frame(width: 3, height: barHeight(for: i))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Simulate varying heights based on audio level
        let baseHeight: CGFloat = 8
        let variation = sin(Double(index) * 0.5) * 0.5 + 0.5
        let levelMultiplier = CGFloat(level) * 2
        return baseHeight + (CGFloat(variation) * levelMultiplier * 24)
    }
}
```

### 4.3 TTS Controls

```swift
// TTSControls.swift

struct TTSControls: View {
    @Bindable var tts: TextToSpeech

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Play/Pause button
            Button {
                if tts.isSpeaking {
                    tts.pause()
                } else {
                    tts.resume()
                }
            } label: {
                Image(systemName: tts.isSpeaking ? "pause.fill" : "play.fill")
            }
            .disabled(!tts.isSpeaking && tts.currentUtterance == nil)

            // Stop button
            Button {
                tts.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .disabled(!tts.isSpeaking)

            // Progress
            if tts.isSpeaking {
                Text("Speaking...")
                    .font(Typography.caption)
                    .foregroundStyle(DarkText.tertiary)
            }

            Spacer()

            // Speed control
            Menu {
                Button("Slow") { tts.speed = 0.3 }
                Button("Normal") { tts.speed = 0.5 }
                Button("Fast") { tts.speed = 0.7 }
            } label: {
                Image(systemName: "speedometer")
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(DarkBackground.raised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}
```

---

## 5. Voice Settings

### 5.1 Preferences UI

```swift
// VoiceSettings.swift

struct VoiceSettings: View {
    @AppStorage("voiceEnabled") var voiceEnabled = false
    @AppStorage("autoReadResponses") var autoReadResponses = false
    @AppStorage("wakeWordEnabled") var wakeWordEnabled = false
    @AppStorage("voiceId") var voiceId = ""
    @AppStorage("speechRate") var speechRate = 0.5
    @AppStorage("speechVolume") var speechVolume = 1.0

    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        Form {
            Section("Voice Input") {
                Toggle("Enable voice input", isOn: $voiceEnabled)

                Toggle("Wake word (\"Hey Blaze\")", isOn: $wakeWordEnabled)
                    .disabled(!voiceEnabled)

                LabeledContent("Input language") {
                    Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English")
                }
            }

            Section("Text-to-Speech") {
                Toggle("Read responses aloud", isOn: $autoReadResponses)

                Picker("Voice", selection: $voiceId) {
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))")
                            .tag(voice.identifier)
                    }
                }

                LabeledContent("Speed") {
                    Slider(value: $speechRate, in: 0.2...0.8)
                }

                LabeledContent("Volume") {
                    Slider(value: $speechVolume, in: 0...1)
                }

                Button("Test Voice") {
                    testVoice()
                }
            }

            Section("Keyboard Shortcuts") {
                LabeledContent("Toggle voice input") {
                    KeyboardShortcutView(shortcut: "⌘⇧M")
                }
                LabeledContent("Read last response") {
                    KeyboardShortcutView(shortcut: "⌘⇧R")
                }
                LabeledContent("Stop reading") {
                    KeyboardShortcutView(shortcut: "⌘.")
                }
            }
        }
        .task {
            availableVoices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.quality == .premium || $0.quality == .enhanced }
                .sorted { $0.name < $1.name }
        }
    }

    private func testVoice() {
        TextToSpeech.shared.speak(
            "Hello! I'm your Blaze assistant. I can read responses and understand your voice commands.",
            options: .init(rate: Float(speechRate), pitch: 1.0, volume: Float(speechVolume))
        )
    }
}
```

---

## 6. Wake Word Detection

### 6.1 Continuous Listening

```swift
// WakeWordDetector.swift

actor WakeWordDetector {
    private let wakePhrase = "hey blaze"
    private var isActive = false
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?

    func start() async throws {
        guard !isActive else { return }

        let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        guard speechRecognizer?.isAvailable == true else {
            throw VoiceError.recognizerUnavailable
        }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self, let result = result else { return }

            let transcript = result.bestTranscription.formattedString.lowercased()

            if transcript.contains(self.wakePhrase) {
                Task {
                    await self.handleWakeWord()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isActive = true
    }

    private func handleWakeWord() async {
        // Play activation sound
        await MainActor.run {
            NSSound.beep()
        }

        // Notify to start main recognition
        await MainActor.run {
            NotificationCenter.default.post(name: .wakeWordDetected, object: nil)
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isActive = false
    }
}
```

---

## 7. Accessibility Integration

### 7.1 VoiceOver Coordination

```swift
// VoiceAccessibility.swift

struct VoiceAccessibility {
    /// Coordinate with VoiceOver to avoid conflicts
    static func speakWithVoiceOver(_ text: String) {
        if UIAccessibility.isVoiceOverRunning {
            // Let VoiceOver handle it
            UIAccessibility.post(notification: .announcement, argument: text)
        } else {
            // Use our TTS
            TextToSpeech.shared.speak(text)
        }
    }

    /// Check if we should use voice features
    static var shouldEnableVoice: Bool {
        // Disable if VoiceOver is running to avoid conflicts
        !UIAccessibility.isVoiceOverRunning
    }
}
```

### 7.2 Voice Feedback for Actions

```swift
// VoiceFeedback.swift

struct VoiceFeedback {
    static func announce(_ message: String, priority: Priority = .normal) {
        switch priority {
        case .high:
            TextToSpeech.shared.speak(message, options: .default)
        case .normal:
            // Only if auto-read is enabled
            if UserDefaults.standard.bool(forKey: "autoReadResponses") {
                TextToSpeech.shared.speak(message)
            }
        case .low:
            // Only for explicit read requests
            break
        }
    }

    enum Priority {
        case high    // Always speak
        case normal  // Speak if auto-read enabled
        case low     // Only on request
    }

    // Pre-defined announcements
    static func messageSent() {
        announce("Message sent", priority: .low)
    }

    static func responseReceived() {
        announce("Claude is responding", priority: .low)
    }

    static func toolApprovalNeeded(_ tool: String) {
        announce("Approval needed for \(tool). Say approve or reject.", priority: .high)
    }

    static func error(_ message: String) {
        announce("Error: \(message)", priority: .high)
    }
}
```

---

## 8. Privacy & Security

### 8.1 Data Handling

| Data | Storage | Transmission |
|------|---------|--------------|
| Voice audio | Not stored | Processed on-device only |
| Transcripts | Not stored | Ephemeral in memory |
| Voice settings | Local UserDefaults | Never transmitted |

### 8.2 Permissions

```swift
// VoicePermissions.swift

struct VoicePermissions {
    static func requestAll() async -> Bool {
        let speech = await requestSpeechRecognition()
        let microphone = await requestMicrophoneAccess()
        return speech && microphone
    }

    static func requestSpeechRecognition() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static var currentStatus: PermissionStatus {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioSession.sharedInstance().recordPermission

        if speech == .authorized && mic == .granted {
            return .granted
        } else if speech == .denied || mic == .denied {
            return .denied
        } else {
            return .notDetermined
        }
    }

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }
}
```

---

## 9. Implementation Checklist

- [ ] Speech recognition integration (SFSpeechRecognizer)
- [ ] Text-to-speech engine (AVSpeechSynthesizer)
- [ ] Voice command parser
- [ ] Wake word detection
- [ ] Voice input button UI
- [ ] Live transcript display
- [ ] TTS playback controls
- [ ] Audio waveform visualization
- [ ] Voice settings preferences
- [ ] Code pronunciation formatter
- [ ] VoiceOver coordination
- [ ] Permission handling
- [ ] On-device processing only
- [ ] Keyboard shortcuts
- [ ] Accessibility labels

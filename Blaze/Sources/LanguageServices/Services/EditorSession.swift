import AppKit
import Combine

/// Per-buffer coordinator for language services.
///
/// Critical design decisions:
/// - @MainActor class (NOT actor): Must interact with NSTextView which is MainActor-bound
/// - NO @Published full text: Only publish lightweight metadata to avoid SwiftUI re-render storms
/// - Listens to NSTextStorage.didProcessEditingNotification for incremental edit info
/// - Version-gated processing: stale results are discarded before application
@MainActor
public final class EditorSession: ObservableObject, Identifiable {
    // MARK: - Identity

    /// Unique identifier, typically matches FileTab.id
    public let id: UUID

    /// File URL for language detection and LSP identification
    public private(set) var fileURL: URL?

    // MARK: - Text View Reference

    /// Weak reference to the NSTextView (source of truth for text content)
    public weak var textView: NSTextView?

    // MARK: - Published State (Lightweight Only!)
    // CRITICAL: Never @Published full text - causes SwiftUI re-render storms

    /// Detected or manually set language identifier
    @Published public private(set) var languageId: String = "unknown"

    /// Number of active diagnostics (for badge display)
    @Published public private(set) var diagnosticsCount: Int = 0

    /// Whether highlighting is currently in progress
    @Published public private(set) var isHighlighting: Bool = false

    /// Whether the document has unsaved changes
    @Published public private(set) var isDirty: Bool = false

    /// Whether formatting is currently in progress
    @Published public private(set) var isFormatting: Bool = false

    /// Last formatting result message (for UI feedback)
    @Published public private(set) var lastFormatResult: String?

    // MARK: - Internal State

    /// Monotonically increasing version number, bumped on each edit
    private var documentVersion: Int = 0

    /// Current visible range in the viewport (for prioritization)
    private var currentVisibleRange: NSRange?

    /// Observer token for NSTextStorage notifications
    private var textStorageObserver: NSObjectProtocol?

    /// Debounced highlight task
    private var highlightTask: Task<Void, Never>?

    /// Debounced diagnostics task
    private var diagnosticsTask: Task<Void, Never>?

    /// Debounce interval for highlighting (milliseconds)
    private let highlightDebounce: UInt64 = 150

    /// Debounce interval for diagnostics (milliseconds)
    private let diagnosticsDebounce: UInt64 = 500

    /// Highlight coordinator for applying syntax highlighting
    private var highlightCoordinator: HighlightCoordinator?

    /// The highlighter instance (actor, can be shared)
    private let highlighter: RegexHighlighter = RegexHighlighter()

    /// Diagnostics coordinator for applying squiggly underlines
    private var diagnosticsCoordinator: DiagnosticsCoordinator?

    /// The diagnostics provider instance
    private let diagnosticsProvider: MockDiagnosticsProvider = MockDiagnosticsProvider()

    /// The formatter service (shared actor)
    private let formatterService: FormatterService = FormatterService.shared

    // MARK: - Initialization

    public init(id: UUID = UUID(), fileURL: URL? = nil) {
        self.id = id
        self.fileURL = fileURL

        // Detect language from file extension
        self.languageId = LanguageDetector.detect(fileURL: fileURL)
    }

    deinit {
        // Clean up observer
        if let observer = textStorageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        highlightTask?.cancel()
        diagnosticsTask?.cancel()
    }

    // MARK: - Attachment

    /// Attach this session to an NSTextView.
    /// Call this from NSViewRepresentable.makeNSView after creating the text view.
    public func attachToTextView(_ textView: NSTextView) {
        // Clean up previous observer if re-attaching
        if let observer = textStorageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        highlightCoordinator?.detach()

        self.textView = textView

        // Setup highlight coordinator
        let highlightCoord = HighlightCoordinator(highlighter: highlighter)
        highlightCoord.attach(to: textView)
        self.highlightCoordinator = highlightCoord

        // Setup diagnostics coordinator
        let diagCoord = DiagnosticsCoordinator()
        diagCoord.attach(to: textView)
        self.diagnosticsCoordinator = diagCoord

        // Listen to NSTextStorage edits for incremental info
        textStorageObserver = NotificationCenter.default.addObserver(
            forName: NSTextStorage.didProcessEditingNotification,
            object: textView.textStorage,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleTextStorageEdit(notification)
            }
        }

        // Initial highlight pass
        documentVersion += 1
        scheduleHighlight(editedRange: nil, changeInLength: 0)
    }

    /// Detach from the current text view.
    public func detach() {
        if let observer = textStorageObserver {
            NotificationCenter.default.removeObserver(observer)
            textStorageObserver = nil
        }
        highlightCoordinator?.detach()
        highlightCoordinator = nil
        diagnosticsCoordinator?.detach()
        diagnosticsCoordinator = nil
        textView = nil
        highlightTask?.cancel()
        diagnosticsTask?.cancel()
    }

    // MARK: - Visible Range

    /// Update the visible range (call from ScrollView geometry changes).
    /// Used to prioritize highlighting visible content first.
    public func updateVisibleRange(_ range: NSRange) {
        currentVisibleRange = range
    }

    /// Compute visible range from a rect using the layout manager.
    /// Call this when the scroll position changes.
    public func updateVisibleRange(from visibleRect: CGRect) {
        guard let layoutManager = textView?.layoutManager,
              let textContainer = textView?.textContainer else {
            return
        }

        // Convert visible rect to glyph range, then to character range
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        currentVisibleRange = charRange
    }

    // MARK: - Language Detection

    /// Set the language ID manually (overrides auto-detection)
    public func setLanguage(_ languageId: String) {
        self.languageId = languageId
        // Re-trigger highlighting with new language
        documentVersion += 1
        scheduleHighlight(editedRange: nil, changeInLength: 0)
    }

    /// Re-detect language from current content (checks shebang/modeline)
    /// Call this after initial content is loaded
    public func detectLanguageFromContent() {
        guard let textStorage = textView?.textStorage else { return }
        let detected = LanguageDetector.detect(
            fileURL: fileURL,
            content: textStorage.string,
            manualOverride: nil
        )
        if detected != languageId {
            languageId = detected
            documentVersion += 1
            scheduleHighlight(editedRange: nil, changeInLength: 0)
        }
    }


    // MARK: - Text Storage Notification Handler

    private func handleTextStorageEdit(_ notification: Notification) {
        guard let textStorage = notification.object as? NSTextStorage else { return }

        // Get edit info from the text storage
        let editedRange = textStorage.editedRange
        let changeInLength = textStorage.changeInLength

        // Bump version
        documentVersion += 1
        isDirty = true

        // Schedule debounced processing
        scheduleHighlight(editedRange: editedRange, changeInLength: changeInLength)
        scheduleDiagnostics(editedRange: editedRange)
    }

    // MARK: - Debounced Processing

    private func scheduleHighlight(editedRange: NSRange?, changeInLength: Int) {
        // Cancel any pending highlight task
        highlightTask?.cancel()

        let capturedVersion = documentVersion

        highlightTask = Task { [weak self] in
            // Debounce
            try? await Task.sleep(nanoseconds: (self?.highlightDebounce ?? 150) * 1_000_000)
            guard !Task.isCancelled else { return }

            await self?.performHighlight(version: capturedVersion, editedRange: editedRange, changeInLength: changeInLength)
        }
    }

    private func scheduleDiagnostics(editedRange: NSRange?) {
        // Cancel any pending diagnostics task
        diagnosticsTask?.cancel()

        let capturedVersion = documentVersion

        diagnosticsTask = Task { [weak self] in
            // Debounce (longer than highlighting)
            try? await Task.sleep(nanoseconds: (self?.diagnosticsDebounce ?? 500) * 1_000_000)
            guard !Task.isCancelled else { return }

            await self?.performDiagnostics(version: capturedVersion, editedRange: editedRange)
        }
    }

    // MARK: - Highlight Processing

    private func performHighlight(version: Int, editedRange: NSRange?, changeInLength: Int) async {
        // Version gate: discard if document changed since we scheduled
        guard version == documentVersion else { return }
        guard let textView = textView,
              let textStorage = textView.textStorage,
              let coordinator = highlightCoordinator else { return }

        isHighlighting = true
        defer { isHighlighting = false }

        // Create snapshot for processing
        let snapshot = TextSnapshot(
            version: version,
            fileURL: fileURL,
            languageId: languageId,
            nsString: textStorage.string as NSString,
            editedRange: editedRange,
            changeInLength: changeInLength,
            visibleRange: currentVisibleRange
        )

        do {
            // Call highlighter (runs on actor, off main thread)
            let spans = try await highlighter.highlight(snapshot)

            // Version gate after async work - discard stale results
            guard version == documentVersion else { return }

            // Apply highlights on main actor
            coordinator.applyHighlights(
                spans,
                editedRange: editedRange,
                visibleRange: currentVisibleRange
            )
        } catch {
            // Highlighting is non-critical, just log
            print("[EditorSession] Highlight error: \(error)")
        }
    }

    // MARK: - Diagnostics Processing

    private func performDiagnostics(version: Int, editedRange: NSRange?) async {
        // Version gate: discard if document changed since we scheduled
        guard version == documentVersion else { return }
        guard let textView = textView,
              let textStorage = textView.textStorage,
              let coordinator = diagnosticsCoordinator else { return }

        // Create snapshot for processing
        let snapshot = TextSnapshot(
            version: version,
            fileURL: fileURL,
            languageId: languageId,
            nsString: textStorage.string as NSString,
            editedRange: editedRange,
            changeInLength: 0,
            visibleRange: currentVisibleRange
        )

        do {
            // Call diagnostics provider (runs on actor, off main thread)
            let diagnostics = try await diagnosticsProvider.provideDiagnostics(snapshot)

            // Version gate after async work - discard stale results
            guard version == documentVersion else { return }

            // Apply diagnostics on main actor
            coordinator.applyDiagnostics(diagnostics)
            diagnosticsCount = diagnostics.count
        } catch {
            // Diagnostics are non-critical, just log
            print("[EditorSession] Diagnostics error: \(error)")
        }
    }

    // MARK: - Public API for Formatting

    /// Mark the document as saved (clears dirty flag)
    public func markSaved() {
        isDirty = false
    }

    /// Format the current document using the configured formatter.
    ///
    /// This method:
    /// 1. Gets the current text from the text view
    /// 2. Calls the FormatterService actor
    /// 3. Applies the formatted text with proper undo support
    /// 4. Preserves selection as much as possible
    ///
    /// - Returns: A result message for UI feedback
    @discardableResult
    public func formatDocument() async -> String {
        guard let textView = textView,
              let textStorage = textView.textStorage else {
            let msg = "No text view attached"
            lastFormatResult = msg
            return msg
        }

        isFormatting = true
        defer { isFormatting = false }

        let currentText = textStorage.string

        // Call formatter service (runs on actor, off main thread)
        let result = await formatterService.format(
            text: currentText,
            fileURL: fileURL,
            languageId: languageId
        )

        // Handle result
        switch result {
        case .formatted(let formattedText):
            applyFormattedText(formattedText, to: textView)
            let msg = "Document formatted"
            lastFormatResult = msg
            return msg

        case .noChange:
            let msg = "Already formatted"
            lastFormatResult = msg
            return msg

        case .unsupported(let message):
            lastFormatResult = message
            return message

        case .error(let message):
            let msg = "Format error: \(message)"
            lastFormatResult = msg
            return msg
        }
    }

    /// Apply formatted text to the text view with proper undo support.
    ///
    /// This follows AppKit text system best practices:
    /// 1. Save selection ranges
    /// 2. Request permission via shouldChangeText
    /// 3. Wrap in undo group
    /// 4. Perform edit with proper notifications
    /// 5. Restore selection (clamped to new length)
    private func applyFormattedText(_ formattedText: String, to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        // 1. Save selection (UTF-16 offsets)
        let savedSelectionRanges = textView.selectedRanges

        // 2. Request permission from text system
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard textView.shouldChangeText(in: fullRange, replacementString: formattedText) else {
            return // Text system rejected the edit
        }

        // 3. Wrap in undo group using textView's undoManager
        textView.undoManager?.beginUndoGrouping()
        textView.undoManager?.setActionName("Format Document")

        // 4. Perform edit with proper text system notifications
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: fullRange, with: formattedText)
        textStorage.endEditing()

        // 5. Notify text system edit is complete
        textView.didChangeText()

        // 6. End undo group
        textView.undoManager?.endUndoGrouping()

        // 7. Restore selection (clamped to new document length)
        let newLength = textStorage.length
        let restoredRanges = savedSelectionRanges.compactMap { rangeValue -> NSValue? in
            let range = rangeValue.rangeValue
            let clampedLocation = min(range.location, newLength)
            let clampedLength = min(range.length, newLength - clampedLocation)
            return NSValue(range: NSRange(location: clampedLocation, length: clampedLength))
        }
        if !restoredRanges.isEmpty {
            textView.selectedRanges = restoredRanges
        }
    }

    /// Clear the last format result message
    public func clearFormatResult() {
        lastFormatResult = nil
    }
}

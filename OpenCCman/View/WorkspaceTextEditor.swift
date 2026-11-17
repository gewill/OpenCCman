import SwiftUI
#if os(iOS)
  @_spi(Advanced) import SwiftUIIntrospect
#endif

#if os(macOS)
  /// Draw behind glyphs without attributed-string mutations. Only visible
  /// character ranges ask TextKit for geometry, including a caret for empty sides.
  final class WorkspaceDiffTextView: NSTextView {
    private(set) var decoration: WorkspaceDiffDecoration?
    private var navigationID: UUID?

    func updateDecoration(_ value: WorkspaceDiffDecoration?) {
      let changed = decoration?.id != value?.id || decoration?.currentIndex != value?.currentIndex
      if let value, !string.utf8.elementsEqual(value.text.utf8) {
        decoration = nil
        needsDisplay = true
        return
      }
      decoration = value
      if changed { needsDisplay = true }
      guard !hasMarkedText(), let token = value?.navigationID, token != navigationID,
            let range = value?.selectedRange else { return }
      navigationID = token
      setSelectedRange(range)
      scrollRangeToVisible(range)
    }

    override func didChangeText() {
      decoration = nil
      needsDisplay = true
      super.didChangeText()
    }

    override func drawBackground(in rect: NSRect) {
      super.drawBackground(in: rect)
      guard let decoration, !hasMarkedText(), let layout = layoutManager, let container = textContainer else { return }
      let origin = textContainerOrigin
      let visible = rect.offsetBy(dx: -origin.x, dy: -origin.y)
      let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
      let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
      func paint(_ box: CGRect, current: Bool, empty: Bool) {
        var box = box.offsetBy(dx: origin.x, dy: origin.y)
        if empty { box.size.width = 3 }
        guard box.intersects(rect) else { return }
        NSColor.systemOrange.withAlphaComponent(current ? 0.35 : 0.18).setFill()
        NSBezierPath(rect: box).fill()
        NSColor.labelColor.withAlphaComponent(0.8).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: box.minX, y: box.maxY - 1))
        line.line(to: NSPoint(x: box.maxX, y: box.maxY - 1))
        line.lineWidth = current ? 2 : 1
        line.stroke()
        if empty || current { NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5)).stroke() }
      }
      for (index, range) in decoration.ranges.enumerated() {
        guard range.location <= NSMaxRange(characters), NSMaxRange(range) >= characters.location else { continue }
        if range.length == 0 {
          if range.location == (string as NSString).length {
            let box: CGRect
            if layout.extraLineFragmentRect.height > 0 { box = layout.extraLineFragmentRect }
            else if layout.numberOfGlyphs > 0 {
              let last = layout.boundingRect(forGlyphRange: NSRange(location: layout.numberOfGlyphs - 1, length: 1), in: container)
              box = CGRect(x: last.maxX, y: last.minY, width: 3, height: last.height)
            } else { box = CGRect(x: 0, y: 0, width: 3, height: (font?.pointSize ?? 12) * 1.3) }
            paint(box, current: decoration.currentIndex == index, empty: true)
          } else {
            let glyph = layout.glyphIndexForCharacter(at: range.location)
            paint(layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container),
                  current: decoration.currentIndex == index, empty: true)
          }
        } else {
          let glyphRange = layout.glyphRange(forCharacterRange: NSIntersectionRange(range, characters), actualCharacterRange: nil)
          layout.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { box, _ in
            paint(box, current: decoration.currentIndex == index, empty: false)
          }
        }
      }
    }
  }
#else
  import UIKit

  /// Overlay geometry uses UITextInput, keeping SwiftUI's editor/delegate,
  /// marked text and TextKit version intact. It does not intercept touches.
  @MainActor final class WorkspaceMobileDiffPainter: ObservableObject {
    private weak var editor: UITextView?
    private var overlay: WorkspaceDiffOverlay?
    private var observations: [NSKeyValueObservation] = []
    private var textObserver: NSObjectProtocol?
    private var navigationID: UUID?

    func update(_ editor: UITextView, decoration: WorkspaceDiffDecoration?) {
      if self.editor !== editor {
        overlay?.removeFromSuperview()
        observations.removeAll()
        if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
        self.editor = editor
        let overlay = WorkspaceDiffOverlay()
        overlay.editor = editor
        overlay.isUserInteractionEnabled = false
        overlay.isAccessibilityElement = false
        overlay.backgroundColor = .clear
        overlay.isOpaque = false
        self.overlay = overlay
        editor.addSubview(overlay)
        observations = [editor.observe(\.contentOffset, options: [.new]) { [weak overlay, weak editor] _, _ in
          guard let editor else { return }
          overlay?.frame = editor.bounds
          overlay?.setNeedsDisplay()
        }, editor.observe(\.bounds, options: [.new]) { [weak overlay, weak editor] _, _ in
          guard let editor else { return }
          overlay?.frame = editor.bounds
          overlay?.setNeedsDisplay()
        }]
        textObserver = NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification, object: editor, queue: .main) { [weak overlay] _ in
          overlay?.decoration = nil
          overlay?.setNeedsDisplay()
        }
      }
      if let decoration, !editor.text.utf8.elementsEqual(decoration.text.utf8) {
        overlay?.decoration = nil
        overlay?.setNeedsDisplay()
        return
      }
      overlay?.decoration = decoration
      overlay?.frame = editor.bounds
      overlay?.setNeedsDisplay()
      guard editor.markedTextRange == nil, let token = decoration?.navigationID, token != navigationID,
            let range = decoration?.selectedRange else { return }
      navigationID = token
      editor.selectedRange = range
      editor.scrollRangeToVisible(range)
    }

    deinit {
      if let textObserver { NotificationCenter.default.removeObserver(textObserver) }
    }
  }

  private final class WorkspaceDiffOverlay: UIView {
    weak var editor: UITextView?
    var decoration: WorkspaceDiffDecoration?

    override func draw(_ rect: CGRect) {
      guard let editor, let decoration, editor.markedTextRange == nil,
            let top = editor.closestPosition(to: CGPoint(x: editor.bounds.minX, y: editor.bounds.minY)),
            let bottom = editor.closestPosition(to: CGPoint(x: editor.bounds.maxX, y: editor.bounds.maxY)) else { return }
      let start = editor.offset(from: editor.beginningOfDocument, to: top)
      let end = editor.offset(from: editor.beginningOfDocument, to: bottom)
      for (index, range) in decoration.ranges.enumerated() {
        guard NSMaxRange(range) >= start, range.location <= end,
              let a = editor.position(from: editor.beginningOfDocument, offset: max(range.location, start)),
              let b = editor.position(from: editor.beginningOfDocument, offset: min(NSMaxRange(range), end)),
              let textRange = editor.textRange(from: a, to: b) else { continue }
        let boxes = range.length == 0 ? [editor.caretRect(for: a)] : editor.selectionRects(for: textRange).map(\.rect)
        for raw in boxes {
          var box = raw.offsetBy(dx: -editor.bounds.minX, dy: -editor.bounds.minY)
          if range.length == 0 { box.size.width = 3 }
          guard box.intersects(bounds) else { continue }
          let current = decoration.currentIndex == index
          UIColor.systemOrange.withAlphaComponent(current ? 0.25 : 0.14).setFill()
          UIBezierPath(rect: box).fill()
          UIColor.label.withAlphaComponent(0.85).setStroke()
          let line = UIBezierPath()
          line.move(to: CGPoint(x: box.minX, y: box.maxY - 1))
          line.addLine(to: CGPoint(x: box.maxX, y: box.maxY - 1))
          line.lineWidth = current ? 2 : 1
          line.stroke()
          if current || range.length == 0 { UIBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5)).stroke() }
        }
      }
    }
  }
#endif

/// The workspace owns text and layout; the platform editor owns editing state.
struct WorkspaceTextEditor: View {
  @Binding var text: String
  var isEditable = true
  var label = ""
  var diff: WorkspaceDiffDecoration?
  #if os(iOS)
    @StateObject private var diffPainter = WorkspaceMobileDiffPainter()
  #endif
  #if os(macOS)
    var readingState: WorkspaceEditorReadingState?
  #endif

  var body: some View {
    #if os(macOS)
      NativeWorkspaceTextEditor(text: $text, isEditable: isEditable, label: label,
                                readingState: readingState, diff: diff)
    #else
      TextEditor(text: $text)
        .clearTextEdtorStyle(isEditable: isEditable)
        .introspect(.textEditor, on: AppIntrospection.textEditor) { editor in
          diffPainter.update(editor, decoration: diff)
        }
    #endif
  }
}

#if os(macOS)
  import AppKit

  /// A scroll viewport has no content-derived ideal size. In particular, a
  /// SwiftUI size query must not ask TextEditor to lay out the entire document.
  final class WorkspaceEditorViewport: NSScrollView {
    override var intrinsicContentSize: NSSize {
      NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
  }

  @MainActor
  final class WorkspaceTextEditorCoordinator: NSObject, NSTextViewDelegate {
    private var text: Binding<String>
    private var renderedText: String?
    private var applyingSource = false
    private var appliedTextSize = AppTextSize.standard
    private let scrollKeeper = WorkspaceScrollKeeper()
    private let editingUndoManager = UndoManager()
    private let readingState: WorkspaceEditorReadingState?
    private var didRestoreReadingPosition = false

    #if WORKSPACE_SCROLL_CHECKS
      var isScrollRestorationPending: Bool { scrollKeeper.isRestorationPending }
    #endif

    init(text: Binding<String>, readingState: WorkspaceEditorReadingState? = nil) {
      self.text = text
      self.readingState = readingState
    }

    func makeViewport() -> WorkspaceEditorViewport {
      let storage = NSTextStorage()
      let layout = NSLayoutManager()
      layout.allowsNonContiguousLayout = true
      layout.backgroundLayoutEnabled = false
      storage.addLayoutManager(layout)
      let container = NSTextContainer(containerSize: NSSize(width: 1, height: CGFloat.greatestFiniteMagnitude))
      container.widthTracksTextView = true
      container.lineFragmentPadding = 0
      layout.addTextContainer(container)
      let editor = WorkspaceDiffTextView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), textContainer: container)
      editor.isRichText = false
      editor.isVerticallyResizable = true
      editor.isHorizontallyResizable = false
      editor.autoresizingMask = [.width]
      editor.minSize = .zero
      editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
      editor.textContainerInset = NSSize(width: 0, height: 1)
      editor.drawsBackground = false
      editor.backgroundColor = .clear
      // Match TextEditor's native editable-text default, including the user's
      // font preference. A preferred body font changes wrapping and appearance.
      editor.font = NSFont.userFont(ofSize: 0)
      editor.textColor = .labelColor
      editor.allowsUndo = true
      editor.usesFindBar = true
      editor.delegate = self

      let viewport = WorkspaceEditorViewport()
      viewport.hasVerticalScroller = true
      viewport.autohidesScrollers = true
      viewport.drawsBackground = false
      viewport.borderType = .noBorder
      viewport.documentView = editor
      scrollKeeper.attach(editor)
      return viewport
    }

    func update(_ viewport: WorkspaceEditorViewport, text: Binding<String>, isEditable: Bool, isEnabled: Bool,
                accessibilityLabel: String = "", textSize: AppTextSize = .standard,
                diff: WorkspaceDiffDecoration? = nil) {
      self.text = text
      guard let editor = viewport.documentView as? NSTextView else { return }
      editor.isEditable = isEditable && isEnabled
      editor.isSelectable = isEnabled
      // SwiftUI's modifier labels the representable's scroll view. Label the
      // actual text area as well, so direct VoiceOver navigation keeps its role.
      editor.setAccessibilityLabel(accessibilityLabel.isEmpty ? nil : accessibilityLabel)
      let nativeFont = NSFont.userFont(ofSize: 0) ?? NSFont.systemFont(ofSize: 12)
      let scaledFont = nativeFont.withSize(nativeFont.pointSize * textSize.multiplier)
      if !editor.hasMarkedText(), appliedTextSize != textSize {
        scrollKeeper.changeTypography {
          // This is a plain-text editor. AppKit can leave hundreds of
          // thousands of separate attribute runs after visiting a distant
          // paragraph; NSTextView.font then updates each run synchronously.
          // Rebuild one uniform run without replacing the editor or its text.
          let selection = editor.selectedRange()
          let attributes: [NSAttributedString.Key: Any] = [
            .font: scaledFont,
            .foregroundColor: editor.textColor ?? NSColor.labelColor
          ]
          editor.textStorage?.setAttributedString(NSAttributedString(string: editor.string, attributes: attributes))
          editor.typingAttributes[.font] = scaledFont
          if editor.selectedRange() != selection { editor.setSelectedRange(selection) }
        }
        appliedTextSize = textSize
      }
      let value = text.wrappedValue
      // A layout, language, theme or task update must not write back into the
      // native editor: doing so would disturb marked text, selection and undo.
      if !matchesRenderedBytes(value) {
        applyingSource = true
        defer { applyingSource = false }
        if editor.hasMarkedText() { editor.unmarkText() }
        (editor as? WorkspaceDiffTextView)?.updateDecoration(nil)
        editor.string = value
        renderedText = value
        // Old edit operations refer to the previous document's character ranges.
        // Native edits update renderedText before publishing, so their echo does
        // not clear the undo history.
        editor.undoManager?.removeAllActions()
      }
      if let diffEditor = editor as? WorkspaceDiffTextView {
        diffEditor.updateDecoration(diff)
      }
      if !didRestoreReadingPosition {
        didRestoreReadingPosition = true
        if let position = readingState?.position {
          scrollKeeper.restoreReadingPosition(position)
        }
      }
    }

    func saveReadingPosition(in viewport: WorkspaceEditorViewport) {
      guard let readingState, let editor = viewport.documentView as? NSTextView else { return }
      // A source replacement can race route teardown. Only retain a position
      // in the document actually held by the window model.
      guard editor.string.utf8.elementsEqual(text.wrappedValue.utf8) else {
        readingState.invalidate()
        return
      }
      readingState.position = scrollKeeper.currentReadingPosition()
    }

    func textDidChange(_ notification: Notification) {
      guard !applyingSource, let editor = notification.object as? NSTextView else { return }
      let value = editor.string
      renderedText = value
      text.wrappedValue = value
    }

    func undoManager(for view: NSTextView) -> UndoManager? {
      editingUndoManager
    }

    private func matchesRenderedBytes(_ value: String) -> Bool {
      guard let renderedText else { return false }
      // String equality is canonically equivalent, but file imports must also
      // preserve the spelling/order of combining scalars. Compare literal UTF-8;
      // identical contiguous storage takes the constant-time path on UI echoes.
      let contiguousMatch = renderedText.utf8.withContiguousStorageIfAvailable { old in
        value.utf8.withContiguousStorageIfAvailable { new in
          guard old.count == new.count else { return false }
          guard !old.isEmpty else { return true }
          return old.baseAddress == new.baseAddress || memcmp(old.baseAddress!, new.baseAddress!, old.count) == 0
        }
      } ?? nil
      return contiguousMatch ?? renderedText.utf8.elementsEqual(value.utf8)
    }
  }

  private struct NativeWorkspaceTextEditor: NSViewRepresentable {
    @Environment(\.appTextSize) private var textSize
    @Binding var text: String
    var isEditable: Bool
    var label: String
    var readingState: WorkspaceEditorReadingState?
    var diff: WorkspaceDiffDecoration?

    func makeCoordinator() -> WorkspaceTextEditorCoordinator {
      WorkspaceTextEditorCoordinator(text: $text, readingState: readingState)
    }

    func makeNSView(context: Context) -> WorkspaceEditorViewport {
      context.coordinator.makeViewport()
    }

    func updateNSView(_ viewport: WorkspaceEditorViewport, context: Context) {
      context.coordinator.update(viewport, text: $text, isEditable: isEditable,
                                 isEnabled: context.environment.isEnabled,
                                 accessibilityLabel: label.localized(in: context.environment.locale),
                                 textSize: textSize, diff: diff)
    }

    static func dismantleNSView(_ viewport: WorkspaceEditorViewport, coordinator: WorkspaceTextEditorCoordinator) {
      coordinator.saveReadingPosition(in: viewport)
      (viewport.documentView as? NSTextView)?.delegate = nil
    }
  }
#endif

import SwiftUI

/// The workspace owns text and layout; the platform editor owns editing state.
struct WorkspaceTextEditor: View {
  @Binding var text: String
  var isEditable = true
  var label = ""

  var body: some View {
    #if os(macOS)
      NativeWorkspaceTextEditor(text: $text, isEditable: isEditable, label: label)
    #else
      TextEditor(text: $text)
        .clearTextEdtorStyle(isEditable: isEditable)
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

    #if WORKSPACE_SCROLL_CHECKS
      var isScrollRestorationPending: Bool { scrollKeeper.isRestorationPending }
    #endif

    init(text: Binding<String>) {
      self.text = text
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
      let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), textContainer: container)
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
                accessibilityLabel: String = "", textSize: AppTextSize = .standard) {
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
      guard !matchesRenderedBytes(value) else { return }
      applyingSource = true
      defer { applyingSource = false }
      if editor.hasMarkedText() { editor.unmarkText() }
      editor.string = value
      renderedText = value
      // Old edit operations refer to the previous document's character ranges.
      // Native edits update renderedText before publishing, so their echo does
      // not clear the undo history.
      editor.undoManager?.removeAllActions()
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

    func makeCoordinator() -> WorkspaceTextEditorCoordinator {
      WorkspaceTextEditorCoordinator(text: $text)
    }

    func makeNSView(context: Context) -> WorkspaceEditorViewport {
      context.coordinator.makeViewport()
    }

    func updateNSView(_ viewport: WorkspaceEditorViewport, context: Context) {
      context.coordinator.update(viewport, text: $text, isEditable: isEditable,
                                 isEnabled: context.environment.isEnabled,
                                 accessibilityLabel: label.localized(in: context.environment.locale),
                                 textSize: textSize)
    }

    static func dismantleNSView(_ viewport: WorkspaceEditorViewport, coordinator: WorkspaceTextEditorCoordinator) {
      (viewport.documentView as? NSTextView)?.delegate = nil
    }
  }
#endif

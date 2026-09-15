import AppKit
import SwiftUI

@main
enum WorkspaceTextEditorChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    var source = "中文\u{0} 👩🏽‍💻 e\u{301}\r\n\r\nsecond line"
    let binding = Binding(get: { source }, set: { source = $0 })
    let coordinator = WorkspaceTextEditorCoordinator(text: binding)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 400, height: 240))
    let editor = viewport.documentView as! NSTextView
    precondition(editor.font == NSFont.userFont(ofSize: 0),
                 "Start with the native editable-text font")
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true, accessibilityLabel: "原文")
    precondition(editor.string == source && editor.isEditable)
    // The first Chinese run uses the system's fallback family, at the same size.
    precondition(editor.font?.pointSize == NSFont.userFont(ofSize: 0)?.pointSize)
    precondition(editor.accessibilityLabel() == "原文", "The text area itself needs a localized label")
    precondition(editor.layoutManager!.allowsNonContiguousLayout)
    precondition(!editor.layoutManager!.backgroundLayoutEnabled)
    precondition(viewport.intrinsicContentSize == NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric))

    // Native typing, undo and redo must update the authoritative SwiftUI binding.
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    let original = source
    editor.insertText("前", replacementRange: NSRange(location: 0, length: 0))
    precondition(source == "前" + original)
    editor.breakUndoCoalescing()
    let selection = editor.selectedRange()
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    precondition(editor.selectedRange() == selection)
    precondition(editor.undoManager!.canUndo)
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true, accessibilityLabel: "Source")
    precondition(editor.accessibilityLabel() == "Source" && editor.selectedRange() == selection)
    editor.undoManager!.undo()
    precondition(source == original)
    editor.undoManager!.redo()
    precondition(source == "前" + original)

    editor.setMarkedText("pinyin", selectedRange: NSRange(location: 3, length: 0),
                         replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = editor.markedRange()
    let markedSelection = editor.selectedRange()
    let textBeforeUpdate = editor.string
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    precondition(editor.hasMarkedText() && editor.markedRange() == marked)
    precondition(editor.selectedRange() == markedSelection && editor.string == textBeforeUpdate)
    editor.unmarkText()

    // Rendering the read-only output must not discard the source undo history.
    var result = "converted"
    let resultBinding = Binding(get: { result }, set: { result = $0 })
    let resultCoordinator = WorkspaceTextEditorCoordinator(text: resultBinding)
    let resultViewport = resultCoordinator.makeViewport()
    resultCoordinator.update(resultViewport, text: resultBinding, isEditable: false, isEnabled: true)
    let resultEditor = resultViewport.documentView as! NSTextView
    precondition(!resultEditor.isEditable && resultEditor.isSelectable)
    precondition(resultEditor.undoManager !== editor.undoManager)
    precondition(editor.undoManager!.canUndo)

    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: false)
    precondition(!editor.isEditable && !editor.isSelectable)
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    source = "replacement\r\n\u{0}"
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    precondition(editor.string == source && !editor.undoManager!.canUndo)
    precondition(!editor.hasMarkedText())
    // Swift == considers these equal; the editor must still replace their bytes.
    source = "e\u{301}\u{323}"
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    let previousSpelling = source
    source = "e\u{323}\u{301}"
    precondition(source == previousSpelling)
    precondition(!source.utf8.elementsEqual(previousSpelling.utf8))
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true)
    precondition(editor.string.utf8.elementsEqual(source.utf8))
    print("PASS: complete text, typing/binding, undo/redo, marked text echo, selection, independent undo, disabled/read-only and external replacement")

    // Exercise the real representable in SwiftUI layout, without opening a
    // window. Large text must not supply the viewport's intrinsic content size.
    let paragraph = "中文布局 👩🏽‍💻 e\u{301}\r\n"
    let large = String(repeating: paragraph, count: 160_000)
    let host = NSHostingView(rootView: WorkspaceTextEditor(text: .constant(large))
      .frame(width: 420, height: 240))
    host.frame = NSRect(x: 0, y: 0, width: 420, height: 240)
    host.layoutSubtreeIfNeeded()
    let size = host.fittingSize
    precondition(size.width == 420 && size.height == 240)
    let native = findEditor(host)!
    precondition(native.string == large)
    let firstUnlaid = native.layoutManager!.firstUnlaidCharacterIndex()
    precondition(firstUnlaid < native.textStorage!.length,
                 "Viewport measurement forced layout to the end of the document")
    print("PASS: SwiftUI bounded sizing leaves distant text unlaid; first unlaid \(firstUnlaid), characters \(native.textStorage!.length)")
  }

  @MainActor static func findEditor(_ view: NSView) -> NSTextView? {
    if let editor = view as? NSTextView { return editor }
    return view.subviews.lazy.compactMap(findEditor).first
  }
}

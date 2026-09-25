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
    let fontDuringComposition = editor.font
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true, textSize: .large)
    precondition(editor.hasMarkedText() && editor.font == fontDuringComposition,
                 "Do not reflow an active input-method composition")
    viewport.setFrameSize(NSSize(width: 760, height: 260))
    settle(coordinator)
    precondition(editor.markedRange() == marked && editor.selectedRange() == markedSelection,
                 "Production resize must preserve marked text and its selection")
    editor.unmarkText()
    let committedSelection = editor.selectedRange()
    let committedText = editor.string
    let originalFontSize = editor.font!.pointSize
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true, textSize: .large)
    settle(coordinator)
    precondition(editor.font!.pointSize == originalFontSize * AppTextSize.large.multiplier)
    precondition(editor.selectedRange() == committedSelection && editor.string == committedText)
    coordinator.update(viewport, text: binding, isEditable: true, isEnabled: true, textSize: .standard)
    settle(coordinator)
    precondition(editor.font!.pointSize == originalFontSize && editor.undoManager!.canUndo)

    // The size change is presentation, not a document edit in the undo stack.
    var undoSource = "before"
    let undoBinding = Binding(get: { undoSource }, set: { undoSource = $0 })
    let undoCoordinator = WorkspaceTextEditorCoordinator(text: undoBinding)
    let undoViewport = undoCoordinator.makeViewport()
    undoCoordinator.update(undoViewport, text: undoBinding, isEditable: true, isEnabled: true)
    let undoEditor = undoViewport.documentView as! NSTextView
    undoEditor.insertText("X", replacementRange: NSRange(location: 0, length: 0))
    undoEditor.breakUndoCoalescing()
    precondition(undoSource == "Xbefore")
    undoCoordinator.update(undoViewport, text: undoBinding, isEditable: true, isEnabled: true,
                           textSize: .extraLarge)
    settle(undoCoordinator)
    undoEditor.undoManager!.undo()
    precondition(undoSource == "before", "Typography must not insert an undo step")

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

    checkRouteReadingPosition(editable: true)
    checkRouteReadingPosition(editable: false)

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

    for mebibytes in [1, 10] {
      for editable in [true, false] {
        checkProductionViewport(mebibytes: mebibytes, editable: editable)
      }
    }
    // The intervening RunLoop turns also drain the hosted editor's deferred
    // capture. It must not expand the initial viewport measurement to all text.
    withExtendedLifetime(host) {
      precondition(native.layoutManager!.firstUnlaidCharacterIndex() < native.textStorage!.length)
    }
  }

  /// Settings removes the whole workspace route and creates new native editors.
  /// Both panes must regain their own logical top line, without retaining text.
  @MainActor private static func checkRouteReadingPosition(editable: Bool) {
    let paragraph = "段落 👩🏽‍💻 e\u{301} 中文換行與獨立閱讀位置\n"
    var document = String(repeating: paragraph, count: 20_000)
    let binding = Binding(get: { document }, set: { document = $0 })
    let state = WorkspaceEditorReadingState()
    let first = WorkspaceTextEditorCoordinator(text: binding, readingState: state)
    let firstViewport = first.makeViewport()
    firstViewport.setFrameSize(NSSize(width: 420, height: 240))
    first.update(firstViewport, text: binding, isEditable: editable, isEnabled: true)
    let firstEditor = firstViewport.documentView as! NSTextView
    let midpoint = (document as NSString).length / 2
    firstEditor.scrollRangeToVisible(NSRange(location: midpoint, length: 1))
    settle(first)
    let before = topLine(firstEditor, firstViewport)
    precondition(before.location > 0)
    first.saveReadingPosition(in: firstViewport)
    precondition(state.position != nil)

    let second = WorkspaceTextEditorCoordinator(text: binding, readingState: state)
    let secondViewport = second.makeViewport()
    secondViewport.setFrameSize(NSSize(width: 420, height: 240))
    second.update(secondViewport, text: binding, isEditable: editable, isEnabled: true)
    settle(second)
    let secondEditor = secondViewport.documentView as! NSTextView
    let after = topLine(secondEditor, secondViewport)
    precondition(NSLocationInRange(before.location, after),
                 "Settings return lost the \(editable ? "source" : "result") reading line")
    precondition(secondEditor.string.utf8.elementsEqual(document.utf8))

    state.invalidate()
    precondition(state.position == nil)
    let third = WorkspaceTextEditorCoordinator(text: binding, readingState: state)
    let thirdViewport = third.makeViewport()
    thirdViewport.setFrameSize(NSSize(width: 420, height: 240))
    third.update(thirdViewport, text: binding, isEditable: editable, isEnabled: true)
    settle(third)
    precondition(topLine(thirdViewport.documentView as! NSTextView, thirdViewport).location == 0,
                 "A new document must not inherit the previous reading position")
    record(["scenario": "settings-route-reading-position", "editable": editable,
            "before": [before.location, before.length], "after": [after.location, after.length],
            "passed": true])
  }

  /// Exercise the actual factory/delegate/keeper together, without opening a
  /// window or prewarming all layout. This does not cover the outer workspace
  /// ScrollView, first-responder behavior or actual divider gestures.
  @MainActor private static func checkProductionViewport(mebibytes: Int, editable: Bool) {
    let paragraph = "中文重排 👩🏽‍💻 e\u{301}\r\n" + String(repeating: "Reading position 中文 ", count: 24) + "\r\n"
    let repetitions = mebibytes * 1_048_576 / paragraph.utf8.count
    var document = String(repeating: paragraph, count: repetitions)
    let binding = Binding(get: { document }, set: { document = $0 })
    let coordinator = WorkspaceTextEditorCoordinator(text: binding)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 420, height: 240))
    coordinator.update(viewport, text: binding, isEditable: editable, isEnabled: true)
    let editor = viewport.documentView as! NSTextView
    let manager = editor.layoutManager!
    let initialDelegate = editor.delegate
    let original = document
    let middle = (paragraph as NSString).length * (repetitions / 2)
    let selection = NSRange(location: middle, length: 2)
    editor.setSelectedRange(selection)
    editor.scrollRangeToVisible(selection)
    settle(coordinator)
    precondition(editor.window == nil)
    precondition(visibleCharacters(editor, viewport).intersection(selection) != nil,
                 "Middle navigation must expose the selected text without prewarming")

    let sizes: [[NSSize]] = [
      [NSSize(width: 840, height: 180)],
      [NSSize(width: 320, height: 300)],
      [NSSize(width: 760, height: 260), NSSize(width: 620, height: 210), NSSize(width: 500, height: 280)]
    ]
    for (index, sequence) in sizes.enumerated() {
      let before = topLine(editor, viewport)
      for size in sequence { viewport.setFrameSize(size) }
      // Model/task updates during reflow must not replace the native document.
      coordinator.update(viewport, text: binding, isEditable: editable, isEnabled: true,
                         accessibilityLabel: editable ? "Source" : "Result")
      settle(coordinator)
      let after = topLine(editor, viewport)
      let retained = NSLocationInRange(before.location, after)
      record(["scenario": "production-middle-\(index)", "MiB": mebibytes, "bytes": original.utf8.count,
              "editable": editable, "before": [before.location, before.length],
              "after": [after.location, after.length], "passed": retained])
      precondition(retained, "Production viewport reflow lost the top reading line")
      precondition(editor.selectedRange() == selection)
      precondition(editor.layoutManager === manager && editor.delegate === initialDelegate)
      precondition(editor.isEditable == editable && editor.isSelectable)
      precondition(editor.string.utf8.elementsEqual(original.utf8))
    }

    // Reflow from an app-local size change must retain the logical reading
    // position and native editing state for both input and read-only result.
    for textSize in [AppTextSize.extraLarge, .standard] {
      let before = topLine(editor, viewport)
      let started = CFAbsoluteTimeGetCurrent()
      coordinator.update(viewport, text: binding, isEditable: editable, isEnabled: true,
                         textSize: textSize)
      settle(coordinator)
      let elapsed = CFAbsoluteTimeGetCurrent() - started
      let after = topLine(editor, viewport)
      let retained = NSLocationInRange(before.location, after)
      record(["scenario": "production-type-size-\(textSize.rawValue)", "MiB": mebibytes,
              "editable": editable, "before": [before.location, before.length],
              "after": [after.location, after.length], "seconds": elapsed, "passed": retained])
      precondition(retained, "Typography reflow lost the top reading line")
      precondition(editor.selectedRange() == selection)
      precondition(editor.layoutManager === manager && editor.delegate === initialDelegate)
      precondition(editor.string.utf8.elementsEqual(original.utf8))
    }

    // Jump to a previously unseen tail, then resize. Query the glyphs in the
    // viewport, not a point-insertion estimate beyond the last rendered line.
    let tail = NSRange(location: editor.textStorage!.length - 4, length: 1)
    editor.setSelectedRange(tail)
    editor.scrollRangeToVisible(tail)
    settle(coordinator)
    precondition(NSLocationInRange(tail.location, visibleCharacters(editor, viewport)))

    viewport.setFrameSize(NSSize(width: 360, height: 240))
    settle(coordinator)
    precondition(editor.selectedRange() == tail)
    // A resize retains the reading anchor, not necessarily the tail itself.
    editor.scrollRangeToVisible(tail)
    settle(coordinator)
    precondition(NSLocationInRange(tail.location, visibleCharacters(editor, viewport)))

    // Selection navigation takes priority over an already queued resize.
    viewport.setFrameSize(NSSize(width: 640, height: 260))
    editor.setSelectedRange(selection)
    editor.scrollRangeToVisible(selection)
    settle(coordinator)
    precondition(editor.selectedRange() == selection)
    precondition(NSLocationInRange(selection.location, visibleCharacters(editor, viewport)))

    // Replacing the document while a resize is queued invalidates the old
    // restoration. It must never write the old text or selection back.
    viewport.setFrameSize(NSSize(width: 800, height: 200))
    document = "新文稿\r\n\u{0} 👩🏽‍💻 e\u{301}"
    coordinator.update(viewport, text: binding, isEditable: editable, isEnabled: true)
    viewport.contentView.scroll(to: .zero)
    settle(coordinator)
    precondition(editor.string.utf8.elementsEqual(document.utf8))
    precondition(viewport.contentView.bounds.minY == 0)
    precondition(!editor.undoManager!.canUndo)
    record(["scenario": "production-tail-navigation-and-replacement", "MiB": mebibytes, "bytes": original.utf8.count,
            "editable": editable, "passed": true])
  }

  @MainActor private static func topLine(_ editor: NSTextView, _ viewport: NSScrollView) -> NSRange {
    let point = editor.convert(viewport.contentView.bounds.origin, from: viewport.contentView)
    let origin = editor.textContainerOrigin
    let layout = editor.layoutManager!
    let glyph = layout.glyphIndex(for: NSPoint(x: max(0, point.x - origin.x), y: max(0, point.y - origin.y)),
                                  in: editor.textContainer!)
    var range = NSRange()
    _ = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
    return layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
  }

  @MainActor private static func visibleCharacters(_ editor: NSTextView, _ viewport: NSScrollView) -> NSRange {
    let origin = editor.textContainerOrigin
    let rect = editor.convert(viewport.contentView.bounds, from: viewport.contentView)
      .offsetBy(dx: -origin.x, dy: -origin.y)
    let layout = editor.layoutManager!
    let glyphs = layout.glyphRange(forBoundingRect: rect, in: editor.textContainer!)
    return layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
  }

  @MainActor private static func settle(_ coordinator: WorkspaceTextEditorCoordinator) {
    let deadline = Date(timeIntervalSinceNow: 2)
    repeat {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    } while coordinator.isScrollRestorationPending && Date() < deadline
    precondition(!coordinator.isScrollRestorationPending, "Production scroll restoration timed out")
  }

  private static func record(_ fields: [String: Any]) {
    var fields = fields
    fields["hasWindow"] = false
    fields["os"] = ProcessInfo.processInfo.operatingSystemVersionString
    let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    FileHandle.standardError.write(data)
    FileHandle.standardError.write(Data([10]))
  }

  @MainActor static func findEditor(_ view: NSView) -> NSTextView? {
    if let editor = view as? NSTextView { return editor }
    return view.subviews.lazy.compactMap(findEditor).first
  }
}

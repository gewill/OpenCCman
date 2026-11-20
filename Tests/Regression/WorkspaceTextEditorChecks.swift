import AppKit
import SwiftUI

@main
enum WorkspaceTextEditorChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    if #available(macOS 12.0, *) {
      // Private benchmark variants must retain the native subclass while
      // opting into TextKit 2; a disabled decoration must not force fallback.
      let modernEditor = WorkspaceDiffTextView(usingTextLayoutManager: true)
      modernEditor.string = "中文 👩🏽‍💻"
      modernEditor.updateDecoration(nil)
      precondition(modernEditor.textLayoutManager != nil)
      precondition(modernEditor.string == "中文 👩🏽‍💻")
      print("PASS: diff editor retains explicit TextKit 2 construction with differences disabled")
    }
    var source = "中文\u{0} 👩🏽‍💻 e\u{301}\r\n\r\nsecond line"
    let text = editorText({ source }, { source = $0 })
    let coordinator = WorkspaceTextEditorCoordinator(text: text)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 400, height: 240))
    let editor = viewport.documentView as! NSTextView
    precondition(editor.font == NSFont.userFont(ofSize: 0),
                 "Start with the native editable-text font")
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, accessibilityLabel: "原文")
    precondition(editor.string == source && editor.isEditable)
    // The first Chinese run uses the system's fallback family, at the same size.
    precondition(editor.font?.pointSize == NSFont.userFont(ofSize: 0)?.pointSize)
    precondition(editor.accessibilityLabel() == "原文", "The text area itself needs a localized label")
    precondition(editor.layoutManager!.allowsNonContiguousLayout)
    precondition(!editor.layoutManager!.backgroundLayoutEnabled)
    precondition(viewport.intrinsicContentSize == NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric))

    // Native typing, undo and redo must update the authoritative SwiftUI text.
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    let original = source
    editor.insertText("前", replacementRange: NSRange(location: 0, length: 0))
    precondition(source == "前" + original)
    editor.breakUndoCoalescing()
    let selection = editor.selectedRange()
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.selectedRange() == selection)
    precondition(editor.undoManager!.canUndo)

    let diffEditor = editor as! WorkspaceDiffTextView
    let plainStorage = editor.textStorage!.copy() as! NSAttributedString
    let beforeDiffSelection = editor.selectedRange()
    let diffID = UUID()
    let decoration = WorkspaceDiffDecoration(id: diffID, text: editor.string,
                                             ranges: [NSRange(location: 0, length: 1)],
                                             currentIndex: nil, navigationID: nil)
    diffEditor.updateDecoration(decoration)
    precondition(editor.selectedRange() == beforeDiffSelection && editor.textStorage!.isEqual(to: plainStorage),
                 "Showing differences must not alter selection or attributed storage")
    let navigation = UUID()
    diffEditor.updateDecoration(WorkspaceDiffDecoration(id: diffID, text: editor.string,
      ranges: decoration.ranges, currentIndex: 0, navigationID: navigation))
    precondition(editor.selectedRange() == decoration.ranges[0])
    editor.setSelectedRange(beforeDiffSelection)
    diffEditor.updateDecoration(WorkspaceDiffDecoration(id: diffID, text: editor.string,
      ranges: decoration.ranges, currentIndex: 0, navigationID: navigation))
    precondition(editor.selectedRange() == beforeDiffSelection, "Layout updates cannot replay navigation")
    diffEditor.updateDecoration(nil)
    precondition(editor.textStorage!.isEqual(to: plainStorage) && editor.undoManager!.canUndo)
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, accessibilityLabel: "Source")
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
    diffEditor.updateDecoration(WorkspaceDiffDecoration(id: UUID(), text: editor.string,
      ranges: [NSRange(location: 0, length: 1)], currentIndex: 0, navigationID: UUID()))
    precondition(editor.hasMarkedText() && editor.selectedRange() == markedSelection,
                 "Difference navigation cannot interrupt marked text")
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.hasMarkedText() && editor.markedRange() == marked)
    precondition(editor.selectedRange() == markedSelection && editor.string == textBeforeUpdate)
    let fontDuringComposition = editor.font
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, textSize: .large)
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
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, textSize: .large)
    settle(coordinator)
    precondition(editor.font!.pointSize == originalFontSize * AppTextSize.large.multiplier)
    precondition(editor.selectedRange() == committedSelection && editor.string == committedText)
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, textSize: .standard)
    settle(coordinator)
    precondition(editor.font!.pointSize == originalFontSize && editor.undoManager!.canUndo)

    // The size change is presentation, not a document edit in the undo stack.
    var undoSource = "before"
    let undoText = editorText({ undoSource }, { undoSource = $0 })
    let undoCoordinator = WorkspaceTextEditorCoordinator(text: undoText)
    let undoViewport = undoCoordinator.makeViewport()
    undoCoordinator.update(undoViewport, text: undoText, isEditable: true, isEnabled: true)
    let undoEditor = undoViewport.documentView as! NSTextView
    undoEditor.insertText("X", replacementRange: NSRange(location: 0, length: 0))
    undoEditor.breakUndoCoalescing()
    precondition(undoSource == "Xbefore")
    undoCoordinator.update(undoViewport, text: undoText, isEditable: true, isEnabled: true,
                           textSize: .extraLarge)
    settle(undoCoordinator)
    undoEditor.undoManager!.undo()
    precondition(undoSource == "before", "Typography must not insert an undo step")

    // Rendering the read-only output must not discard the source undo history.
    var result = "converted"
    let resultText = editorText({ result }, { result = $0 })
    let resultCoordinator = WorkspaceTextEditorCoordinator(text: resultText)
    let resultViewport = resultCoordinator.makeViewport()
    resultCoordinator.update(resultViewport, text: resultText, isEditable: false, isEnabled: true)
    let resultEditor = resultViewport.documentView as! NSTextView
    precondition(!resultEditor.isEditable && resultEditor.isSelectable)
    precondition(resultEditor.undoManager !== editor.undoManager)
    precondition(editor.undoManager!.canUndo)

    coordinator.update(viewport, text: text, isEditable: true, isEnabled: false)
    precondition(!editor.isEditable && !editor.isSelectable)
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    source = "replacement\r\n\u{0}"
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.string == source && !editor.undoManager!.canUndo)
    precondition(!editor.hasMarkedText())
    // Swift == considers these equal; the editor must still replace their bytes.
    source = "e\u{301}\u{323}"
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    let previousSpelling = source
    source = "e\u{323}\u{301}"
    precondition(source == previousSpelling)
    precondition(!source.utf8.elementsEqual(previousSpelling.utf8))
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.string.utf8.elementsEqual(source.utf8))
    print("PASS: complete text, typing/text, undo/redo, marked text echo, selection, independent undo, disabled/read-only and external replacement")

    checkRouteReadingPosition(editable: true)
    checkRouteReadingPosition(editable: false)

    // Exercise the real representable in SwiftUI layout, without opening a
    // window. Large text must not supply the viewport's intrinsic content size.
    let paragraph = "中文布局 👩🏽‍💻 e\u{301}\r\n"
    let large = String(repeating: paragraph, count: 160_000)
    let host = NSHostingView(rootView: WorkspaceTextEditor(text: editorText({ large }))
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
    checkLiteralEquality()
    checkKeystrokeEcho(mebibytes: 10)
    checkReportedEdits()
    checkHostedKeystroke(mebibytes: 10)
    checkExternalReplacement(mebibytes: 1)
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
    let text = editorText({ document }, { document = $0 })
    let state = WorkspaceEditorReadingState()
    let first = WorkspaceTextEditorCoordinator(text: text, readingState: state)
    let firstViewport = first.makeViewport()
    firstViewport.setFrameSize(NSSize(width: 420, height: 240))
    first.update(firstViewport, text: text, isEditable: editable, isEnabled: true)
    let firstEditor = firstViewport.documentView as! NSTextView
    let midpoint = (document as NSString).length / 2
    firstEditor.scrollRangeToVisible(NSRange(location: midpoint, length: 1))
    settle(first)
    let before = topLine(firstEditor, firstViewport)
    precondition(before.location > 0)
    first.saveReadingPosition(in: firstViewport)
    precondition(state.position != nil)

    let second = WorkspaceTextEditorCoordinator(text: text, readingState: state)
    let secondViewport = second.makeViewport()
    secondViewport.setFrameSize(NSSize(width: 420, height: 240))
    second.update(secondViewport, text: text, isEditable: editable, isEnabled: true)
    settle(second)
    let secondEditor = secondViewport.documentView as! NSTextView
    let after = topLine(secondEditor, secondViewport)
    precondition(NSLocationInRange(before.location, after),
                 "Settings return lost the \(editable ? "source" : "result") reading line")
    precondition(secondEditor.string.utf8.elementsEqual(document.utf8))

    state.invalidate()
    precondition(state.position == nil)
    let third = WorkspaceTextEditorCoordinator(text: text, readingState: state)
    let thirdViewport = third.makeViewport()
    thirdViewport.setFrameSize(NSSize(width: 420, height: 240))
    third.update(thirdViewport, text: text, isEditable: editable, isEnabled: true)
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
    let text = editorText({ document }, { document = $0 })
    let coordinator = WorkspaceTextEditorCoordinator(text: text)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 420, height: 240))
    coordinator.update(viewport, text: text, isEditable: editable, isEnabled: true)
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
      coordinator.update(viewport, text: text, isEditable: editable, isEnabled: true,
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
      coordinator.update(viewport, text: text, isEditable: editable, isEnabled: true,
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
    coordinator.update(viewport, text: text, isEditable: editable, isEnabled: true)
    viewport.contentView.scroll(to: .zero)
    settle(coordinator)
    precondition(editor.string.utf8.elementsEqual(document.utf8))
    precondition(viewport.contentView.bounds.minY == 0)
    precondition(!editor.undoManager!.canUndo)
    record(["scenario": "production-tail-navigation-and-replacement", "MiB": mebibytes, "bytes": original.utf8.count,
            "editable": editable, "passed": true])
  }

  /// Each shortcut in `hasSameUTF8` must give the byte-exact answer, in both
  /// directions: the same value, small strings, identical bytes in new
  /// storage, equal-length differences and AppKit's bridged snapshots.
  @MainActor private static func checkLiteralEquality() {
    let large = String(repeating: "中文 e\u{301}", count: 50_000)
    let pairs: [(String, String, Bool)] = [
      ("", "", true), ("", "a", false),
      ("e\u{301}x", "xe\u{301}", false),
      ("e\u{301}\u{323}", "e\u{323}\u{301}", false),
      (large, String(decoding: Array(large.utf8), as: UTF8.self), true),
      (large, large.replacingOccurrences(of: "文", with: "字"), false),
      (large, large + "x", false),
    ]
    for (a, b, expected) in pairs {
      precondition(a.hasSameUTF8(as: b) == expected && b.hasSameUTF8(as: a) == expected)
    }
    precondition(large.hasSameUTF8(as: large))
    let editor = NSTextView()
    editor.string = large
    let bridged = editor.string
    precondition(bridged.hasSameUTF8(as: bridged) && bridged.hasSameUTF8(as: large) && large.hasSameUTF8(as: bridged))
    editor.setSelectedRange(NSRange(location: 1, length: 1))
    editor.insertText("字", replacementRange: NSRange(location: NSNotFound, length: 0))
    let replaced = editor.string
    precondition(replaced.utf16.count == bridged.utf16.count)
    precondition(!replaced.hasSameUTF8(as: bridged) && !bridged.hasSameUTF8(as: replaced) && !replaced.hasSameUTF8(as: large))
    print("PASS: byte-exact equality for the same value, small, large, bridged, equal-length and canonically equivalent text")
  }

  /// A native keystroke publishes the editor's own string. The model's change
  /// check (`HomeViewModel.inputText`) and the next update must not compare the
  /// whole document, for an insertion or an equal-length replacement of a
  /// selected character: together they stay within 20 ms at 10 MiB.
  @MainActor private static func checkKeystrokeEcho(mebibytes: Int) {
    let paragraph = "中文按鍵 👩🏽‍💻 e\u{301}\r\n" + String(repeating: "鼠标里面的硅二极管坏了 ", count: 16) + "\r\n"
    var document = String(repeating: paragraph, count: mebibytes * 1_048_576 / paragraph.utf8.count)
    var changes = 0
    var modelCheck: CFAbsoluteTime = 0
    let text = modelText({ document }, { value, changed in
      let oldValue = document
      document = value
      let started = CFAbsoluteTimeGetCurrent()
      if changed || !document.hasSameUTF8(as: oldValue) { changes += 1 }  // HomeViewModel.inputText didSet
      modelCheck += CFAbsoluteTimeGetCurrent() - started
    })
    let coordinator = WorkspaceTextEditorCoordinator(text: text)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 420, height: 240))
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    let editor = viewport.documentView as! NSTextView
    for (place, replacing) in [("middle", false), ("end", false), ("middle", true), ("end", true)] {
      let length = editor.textStorage!.length
      let location = place == "middle" ? length / 2 : length - (replacing ? 1 : 0)
      editor.setSelectedRange(NSRange(location: location, length: replacing ? 1 : 0))
      let typed = replacing && editor.attributedSubstring(forProposedRange: editor.selectedRange(), actualRange: nil)?
        .string == "字" ? "文" : "字"
      let before = changes
      modelCheck = 0
      editor.insertText(typed, replacementRange: NSRange(location: NSNotFound, length: 0))
      editor.breakUndoCoalescing()
      precondition(changes == before + 1 && editor.string.utf8.count == document.utf8.count,
                   "A typed character reaches the model as a change")
      let selection = editor.selectedRange()
      let started = CFAbsoluteTimeGetCurrent()
      coordinator.update(viewport, text: text, isEditable: true, isEnabled: true, accessibilityLabel: "Source")
      let update = CFAbsoluteTimeGetCurrent() - started
      let scenario = "keystroke-echo-\(replacing ? "replace-" : "")\(place)"
      record(["scenario": scenario, "MiB": mebibytes, "bytes": document.utf8.count,
              "modelCheckMilliseconds": modelCheck * 1000, "updateMilliseconds": update * 1000,
              "passed": modelCheck + update < 0.02])
      precondition(modelCheck + update < 0.02, "A keystroke compared the whole document (\(scenario))")
      precondition(editor.undoManager!.canUndo && editor.selectedRange() == selection,
                   "The editor's own echo must not replace its document")
    }
    print("PASS: \(mebibytes) MiB keystroke echo, inserting and replacing a selected character; model change check and editor update without a document comparison")
  }

  /// The editor reports a change only when AppKit replaces text with different
  /// text. Without the report the model compares, so identical text typed over
  /// itself keeps the result, and other edits stay correct either way.
  @MainActor private static func checkReportedEdits() {
    var document = "中文 e\u{301}"
    var reports: [Bool] = []
    let text = modelText({ document }, { value, changed in document = value; reports.append(changed) })
    let coordinator = WorkspaceTextEditorCoordinator(text: text)
    let viewport = coordinator.makeViewport()
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    let editor = viewport.documentView as! NSTextView
    func type(_ string: String, over range: NSRange) {
      editor.setSelectedRange(range)
      editor.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
      editor.breakUndoCoalescing()
    }
    type("前", over: NSRange(location: 0, length: 0))
    precondition(reports == [true] && document == "前中文 e\u{301}", "An insertion is reported")
    type("后", over: NSRange(location: 0, length: 1))
    precondition(reports == [true, true] && document == "后中文 e\u{301}", "An equal-length replacement is reported")
    type("后", over: NSRange(location: 0, length: 1))
    precondition(reports == [true, true, false] && document == "后中文 e\u{301}",
                 "Identical text typed over itself is left to the model's comparison")
    let beforeUndo = reports.count
    editor.undoManager!.undo()
    precondition(editor.string.utf8.elementsEqual(document.utf8) && reports.count > beforeUndo,
                 "Undo reaches the model, reported or compared: \(reports) [\(document)] [\(editor.string)]")
    print("PASS: edits reported from the edited ranges: insertion, equal-length replacement, identical text left to the model, undo (reported: \(reports.last!))")
  }

  /// The app's panes observe the window model, which publishes every keystroke,
  /// and SwiftUI compares each view's new value with the old one. Values that
  /// held the document (a `Binding<String>`) were compared by canonical
  /// equivalence up to the edit, three times per key: 0.3–0.5 s at 10 MiB in
  /// the app (#352). Hosted the same way, a typed character must reach the
  /// model and SwiftUI must have updated the editor within 100 ms (about
  /// 15–20 ms on an M4 Pro; the pre-fix editor took 0.4–0.8 s here).
  @MainActor private static func checkHostedKeystroke(mebibytes: Int) {
    let paragraph = "中文宿主 👩🏽‍💻 e\u{301}\r\n" + String(repeating: "鼠标里面的硅二极管坏了 ", count: 16) + "\r\n"
    let document = String(repeating: paragraph, count: mebibytes * 1_048_576 / paragraph.utf8.count)
    let length = document.utf16.count
    let model = HostedModel(document)
    // Shown without activating, as IntrospectionChecks does: SwiftUI updates a
    // window's hosting view through its display cycle on older systems.
    NSApplication.shared.setActivationPolicy(.prohibited)
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320), styleMask: [.titled],
                          backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: HostedPane(model: model))
    window.orderFront(nil)
    defer { window.close() }
    var found: NSTextView?
    let deadline = Date(timeIntervalSinceNow: 10)
    while found?.textStorage?.length != length, Date() < deadline {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
      found = window.contentView.flatMap(findEditor)
    }
    guard let editor = found, editor.textStorage!.length == length else {
      preconditionFailure("The hosted editor never showed the model's document")
    }
    // Not measured: from the first keystroke on, the model holds the editor's
    // own string, as it does while typing. Comparing that bridged string is
    // the slow case; the initial native document was compared quickly.
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    editor.insertText("前", replacementRange: NSRange(location: NSNotFound, length: 0))
    editor.breakUndoCoalescing()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
    for (place, replacing) in [("middle", false), ("end", false), ("middle", true), ("end", true)] {
      let before = editor.textStorage!.length
      let location = place == "middle" ? before / 2 : before - (replacing ? 1 : 0)
      editor.setSelectedRange(NSRange(location: location, length: replacing ? 1 : 0))
      let typed = replacing && editor.attributedSubstring(forProposedRange: editor.selectedRange(), actualRange: nil)?
        .string == "字" ? "文" : "字"
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
      let reads = model.reads
      let revision = model.revision
      let started = CFAbsoluteTimeGetCurrent()
      editor.insertText(typed, replacementRange: NSRange(location: NSNotFound, length: 0))
      while model.reads == reads, CFAbsoluteTimeGetCurrent() - started < 5 {
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.001))
      }
      let elapsed = CFAbsoluteTimeGetCurrent() - started
      let after = before + (replacing ? 0 : 1)
      precondition(model.reads > reads, "SwiftUI never updated the hosted editor after a keystroke")
      precondition(model.revision == revision + 1 && model.text.utf16.count == after
                   && editor.textStorage!.length == after, "The typed character reaches the model once")
      let scenario = "hosted-keystroke-\(replacing ? "replace-" : "")\(place)"
      record(["scenario": scenario, "MiB": mebibytes, "bytes": model.text.utf8.count,
              "milliseconds": elapsed * 1000, "passed": elapsed < 0.1])
      precondition(elapsed < 0.1, "A keystroke compared the document (\(scenario))")
      editor.breakUndoCoalescing()
    }
    print("PASS: \(mebibytes) MiB keystroke in a SwiftUI pane observing its model, inserting and replacing; no document comparison")
  }

  /// Model writes that bypass the editor still compare bytes at document size:
  /// equal length with one different character is rendered, a new string with
  /// identical bytes is not (the undo history survives).
  @MainActor private static func checkExternalReplacement(mebibytes: Int) {
    let paragraph = "外部替換 👩🏽‍💻 e\u{301}\r\n" + String(repeating: "鼠标里面的硅二极管坏了 ", count: 16) + "\r\n"
    let count = mebibytes * 1_048_576 / paragraph.utf8.count
    var document = String(repeating: paragraph, count: count)
    let text = editorText({ document }, { document = $0 })
    let coordinator = WorkspaceTextEditorCoordinator(text: text)
    let viewport = coordinator.makeViewport()
    viewport.setFrameSize(NSSize(width: 420, height: 240))
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    let editor = viewport.documentView as! NSTextView
    editor.setSelectedRange(NSRange(location: 0, length: 0))
    editor.insertText("前", replacementRange: NSRange(location: NSNotFound, length: 0))
    editor.breakUndoCoalescing()
    precondition(editor.undoManager!.canUndo)

    document = String(decoding: Array(document.utf8), as: UTF8.self)
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.undoManager!.canUndo, "Identical bytes in a new string are not a replacement")

    let half = String(repeating: paragraph, count: count / 2)
    let replaced = paragraph.replacingOccurrences(of: "坏", with: "壞")
    precondition(replaced.utf16.count == paragraph.utf16.count && replaced.utf8.count == paragraph.utf8.count)
    document = "後" + half + replaced + String(repeating: paragraph, count: count - count / 2 - 1)
    precondition(document.utf16.count == editor.textStorage!.length)
    coordinator.update(viewport, text: text, isEditable: true, isEnabled: true)
    precondition(editor.string.utf8.elementsEqual(document.utf8) && !editor.undoManager!.canUndo,
                 "An equal-length model replacement must be rendered")
    print("PASS: \(mebibytes) MiB external replacement; equal length rendered, identical bytes kept with undo")
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

  /// The editor's text as a window model provides it, here from local closures.
  @MainActor static func editorText(_ read: @escaping @MainActor () -> String,
                                    _ write: (@MainActor (String) -> Void)? = nil) -> WorkspaceEditorText {
    guard let write else { return modelText(read, nil) }
    return modelText(read) { text, _ in write(text) }
  }

  /// As `editorText`, with the editor's report of a known change.
  @MainActor static func modelText(_ read: @escaping @MainActor () -> String,
                                   _ write: (@MainActor (_ text: String, _ changed: Bool) -> Void)?) -> WorkspaceEditorText {
    WorkspaceEditorText(source: WorkspaceEditorTextSource(read: read, write: write), revision: 0)
  }
}

/// The window model's part that the source pane uses (`HomeViewModel`).
@MainActor
private final class HostedModel: ObservableObject {
  @Published var text: String {
    didSet {
      let reported = editChanged
      editChanged = false
      if reported || !text.hasSameUTF8(as: oldValue) { revision += 1 }
    }
  }
  private(set) var revision = 0
  /// How often the editor has read the text: once per SwiftUI update of it.
  private(set) var reads = 0
  private var editChanged = false
  private lazy var source = WorkspaceEditorTextSource(read: { [weak self] in
    guard let self else { return "" }
    reads += 1
    return text
  }, write: { [weak self] value, changed in
    guard let self else { return }
    editChanged = changed
    text = value
  })

  var editorText: WorkspaceEditorText { WorkspaceEditorText(source: source, revision: revision) }

  init(_ text: String) { self.text = text }
}

/// Observes the whole model and reads the text, as the app's source pane does.
private struct HostedPane: View {
  @ObservedObject var model: HostedModel

  var body: some View {
    VStack {
      Text(model.text.isEmpty ? "empty" : "text")
      WorkspaceTextEditor(text: model.editorText, label: "Source")
    }
    .frame(width: 520, height: 320)
  }
}

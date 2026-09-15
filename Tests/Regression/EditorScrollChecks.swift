import AppKit

@main
enum EditorScrollChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    let scroll = NSTextView.scrollableTextView()
    scroll.setFrameSize(NSSize(width: 400, height: 240))
    let text = scroll.documentView as! NSTextView
    text.string = (0 ..< 30).map { index in
      "Paragraph \(index): " + String(repeating: "中文重排测试 é 👩🏽‍💻 keep this reading position. ", count: 10) + "\n"
    }.joined()
    text.layoutManager!.ensureLayout(for: text.textContainer!)
    text.sizeToFit()
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    let target = (text.string as NSString).range(of: "Paragraph 15:").location
    text.scrollRangeToVisible(NSRange(location: target, length: 1))
    let oldSelection = NSRange(location: target, length: 12)
    text.setSelectedRange(oldSelection)
    let beforeLine = topLine(text, scroll)
    let beforeBounds = scroll.contentView.bounds
    scroll.setFrameSize(NSSize(width: 850, height: 180))
    settle(keeper)
    let widenedLine = topLine(text, scroll)
    let retainedLine = NSLocationInRange(beforeLine.location, widenedLine)
    recordReflow("initial-width", before: beforeLine, after: widenedLine,
                 beforeBounds: beforeBounds, text: text, scroll: scroll, passed: retainedLine)
    precondition(retainedLine, "Width reflow must retain the old top character's line: before \(beforeLine), after \(widenedLine), clip before \(beforeBounds), after \(scroll.contentView.bounds)")
    precondition(text.selectedRange() == oldSelection, "Restoring scroll must not change the selection")
    let widerLine = topLine(text, scroll)
    let widerBounds = scroll.contentView.bounds
    scroll.setFrameSize(NSSize(width: 360, height: 300))
    settle(keeper)
    let narrowLine = topLine(text, scroll)
    let retainedNearCharacter = abs(narrowLine.location - widerLine.location) < 50
    recordReflow("initial-narrow", before: widerLine, after: narrowLine,
                 beforeBounds: widerBounds, text: text, scroll: scroll, passed: retainedNearCharacter)
    precondition(retainedNearCharacter, "Narrowing must remain near the same character: before \(widerLine), after \(narrowLine), clip before \(widerBounds), after \(scroll.contentView.bounds)")
    precondition(text.selectedRange() == oldSelection)
    // Coalesced resizes and a new document must not replay an old anchor.
    scroll.setFrameSize(NSSize(width: 800, height: 250))
    scroll.setFrameSize(NSSize(width: 500, height: 200))
    text.string = "New document\n"
    scroll.contentView.scroll(to: .zero)
    settle(keeper)
    precondition(scroll.contentView.bounds.minY == 0)
    precondition(text.string == "New document\n")
    text.setSelectedRange(NSRange(location: 0, length: 0))
    text.setMarkedText("pinyin", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = text.markedRange()
    precondition(text.hasMarkedText())
    scroll.setFrameSize(NSSize(width: 700, height: 240))
    settle(keeper)
    precondition(text.markedRange() == marked, "Scroll restoration cannot commit or discard composition")
    checkUnlaidOutDocumentEnd()
    checkLargeEditor()
    checkMiddleReflowAnchor()
    checkNavigationDuringReflow()
    print("PASS: on-demand document end, native text reflow, selection, rapid resize, new-document reset and marked range preservation")
  }

  @MainActor private static func checkUnlaidOutDocumentEnd() {
    let scroll = NSTextView.scrollableTextView()
    scroll.setFrameSize(NSSize(width: 420, height: 240))
    let text = scroll.documentView as! NSTextView
    // This case exercises the macOS 11 / TextKit 1 compatibility path explicitly.
    _ = text.layoutManager
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    // No ensureLayout/sizeToFit prewarming: jump to text that has never been
    // visible, then resize. Native on-demand layout must make the tail readable.
    text.string = String(repeating: "中文 👩🏽‍💻 é paragraph for distant scrolling.\n", count: 16000)
    let end = (text.string as NSString).length - 2
    text.setSelectedRange(NSRange(location: end, length: 1))
    text.scrollRangeToVisible(NSRange(location: end, length: 1))
    settle(keeper)
    let visible = text.layoutManager!.glyphRange(forBoundingRect: text.visibleRect, in: text.textContainer!)
    let characters = text.layoutManager!.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
    precondition(NSLocationInRange(end, characters), "First jump must lay out the unseen document tail")
    scroll.setFrameSize(NSSize(width: 760, height: 260))
    settle(keeper)
    precondition(text.selectedRange() == NSRange(location: end, length: 1), "Tail selection must survive reflow")
  }


  @MainActor private static func checkLargeEditor() {
    let scroll = NSTextView.scrollableTextView()
    let text = scroll.documentView as! NSTextView
    let manager = text.layoutManager!
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = scroll
    window.orderFront(nil)
    defer { window.close() }
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    precondition(manager.allowsNonContiguousLayout && !manager.backgroundLayoutEnabled)
    text.string = (0..<1000).map { "Paragraph \($0): " + String(repeating: "中文 é 👩🏽‍💻 reflow ", count: 30) + "\n" }.joined()
    settle(keeper)
    let target = (text.string as NSString).range(of: "Paragraph 500:").location
    text.setSelectedRange(NSRange(location: target, length: 8))
    text.scrollRangeToVisible(NSRange(location: target, length: 8))
    settle(keeper)
    let selected = text.selectedRange()
    let top = text.characterIndexForInsertion(at: text.convert(scroll.contentView.bounds.origin, from: scroll.contentView))
    window.setContentSize(NSSize(width: 760, height: 260))
    settle(keeper)
    precondition(text.layoutManager === manager, "Keeper must retain the native layout manager")
    precondition(text.selectedRange() == selected, "Noncontiguous reflow must preserve selection")
    let currentTop = text.characterIndexForInsertion(at: text.convert(scroll.contentView.bounds.origin, from: scroll.contentView))
    precondition(abs(currentTop - top) < 100, "Noncontiguous reflow must preserve the top reading line")
    let tail = (text.string as NSString).length - 2
    text.setSelectedRange(NSRange(location: tail, length: 0))
    text.scrollRangeToVisible(NSRange(location: tail, length: 1))
    settle(keeper)
    // An insertion point beyond the last rendered line is not a reliable
    // visible-text query on macOS 15. Ask for the actual visible glyph range.
    let visibleGlyphs = manager.glyphRange(forBoundingRect: text.visibleRect, in: text.textContainer!)
    let visibleCharacters = manager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)
    precondition(NSLocationInRange(tail, visibleCharacters),
                 "First jump must make the previously unseen tail visible: tail \(tail), visible \(visibleCharacters), bounds \(text.visibleRect)")
    window.setContentSize(NSSize(width: 380, height: 260))
    settle(keeper)
    precondition(text.layoutManager === manager)
    precondition(text.selectedRange().location == tail)
    text.setMarkedText("pinyin", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = text.markedRange()
    window.setContentSize(NSSize(width: 600, height: 260))
    settle(keeper)
    precondition(text.markedRange() == marked)
    precondition(text.layoutManager === manager)
    text.unmarkText()
    text.string = "New document\n"
    scroll.contentView.scroll(to: .zero)
    settle(keeper)
    precondition(scroll.contentView.bounds.minY == 0)
    // Long paragraphs exercise wrapped lines within one layout fragment rather
    // than only the short multilingual paragraphs used above.
    for mib in [1, 5, 10] {
      let paragraph = String(repeating: "中文 é 👩🏽‍💻 long paragraph ", count: 256) + "\r\n"
      text.string = String(repeating: paragraph, count: mib * 1024 * 1024 / paragraph.utf8.count)
      let length = (text.string as NSString).length
      let range = (text.string as NSString).rangeOfComposedCharacterSequence(at: length / 2)
      text.setSelectedRange(NSRange(location: range.location, length: 0))
      text.scrollRangeToVisible(range)
      settle(keeper)
      window.setContentSize(NSSize(width: 400, height: 240)); settle(keeper)
      window.setContentSize(NSSize(width: 700, height: 240)); settle(keeper)
      precondition(text.layoutManager === manager)
      precondition(text.selectedRange().location == range.location)
    }
    print("PASS: 1/5/10 MiB long paragraphs retain the native editor and selection through reflow")
    print("PASS: Native editor retained through attach, middle/tail resize, selection, composition and replacement")
  }

  @MainActor private static func checkNavigationDuringReflow() {
    let scroll = NSTextView.scrollableTextView()
    let text = scroll.documentView as! NSTextView
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = scroll
    window.orderFront(nil)
    defer { window.close() }
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    text.string = (0..<1000).map { "Paragraph \($0): " + String(repeating: "中文 é 👩🏽‍💻 reflow ", count: 30) + "\n" }.joined()
    settle(keeper)
    let middle = (text.string as NSString).range(of: "Paragraph 500:").location
    text.setSelectedRange(NSRange(location: middle, length: 8))
    text.scrollRangeToVisible(NSRange(location: middle, length: 8))
    settle(keeper)
    // Intentionally navigate before queued restoration callbacks can run.
    window.setContentSize(NSSize(width: 760, height: 260))
    let tail = (text.string as NSString).length - 2
    text.setSelectedRange(NSRange(location: tail, length: 0))
    text.scrollRangeToVisible(NSRange(location: tail, length: 1))
    for _ in 0..<4 { settle(keeper) }
    let manager = text.layoutManager!
    let visible = manager.characterRange(forGlyphRange: manager.glyphRange(forBoundingRect: text.visibleRect,
                                          in: text.textContainer!), actualGlyphRange: nil)
    precondition(text.selectedRange().location == tail)
    precondition(NSLocationInRange(tail, visible), "Later navigation must win over queued width restoration")
    withExtendedLifetime(keeper) {}
    print("PASS: navigation during pending reflow keeps the new caret visible")
  }

  @MainActor private static func checkMiddleReflowAnchor() {
    let scroll = NSTextView.scrollableTextView()
    scroll.setFrameSize(NSSize(width: 400, height: 240))
    let text = scroll.documentView as! NSTextView
    text.string = (0..<1500).map { index in
      "Paragraph \(index): " + String(repeating: "中文重排测试 é 👩🏽‍💻 keep this reading position. ", count: 10) + "\n"
    }.joined()
    text.layoutManager!.ensureLayout(for: text.textContainer!)
    text.sizeToFit()
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    let middle = (text.string as NSString).range(of: "Paragraph 750:").location
    text.scrollRangeToVisible(NSRange(location: middle, length: 1))
    text.setSelectedRange(NSRange(location: middle, length: 12))
    let beforeLine = topLine(text, scroll)
    let beforeBounds = scroll.contentView.bounds
    scroll.setFrameSize(NSSize(width: 850, height: 180))
    settle(keeper)
    let afterLine = topLine(text, scroll)
    let retainedLine = NSLocationInRange(beforeLine.location, afterLine)
    recordReflow("large-middle-width", before: beforeLine, after: afterLine,
                 beforeBounds: beforeBounds, text: text, scroll: scroll, passed: retainedLine)
    precondition(retainedLine,
                 "Large middle anchor must retain its line after width reflow: before \(beforeLine), after \(afterLine), clip before \(beforeBounds), after \(scroll.contentView.bounds)")
  }

  @MainActor private static func recordReflow(_ scenario: String, before: NSRange, after: NSRange,
                                             beforeBounds: NSRect, text: NSTextView,
                                             scroll: NSScrollView, passed: Bool) {
    // Use the already-observed line ranges: another layout query could alter the
    // state we are diagnosing. Write synchronously so a failed precondition does
    // not discard the evidence buffered before its crash.
    let record: [String: Any] = [
      "event": "reading-anchor", "scenario": scenario, "passed": passed,
      "beforeLine": [before.location, before.length], "afterLine": [after.location, after.length],
      "beforeClipBounds": NSStringFromRect(beforeBounds),
      "afterClipBounds": NSStringFromRect(scroll.contentView.bounds),
      "editorFrame": NSStringFromRect(text.frame),
      "selection": NSStringFromRange(text.selectedRange()),
      "hasWindow": text.window != nil,
      "os": ProcessInfo.processInfo.operatingSystemVersionString
    ]
    let data = try! JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
    FileHandle.standardError.write(data)
    FileHandle.standardError.write(Data([10]))
  }

  @MainActor private static func topLine(_ text: NSTextView, _ scroll: NSScrollView) -> NSRange {
    let layout = text.layoutManager!
    let point = text.convert(scroll.contentView.bounds.origin, from: scroll.contentView)
    let origin = text.textContainerOrigin
    let glyph = layout.glyphIndex(for: NSPoint(x: max(0, point.x - origin.x), y: max(0, point.y - origin.y)), in: text.textContainer!)
    var range = NSRange()
    _ = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &range)
    return layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
  }

  @MainActor private static func settle(_ keeper: WorkspaceScrollKeeper) {
    let deadline = Date(timeIntervalSinceNow: 2)
    repeat {
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
    } while keeper.isRestorationPending && Date() < deadline
    precondition(!keeper.isRestorationPending,
                 "Scroll restoration did not finish before the bounded deadline")
  }
}

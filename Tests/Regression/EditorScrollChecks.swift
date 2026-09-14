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
    let before = topLine(text, scroll).location
    scroll.setFrameSize(NSSize(width: 850, height: 180))
    settle()
    precondition(NSLocationInRange(before, topLine(text, scroll)), "Width reflow must retain the old top character's line")
    precondition(text.selectedRange() == oldSelection, "Restoring scroll must not change the selection")
    let wider = topLine(text, scroll).location
    scroll.setFrameSize(NSSize(width: 360, height: 300))
    settle()
    let narrowLine = topLine(text, scroll)
    precondition(abs(narrowLine.location - wider) < 50, "Narrowing must remain near the same character")
    precondition(text.selectedRange() == oldSelection)
    // Coalesced resizes and a new document must not replay an old anchor.
    scroll.setFrameSize(NSSize(width: 800, height: 250))
    scroll.setFrameSize(NSSize(width: 500, height: 200))
    text.string = "New document\n"
    scroll.contentView.scroll(to: .zero)
    settle()
    precondition(scroll.contentView.bounds.minY == 0)
    precondition(text.string == "New document\n")
    text.setSelectedRange(NSRange(location: 0, length: 0))
    text.setMarkedText("pinyin", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = text.markedRange()
    precondition(text.hasMarkedText())
    scroll.setFrameSize(NSSize(width: 700, height: 240))
    settle()
    precondition(text.markedRange() == marked, "Scroll restoration cannot commit or discard composition")
    checkUnlaidOutDocumentEnd()
    checkMiddleReflowAnchor()
    print("PASS: on-demand document end, native text reflow, selection, rapid resize, new-document reset and marked range preservation")
  }

  @MainActor private static func checkUnlaidOutDocumentEnd() {
    let scroll = NSTextView.scrollableTextView()
    scroll.setFrameSize(NSSize(width: 420, height: 240))
    let text = scroll.documentView as! NSTextView
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    // No ensureLayout/sizeToFit prewarming: jump to text that has never been
    // visible, then resize. Native on-demand layout must make the tail readable.
    text.string = String(repeating: "中文 👩🏽‍💻 é paragraph for distant scrolling.\n", count: 16000)
    let end = (text.string as NSString).length - 2
    text.setSelectedRange(NSRange(location: end, length: 1))
    text.scrollRangeToVisible(NSRange(location: end, length: 1))
    settle()
    let visible = text.layoutManager!.glyphRange(forBoundingRect: text.visibleRect, in: text.textContainer!)
    let characters = text.layoutManager!.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
    precondition(NSLocationInRange(end, characters), "First jump must lay out the unseen document tail")
    scroll.setFrameSize(NSSize(width: 760, height: 260))
    settle()
    precondition(text.selectedRange() == NSRange(location: end, length: 1), "Tail selection must survive reflow")
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
    let before = topLine(text, scroll).location
    scroll.setFrameSize(NSSize(width: 850, height: 180))
    settle()
    precondition(NSLocationInRange(before, topLine(text, scroll)),
                 "Large middle anchor must retain its line after width reflow")
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

  private static func settle() {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
  }
}

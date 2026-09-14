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
    if #available(macOS 12.0, *) { checkModernEditor() }
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
    settle()
    let visible = text.layoutManager!.glyphRange(forBoundingRect: text.visibleRect, in: text.textContainer!)
    let characters = text.layoutManager!.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
    precondition(NSLocationInRange(end, characters), "First jump must lay out the unseen document tail")
    scroll.setFrameSize(NSSize(width: 760, height: 260))
    settle()
    precondition(text.selectedRange() == NSRange(location: end, length: 1), "Tail selection must survive reflow")
  }


  @available(macOS 12.0, *)
  @MainActor private static func checkModernEditor() {
    let scroll = NSTextView.scrollableTextView()
    let text = scroll.documentView as! NSTextView
    guard let manager = text.textLayoutManager else { return }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = scroll
    window.orderFront(nil)
    defer { window.close() }
    let keeper = WorkspaceScrollKeeper()
    keeper.attach(text)
    text.string = (0..<1000).map { "Paragraph \($0): " + String(repeating: "中文 é 👩🏽‍💻 reflow ", count: 30) + "\n" }.joined()
    settle()
    let target = (text.string as NSString).range(of: "Paragraph 500:").location
    text.setSelectedRange(NSRange(location: target, length: 8))
    text.scrollRangeToVisible(NSRange(location: target, length: 8))
    settle()
    let selected = text.selectedRange()
    let top = text.characterIndexForInsertion(at: text.convert(scroll.contentView.bounds.origin, from: scroll.contentView))
    window.setContentSize(NSSize(width: 760, height: 260))
    settle()
    precondition(text.textLayoutManager === manager, "Keeper must not force TextKit 1 fallback")
    precondition(text.selectedRange() == selected, "Modern reflow must preserve selection")
    let currentTop = text.characterIndexForInsertion(at: text.convert(scroll.contentView.bounds.origin, from: scroll.contentView))
    precondition(abs(currentTop - top) < 100, "Modern reflow must preserve the top reading line")
    let tail = (text.string as NSString).length - 2
    text.setSelectedRange(NSRange(location: tail, length: 0))
    text.scrollRangeToVisible(NSRange(location: tail, length: 1))
    settle()
    window.setContentSize(NSSize(width: 380, height: 260))
    settle()
    precondition(text.textLayoutManager === manager)
    precondition(text.selectedRange().location == tail)
    text.setMarkedText("pinyin", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    let marked = text.markedRange()
    window.setContentSize(NSSize(width: 600, height: 260))
    settle()
    precondition(text.markedRange() == marked)
    precondition(text.textLayoutManager === manager)
    text.unmarkText()
    text.string = "New document\n"
    scroll.contentView.scroll(to: .zero)
    settle()
    precondition(scroll.contentView.bounds.minY == 0)
    print("PASS: TextKit 2 retained through attach, middle/tail resize, selection, composition and replacement")
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

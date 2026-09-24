// Standalone AppKit diagnostic, deliberately absent from the shipping target.
// Build with swiftc -O -target arm64-apple-macos12.0 -framework AppKit.
import AppKit
import Foundation
import Darwin

@MainActor
enum NativeTextKitMemory {
  static func main() throws {
    let arguments = CommandLine.arguments
    func value(after flag: String) -> String {
      guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        fatalError("Missing \(flag)")
      }
      return arguments[index + 1]
    }
    let mode = value(after: "--mode")
    precondition(mode == "tk1" || mode == "tk2")
    let widthSwitch = arguments.contains("--width-switch")
    let noRescroll = arguments.contains("--no-rescroll")
    let recovery = arguments.contains("--recovery")
    let contentWidth: Double
    if arguments.contains("--content-width") {
      guard let value = Double(value(after: "--content-width")), (300...1200).contains(value) else {
        fatalError("Invalid --content-width")
      }
      contentWidth = value
    } else {
      contentWidth = 1200
    }
    precondition(!noRescroll || widthSwitch)
    let narrowWidth: Double
    if arguments.contains("--narrow-width") {
      guard let value = Double(value(after: "--narrow-width")), (300..<1200).contains(value) else {
        fatalError("Invalid --narrow-width")
      }
      narrowWidth = value
    } else {
      narrowWidth = 800
    }
    let input = URL(fileURLWithPath: value(after: "--input"))
    let output = URL(fileURLWithPath: value(after: "--output"))
    let source = try String(contentsOf: input, encoding: .utf8)
    let sourceBytes = try input.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
    let sourceLength = (source as NSString).length
    let start = DispatchTime.now().uptimeNanoseconds
    var rows: [[String: Any]] = []
    var switchCount = 0

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let editor = NSTextView(usingTextLayoutManager: mode == "tk2")
    let observer = NotificationCenter.default.addObserver(
      forName: NSTextView.willSwitchToNSLayoutManagerNotification, object: editor, queue: .main
    ) { _ in switchCount += 1 }
    defer { NotificationCenter.default.removeObserver(observer) }
    editor.isRichText = false
    editor.isVerticallyResizable = true
    editor.isHorizontallyResizable = false
    editor.autoresizingMask = [.width]
    editor.minSize = .zero
    editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    editor.textContainerInset = NSSize(width: 0, height: 1)
    editor.textContainer?.widthTracksTextView = true
    editor.textContainer?.lineFragmentPadding = 0
    if mode == "tk1" {
      editor.layoutManager?.allowsNonContiguousLayout = true
      editor.layoutManager?.backgroundLayoutEnabled = false
    }
    editor.font = NSFont.userFont(ofSize: 0)

    let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 800))
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.documentView = editor
    let window = NSWindow(contentRect: scroll.bounds, styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
    window.contentView = scroll
    window.setContentSize(NSSize(width: contentWidth, height: 800))
    window.makeKeyAndOrderFront(nil)

    func perform() throws {
      // Activation is requested after the standard AppKit event loop starts.
      // Calling activate before run() can leave every sample in the background.
      app.activate(ignoringOtherApps: true)
      for _ in 0..<500 where !app.isActive {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      }

    func flush() {
      for _ in 0..<2 {
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      }
    }
    func sample(_ name: String, actionMS: Double? = nil, targetVisible: Bool? = nil,
                scrollAttempts: Int? = nil, targetRect: NSRect? = nil,
                viewportRect: NSRect? = nil) throws {
      var info = task_vm_info_data_t()
      var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
      let status = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
          task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
      }
      guard status == KERN_SUCCESS else { throw NSError(domain: "NativeTextKitMemory", code: 1) }
      var row: [String: Any] = [
        "name": name,
        "elapsed_ms": Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000,
        "rss_bytes": info.resident_size,
        "physical_footprint_bytes": info.phys_footprint,
        "textkit2": editor.textLayoutManager != nil,
        "fallback_events": switchCount,
        "app_active": NSApp.isActive,
        "visible": window.isVisible,
        "window_content_points": [window.contentView?.bounds.width ?? 0, window.contentView?.bounds.height ?? 0],
        "editor_viewport_width": scroll.contentView.bounds.width,
        "viewport_y": scroll.contentView.bounds.minY,
        "editor_utf16": (editor.string as NSString).length,
        "storage_utf16": editor.textStorage?.length ?? -1
      ]
      if let actionMS { row["action_ms"] = actionMS }
      if let targetVisible { row["target_visible"] = targetVisible }
      if let scrollAttempts { row["scroll_attempts"] = scrollAttempts }
      if let targetRect { row["target_screen_rect"] = [targetRect.minX, targetRect.minY, targetRect.width, targetRect.height] }
      if let viewportRect { row["viewport_screen_rect"] = [viewportRect.minX, viewportRect.minY, viewportRect.width, viewportRect.height] }
      rows.append(row)
      let report: [String: Any] = [
        "status": "running", "pid": getpid(), "mode": mode,
        "source_utf8_bytes": sourceBytes,
        "source_utf16": sourceLength, "window_content_points": [contentWidth, 800], "rows": rows
      ]
      try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        .write(to: output, options: .atomic)
    }

    flush()
    try sample("empty_ready")
    let assignStart = DispatchTime.now().uptimeNanoseconds
    editor.string = source
    flush()
    try sample("first_display", actionMS: Double(DispatchTime.now().uptimeNanoseconds - assignStart) / 1_000_000)
    var allTargetsVisible = true
    let nsSource = source as NSString
    for (name, proposed) in [("start", 0), ("middle", sourceLength / 2), ("end", max(0, sourceLength - 2))] {
      let begin = DispatchTime.now().uptimeNanoseconds
      // The repeated fixture's midpoint can land inside a family Emoji. Use
      // the next paragraph start so firstRect checks an ordinary text glyph.
      let precedingBreak = name == "middle"
        ? nsSource.range(of: "\r\n\r\n", options: .backwards, range: NSRange(location: 0, length: proposed))
        : NSRange(location: NSNotFound, length: 0)
      let nextPlain = name == "middle"
        ? nsSource.range(of: "汉", range: NSRange(location: proposed, length: min(128, sourceLength - proposed)))
        : NSRange(location: NSNotFound, length: 0)
      let location: Int
      if precedingBreak.location != NSNotFound && precedingBreak.location + precedingBreak.length < sourceLength {
        location = precedingBreak.location + precedingBreak.length
      } else if nextPlain.location != NSNotFound {
        location = nextPlain.location
      } else {
        location = nsSource.rangeOfComposedCharacterSequence(at: proposed).location
      }
      let range = NSRange(location: location, length: 0)
      editor.setSelectedRange(range)
      var targetVisible = false
      var attempts = 0
      var targetRect = NSRect.zero
      var viewportRect = NSRect.zero
      for attempt in 1...8 {
        attempts = attempt
        editor.scrollRangeToVisible(range)
        flush()
        // firstRect requests actual geometry; an offset alone may be an
        // estimated offscreen position during noncontiguous layout.
        targetRect = editor.firstRect(forCharacterRange: NSRange(location: location, length: 1), actualRange: nil)
        viewportRect = window.convertToScreen(scroll.convert(scroll.bounds, to: nil))
        targetVisible = !targetRect.isEmpty && targetRect.intersects(viewportRect)
        if targetVisible { break }
      }
      allTargetsVisible = allTargetsVisible && targetVisible
      try sample("scroll_\(name)", actionMS: Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000,
                 targetVisible: targetVisible, scrollAttempts: attempts,
                 targetRect: targetRect, viewportRect: viewportRect)
    }
    if widthSwitch {
      let lastLocation = nsSource.rangeOfComposedCharacterSequence(at: max(0, sourceLength - 2)).location
      let lastRange = NSRange(location: lastLocation, length: 0)
      for (name, width) in [("width_narrow", narrowWidth), ("width_wide", 1200.0)] {
        let begin = DispatchTime.now().uptimeNanoseconds
        window.setContentSize(NSSize(width: width, height: 800))
        if !noRescroll { editor.scrollRangeToVisible(lastRange) }
        flush()
        let targetRect = editor.firstRect(forCharacterRange: NSRange(location: lastLocation, length: 1), actualRange: nil)
        let viewportRect = window.convertToScreen(scroll.convert(scroll.bounds, to: nil))
        let visible = !targetRect.isEmpty && targetRect.intersects(viewportRect)
        if !noRescroll { allTargetsVisible = allTargetsVisible && visible }
        try sample(name, actionMS: Double(DispatchTime.now().uptimeNanoseconds - begin) / 1_000_000,
                   targetVisible: visible, scrollAttempts: noRescroll ? 0 : 1, targetRect: targetRect,
                   viewportRect: viewportRect)
      }
    }
    if recovery {
      try sample("recovery_before_clear")
      editor.string = ""
      editor.undoManager?.removeAllActions()
      flush()
      try sample("recovery_clear_ack")
      func wait(_ seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
          RunLoop.main.run(until: min(end, Date().addingTimeInterval(0.05)))
        }
        flush()
      }
      wait(5)
      try sample("recovery_after_5s")
      wait(25)
      try sample("recovery_after_30s")
    }
    let final: [String: Any] = [
      "status": allTargetsVisible ? "complete" : "target_not_visible", "pid": getpid(), "mode": mode,
      "source_utf8_bytes": sourceBytes,
      "source_utf16": sourceLength, "window_content_points": [contentWidth, 800], "rows": rows
    ]
    try JSONSerialization.data(withJSONObject: final, options: [.prettyPrinted, .sortedKeys])
      .write(to: output, options: .atomic)
    window.close()
    }
    DispatchQueue.main.async {
      do { try perform() }
      catch {
        fputs("Native TextKit diagnostic failed: \(error)\n", stderr)
        exit(1)
      }
      app.terminate(nil)
    }
    app.run()
  }
}

try MainActor.assumeIsolated { try NativeTextKitMemory.main() }

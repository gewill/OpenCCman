#if os(macOS)
import AppKit
import SwiftUI

@main
struct MainWindowNativeChecks {
  @MainActor
  static func main() {
    _ = NSApplication.shared
    let name = "OpenCCman.WindowSizing.Test." + UUID().uuidString
    defer { NSWindow.removeFrame(usingName: name) }
    let window = NSWindow(contentRect: NSRect(x: 80, y: 100, width: 800, height: 600),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let restoring = CommandLine.arguments.contains("restore")
    if restoring {
      window.setFrameAutosaveName(name)
      window.saveFrame(usingName: name)
    }
    MainWindowSizing.captureInitialFrames()
    // Simulate a temporary frame written during SwiftUI window creation.
    window.setFrameAutosaveName(name)
    window.setContentSize(NSSize(width: 900, height: 450))
    window.saveFrame(usingName: name)
    let sizing = MainWindowSizing()
    sizing.attach(to: window)
    let expected = restoring ? NSSize(width: 800, height: 600) : MainWindowGeometry.recommendedContentSize
    let deadline = Date().addingTimeInterval(2)
    while window.contentRect(forFrameRect: window.frame).size != expected && Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    precondition(window.contentRect(forFrameRect: window.frame).size == expected,
                 "Initial history snapshot must distinguish restored and provisional frames")
    precondition(window.contentMinSize == MainWindowGeometry.minimumContentSize)
    window.setContentSize(NSSize(width: 760, height: 500))
    sizing.attach(to: window)
    RunLoop.main.run(until: Date().addingTimeInterval(0.03))
    precondition(window.contentRect(forFrameRect: window.frame).size == NSSize(width: 760, height: 500),
                 "Repeated attachment must not reset a resized window")
    var reports = 0
    let reader = MainWindowReader.ReaderView()
    reader.onAttach = { observed in precondition(observed === window); reports += 1 }
    window.contentView?.addSubview(reader)
    RunLoop.main.run(until: Date().addingTimeInterval(0.03))
    reader.reportWindow()
    precondition(reports == 1, "Native window attachment must report once without an OS allowlist")
    window.close()
    print("PASS: native \(restoring ? "restoration" : "first launch"), provisional autosave, minimum size, idempotent attachment and window reader")
  }
}
#endif

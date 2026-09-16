import AppKit
import SwiftUI

// A separate, dependency-free SwiftUI lifecycle experiment, not an application
// acceptance test. It manipulates only its own diagnostic windows.
@MainActor final class Probe: NSObject, NSApplicationDelegate {
  static var current: Probe!
  var hasStarted = false
  var events: [[String: Any]] = []
  var initialPID = ProcessInfo.processInfo.processIdentifier
  let mode = UserDefaults.standard.string(forKey: "mode") ?? "baseline"
  let output = UserDefaults.standard.string(forKey: "report")!

  override init() { super.init(); Self.current = self }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    record("reopen-event")
    if !flag { _ = activateExistingWindow() }
    return true
  }

  // Mirrors the existing production activation path for comparison only.
  func activateExistingWindow() -> NSWindow? {
    let keyWindow = NSApp.keyWindow.flatMap { $0.canBecomeMain ? $0 : nil }
    let window = keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.canBecomeMain })
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    return window
  }

  func attach(_ window: NSWindow) {
    guard !hasStarted else { record("new-window-attached"); return }
    hasStarted = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.record("before-close")
      window.close()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.record("closed")
        _ = self.activateExistingWindow()
        if self.mode == "workspace" {
          let config = NSWorkspace.OpenConfiguration()
          config.createsNewApplicationInstance = false
          NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { app, error in
            let returnedPID = app?.processIdentifier
            let errorText = error?.localizedDescription
            DispatchQueue.main.async {
              self.events.append(["event": "workspace-completion", "pid": returnedPID ?? -1, "error": errorText ?? ""])
            }
          }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.finish() }
      }
    }
  }

  func record(_ name: String) {
    events.append(["event": name, "pid": ProcessInfo.processInfo.processIdentifier,
                   "visibleMainWindows": NSApp.windows.filter { $0.canBecomeMain && $0.isVisible }.count])
  }

  func finish() {
    record("final")
    let data = try! JSONSerialization.data(withJSONObject: ["mode": mode, "events": events], options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: URL(fileURLWithPath: output))
    NSApp.terminate(nil)
  }
}

struct Reader: NSViewRepresentable {
  final class View: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let window { DispatchQueue.main.async { Probe.current.attach(window) } }
    }
  }
  func makeNSView(context: Context) -> View { View() }
  func updateNSView(_ view: View, context: Context) {}
}

@main struct WindowReopenProbe: App {
  @NSApplicationDelegateAdaptor(Probe.self) var delegate
  var body: some Scene {
    WindowGroup { Text("OpenCCman window lifecycle diagnostic").padding(40).background(Reader()) }
  }
}

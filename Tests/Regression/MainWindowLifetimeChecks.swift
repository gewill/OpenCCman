#if os(macOS)
import AppKit
import SwiftUI

private final class LifetimeModel: ObservableObject {
  static var nextID = 0
  static var live: Set<Int> = []
  let id: Int
  init() {
    Self.nextID += 1
    id = Self.nextID
    Self.live.insert(id)
  }
  deinit { Self.live.remove(id) }
}

private struct LifetimeContent: View {
  @StateObject private var model = LifetimeModel()
  var body: some View { Text("Synthetic window \(model.id)").background(MainWindowReader { _ in _ = model.id }) }
}

@main
struct MainWindowLifetimeChecks {
  @MainActor static func settle() {
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
  }

  @MainActor static func makeWindow() -> NSWindow {
    let window = NSWindow(contentRect: NSRect(x: 80, y: 100, width: 300, height: 200),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: WindowContentLifetime { LifetimeContent() })
    window.orderFront(nil)
    window.contentView?.layoutSubtreeIfNeeded()
    settle()
    return window
  }

  @MainActor static func main() {
    _ = NSApplication.shared
    let first = makeWindow()
    let second = makeWindow()
    precondition(LifetimeModel.live == [1, 2])
    // Deliberately keep both hosting views alive after closing their windows.
    // The boundary must release only the window-owned business subtree.
    let hosts = [first.contentView!, second.contentView!]
    func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
    let retainedReaders = hosts.flatMap(descendants).filter { $0 is MainWindowReader.ReaderView }
    defer { withExtendedLifetime(retainedReaders) {} }
    first.orderOut(nil)
    settle()
    precondition(LifetimeModel.live == [1, 2], "Hiding must preserve window state")
    first.orderFront(nil)
    let unrelated = NSWindow(contentRect: .zero, styleMask: .borderless,
      backing: .buffered, defer: false)
    NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: unrelated)
    settle()
    precondition(LifetimeModel.live == [1, 2], "Unrelated close must not clear either window")
    second.close()
    settle()
    precondition(LifetimeModel.live == [1], "Closed subtree must release despite a retained host")
    NotificationCenter.default.post(name: NSWindow.willCloseNotification, object: second)
    settle()
    precondition(LifetimeModel.live == [1], "Duplicate close must preserve the other window")
    let reopened = makeWindow()
    precondition(LifetimeModel.live == [1, 3], "New window must create fresh content")
    reopened.close()
    first.close()
    settle()
    withExtendedLifetime(hosts) {
      precondition(LifetimeModel.live.isEmpty, "All closed business models must release")
    }
    // SwiftUI may reuse a retained WindowGroup host when the last window is
    // closed and the app is reopened. Its business content must mount again.
    let original = makeWindow()
    let reusedHost = original.contentView!
    original.close()
    settle()
    precondition(LifetimeModel.live.isEmpty, "Closed reusable host must release its model")
    let replacement = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 300, height: 200),
      styleMask: [.titled, .closable], backing: .buffered, defer: false)
    replacement.isReleasedWhenClosed = false
    replacement.contentView = reusedHost
    replacement.orderFront(nil)
    replacement.contentView?.layoutSubtreeIfNeeded()
    settle()
    precondition(LifetimeModel.live.count == 1, "A host attached to a new window must remount content")
    replacement.close()
    settle()
    precondition(LifetimeModel.live.isEmpty, "Reused host must release its new model on close")
    print("PASS: retained hosts, unrelated/duplicate close, hidden window state, fresh and reused windows, final release")
  }
}
#endif

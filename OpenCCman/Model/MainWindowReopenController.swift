#if os(macOS)
import AppKit

struct PendingWindowNotification {
  let name: Notification.Name
  let userInfo: [AnyHashable: Any]?
  let windowID: ObjectIdentifier?

  static func take(for window: NSWindow, from pending: inout Self?) -> Self? {
    guard let request = pending, request.windowID == nil || request.windowID == ObjectIdentifier(window) else {
      return nil
    }
    pending = nil
    return request
  }

  static func discard(boundTo window: NSWindow, from pending: inout Self?) {
    if pending?.windowID == ObjectIdentifier(window) { pending = nil }
  }
}


/// Coalesces external entry requests until SwiftUI has actually bound a window.
/// A successful Launch Services callback means the process opened, not that its
/// WindowGroup is ready to consume a notification.
@MainActor
final class MainWindowReopenController {
  typealias Completion = @MainActor (Error?) -> Void
  private var pendingID: UUID?

  static func selectWindow(key: NSWindow?, main: NSWindow?, windows: [NSWindow],
                           isReady: (NSWindow) -> Bool) -> NSWindow? {
    [key, main].compactMap { $0 }.first(where: isReady)
      ?? windows.first(where: isReady)
      ?? windows.first { $0.canBecomeMain && !($0 is NSPanel) }
  }

  func request(open: (@escaping Completion) -> Void, onFailure: @escaping (Error) -> Void) {
    guard pendingID == nil else { return }
    let id = UUID()
    pendingID = id
    open { [weak self] error in
      guard let self, self.pendingID == id, let error else { return }
      self.pendingID = nil
      onFailure(error)
    }
  }

  func windowBecameReady() {
    pendingID = nil
  }
}
#endif

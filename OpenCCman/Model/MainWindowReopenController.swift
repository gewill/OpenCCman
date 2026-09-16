import Foundation

/// Coalesces external entry requests until SwiftUI has actually bound a window.
/// A successful Launch Services callback means the process opened, not that its
/// WindowGroup is ready to consume a notification.
@MainActor
final class MainWindowReopenController {
  typealias Completion = @MainActor (Error?) -> Void
  private var pendingID: UUID?

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

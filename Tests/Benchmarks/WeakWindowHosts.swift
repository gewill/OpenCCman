// Appended only with --observe-hosts. No AX queries, observers or view modifiers.
// This is an additional observation condition, not a transparent measurement.
@MainActor final class WeakWindowHosts {
  private final class Entry {
    let id: Int
    weak var window: NSWindow?
    weak var initialContent: NSView?
    let contentType: String

    init(id: Int, window: NSWindow) {
      self.id = id
      self.window = window
      initialContent = window.contentView
      contentType = window.contentView.map { String(reflecting: type(of: $0)) } ?? "nil"
    }
  }

  static let shared = WeakWindowHosts()
  private var entries: [Entry] = []

  func snapshot() -> [[String: Any]] {
    // Only weak references survive this call. Do not keep a window array or
    // content view in a timer closure. Retain dead entries to preserve identity.
    for window in NSApp.windows where window.isVisible && window.canBecomeMain {
      if !entries.contains(where: { $0.window === window }) {
        entries.append(Entry(id: entries.count + 1, window: window))
      }
    }
    return entries.map { entry in
      ["id": entry.id,
       "windowAlive": entry.window != nil,
       "windowVisible": entry.window?.isVisible ?? false,
       "initialContentAlive": entry.initialContent != nil,
       "initialContentType": entry.contentType]
    }
  }
}

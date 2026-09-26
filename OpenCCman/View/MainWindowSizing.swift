#if os(macOS)
import AppKit
import Combine
import SwiftUI

/// Reuses SwiftUI's native frame autosave name; never replaces its window delegate or scene identity.
final class MainWindowSizing: ObservableObject {
  private static var savedFrames: [String: String]?

  /// Snapshot before SwiftUI creates any windows: AppKit can autosave a provisional frame during launch.
  static func captureInitialFrames() {
    guard savedFrames == nil else { return }
    savedFrames = UserDefaults.standard.dictionaryRepresentation().reduce(into: [:]) { result, entry in
      if entry.key.hasPrefix("NSWindow Frame "), let value = entry.value as? String,
         MainWindowGeometry.hasSavedFrame(value) { result[entry.key] = value }
    }
  }

  private weak var window: NSWindow?
  private var observers: [NSObjectProtocol] = []

  deinit { observers.forEach(NotificationCenter.default.removeObserver) }

  func attach(to window: NSWindow) {
    guard self.window !== window else { return }
    observers.forEach(NotificationCenter.default.removeObserver)
    observers.removeAll()
    self.window = window
    window.contentMinSize = MainWindowGeometry.minimumContentSize
    // SwiftUI finishes installing its frame autosave name during window creation.
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window, self.window === window else { return }
      let name = window.frameAutosaveName
      let saved = name.isEmpty ? nil : Self.savedFrames?["NSWindow Frame " + name]
      if let saved, MainWindowGeometry.hasSavedFrame(saved) {
        window.setFrame(from: saved)
      } else {
        window.setContentSize(MainWindowGeometry.recommendedContentSize)
        // Keep SwiftUI's cascading placement for additional windows.
        if !NSApp.windows.contains(where: { $0 !== window && $0.canBecomeMain && $0.isVisible }) {
          window.center()
        }
      }
      self.constrainToScreen()
      self.observe(window)
    }
  }

  private func observe(_ window: NSWindow) {
    observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didEndSheetNotification,
      object: nil, queue: .main) { [weak self] notification in
      guard let self, let target = notification.object as? NSWindow, target === self.window else { return }
      // AppKit restores the parent's pre-sheet origin after dismissing a sheet. A first-launch
      // sheet may have captured the provisional frame before our recommended size was applied.
      DispatchQueue.main.async { [weak self, weak target] in
        guard let self, let target, self.window === target else { return }
        self.constrainToScreen()
      }
    })
    observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
      object: nil, queue: .main) { [weak self] notification in
      guard let self, let target = notification.object as? NSWindow, target === self.window,
            !target.frameAutosaveName.isEmpty else { return }
      Self.savedFrames?["NSWindow Frame " + target.frameAutosaveName] = target.frameDescriptor
    })
    for name in [NSWindow.didChangeScreenNotification, NSWindow.didEndLiveResizeNotification,
                 NSWindow.didExitFullScreenNotification] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] notification in
        guard let self, let target = notification.object as? NSWindow, target === self.window else { return }
        self.constrainToScreen()
      })
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.constrainToScreen() })
  }

  private func constrainToScreen() {
    guard let window, !window.styleMask.contains(.fullScreen), !window.inLiveResize,
          let screen = window.screen ?? NSScreen.main else { return }
    let frame = MainWindowGeometry.constrained(window.frame,
      visibleScreens: NSScreen.screens.map(\.visibleFrame), fallback: screen.visibleFrame)
    if frame != window.frame { window.setFrame(frame, display: true) }
    #if DEBUG
    if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-window-sizing-report"),
       ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
      let report: [String: Any] = ["frame": NSStringFromRect(window.frame),
        "contentRect": NSStringFromRect(window.contentRect(forFrameRect: window.frame)),
        "contentLayoutRect": NSStringFromRect(window.contentLayoutRect),
        "minSize": NSStringFromSize(window.minSize), "contentMinSize": NSStringFromSize(window.contentMinSize)]
      if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: URL(fileURLWithPath: ProcessInfo.processInfo.arguments[index + 1]), options: .atomic)
      }
    }
    #endif
  }
}
/// Obtains the actual hosting window without depending on a SwiftUI view hierarchy or OS allowlist.
struct MainWindowReader: NSViewRepresentable {
  var onAttach: (NSWindow) -> Void

  func makeNSView(context: Context) -> ReaderView {
    let view = ReaderView()
    view.onAttach = onAttach
    return view
  }

  func updateNSView(_ view: ReaderView, context: Context) {
    view.onAttach = onAttach
    view.reportWindow()
  }

  static func dismantleNSView(_ view: ReaderView, coordinator: ()) {
    // A retained native reader must not keep its removed SwiftUI owner alive.
    view.onAttach = nil
  }

  final class ReaderView: NSView {
    var onAttach: ((NSWindow) -> Void)?
    private weak var reportedWindow: NSWindow?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      reportWindow()
    }

    func reportWindow() {
      guard let window, reportedWindow !== window else { return }
      reportedWindow = window
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window else { return }
        self.onAttach?(window)
      }
    }
  }
}
/// Releases closed-window content even when an accessibility client retains its hosting view.
/// Keep this boundary outside the Router and its window-owned StateObjects.
struct WindowContentLifetime<Content: View>: View {
  @State private var closed = false
  @State private var windowID: ObjectIdentifier?
  @ViewBuilder var content: () -> Content

  var body: some View {
    Group {
      if !closed { content() }
    }
    .background(MainWindowReader { window in
      let attachedID = ObjectIdentifier(window)
      guard windowID != attachedID else { return }
      windowID = attachedID
      // WindowGroup may attach a retained host to a new NSWindow after the
      // previous one closed. The old content is gone; mount fresh content.
      closed = false
    }
      .allowsHitTesting(false).accessibilityHidden(true))
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
      guard !closed, let window = notification.object as? NSWindow,
            ObjectIdentifier(window) == windowID else { return }
      closed = true
      // Hidden hosting views may never perform another layout pass. Apply the pending
      // removal after the close notification; never retain the window or its host.
      DispatchQueue.main.async { [weak host = window.contentView] in
        host?.needsLayout = true
        host?.layoutSubtreeIfNeeded()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
      guard closed, let window = notification.object as? NSWindow,
            ObjectIdentifier(window) == windowID, window.isVisible else { return }
      // A WindowGroup may reopen the same NSWindow and hosting view, so the
      // reader's window-identity callback will not run a second time.
      closed = false
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification)) { notification in
      guard closed, let window = notification.object as? NSWindow,
            ObjectIdentifier(window) == windowID else { return }
      // AppKit can send its update before orderFront marks a reused window
      // visible. Check on the next main-loop turn, after the order completes.
      DispatchQueue.main.async { [weak window] in
        guard let window, closed, ObjectIdentifier(window) == windowID,
              window.isVisible else { return }
        closed = false
      }
    }
  }
}
#endif

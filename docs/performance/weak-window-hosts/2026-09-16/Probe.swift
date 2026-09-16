import AppKit
import SwiftUI

@MainActor final class ProbeModel: ObservableObject {
  @Published var text = "Synthetic lifetime fixture"
  init() { ProbeLog.shared.created(self) }
}
@MainActor final class ProbeLog {
  final class Weak { weak var value: ProbeModel?; init(_ value: ProbeModel) { self.value = value } }
  static let shared = ProbeLog()
  var models: [Weak] = []
  var timer: Timer?
  let started = ProcessInfo.processInfo.systemUptime
  let file: FileHandle
  init() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCCman-MinimalLifetime-\(ProcessInfo.processInfo.processIdentifier).jsonl")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    file = try! FileHandle(forWritingTo: url)
  }
  func created(_ model: ProbeModel) {
    models.append(Weak(model)); record("created")
  }
  func start() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      Task { @MainActor in ProbeLog.shared.record("sample") }
    }
  }
  func record(_ event: String) {
    var value: [String: Any] = ["event": event, "created": models.count,
      "alive": models.filter { $0.value != nil }.count,
      "visible": NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }.count,
      "elapsed": ProcessInfo.processInfo.systemUptime - started]
    value["hosts"] = WeakWindowHosts.shared.snapshot()
    file.write(try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]))
    file.write(Data([10]))
  }
}
struct ProbeRoot: View {
  @StateObject private var model = ProbeModel()
  var body: some View {
    ProbeChild().environmentObject(model).frame(width: 420, height: 180)
  }
}
struct ProbeChild: View {
  @EnvironmentObject var model: ProbeModel
  var body: some View { Text(model.text).padding() }
}
@main struct MinimalLifetimeApp: App {
  init() { ProbeLog.shared.start() }
  var body: some Scene { WindowGroup("Minimal Text Probe", id: "lifetime") { ProbeRoot().background(LifetimeDriverView()) } }
}

// Appended only to the isolated macOS 13+ automatic fixture, never an app target.
// Exercise a real WindowGroup through public openWindow / performClose APIs.
// No synthetic keyboard input or external application control is involved.
struct LifetimeDriverView: View {
  @Environment(\.openWindow) private var openWindow
  var body: some View {
    Color.clear.onAppear { LifetimeDriver.shared.start(openWindow) }
  }
}

@MainActor final class LifetimeDriver {
  static let shared = LifetimeDriver()
  private enum Phase { case idle, first, pair, one, zero }
  private var phase = Phase.idle
  private var opener: OpenWindowAction?
  private var timer: Timer?
  private var anchor: ObjectIdentifier?
  private var began = 0.0
  private var closedAt = 0.0
  private var pairAt = 0.0
  private var recordedFive = false

  func start(_ openWindow: OpenWindowAction) {
    guard phase == .idle else { return }
    phase = .first
    began = ProcessInfo.processInfo.systemUptime
    opener = openWindow
    ProbeLog.shared.record("driver_started")
    let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
      Task { @MainActor in LifetimeDriver.shared.tick() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func tick() {
    let now = ProcessInfo.processInfo.systemUptime
    guard now - began < 80 else { finish(failed: "timeout"); return }
    // Strong window references are local to this tick only. Keep no NSWindow,
    // root view, model or OpenWindowAction across the observation intervals.
    let windows = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }
    switch phase {
    case .idle: break
    case .first:
      // Leave an explicit startup interval so a local AX control can observe
      // only the first window before the second window is created.
      guard windows.count == 1, now - began >= 10 else { return }
      anchor = ObjectIdentifier(windows[0])
      phase = .pair
      opener?(id: "lifetime")
      opener = nil
    case .pair:
      guard windows.count == 2,
            let second = windows.first(where: { ObjectIdentifier($0) != anchor }) else { return }
      if pairAt == 0 {
        pairAt = now
        ProbeLog.shared.record("driver_pair_visible")
      }
      // Fixed in every run, whether or not the investigator queries its AX tree.
      guard now - pairAt >= 10 else { return }
      ProbeLog.shared.record("driver_before_second_close")
      phase = .one
      closedAt = 0
      second.performClose(nil)
    case .one:
      guard windows.count == 1, ObjectIdentifier(windows[0]) == anchor else { return }
      if closedAt == 0 {
        closedAt = now
        ProbeLog.shared.record("driver_second_closed")
      }
      if now - closedAt >= 5 && !recordedFive {
        recordedFive = true
        ProbeLog.shared.record("driver_second_plus_5")
      }
      if now - closedAt >= 20 {
        ProbeLog.shared.record("driver_second_plus_20")
        phase = .zero
        closedAt = 0
        recordedFive = false
        windows[0].performClose(nil)
      }
    case .zero:
      guard windows.isEmpty else { return }
      if closedAt == 0 {
        closedAt = now
        ProbeLog.shared.record("driver_final_closed")
      }
      if now - closedAt >= 5 && !recordedFive {
        recordedFive = true
        ProbeLog.shared.record("driver_final_plus_5")
      }
      if now - closedAt >= 20 {
        ProbeLog.shared.record("driver_final_plus_20")
        finish(failed: nil)
      }
    }
  }

  private func finish(failed reason: String?) {
    timer?.invalidate()
    timer = nil
    opener = nil
    ProbeLog.shared.record(reason.map { "driver_failed:\($0)" } ?? "driver_finished")
    NSApp.terminate(nil)
  }
}

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

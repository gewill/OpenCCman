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
    let value: [String: Any] = ["event": event, "created": models.count,
      "alive": models.filter { $0.value != nil }.count,
      "visible": NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }.count,
      "elapsed": ProcessInfo.processInfo.systemUptime - started]
    file.write(try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]))
    file.write(Data([10]))
  }
}
struct ProbeRoot: View {
  @StateObject private var model = ProbeModel()
  var body: some View {
    ProbeChild().environmentObject(model).frame(width: 420, height: 180)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
        _ = model.text.count
      }
  }
}
struct ProbeChild: View {
  @EnvironmentObject var model: ProbeModel
  var body: some View { TextEditor(text: $model.text).padding() }
}
@main struct MinimalLifetimeApp: App {
  init() { ProbeLog.shared.start() }
  var body: some Scene { WindowGroup("Minimal Lifetime Probe") { ProbeRoot() } }
}

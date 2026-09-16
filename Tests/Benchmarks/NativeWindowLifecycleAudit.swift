// Added only to a private diagnostic copy by prepare-window-lifecycle.py.
// Never included in the shipping Xcode target. Does not create/close any window.
import AppKit
import Foundation

@MainActor
final class NativeWindowLifecycleAudit {
  static let bundleID = "org.gewill.OpenCCman.NativeWindowLifecycleAudit"
  static let shared = NativeWindowLifecycleAudit()

  private final class WeakModel {
    let number: Int
    weak var model: HomeViewModel?
    init(_ model: HomeViewModel, number: Int) { self.model = model; self.number = number }
  }

  private var models: [ObjectIdentifier: WeakModel] = [:]
  private var nextNumber = 1
  private var timer: Timer?
  private var file: FileHandle?
  private let start = DispatchTime.now().uptimeNanoseconds

  static func prepare() {
    precondition(Bundle.main.bundleIdentifier == bundleID, "Refuse production preferences")
    let defaults = UserDefaults.standard
    defaults.removePersistentDomain(forName: bundleID)
    defaults.set(false, forKey: "isPro")
    defaults.set(Date().addingTimeInterval(86400).timeIntervalSince1970, forKey: "lastCheckProDate")
    defaults.set(Bundle.main.appVersion, forKey: "lastVersionPromptedForReview")
    // The private build skips purchase configuration and global shortcut/service
    // registration. Normal WindowGroup, Router, model and editor ownership remain.
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(bundleID, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let output = directory.appendingPathComponent("lifecycle-\(ProcessInfo.processInfo.processIdentifier)-\(UUID().uuidString).jsonl")
      guard FileManager.default.createFile(atPath: output.path, contents: nil) else {
        fatalError("Unable to create lifecycle report")
      }
      shared.file = try FileHandle(forWritingTo: output)
      shared.record("process_initialized")
      let timer = Timer(timeInterval: 1, repeats: true) { _ in
        Task { @MainActor in shared.record("sample") }
      }
      shared.timer = timer
      RunLoop.main.add(timer, forMode: .common)
      NSLog("Native window lifecycle report: %@", output.path)
    } catch { fatalError("Unable to open lifecycle report: \(error)") }
  }

  static func created(_ model: HomeViewModel) -> Int {
    let id = ObjectIdentifier(model)
    precondition(shared.models[id]?.model == nil, "A live model must be registered only once")
    let number = shared.nextNumber
    shared.nextNumber += 1
    shared.models[id] = WeakModel(model, number: number)
    shared.record("model_created", number: number)
    return number
  }

  nonisolated static func released(_ id: ObjectIdentifier, number: Int) {
    // Pass only identity; never capture the object being deinitialized.
    Task { @MainActor in
      // A new allocation may reuse the address before this task runs.
      if shared.models[id]?.number == number { shared.models.removeValue(forKey: id) }
      shared.record("model_deinitialized", number: number)
    }
  }

  private func record(_ event: String, number: Int? = nil) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    var usage = rusage()
    let usageResult = getrusage(RUSAGE_SELF, &usage)
    let live = models.values.filter { $0.model != nil }.map(\.number).sorted()
    let states: [[String: Any]] = models.values.compactMap { box in
      guard let model = box.model else { return nil }
      return ["number": box.number, "converting": model.isLoading, "importing": model.isImporting]
    }.sorted { ($0["number"] as! Int) < ($1["number"] as! Int) }
    let windows = NSApp?.windows.filter { $0.isVisible && $0.canBecomeMain } ?? []
    var row: [String: Any] = [
      "event": event, "pid": ProcessInfo.processInfo.processIdentifier,
      "elapsed_ms": Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000,
      "live_model_numbers": live, "model_states": states, "visible_main_capable_windows": windows.count,
      "created_total": nextNumber - 1, "task_info_status": result, "rusage_status": usageResult,
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
    ]
    if let number { row["model_number"] = number }
    if result == KERN_SUCCESS {
      row["rss_bytes"] = info.resident_size
      row["physical_footprint_bytes"] = info.phys_footprint
    }
    if usageResult == 0 { row["process_peak_rss_bytes"] = usage.ru_maxrss }
    do {
      var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
      data.append(0x0A)
      guard let file else { fatalError("Missing lifecycle report handle") }
      try file.write(contentsOf: data)
      try file.synchronize()
    } catch { fatalError("Unable to persist lifecycle sample: \(error)") }
  }
}

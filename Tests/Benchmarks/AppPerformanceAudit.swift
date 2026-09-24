// Injected ONLY into a temporary, isolated Release app by benchmark-app.py.
// This file is deliberately absent from the shipping Xcode target.
import AppKit
import Combine
import CryptoKit
import os.signpost

import SwiftUI
import SwiftUIRouter

@MainActor
final class AppPerformanceAudit {
  static let shared = AppPerformanceAudit()
  private let start = DispatchTime.now().uptimeNanoseconds
  private var started = false
  private var activity: NSObjectProtocol?
  private var rows: [[String: Any]] = []
  private var windows: [NSWindow] = []
  private var models: [WeakModel] = []
  private var timer: Timer?
  private var heartbeat = DispatchTime.now().uptimeNanoseconds
  private var maximumHeartbeatGap = 0.0
  private let output = ProcessInfo.processInfo.arguments.drop { $0 != "-performance-output" }.dropFirst().first!
  private let log = OSLog(subsystem: "org.gewill.OpenCCman.PerformanceAudit", category: .pointsOfInterest)

  private final class WeakModel {
    weak var value: HomeViewModel?
    init(_ value: HomeViewModel) { self.value = value }
  }

  static func prepare() {
    // Refuse to touch the production preferences even if the build recipe changes.
    precondition(Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.PerformanceAudit")
    let defaults = UserDefaults.standard
    defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    defaults.set(true, forKey: "isPro")
    defaults.set(Date().addingTimeInterval(86400).timeIntervalSince1970, forKey: "lastCheckProDate")
    defaults.set(Bundle.main.appVersion, forKey: "lastVersionPromptedForReview")
    shared.activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Finite application performance measurement")
    shared.record("process_initialized")
  }

  func register(_ model: HomeViewModel, window: NSWindow) {
    if !models.contains(where: { $0.value === model }) { models.append(WeakModel(model)) }
    guard !started else { return }
    started = true
    window.setContentSize(NSSize(width: 1200, height: 800))
    window.center()
    Task { await run(model, window: window) }
  }

  private func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
  private func ms(_ since: UInt64) -> Double { Double(now() - since) / 1_000_000 }
  private func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
  private func memory() -> [String: Any] {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    var usage = rusage()
    let usageStatus = getrusage(RUSAGE_SELF, &usage)
    return ["rss_bytes": status == KERN_SUCCESS ? info.resident_size : 0,
            "physical_footprint_bytes": status == KERN_SUCCESS ? info.phys_footprint : 0,
            "process_peak_rss_bytes": usageStatus == 0 ? usage.ru_maxrss : 0,
            "task_info_status": status, "rusage_status": usageStatus]
  }
  private func record(_ name: String, _ values: [String: Any] = [:]) {
    var row = values
    row["name"] = name
    row["app_active"] = NSApp?.isActive ?? false
    row["visible_window_count"] = NSApp?.windows.filter { $0.isVisible }.count ?? 0
    row["elapsed_ms"] = ms(start)
    row["memory"] = memory()
    var usage = rusage()
    if getrusage(RUSAGE_SELF, &usage) == 0 {
      row["process_cpu_ms"] = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000
        + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1000
    }
    row["maximum_main_timer_gap_ms"] = maximumHeartbeatGap
    rows.append(row)
    // Persist after each stage so a timeout/crash still leaves useful evidence.
    save(status: "running")
  }
  private func save(status: String, error: String? = nil) {
    var report: [String: Any] = ["schema": 1, "status": status, "pid": ProcessInfo.processInfo.processIdentifier,
                               "rows": rows, "window_content_points": [1200, 800]]
    if let error { report["error"] = error }
    do { try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output), options: .atomic) }
    catch { NSLog("Performance report write failed: %@", error.localizedDescription) }
  }
  private func yieldUI(_ window: NSWindow) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        continuation.resume()
      }
    }
  }
  private func editors(in view: NSView) -> [NSTextView] {
    if let text = view as? NSTextView { return text.isFieldEditor ? [] : [text] }
    return view.subviews.flatMap { editors(in: $0) }
  }
  // Lengths are computed before the measured interval. Never bridge/compare
  // entire strings in this polling loop; exact validation happens after stopping.
  private func awaitEditorLengths(_ lengths: (Int, Int), window: NSWindow) async throws {
    let deadline = now() + 30_000_000_000
    while now() < deadline {
      await yieldUI(window)
      if let content = window.contentView {
        let views = editors(in: content)
        if views.count == 2,
           let source = views.first(where: { $0.isEditable }),
           let result = views.first(where: { !$0.isEditable }),
           source.textStorage?.length == lengths.0, result.textStorage?.length == lengths.1 {
          window.displayIfNeeded()
          return
        }
      }
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    throw NSError(domain: "PerformanceAudit", code: 5,
                  userInfo: [NSLocalizedDescriptionKey: "Native editor length acknowledgement timed out"])
  }
  private func validateEditors(_ model: HomeViewModel, window: NSWindow) throws {
    let views = window.contentView.map { editors(in: $0) } ?? []
    guard views.count == 2,
          let source = views.first(where: { $0.isEditable }),
          let result = views.first(where: { !$0.isEditable }),
          source.string.utf8.elementsEqual(model.inputText.utf8),
          result.string.utf8.elementsEqual(model.resultText.utf8) else {
      throw NSError(domain: "PerformanceAudit", code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Exact editor contents mismatch after stopping timer"])
    }
    if ProcessInfo.processInfo.arguments.contains("-performance-require-textkit2") &&
        (source.textLayoutManager == nil || result.textLayoutManager == nil) {
      throw NSError(domain: "PerformanceAudit", code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "TextKit 2 editor switched to compatibility mode"])
    }
  }
  private func awaitEditors(_ model: HomeViewModel, window: NSWindow) async throws {
    try await awaitEditorLengths((model.inputText.utf16.count, model.resultText.utf16.count), window: window)
    try validateEditors(model, window: window)
  }
  private func settle() async { try? await Task.sleep(nanoseconds: 250_000_000) }
  private func fixture(bytes: Int) -> String {
    let singleParagraph = ProcessInfo.processInfo.arguments.contains("-performance-single-paragraph")
    let unit = singleParagraph
      ? "汉语转换，软件与网络。繁體中文👨‍👩‍👧‍👦e\u{301}"
      : "汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u{301}\r\n\r\n"
    let count = bytes / unit.utf8.count
    let text = String(repeating: unit, count: count) + String(repeating: "a", count: bytes - count * unit.utf8.count)
    if singleParagraph {
      precondition(text.utf8.count == bytes && !text.contains("\r") && !text.contains("\n"))
    }
    return text
  }
  private func convert(_ model: HomeViewModel, window: NSWindow, name: String) async throws {
    let begin = now()
    os_signpost(.begin, log: log, name: "Model conversion")
    var observer: AnyCancellable?
    let finished: UInt64 = await withCheckedContinuation { continuation in
      observer = model.$isLoading.dropFirst().filter { !$0 }.prefix(1).sink { _ in
        continuation.resume(returning: DispatchTime.now().uptimeNanoseconds)
      }
      model.translate()
      if !model.isLoading { observer = nil; continuation.resume(returning: now()) }
    }
    observer = nil
    os_signpost(.end, log: log, name: "Model conversion")
    guard model.error == nil, !model.resultText.isEmpty, model.exportSnapshot?.text == model.resultText else {
      throw NSError(domain: "PerformanceAudit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Conversion failed or export mismatch: \(name)"])
    }
    let lengths = (model.inputText.utf16.count, model.resultText.utf16.count)
    let layoutStart = now()
    os_signpost(.begin, log: log, name: "Result layout flush")
    try await awaitEditorLengths(lengths, window: window)
    os_signpost(.end, log: log, name: "Result layout flush")
    let layoutMS = ms(layoutStart)
    try validateEditors(model, window: window)
    let resultHash = digest(model.resultText)
    record(name, ["model_completion_ms": Double(finished - begin) / 1_000_000,
                  "result_layout_flush_ms": layoutMS, "input_bytes": model.inputText.utf8.count,
                  "input_sha256": digest(model.inputText), "output_sha256": resultHash,
                  "output_bytes": model.resultText.utf8.count, "options": model.options.rawValue,
                  "export_matches_result": true, "editors_match_model": true])
    await settle()
  }

  private func createLoadedWindow(name: String) async throws -> NSWindow {
    let coordinator = WhatsNewCoordinator(version: Bundle.main.appVersion, skipAutomatic: true)
    let root = Router(initialPath: "/home") { RootView() }.environmentObject(coordinator)
      .environment(\.locale, Locale(identifier: "en"))
      .frame(width: 1200, height: 800)
    let extra = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
             styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
    extra.isReleasedWhenClosed = false
    extra.contentView = NSHostingView(rootView: root)
    extra.makeKeyAndOrderFront(nil)
    await yieldUI(extra); await settle()
    let registrationDeadline = now() + 5_000_000_000
    while !models.contains(where: { $0.value?.window === extra }), now() < registrationDeadline {
      await yieldUI(extra); await settle()
    }
    guard let extraModel = models.compactMap({ $0.value }).first(where: { $0.window === extra }) else {
      throw NSError(domain: "PerformanceAudit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Additional window did not register its own model"])
    }
    extraModel.applyPreset(.taiwan)
    extraModel.replaceSource(fixture(bytes: 1024 * 1024))
    try await awaitEditors(extraModel, window: extra)
    try await convert(extraModel, window: extra, name: name)
    return extra
  }


  private func runReflow(_ model: HomeViewModel, window: NSWindow) async throws {
    model.applyPreset(.taiwan)
    let arguments = ProcessInfo.processInfo.arguments
    let maxMiB = arguments.firstIndex(of: "-performance-reflow-max-mib")
      .flatMap { index in arguments.indices.contains(index + 1) ? Int(arguments[index + 1]) : nil } ?? 10
    precondition([1, 5, 10].contains(maxMiB))
    for mib in [1, 5, 10] where mib <= maxMiB {
      model.replaceSource(fixture(bytes: mib * 1024 * 1024))
      try await awaitEditors(model, window: window)
      try await convert(model, window: window, name: "reflow_convert_\(mib)MiB")
      guard let root = window.contentView,
            let source = editors(in: root).first(where: { $0.isEditable }) else { throw NSError(domain: "ReflowAudit", code: 1) }
      let identity = ObjectIdentifier(source)
      let inputHash = digest(model.inputText), resultHash = digest(model.resultText)
      let count = (source.string as NSString).length
      for position in [0, count / 2, max(0, count - 2)] {
        let text = source.string as NSString
        let composedMidpoint = position == count / 2 &&
          ProcessInfo.processInfo.arguments.contains("-performance-middle-composed")
        // The repeated fixture's midpoint can land inside a family emoji.
        // Check an ordinary glyph nearby so firstRect measures text navigation,
        // rather than the geometry of one UTF-16 unit of a composed character.
        let nextPlain = position == count / 2 && !composedMidpoint
          ? text.range(of: "汉", range: NSRange(location: position, length: min(128, count - position)))
          : NSRange(location: NSNotFound, length: 0)
        let range = nextPlain.location != NSNotFound ? nextPlain : text.rangeOfComposedCharacterSequence(at: position)
        let geometryRange = composedMidpoint ? range : NSRange(location: range.location, length: 1)
        let scrollStart = now()
        record("scroll_begin_\(mib)_\(position)")
        source.setSelectedRange(NSRange(location: range.location, length: 0))
        source.scrollRangeToVisible(range)
        await yieldUI(window); await yieldUI(window)
        var scrollAttempts = 1
        if let scroll = source.enclosingScrollView {
          let target = source.firstRect(forCharacterRange: geometryRange, actualRange: nil)
          let viewport = window.convertToScreen(scroll.convert(scroll.bounds, to: nil))
          if target.isEmpty || !target.intersects(viewport) {
            source.scrollRangeToVisible(range)
            await yieldUI(window); await yieldUI(window)
            scrollAttempts = 2
          }
        }
        var scrollDetails: [String: Any] = ["action_ms": ms(scrollStart), "scroll_attempts": scrollAttempts,
                                            "target_character": range.location,
                                            "target_kind": nextPlain.location == NSNotFound ? "composed" : "next_plain_han",
                                            "target_range_length": range.length,
                                            "geometry_range_length": geometryRange.length]
        if let scroll = source.enclosingScrollView {
          let target = source.firstRect(forCharacterRange: geometryRange, actualRange: nil)
          let viewport = window.convertToScreen(scroll.convert(scroll.bounds, to: nil))
          scrollDetails["selection_visible"] = !target.isEmpty && target.intersects(viewport)
          scrollDetails["selection_relative_y"] = target.minY - viewport.minY
          scrollDetails["source_viewport_y"] = scroll.contentView.bounds.minY
        }
        record("scroll_end_\(mib)_\(position)", scrollDetails)
        for axis in ["vertical", "horizontal"] {
          if mib == 10, position == max(0, count - 2), axis == "vertical",
             ProcessInfo.processInfo.arguments.contains("-performance-reflow-profile-pause") {
            record("profile_before_final_layout")
            try await Task.sleep(nanoseconds: 30_000_000_000)
          }
          record("layout_begin_\(mib)_\(position)_\(axis)")
          let actionStart = now()
          NotificationCenter.default.post(name: .workspaceCommand, object: window, userInfo: ["command": axis])
          await yieldUI(window); await yieldUI(window)
          let actionMS = ms(actionStart)
          let current = editors(in: root).first(where: { $0.isEditable })
          guard current.map(ObjectIdentifier.init) == identity,
                source.selectedRange().location == range.location,
                digest(model.inputText) == inputHash, digest(model.resultText) == resultHash else {
            throw NSError(domain: "ReflowAudit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Editor, selection or text changed during layout"])
          }
          var details: [String: Any] = ["action_ms": actionMS, "selection": range.location,
            "input_sha256": inputHash, "output_sha256": resultHash,
            "source_viewport_y": source.enclosingScrollView?.contentView.bounds.minY ?? -1]
          if let scroll = source.enclosingScrollView {
            let target = source.firstRect(forCharacterRange: geometryRange, actualRange: nil)
            let viewport = window.convertToScreen(scroll.convert(scroll.bounds, to: nil))
            details["selection_visible"] = !target.isEmpty && target.intersects(viewport)
            details["selection_relative_y"] = target.minY - viewport.minY
            details["source_viewport_width"] = scroll.contentView.bounds.width
          }
          if #available(macOS 12.0, *) {
            details["textkit2"] = source.textLayoutManager != nil
            details["result_textkit2"] = editors(in: root).first(where: { !$0.isEditable })?.textLayoutManager != nil
          }
          record("layout_end_\(mib)_\(position)_\(axis)", details)
        }
      }
    }
  }

  private func run(_ model: HomeViewModel, window: NSWindow) async {
    await yieldUI(window)
    var processInfo = proc_bsdinfo()
    let size = Int32(MemoryLayout.size(ofValue: processInfo))
    let readSize = proc_pidinfo(getpid(), PROC_PIDTBSDINFO, 0, &processInfo, size)
    var ready: [String: Any] = ["app_init_to_root_layout_ms": ms(start), "proc_pidinfo_ok": readSize == size]
    if readSize == size {
      let processStart = Double(processInfo.pbi_start_tvsec) + Double(processInfo.pbi_start_tvusec) / 1_000_000
      ready["process_start_to_root_layout_ms"] = (Date().timeIntervalSince1970 - processStart) * 1000
    }
    record("root_layout_ready", ready)
    heartbeat = now()
    timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        let current = self.now()
        self.maximumHeartbeatGap = max(self.maximumHeartbeatGap, Double(current - self.heartbeat) / 1_000_000)
        self.heartbeat = current
      }
    }
    do {
      if ProcessInfo.processInfo.arguments.contains("-performance-reflow") {
        try await runReflow(model, window: window)
        timer?.invalidate(); timer = nil
        if ProcessInfo.processInfo.arguments.contains("-performance-reflow-profile-hold") {
          record("profiling_hold")
          save(status: "profiling_hold")
          return
        }
        save(status: "complete")
        NSApp.terminate(nil)
        return
      }
      if ProcessInfo.processInfo.arguments.contains("-performance-interactive") {
        model.applyPreset(.taiwan)
        model.replaceSource(fixture(bytes: 1024 * 1024))
        try await awaitEditors(model, window: window)
        try await convert(model, window: window, name: "interactive_conversion")
        timer?.invalidate(); timer = nil
        save(status: "interactive_ready")
        return
      }
      model.applyPreset(.taiwan)
      model.replaceSource(fixture(bytes: 256 * 1024))
      try await awaitEditors(model, window: window)
      record("source_ready")
      try await convert(model, window: window, name: "first_conversion")
      let expectedHotHash = digest(model.resultText)
      for index in 1...5 {
        try await convert(model, window: window, name: "hot_\(index)")
        guard digest(model.resultText) == expectedHotHash else { throw NSError(domain: "PerformanceAudit", code: 2) }
      }
      // The historical 1.2.0 wrapper truncates at U+0000. Keep the default
      // correctness check intact, and use a common input only for its
      // separately labeled performance comparison with 1.4.2.
      let comparisonWithoutNUL = ProcessInfo.processInfo.arguments.contains("-performance-comparison-no-nul")
      model.replaceSource("软件网络鼠标里面伪说\r\n\r\n👨‍👩‍👧‍👦 e\u{301}" + (comparisonWithoutNUL ? "结束" : "\0结束"))
      for target in ConversionConfiguration.Language.allCases {
        for variant in ConversionConfiguration.Variant.allCases {
          for region in ConversionConfiguration.Region.allCases {
            if target == .simplified && (variant != .openCC || region != .notConvert) { continue }
            model.targetOptions = target; model.variantOptions = variant; model.regionOptions = region
            await yieldUI(window)
            try await convert(model, window: window, name: "configuration_\(model.options.rawValue)")
            // Independent fixed answers distinguish every effective converter.
            let prefixes = [2: "软件网络鼠标里面伪说", 1: "軟件網絡鼠標裏面僞說",
                            33: "軟件網絡鼠標裡面偽說", 65: "軟件網絡鼠標裏面偽説",
                            1025: "軟體網路滑鼠裏面僞說", 1057: "軟體網路滑鼠裡面偽說",
                            1089: "軟體網路滑鼠裏面偽説"]
            let expected = prefixes[model.options.rawValue]! + "\r\n\r\n👨‍👩‍👧‍👦 e\u{301}"
              + (comparisonWithoutNUL ? "" : "\0") + (target == .simplified ? "结束" : "結束")
            guard model.resultText == expected else { throw NSError(domain: "PerformanceAudit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Known-answer fixture mismatch"] ) }
          }
        }
      }
      record("seven_configurations_resident")
      if ProcessInfo.processInfo.arguments.contains("-performance-hold-after-configurations") {
        timer?.invalidate(); timer = nil
        save(status: "profiling_hold")
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        return
      }
      model.applyPreset(.taiwan)
      for mib in [1, 5, 10] {
        let url = URL(fileURLWithPath: output).deletingLastPathComponent().appendingPathComponent("fixture.txt")
        try fixture(bytes: mib * 1024 * 1024).write(to: url, atomically: true, encoding: .utf8)
        let readStart = now()
        let imported = try await TextFileService.read(url)
        let readMS = ms(readStart)
        let lengths = (imported.text.utf16.count, 0)
        let sourceStart = now()
        model.replaceSource(imported.text, sourceFilename: imported.sourceFilename)
        try await awaitEditorLengths(lengths, window: window)
        let sourceMS = ms(sourceStart)
        try validateEditors(model, window: window)
        record("source_\(mib)MiB", ["read_decode_ms": readMS, "source_layout_flush_ms": sourceMS, "editors_match_model": true])
        try await convert(model, window: window, name: "convert_\(mib)MiB")
        try FileManager.default.removeItem(at: url)
      }
      model.replaceSource("")
      try await awaitEditors(model, window: window); await settle()
      record("large_text_cleared")
      for cycle in 1...2 {
        let firstIndex = models.count
        for index in 1...2 {
          windows.append(try await createLoadedWindow(name: "window_cycle_\(cycle)_\(index)"))
        }
        record("three_windows_cycle_\(cycle)")
        record("windows_close_begin_cycle_\(cycle)")
        for extra in windows { extra.close(); extra.contentView = nil }
        record("windows_close_returned_cycle_\(cycle)")
        windows.removeAll()
        await settle(); await settle()
        record("windows_closed_cycle_\(cycle)", ["extra_models_alive": models.dropFirst(firstIndex).filter { $0.value != nil }.count, "all_extra_models_alive": models.dropFirst().filter { $0.value != nil }.count])
      }
      timer?.invalidate(); timer = nil
      save(status: "complete")
    } catch {
      timer?.invalidate(); timer = nil
      save(status: "failed", error: String(describing: error))
    }
    if let activity { ProcessInfo.processInfo.endActivity(activity) }
    activity = nil
    NSApp.terminate(nil)
  }
}

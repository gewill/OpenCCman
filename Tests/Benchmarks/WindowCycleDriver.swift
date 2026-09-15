// Appended only to the private diagnostic copy. No external application control.
import CryptoKit

struct LifetimeCycleDriverView: View {
  var body: some View { Color.clear.onAppear { WindowCycleDriver.shared.start() } }
}

@MainActor final class WindowCycleDriver {
  static let shared = WindowCycleDriver()
  private enum Phase { case idle, first, opening, hold, closing, observing, zero }
  private var phase = Phase.idle
  private var timer: Timer?
  private var began = 0.0
  private var since = 0.0
  private var anchor: ObjectIdentifier?
  private var baseline = ""
  private var cycle = 1
  private var opened = 0
  private var five = false

  func start() {
    guard phase == .idle else { return }
    phase = .first
    began = ProcessInfo.processInfo.systemUptime
    record("cycles_started")
    let timer = Timer(timeInterval: 0.1, repeats: true) { _ in
      Task { @MainActor in WindowCycleDriver.shared.tick() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func tick() {
    let now = ProcessInfo.processInfo.systemUptime
    guard now - began < 160 else { finish("timeout"); return }
    // Keep windows/models/menu items local to a single tick. The driver stores
    // only scalar identity, timestamps and a hash of the anchor's business state.
    let windows = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }
    switch phase {
    case .idle: break
    case .first:
      guard windows.count == 1, now - began >= 10 else { return }
      anchor = ObjectIdentifier(windows[0])
      guard let hash = NativeWindowLifecycleAudit.anchorHash(anchor!) else { return }
      baseline = hash
      record("cycles_anchor_ready")
      phase = .opening
    case .opening:
      guard windows.count == 1 + opened else { return }
      if opened < 2 {
        guard openNativeWindow() else { finish("new_window_menu_unavailable"); return }
        opened += 1
      } else {
        guard NativeWindowLifecycleAudit.clearNewSources(excluding: anchor!) else { return }
        record("cycle_\(cycle)_ready")
        since = now
        phase = .hold
      }
    case .hold:
      guard windows.count == 3, now - since >= 10 else { return }
      record("cycle_\(cycle)_before_close")
      phase = .closing
    case .closing:
      if let window = windows.first(where: { ObjectIdentifier($0) != anchor }) {
        window.performClose(nil)
      } else if windows.count == 1 {
        since = now
        five = false
        phase = .observing
        record("cycle_\(cycle)_closed")
      }
    case .observing:
      guard windows.count == 1, ObjectIdentifier(windows[0]) == anchor else { return }
      guard NativeWindowLifecycleAudit.anchorHash(anchor!) == baseline else {
        finish("anchor_business_state_changed"); return
      }
      if now - since >= 5 && !five { five = true; record("cycle_\(cycle)_plus_5") }
      if now - since >= 20 {
        record("cycle_\(cycle)_plus_20")
        if cycle < 3 {
          cycle += 1
          opened = 0
          phase = .opening
        } else {
          windows[0].performClose(nil)
          since = 0
          five = false
          phase = .zero
        }
      }
    case .zero:
      guard windows.isEmpty else { return }
      if since == 0 { since = now; record("cycles_final_closed") }
      if now - since >= 5 && !five { five = true; record("cycles_final_plus_5") }
      if now - since >= 20 { record("cycles_final_plus_20"); finish(nil) }
    }
  }

  private func openNativeWindow() -> Bool {
    guard let main = NSApp.mainMenu else { return false }
    var candidates: [(NSMenu, Int)] = []
    func visit(_ menu: NSMenu) {
      for (index, item) in menu.items.enumerated() {
        let modifiers = item.keyEquivalentModifierMask.intersection([.command, .shift, .option, .control])
        if item.keyEquivalent.lowercased() == "n", modifiers == .command,
           item.action != nil { candidates.append((menu, index)) }
        if let child = item.submenu { visit(child) }
      }
    }
    visit(main)
    guard candidates.count == 1 else { return false }
    // Validate only the matching menu; refreshing the Window menu could itself
    // populate window-list items and alter the lifetime being measured.
    let (menu, index) = candidates[0]
    let item = menu.items[index]
    menu.update()
    guard item.isEnabled, let currentIndex = menu.items.firstIndex(where: { $0 === item }) else { return false }
    menu.performActionForItem(at: currentIndex)
    return true
  }

  private func record(_ event: String) {
    NativeWindowLifecycleAudit.cycleRecord(event, cycle: cycle, anchor: anchor)
  }

  private func finish(_ failure: String?) {
    timer?.invalidate()
    timer = nil
    record(failure.map { "cycles_failed:\($0)" } ?? "cycles_finished")
    NSApp.terminate(nil)
  }
}

extension NativeWindowLifecycleAudit {
  static func anchorHash(_ window: ObjectIdentifier) -> String? {
    guard let model = shared.models.values.compactMap(\.model).first(where: {
      $0.window.map(ObjectIdentifier.init) == window
    }) else { return nil }
    let state: [String: Any] = [
      "source": model.inputText, "result": model.resultText,
      "converting": model.isLoading, "importing": model.isImporting,
      "quota": appDefaults[\.testNumbersPerDay],
      "target": String(describing: model.targetOptions),
      "variant": String(describing: model.variantOptions),
      "region": String(describing: model.regionOptions),
    ]
    let data = try! JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  static func clearNewSources(excluding anchor: ObjectIdentifier) -> Bool {
    let models = shared.models.values.compactMap(\.model).filter {
      guard let window = $0.window else { return false }
      return window.isVisible && ObjectIdentifier(window) != anchor
    }
    guard models.count == 2, models.allSatisfy({ !$0.isLoading && !$0.isImporting }) else { return false }
    for model in models { model.replaceSource("") }
    return true
  }

  static func cycleRecord(_ event: String, cycle: Int, anchor: ObjectIdentifier?) {
    let state: [[String: Any]] = shared.models.values.compactMap { box in
      guard let model = box.model else { return nil }
      return ["number": box.number, "source_bytes": model.inputText.utf8.count,
              "result_bytes": model.resultText.utf8.count]
    }.sorted { ($0["number"] as! Int) < ($1["number"] as! Int) }
    shared.record(event, details: ["cycle": cycle, "content_sizes": state,
      "anchor_fingerprint": anchor.flatMap(anchorHash) ?? "",
      "quota": appDefaults[\.testNumbersPerDay]])
  }
}

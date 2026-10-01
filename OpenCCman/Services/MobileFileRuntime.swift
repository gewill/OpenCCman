#if os(iOS)
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MobileFileRuntime {
  static let shared = MobileFileRuntime()
  // Enabled for the v2.2 TestFlight acceptance candidate; public release remains gated on #260.
  nonisolated static let productionEnabled = true
  // #268 remains a separate candidate until its signed-device acceptance. The
  // 100 MiB release gate must not silently enable the experimental capacity.
  nonisolated static let experimentalCapacityEnabled = false
  nonisolated static var isExperimentalCapacityEnabled: Bool {
    #if DEBUG
    if isQABundle, ProcessInfo.processInfo.arguments.contains("-qa-mobile-file-experimental-capacity") { return true }
    #endif
    return experimentalCapacityEnabled
  }
  nonisolated static var isEnabled: Bool {
    #if DEBUG
    if isQABundle, ProcessInfo.processInfo.arguments.contains("-qa-enable-mobile-large-files") { return true }
    #endif
    return productionEnabled
  }
  nonisolated static var isQABundle: Bool {
    Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests"
  }
  var isQualified: Bool {
    #if DEBUG
    if Self.isQABundle, ProcessInfo.processInfo.arguments.contains("-qa-mobile-file-pro") { return true }
    #endif
    return UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue)
  }

  private let protection = LargeFileProtectionGate(available: UIApplication.shared.isProtectedDataAvailable)
  private var activated = false
  private var sceneOwners: [String: UUID] = [:]
  private var disconnectObserver: NSObjectProtocol?
  private var didImportQA = false
  lazy var coordinator = makeCoordinator()
  private lazy var lifecycle = MobileFileLifecycle(protection: protection,
    interrupt: { [weak self] in self?.coordinator.cancel() },
    protectedDataReturned: { [weak self] in self?.coordinator.recover() })

  private func makeCoordinator() -> MobileLargeFileCoordinator {
    let gate = protection
    return MobileLargeFileCoordinator(factory: {
      try await withCheckedThrowingContinuation { continuation in
        DispatchQueue(label: "OpenCCman.mobile-job-bootstrap", qos: .utility).async {
          do {
            let root = try MobileLargeFileService.applicationSupportRoot()
            continuation.resume(returning: MobileLargeFileService(root: root, protection: gate))
          } catch { continuation.resume(throwing: error) }
        }
      }
    }, isQualified: { [weak self] in self?.isQualified ?? false },
       allowsExperimentalCapacity: { Self.isExperimentalCapacityEnabled },
       beginWork: { [weak self] in
         guard let self else { return }
         #if DEBUG
         self.recordResourcesForQA("before_begin")
         #endif
         self.lifecycle.begin()
         #if DEBUG
         self.recordResourcesForQA("after_begin")
         #endif
       },
       endWork: { [weak self] in
         guard let self else { return }
         self.lifecycle.end()
         #if DEBUG
         self.recordResourcesForQA("after_end")
         #endif
       })
  }

  func activate() {
    guard Self.isEnabled, !activated else { return }
    activated = true
    _ = lifecycle
    disconnectObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didDisconnectNotification, object: nil, queue: .main
    ) { [weak self] notification in
      guard let scene = notification.object as? UIScene else { return }
      let id = scene.session.persistentIdentifier
      Task { @MainActor in
        guard let self, let owner = self.sceneOwners.removeValue(forKey: id) else { return }
        self.coordinator.ownerDidClose(owner)
      }
    }
    coordinator.recover()
  }

  func register(scene: UIWindowScene, owner: UUID) { sceneOwners[scene.session.persistentIdentifier] = owner }

  #if DEBUG
  private var qaResourceEvents: [[String: Any]] = []
  private let qaTraceQueue = DispatchQueue(label: "OpenCCman.mobile-resource-qa")

  /// Explicit opt-in on the isolated QA app only. No filenames or text are
  /// recorded. Serial writes preserve the order of actual UIKit operations.
  private func recordResourcesForQA(_ event: String) {
    guard Self.isQABundle, ProcessInfo.processInfo.arguments.contains("-qa-mobile-file-resource-trace") else { return }
    qaResourceEvents.append(["event": event, "resources": lifecycle.qaResourceState,
                             "app_active": UIApplication.shared.applicationState == .active])
    if qaResourceEvents.count > 96 { qaResourceEvents.removeFirst(qaResourceEvents.count - 96) }
    guard let data = try? JSONSerialization.data(withJSONObject: qaResourceEvents, options: [.prettyPrinted, .sortedKeys]) else { return }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("mobile-file-resources-qa.json")
    qaTraceQueue.async { try? data.write(to: url, options: .atomic) }
  }

  func importQAFileIfRequested(into model: HomeViewModel) {
    guard Self.isEnabled, Self.isQABundle, !didImportQA else { return }
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "-qa-import-mobile-file"), args.indices.contains(index + 1) else { return }
    didImportQA = true
    Task {
      await coordinator.waitUntilSettled()
      model.importFile(URL(fileURLWithPath: args[index + 1]))
    }
  }
  #endif
}

/// Read the real window scene without treating SwiftUI disappear (e.g. another
/// full-screen presentation) as closing the iPad window that owns the task.
struct MobileFileSceneReader: UIViewRepresentable {
  let owner: UUID
  func makeUIView(context: Context) -> Reader { Reader(owner: owner) }
  func updateUIView(_ view: Reader, context: Context) { view.register() }
  final class Reader: UIView {
    let owner: UUID
    init(owner: UUID) { self.owner = owner; super.init(frame: .zero); isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); register() }
    func register() {
      if let scene = window?.windowScene { MobileFileRuntime.shared.register(scene: scene, owner: owner) }
    }
  }
}
#endif

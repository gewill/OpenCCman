#if os(iOS)
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MobileFileRuntime {
  static let shared = MobileFileRuntime()
  // #260 owns production enablement after signed device acceptance.
  nonisolated static let productionEnabled = false
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
       beginWork: { [weak self] in self?.lifecycle.begin() },
       endWork: { [weak self] in self?.lifecycle.end() })
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

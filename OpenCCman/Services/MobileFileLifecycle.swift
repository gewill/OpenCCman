#if os(iOS)
import Foundation
import UIKit

/// UIKit resource ownership is independent of SwiftUI view appearance. An
/// inactive scene (picker, Control Centre, call) is not an all-scenes background.
@MainActor
final class MobileFileLifecycle {
  struct Resources {
    var idleDisabled: () -> Bool
    var setIdleDisabled: (Bool) -> Void
    var begin: (@escaping @Sendable () -> Void) -> UIBackgroundTaskIdentifier
    var end: (UIBackgroundTaskIdentifier) -> Void

    static var live: Resources {
      Resources(idleDisabled: { UIApplication.shared.isIdleTimerDisabled },
                setIdleDisabled: { UIApplication.shared.isIdleTimerDisabled = $0 },
                begin: { UIApplication.shared.beginBackgroundTask(withName: "Finish file cleanup", expirationHandler: $0) },
                end: { UIApplication.shared.endBackgroundTask($0) })
    }
  }

  private let resources: Resources
  private let protection: LargeFileProtectionGate
  private let interrupt: @MainActor () -> Void
  private let protectedDataReturned: @MainActor () -> Void
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var backgroundGeneration: UUID?
  private var previousIdleDisabled: Bool?
  private var observers: [NSObjectProtocol] = []

  #if DEBUG
  var qaResourceState: [String: Bool] {
    ["idle_disabled": resources.idleDisabled(),
     "owns_idle_override": previousIdleDisabled != nil,
     "owns_background_task": backgroundTask != .invalid]
  }
  #endif

  init(protection: LargeFileProtectionGate,
       interrupt: @escaping @MainActor () -> Void,
       protectedDataReturned: @escaping @MainActor () -> Void,
       resources: Resources = .live) {
    self.resources = resources
    self.protection = protection
    self.interrupt = interrupt
    self.protectedDataReturned = protectedDataReturned
    observe(UIApplication.didEnterBackgroundNotification) { owner in owner.interrupt() }
    observe(UIScene.didEnterBackgroundNotification) { owner in
      // The notification can precede the connectedScenes activation update.
      Task { @MainActor [weak owner] in
        await Task.yield()
        guard let owner else { return }
        let foreground = UIApplication.shared.connectedScenes.contains {
          $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }
        if !foreground { owner.interrupt() }
      }
    }
    observe(UIApplication.didReceiveMemoryWarningNotification) { $0.interrupt() }
    observe(UIApplication.protectedDataWillBecomeUnavailableNotification) {
      $0.protection.setAvailable(false)
      $0.interrupt()
    }
    observe(UIApplication.protectedDataDidBecomeAvailableNotification) {
      $0.protection.setAvailable(true)
      $0.protectedDataReturned()
    }
  }

  func begin() {
    guard previousIdleDisabled == nil else { return }
    previousIdleDisabled = resources.idleDisabled()
    resources.setIdleDisabled(true)
    let generation = UUID()
    backgroundGeneration = generation
    backgroundTask = resources.begin { [weak self] in
      Task { @MainActor in
        guard let self, self.backgroundGeneration == generation else { return }
        self.interrupt()
        // No awaiting the worker or synchronous disk cleanup on this handler.
        // If suspension wins, the job journal handles recovery next launch.
        if self.backgroundGeneration == generation { self.endBackgroundTask() }
      }
    }
  }

  /// Called only once the actual file worker has returned, including cancel.
  func end() {
    if let previousIdleDisabled {
      resources.setIdleDisabled(previousIdleDisabled)
      self.previousIdleDisabled = nil
    }
    endBackgroundTask()
  }

  private func endBackgroundTask() {
    backgroundGeneration = nil
    guard backgroundTask != .invalid else { return }
    let identifier = backgroundTask
    backgroundTask = .invalid
    resources.end(identifier)
  }

  private func observe(_ name: Notification.Name, action: @escaping @MainActor (MobileFileLifecycle) -> Void) {
    let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in if let self { action(self) } }
    }
    observers.append(observer)
  }

  deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
#endif

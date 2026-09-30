#if os(iOS)
import Foundation
import UIKit

/// Exercises the UIKit adapter in the native XCTest host. Posted notifications
/// are injection, not proof of real scene transitions or physical-device lock.
@MainActor
func checkMobileLifecycle() async throws {
  let gate = LargeFileProtectionGate(available: true)
  var interrupted = 0
  var restored = 0
  let owner = MobileFileLifecycle(protection: gate,
                                  interrupt: { interrupted += 1 }, protectedDataReturned: { restored += 1 })
  // SwiftPM runs in a headless xctest process: idleTimer/background leases
  // require the real App host and are deliberately not claimed by this check.
  NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
  try await Task.sleep(nanoseconds: 50_000_000)
  precondition(interrupted == 0, "Inactive alone must not cancel a job")
  NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
  try await waitForLifecycle { interrupted == 1 }
  NotificationCenter.default.post(name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
  try await waitForLifecycle { interrupted == 2 }
  do { try gate.check(); preconditionFailure("Protection notification closes the gate") }
  catch MobileLargeFileService.JobError.protectedDataUnavailable {}
  NotificationCenter.default.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
  try await waitForLifecycle { restored == 1 }
  try gate.check()
  NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
  try await waitForLifecycle { interrupted == 3 }
  try await checkDelayedExpiration()
  print("PASS: UIKit adapter injected inactive/background/memory/protection notifications; idle timer, leases, real scenes and lock require App-host acceptance")
}

/// Real adapter with injected UIKit resource functions: deterministically holds
/// expiration callbacks across end/begin without needing a headless UIKit lease.
@MainActor
private func checkDelayedExpiration() async throws {
  var idle = false
  var callbacks: [@Sendable () -> Void] = []
  var ended: [UIBackgroundTaskIdentifier] = []
  var interrupted = 0
  let resources = MobileFileLifecycle.Resources(
    idleDisabled: { idle }, setIdleDisabled: { idle = $0 },
    begin: { callback in
      callbacks.append(callback)
      return UIBackgroundTaskIdentifier(rawValue: callbacks.count)
    }, end: { ended.append($0) })
  let owner = MobileFileLifecycle(protection: LargeFileProtectionGate(available: true),
    interrupt: { interrupted += 1 }, protectedDataReturned: {}, resources: resources)
  owner.begin()
  owner.begin()
  precondition(callbacks.count == 1 && idle)
  // Queue the old callback's MainActor hop, then replace its lease before yield.
  callbacks[0]()
  owner.end()
  owner.begin()
  try await Task.sleep(nanoseconds: 50_000_000)
  precondition(interrupted == 0, "An expired old lease must not cancel the new job")
  precondition(ended == [UIBackgroundTaskIdentifier(rawValue: 1)] && idle)
  callbacks[1]()
  try await waitForLifecycle { interrupted == 1 }
  precondition(ended == [UIBackgroundTaskIdentifier(rawValue: 1), UIBackgroundTaskIdentifier(rawValue: 2)])
  precondition(idle, "Only worker completion restores the idle override")
  callbacks[1]()
  try await Task.sleep(nanoseconds: 50_000_000)
  precondition(interrupted == 1, "Duplicate expiration must be ignored")
  owner.end()
  owner.end()
  precondition(!idle && ended.count == 2)
  print("PASS: delayed old expiration ignored; current expiration interrupts once; worker completion restores idle; leases end once (injected resources)")
}

@MainActor
private func waitForLifecycle(_ condition: () -> Bool) async throws {
  for _ in 0..<200 {
    if condition() { return }
    try await Task.sleep(nanoseconds: 10_000_000)
  }
  preconditionFailure("Lifecycle callback was not delivered")
}
#endif

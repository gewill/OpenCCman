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
  print("PASS: UIKit adapter injected inactive/background/memory/protection notifications; idle timer, leases, real scenes and lock require App-host acceptance")
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

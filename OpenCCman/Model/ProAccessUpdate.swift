import Foundation

/// Only a successful, verified customer snapshot can change cached access.
/// A cancelled operation or transport failure is not evidence of revocation.
struct ProAccessUpdate {
  let activeEntitlement: Bool?
  let failed: Bool
  let cancelled: Bool

  func applying(to cached: Bool) -> Bool {
    guard !failed, !cancelled, let activeEntitlement else { return cached }
    return activeEntitlement
  }

  var shouldShowError: Bool { failed && !cancelled }
}

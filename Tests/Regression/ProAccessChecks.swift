import Foundation

@main
enum ProAccessChecks {
  static func main() {
    defer { UserDefaults.standard.removePersistentDomain(forName: quotaSuite) }
    func resolved(_ cached: Bool, _ active: Bool?, failed: Bool = false, cancelled: Bool = false) -> Bool {
      ProAccessUpdate(activeEntitlement: active, failed: failed, cancelled: cancelled).applying(to: cached)
    }
    precondition(resolved(false, true), "Verified restore must grant access")
    precondition(!resolved(true, false), "Verified revocation must remove access")
    precondition(resolved(true, nil), "Absent response must preserve offline Pro")
    precondition(resolved(true, false, failed: true), "Failed response must not revoke cached Pro")
    precondition(!resolved(false, true, failed: true), "Failed response must not grant unverified access")
    precondition(resolved(true, false, cancelled: true), "Cancellation must not revoke access")
    precondition(!resolved(false, true, cancelled: true), "Cancellation must not grant access")
    precondition(!ProAccessUpdate(activeEntitlement: nil, failed: true, cancelled: true).shouldShowError,
                 "User cancellation is not a purchase error")
    precondition(ProAccessUpdate(activeEntitlement: nil, failed: true, cancelled: false).shouldShowError)

    quotaNow = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 12))!
    appDefaults.stored = ["2026-09-14": 12]
    UserDefaults.standard.set(false, forKey: "isPro")
    precondition(TestNumbersPerDayManager.reserve() == nil)
    UserDefaults.standard.set(resolved(false, true), forKey: "isPro")
    let proReservation = TestNumbersPerDayManager.reserve()!
    proReservation.commit()
    precondition(appDefaults.stored["2026-09-14"] == 12, "Restored Pro must not consume quota")
    UserDefaults.standard.set(resolved(true, nil, failed: true), forKey: "isPro")
    precondition(!TestNumbersPerDayManager.isToMax, "Offline failure must preserve Pro quota behavior")
    UserDefaults.standard.set(resolved(true, false), forKey: "isPro")
    precondition(TestNumbersPerDayManager.reserve() == nil, "Revocation must restore the daily limit")
    print("PASS: verified restore/revocation, missing/failed/cancelled snapshots and real quota integration")
  }
}

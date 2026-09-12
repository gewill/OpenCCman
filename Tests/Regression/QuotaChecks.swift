import Foundation

@main
enum QuotaChecks {
  static func main() {
    defer { UserDefaults.standard.removePersistentDomain(forName: quotaSuite) }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    quotaNow = calendar.date(from: DateComponents(
      year: 2026, month: 9, day: 12, hour: 23, minute: 59, second: 59
    ))!
    UserDefaults.standard.set(false, forKey: "isPro")

    precondition(!TestNumbersPerDayManager.isToMax)
    let first = TestNumbersPerDayManager.reserve()!
    precondition(appDefaults.writes == 0, "Reservations must not persist unfinished work")
    first.commit()
    first.commit()
    first.release()
    precondition(appDefaults.stored == ["2026-09-12": 1])
    precondition(appDefaults.writes == 1, "The first conversion must persist once")

    for _ in 2..<12 { TestNumbersPerDayManager.reserve()!.commit() }
    precondition(!TestNumbersPerDayManager.isToMax, "11 conversions still permits conversion")
    let lastSlot = TestNumbersPerDayManager.reserve()!
    precondition(TestNumbersPerDayManager.reserve() == nil, "Another window cannot reserve the last slot twice")
    precondition(TestNumbersPerDayManager.isToMax)
    lastSlot.release()
    lastSlot.commit()
    precondition(!TestNumbersPerDayManager.isToMax, "Failed or cancelled work returns its slot")
    autoreleasepool {
      let abandoned = TestNumbersPerDayManager.reserve()!
      withExtendedLifetime(abandoned) { precondition(TestNumbersPerDayManager.isToMax) }
    }
    precondition(!TestNumbersPerDayManager.isToMax, "Deallocation releases an abandoned reservation")
    let yesterday = TestNumbersPerDayManager.reserve()!
    yesterday.commit()
    precondition(TestNumbersPerDayManager.isToMax, "12 conversions reaches the daily cap")
    precondition(appDefaults.stored == ["2026-09-12": 12])

    appDefaults.stored = ["2026-09-12": 11]
    let crossingMidnight = TestNumbersPerDayManager.reserve()!
    quotaNow = quotaNow.addingTimeInterval(1)
    appDefaults.writes = 0
    precondition(!TestNumbersPerDayManager.isToMax, "Yesterday must not consume today's quota")
    TestNumbersPerDayManager.reserve()!.commit()
    crossingMidnight.commit()
    precondition(appDefaults.stored == ["2026-09-13": 1], "Rollover retains only today's count")
    precondition(appDefaults.writes == 1, "Rollover must not persist an intermediate empty dictionary")

    appDefaults.stored = ["2026-09-13": 12]
    appDefaults.writes = 0
    UserDefaults.standard.set(true, forKey: "isPro")
    precondition(!TestNumbersPerDayManager.isToMax)
    let pro = TestNumbersPerDayManager.reserve()!
    pro.commit()
    precondition(appDefaults.stored == ["2026-09-13": 12] && appDefaults.writes == 0,
                 "Pro conversions do not consume quota")

    // A conversion started as Pro stays exempt even if entitlement changes.
    let expiredPro = TestNumbersPerDayManager.reserve()!
    UserDefaults.standard.set(false, forKey: "isPro")
    expiredPro.commit()
    precondition(appDefaults.writes == 0)

    appDefaults.stored = [:]
    DispatchQueue.concurrentPerform(iterations: 100) { _ in
      TestNumbersPerDayManager.reserve()?.commit()
    }
    precondition(appDefaults.stored == ["2026-09-13": 12], "Concurrent windows cannot overrun the cap")
    precondition(appDefaults.writes == 12)
    print("PASS: quota reservations, concurrent cap, idempotent cleanup, cancellation, deinit, midnight and Pro exemption.")
  }
}

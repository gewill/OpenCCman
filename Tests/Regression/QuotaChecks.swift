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
    TestNumbersPerDayManager.add()
    precondition(appDefaults.stored == ["2026-09-12": 1])
    precondition(appDefaults.writes == 1, "The first conversion must persist once")

    for _ in 2..<12 { TestNumbersPerDayManager.add() }
    precondition(!TestNumbersPerDayManager.isToMax, "11 conversions still permits conversion")
    TestNumbersPerDayManager.add()
    precondition(TestNumbersPerDayManager.isToMax, "12 conversions reaches the daily cap")
    precondition(appDefaults.stored == ["2026-09-12": 12])

    quotaNow = quotaNow.addingTimeInterval(1)
    appDefaults.writes = 0
    precondition(!TestNumbersPerDayManager.isToMax, "Yesterday must not consume today's quota")
    TestNumbersPerDayManager.add()
    precondition(appDefaults.stored == ["2026-09-13": 1], "Rollover retains only today's count")
    precondition(appDefaults.writes == 1, "Rollover must not persist an intermediate empty dictionary")

    appDefaults.stored = ["2026-09-13": 12]
    appDefaults.writes = 0
    UserDefaults.standard.set(true, forKey: "isPro")
    precondition(!TestNumbersPerDayManager.isToMax)
    TestNumbersPerDayManager.add()
    precondition(appDefaults.stored == ["2026-09-13": 12] && appDefaults.writes == 0,
                 "Pro conversions do not consume quota")

    print("PASS: daily quota boundaries, midnight rollover, Pro exemption, single persistence.")
  }
}

import Foundation

enum TestNumbersPerDayManager {
  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static func add() {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue) == false else { return }

    let today = dayFormatter.string(from: Date())
    let count = appDefaults[\.testNumbersPerDay][today] ?? 0
    appDefaults[\.testNumbersPerDay] = [today: count + 1]
  }

  static var isToMax: Bool {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue) == false else { return false }

    let today = dayFormatter.string(from: Date())

    if let count = appDefaults[\.testNumbersPerDay][today] {
      return count >= FreeFeature.maxTestNumber
    } else {
      return false
    }
  }
}

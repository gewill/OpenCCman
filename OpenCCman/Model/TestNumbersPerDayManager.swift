import Foundation

enum TestNumbersPerDayManager {
  static func add() {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue) == false else { return }

    let today = Date().string(withFormat: "yyyy-MM-dd")

    if let count = appDefaults[\.testNumbersPerDay][today] {
      appDefaults[\.testNumbersPerDay][today] = count + 1
    } else {
      appDefaults[\.testNumbersPerDay] = [:]
      appDefaults[\.testNumbersPerDay][today] = 1
    }
  }

  static var isToMax: Bool {
    guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue) == false else { return false }

    let today = Date().string(withFormat: "yyyy-MM-dd")

    if let count = appDefaults[\.testNumbersPerDay][today] {
      return count >= FreeFeature.maxTestNumber
    } else {
      return false
    }
  }
}

import Foundation

// Isolate the actual manager from the app's preferences and wall clock.
let quotaSuite = "OpenCCman.QuotaRegression.\(UUID().uuidString)"
enum UserDefaults {
  static let standard = Foundation.UserDefaults(suiteName: quotaSuite)!
}

var quotaNow = Foundation.Date(timeIntervalSince1970: 0)
func Date() -> Foundation.Date { quotaNow }

enum UserDefaultsKeys: String { case isPro }
enum FreeFeature { static let maxTestNumber = 12 }
struct DefaultsKeys {
  var testNumbersPerDay: String { "testNumbersPerDay" }
}

final class QuotaDefaults {
  var stored: [String: Int] = [:]
  var writes = 0

  subscript(_ key: KeyPath<DefaultsKeys, String>) -> [String: Int] {
    get { stored }
    set {
      stored = newValue
      writes += 1
    }
  }
}

let appDefaults = QuotaDefaults()

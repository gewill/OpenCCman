import Foundation
import SwiftyUserDefaults

let appDefaults = Defaults

extension DefaultsKeys {
  var testNumbersPerDay: DefaultsKey<[String: Int]> { .init(UserDefaultsKeys.testNumbersPerDay.rawValue, defaultValue: [:]) }
}

enum UserDefaultsKeys: String {
  case hasHapticFeedback
  case fontName
  case selectedLocale
  case isPro
  case lastCheckProDate
  case testNumbersPerDay
  case targetOptions
  case variantOptions
  case regionOptions
}

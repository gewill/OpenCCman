import Foundation
import SwiftyUserDefaults

let appDefaults = Defaults

extension DefaultsKeys {
  var testNumbersPerDay: DefaultsKey<[String: Int]> { .init(UserDefaultsKeys.testNumbersPerDay.rawValue, defaultValue: [:]) }
  var targetOptions: DefaultsKey<HomeViewModel.Language> { .init(UserDefaultsKeys.targetOptions.rawValue, defaultValue: .traditional) }
  var variantOptions: DefaultsKey<HomeViewModel.Variant> { .init(UserDefaultsKeys.variantOptions.rawValue, defaultValue: .openCC) }
  var regionOptions: DefaultsKey<HomeViewModel.Region> { .init(UserDefaultsKeys.regionOptions.rawValue, defaultValue: .notConvert) }
  var showMenuBarIcon: DefaultsKey<Bool> { .init(UserDefaultsKeys.showMenuBarIcon.rawValue, defaultValue: false) }
}

enum UserDefaultsKeys: String {
  case hasHapticFeedback
  case fontName
  case selectedLocale
  case selectedTheme
  case isPro
  case lastCheckProDate
  case testNumbersPerDay
  case targetOptions
  case variantOptions
  case regionOptions
  case lastVersionPromptedForReview
  case showMenuBarIcon
}

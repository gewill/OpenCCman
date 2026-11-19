import Foundation
import SwiftyUserDefaults

let appDefaults = Defaults

extension DefaultsKeys {
  var testNumbersPerDay: DefaultsKey<[String: Int]> { .init(UserDefaultsKeys.testNumbersPerDay.rawValue, defaultValue: [:]) }
  // The conversion since #305. Absent source or target means settings from an
  // earlier version, which `ConversionConfiguration.saved` migrates once.
  var conversionSource: DefaultsKey<ConversionConfiguration.Standard?> { .init(UserDefaultsKeys.conversionSource.rawValue) }
  var conversionTarget: DefaultsKey<ConversionConfiguration.Standard?> { .init(UserDefaultsKeys.conversionTarget.rawValue) }
  var conversionPhrases: DefaultsKey<ConversionConfiguration.Region> { .init(UserDefaultsKeys.conversionPhrases.rawValue, defaultValue: .notConvert) }
  // Settings before #305: read only for that migration, and left in place so an
  // earlier version still finds its own settings.
  var targetOptions: DefaultsKey<ConversionConfiguration.Language> { .init(UserDefaultsKeys.targetOptions.rawValue, defaultValue: .traditional) }
  var variantOptions: DefaultsKey<ConversionConfiguration.Variant> { .init(UserDefaultsKeys.variantOptions.rawValue, defaultValue: .openCC) }
  var regionOptions: DefaultsKey<ConversionConfiguration.Region> { .init(UserDefaultsKeys.regionOptions.rawValue, defaultValue: .notConvert) }
  var simplifiedSourceOptions: DefaultsKey<ConversionConfiguration.Variant> { .init(UserDefaultsKeys.simplifiedSourceOptions.rawValue, defaultValue: .openCC) }
  var simplifiedRegionOptions: DefaultsKey<ConversionConfiguration.Region> { .init(UserDefaultsKeys.simplifiedRegionOptions.rawValue, defaultValue: .notConvert) }
  var showMenuBarIcon: DefaultsKey<Bool> { .init(UserDefaultsKeys.showMenuBarIcon.rawValue, defaultValue: true) }
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
  case simplifiedSourceOptions
  case simplifiedRegionOptions
  case conversionSource
  case conversionTarget
  case conversionPhrases
  case showsConversionConfigurationName
  case lastVersionPromptedForReview
  case showMenuBarIcon
  case shortcutFailureToast
  case shortcutSuccessToast
  case globalShortcutEnabled
  case macTextSize
}

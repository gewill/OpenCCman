// Only app integration is stubbed; Combine, SwiftUI, OpenCC and defaults are real.
import Combine
import Foundation
import SwiftUI
import SwiftyUserDefaults

let coreSuite = "OpenCCman.CoreChecks.\(UUID().uuidString)"
enum UserDefaults {
  static let standard = Foundation.UserDefaults(suiteName: coreSuite)!
}
let appDefaults = DefaultsAdapter(defaults: UserDefaults.standard, keyStore: DefaultsKeys())
extension DefaultsKeys {
  var conversionSource: DefaultsKey<ConversionConfiguration.Standard?> { .init("conversionSource") }
  var conversionTarget: DefaultsKey<ConversionConfiguration.Standard?> { .init("conversionTarget") }
  var conversionPhrases: DefaultsKey<ConversionConfiguration.Region> { .init("conversionPhrases", defaultValue: .notConvert) }
  var targetOptions: DefaultsKey<ConversionConfiguration.Language> { .init("targetOptions", defaultValue: .traditional) }
  var variantOptions: DefaultsKey<ConversionConfiguration.Variant> { .init("variantOptions", defaultValue: .openCC) }
  var regionOptions: DefaultsKey<ConversionConfiguration.Region> { .init("regionOptions", defaultValue: .notConvert) }
  var simplifiedSourceOptions: DefaultsKey<ConversionConfiguration.Variant> { .init("simplifiedSourceOptions", defaultValue: .openCC) }
  var simplifiedRegionOptions: DefaultsKey<ConversionConfiguration.Region> { .init("simplifiedRegionOptions", defaultValue: .notConvert) }
  var testNumbersPerDay: DefaultsKey<[String: Int]> { .init("testNumbersPerDay", defaultValue: [:]) }
}
enum UserDefaultsKeys: String {
  case lastVersionPromptedForReview = "CoreChecks.reviewVersion"
  case isPro
}
enum FreeFeature { static let maxTestNumber = 12 }
var coreQuotaCount: Int { appDefaults[\.testNumbersPerDay].values.reduce(0, +) }
protocol Segmentable: Identifiable, Hashable { var title: String { get } }
extension Bundle { var appVersion: String { "core-checks" } }
@MainActor enum ReviewHandler {
  static var requests = 0
  static func requestReview() -> Bool { requests += 1; return true }
}
extension Notification.Name {
  static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

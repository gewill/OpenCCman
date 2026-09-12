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
  var targetOptions: DefaultsKey<HomeViewModel.Language> { .init("targetOptions", defaultValue: .traditional) }
  var variantOptions: DefaultsKey<HomeViewModel.Variant> { .init("variantOptions", defaultValue: .openCC) }
  var regionOptions: DefaultsKey<HomeViewModel.Region> { .init("regionOptions", defaultValue: .notConvert) }
  var testNumbersPerDay: DefaultsKey<[String: Int]> { .init("testNumbersPerDay", defaultValue: [:]) }
}
enum UserDefaultsKeys: String {
  case lastVersionPromptedForReview = "CoreChecks.reviewVersion"
  case isPro
}
enum FreeFeature { static let maxTestNumber = 12 }
var coreQuotaCount: Int { appDefaults[\.testNumbersPerDay].values.reduce(0, +) }
protocol Segmentable: Identifiable, Equatable { var title: String { get } }
extension Bundle { var appVersion: String { "core-checks" } }
@MainActor enum ReviewHandler {
  static var requests = 0
  static func requestReview() { requests += 1 }
}
extension Notification.Name {
  static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

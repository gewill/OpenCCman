// Only app integration is stubbed; Combine, SwiftUI, OpenCC and defaults are real.
import Combine
import Foundation
import SwiftUI
import SwiftyUserDefaults

let coreSuite = "OpenCCman.CoreChecks.\(UUID().uuidString)"
let appDefaults = DefaultsAdapter(defaults: UserDefaults(suiteName: coreSuite)!, keyStore: DefaultsKeys())
extension DefaultsKeys {
  var targetOptions: DefaultsKey<HomeViewModel.Language> { .init("targetOptions", defaultValue: .traditional) }
  var variantOptions: DefaultsKey<HomeViewModel.Variant> { .init("variantOptions", defaultValue: .openCC) }
  var regionOptions: DefaultsKey<HomeViewModel.Region> { .init("regionOptions", defaultValue: .notConvert) }
}
enum UserDefaultsKeys: String { case lastVersionPromptedForReview = "CoreChecks.reviewVersion" }
protocol Segmentable: Identifiable, Equatable { var title: String { get } }
extension Bundle { var appVersion: String { "core-checks" } }
@MainActor enum ReviewHandler {
  static var requests = 0
  static func requestReview() { requests += 1 }
}
@MainActor enum TestNumbersPerDayManager {
  static var isToMax = false
  static var count = 0
  static func add() { count += 1 }
}
extension Notification.Name {
  static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

import Foundation
import RevenueCat
import SwiftUI

// Test-only definitions for the actual app constants and an isolated preferences domain.
protocol Pickable: Identifiable { var title: LocalizedStringKey { get } }
private let suite = "OpenCCman.IAPLocaleChecks.\(UUID())"
enum UserDefaults {
  static let standard = Foundation.UserDefaults(suiteName: suite)!
}

@main
enum IAPLocaleChecks {
  static func main() {
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let settings: [(String?, String)] = [
      (nil, LocaleConstants.system.identifier),
      ("system", LocaleConstants.system.identifier),
      ("en", "en"), ("zh_Hans", "zh_Hans"), ("zh_Hant", "zh_Hant"),
      ("invalid-locale", LocaleConstants.system.identifier),
    ]
    for (saved, expected) in settings {
      Purchases.resetForCheck()
      UserDefaults.standard.set(saved, forKey: UserDefaultsKeys.selectedLocale.rawValue)
      UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isPro.rawValue)
      UserDefaults.standard.set(["fixture-day": 12], forKey: UserDefaultsKeys.testNumbersPerDay.rawValue)
      let before = UserDefaults.standard.dictionaryRepresentation() as NSDictionary

      #if !IAP_LOCALE_BOOTSTRAP_ONLY
      IAPManager.shared.updatePreferredUILocale(.zh_Hant)
      precondition(Purchases.localeCalls.isEmpty, "Preview/unconfigured path must not access the SDK singleton")
      #endif

      IAPManager.shared.configure()
      let observation = ["saved": saved ?? "<unset>", "expected": expected,
                         "sdk_initial_locale": Purchases.initialLocale ?? "<none>"]
      FileHandle.standardError.write(try! JSONSerialization.data(withJSONObject: observation, options: [.sortedKeys]))
      FileHandle.standardError.write(Data([10]))
      precondition(Purchases.initialLocale == expected,
                   "Initial SDK locale must match the app's saved/effective language")
      precondition(Purchases.proxyAtConfiguration?.absoluteString == "https://api.rc-backup.com/",
                   "Proxy must be set before initial SDK requests")
      precondition(Purchases.shared.delegate === IAPManager.shared)
      IAPManager.shared.configure()
      precondition(Purchases.configureCount == 1, "Repeated initialization must not replace the SDK session")

      #if !IAP_LOCALE_BOOTSTRAP_ONLY
      for choice in [LocaleConstants.zh_Hans, .zh_Hant, .en, .system] {
        IAPManager.shared.updatePreferredUILocale(choice)
      }
      precondition(Purchases.localeCalls == ["zh_Hans", "zh_Hant", "en", LocaleConstants.system.identifier],
                   "Runtime language choices must reach the SDK, including the effective system fallback")
      #endif

      precondition(Purchases.customerInfoCalls == 0, "The app locale bridge must not request access refresh")
      precondition(before.isEqual(UserDefaults.standard.dictionaryRepresentation() as NSDictionary),
                   "Language synchronization must not mutate saved preferences, Pro, or quota")
    }
    print("PASS: real IAPManager; 6 saved-language cases, proxy ordering, configure idempotence, locale updates and unchanged preferences")
  }
}

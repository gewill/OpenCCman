import Foundation
import SwiftUI

// Test-only definitions for the actual app constants and an isolated preferences domain.
protocol Pickable: Identifiable { var title: LocalizedStringKey { get } }
private let suite = "OpenCCman.AppLanguageChecks.\(UUID())"
enum UserDefaults {
  static let standard = Foundation.UserDefaults(suiteName: suite)!
}

@main
enum AppLanguageChecks {
  static func main() {
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

    checkLanguageTags()
    checkAppleLanguagesSync()
    checkLegacySelectionSurvives()
    checkTagMatching()

    print("PASS: BCP-47 tags, AppleLanguages writes and removal, legacy selection fallback and tag matching")
  }

  /// `AppleLanguages` and bundle lookup need hyphens; `identifier` stays underscored.
  private static func checkLanguageTags() {
    precondition(LocaleConstants.zh_Hans.languageTag == "zh-Hans")
    precondition(LocaleConstants.zh_Hant.languageTag == "zh-Hant")
    precondition(LocaleConstants.en.languageTag == "en")
    precondition(LocaleConstants.zh_Hans.identifier == "zh_Hans",
                 "The SDK bridge and its regression check expect the underscore form")
    precondition(LocaleConstants.zh_Hans.locale.identifier == "zh-Hans")
  }

  /// Read the app's own domain, never the merged search list: that one also
  /// serves `NSGlobalDomain`, so it reports the system languages as if the app
  /// had stored them.
  private static var storedAppleLanguages: [String]? {
    UserDefaults.standard.persistentDomain(forName: suite)?[LocaleConstants.appleLanguagesKey] as? [String]
  }

  private static func checkAppleLanguagesSync() {
    for choice in [LocaleConstants.en, .zh_Hans, .zh_Hant] {
      LocaleConstants.syncToUserDefaults(choice)
      precondition(storedAppleLanguages == [choice.languageTag],
                   "A language choice must be stored as a single BCP-47 tag")
    }

    LocaleConstants.syncToUserDefaults(.system)
    precondition(storedAppleLanguages == nil,
                 "Following the system must remove the override, not store a resolved language")
  }

  /// Existing installs keep their choice in the legacy key. Reading the app's own
  /// domain keeps it visible; a plain `AppleLanguages` lookup would instead return
  /// the system languages and silently discard it.
  private static func checkLegacySelectionSurvives() {
    LocaleConstants.syncToUserDefaults(.system)
    for legacy in [LocaleConstants.en, .zh_Hans, .zh_Hant] {
      UserDefaults.standard.set(legacy.rawValue, forKey: UserDefaultsKeys.selectedLocale.rawValue)
      precondition(LocaleConstants.savedSelection == legacy,
                   "A stored legacy choice must survive until it is migrated")
    }

    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.selectedLocale.rawValue)
    precondition(LocaleConstants.savedSelection == .system,
                 "No stored choice must read as following the system")
  }

  private static func checkTagMatching() {
    let expectations: [(String, LocaleConstants)] = [
      ("zh-Hant", .zh_Hant), ("zh_Hant", .zh_Hant), ("zh-Hant-TW", .zh_Hant),
      ("zh-Hans", .zh_Hans), ("zh-Hans-CN", .zh_Hans),
      ("en", .en), ("en-US", .en),
      ("fr", .zh_Hant),
    ]
    for (tag, expected) in expectations {
      precondition(LocaleConstants.match(tag: tag) == expected,
                   "Tag \(tag) must resolve to \(expected.rawValue)")
    }
  }
}

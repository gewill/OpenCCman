import CoreGraphics
import Foundation
import Neumorphic
import SwiftUI

enum ChineseLanguageConstant: String {
  case zh_Hans = "zh-Hans"
  case zh_Hant = "zh-Hant"
  case languageCode = "zh"
  case simpleScriptCode = "Hans"
  case traditionalScriptCode = "Hant"
}

enum LocaleConstants: String, CaseIterable, Identifiable, Pickable {
  case system
  case en
  case zh_Hans
  case zh_Hant

  var identifier: String {
    switch self {
    case .system: return Self.systemIdentifier
    default: return rawValue
    }
  }

  /// BCP-47 tag for `AppleLanguages` and bundle lookup; `identifier` keeps the
  /// underscore form the SDK bridge and its regression check already expect.
  var languageTag: String {
    identifier.replacingOccurrences(of: "_", with: "-")
  }

  var locale: Locale {
    switch self {
    case .system: return .current
    default: return Locale(identifier: languageTag)
    }
  }

  /// `.system` removes the app's `AppleLanguages` override, so the preferred
  /// list is the system's own. Do not read `Locale.current` here: the override
  /// pollutes it while another language is active.
  static var systemIdentifier: String {
    resolveIdentifier(from: Locale.preferredLanguages.first)
  }

  /// The real system language even while the app overrides `AppleLanguages`,
  /// read from the global domain instead of the app's own defaults.
  static var systemPreferredLocale: LocaleConstants {
    let global = Foundation.UserDefaults(suiteName: ".GlobalPreferences")?
      .array(forKey: appleLanguagesKey) as? [String]
    let preferred = global?.first ?? Locale.preferredLanguages.first
    return LocaleConstants(rawValue: resolveIdentifier(from: preferred)) ?? .zh_Hant
  }

  private static func resolveIdentifier(from preferred: String?) -> String {
    guard let preferred else { return Self.zh_Hant.rawValue }
    let tag = preferred.replacingOccurrences(of: "_", with: "-")
    if tag.hasPrefix(ChineseLanguageConstant.languageCode.rawValue) {
      return tag.contains(ChineseLanguageConstant.simpleScriptCode.rawValue)
        ? Self.zh_Hans.rawValue
        : Self.zh_Hant.rawValue
    }
    let languageCode = tag.split(separator: "-").first.map(String.init) ?? tag
    if notChineseLanguages.map({ $0.rawValue }).contains(languageCode) {
      return languageCode
    }
    return Self.zh_Hant.rawValue
  }

  // MARK: - AppleLanguages

  static let appleLanguagesKey = "AppleLanguages"

  /// Persist the choice into `AppleLanguages` so `Bundle.main` itself resolves
  /// every localized resource. Sheets, AppKit and system-provided UI then follow
  /// the in-app language without per-presentation environment plumbing.
  static func syncToUserDefaults(_ locale: LocaleConstants) {
    switch locale {
    case .system:
      UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
    default:
      UserDefaults.standard.set([locale.languageTag], forKey: appleLanguagesKey)
    }
    UserDefaults.standard.synchronize()
  }

  /// The app's own `AppleLanguages` override. Read the app domain explicitly:
  /// `UserDefaults.standard` also searches `NSGlobalDomain`, so a plain lookup
  /// returns the system languages and makes every launch look already migrated.
  static var appDomainAppleLanguages: [String]? {
    guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
    return UserDefaults.standard.persistentDomain(forName: bundleID)?[appleLanguagesKey] as? [String]
  }

  /// The stored choice, without migrating or writing anything, so callers on the
  /// launch path can read it before the migration runs.
  static var savedSelection: LocaleConstants {
    if let tag = appDomainAppleLanguages?.first,
       let matched = match(tag: tag) {
      return matched
    }
    if let rawValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedLocale.rawValue),
       let legacy = LocaleConstants(rawValue: rawValue) {
      return legacy
    }
    return .system
  }

  static func match(tag: String) -> LocaleConstants? {
    let normalized = tag.replacingOccurrences(of: "_", with: "-")
    let selectable = allCases.filter { $0 != .system }
    if let exact = selectable.first(where: { $0.languageTag == normalized }) {
      return exact
    }
    if let prefixed = selectable.first(where: { normalized.hasPrefix($0.languageTag) }) {
      return prefixed
    }
    return LocaleConstants(rawValue: resolveIdentifier(from: normalized))
  }

  static var chineseLanguages: [LocaleConstants] {
    [.zh_Hans, .zh_Hant]
  }

  static var notChineseLanguages: [LocaleConstants] {
    Self.allCases.filter {
      Self.chineseLanguages.contains($0) == false
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .system: return "Follow system"
    case .en: return "English"
    case .zh_Hans: return "简体中文"
    case .zh_Hant: return "繁體中文"
    }
  }

  var helpUrl: String {
    "https://gewill.org/2023/12/17/introducing-OpenCCman-\(identifier)/"
  }

  var privacyUrl: String {
    switch identifier {
    case Self.zh_Hant.identifier: "\(helpUrl)#%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96"
    case Self.zh_Hans.identifier: "\(helpUrl)#%E9%9A%90%E7%A7%81%E6%94%BF%E7%AD%96"
    default: "\(helpUrl)#Privacy-policy"
    }
  }

  var id: LocaleConstants { self }
}

enum Theme: String, CaseIterable, Identifiable, Pickable {
  case system, light, dark

  var colorScheme: ColorScheme? {
    switch self {
    case .system:
      return nil
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }

  var title: LocalizedStringKey {
    switch self {
    case .system: return "Follow system"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var id: Theme { self }
}

enum Constant {
  #if os(macOS)
    static let padding: CGFloat = 12
    static let smallButtonSize: CGSize = .init(width: 30, height: 30)
  #elseif targetEnvironment(macCatalyst)
    static let padding: CGFloat = 12
    static let smallButtonSize: CGSize = .init(width: 30, height: 30)
  #else
    static let padding: CGFloat = 12
    static let smallButtonSize: CGSize = .init(width: 40, height: 40)
  #endif
  static let cornerRadius: CGFloat = 20
  static let maxiPhoneScreenWidth: CGFloat = 428
  static let maxiPhoneScreenHeight: CGFloat = 926
  static let tabBarHeight: CGFloat = 94
}

enum Padding {
  static let verySmall: CGFloat = 3
  static let small: CGFloat = 6
  static let normal: CGFloat = 12
  static let large: CGFloat = 18
  static let verLarge: CGFloat = 24
}

enum UserInterfaceIdiom: Int {
  case unspecified = -1
  case phone = 0
  case pad = 1
  case tv = 2
  case carPlay = 3
  case mac = 5
  case watch = 6

  static var current: UserInterfaceIdiom {
    #if targetEnvironment(macCatalyst)
      return .mac
    #elseif os(iOS)
      UserInterfaceIdiom(rawValue: UIDevice.current.userInterfaceIdiom.rawValue) ?? .unspecified
    #elseif os(macOS)
      return .mac
    #elseif os(watchOS)
      return .watch
    #elseif os(tvOS)
      return .tv
    #else
      return .unspecified
    #endif
  }
}

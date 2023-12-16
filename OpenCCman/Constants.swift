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

enum LocaleConstants: String, CaseIterable, Identifiable {
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

  static var systemIdentifier: String {
    if let languageCode = Locale.current.languageCode {
      switch languageCode {
      case ChineseLanguageConstant.languageCode.rawValue:
        if Locale.current.scriptCode == ChineseLanguageConstant.simpleScriptCode.rawValue {
          return Self.zh_Hans.rawValue
        } else {
          return Self.zh_Hant.rawValue
        }
      case _ where notChineseLanguages.map { $0.rawValue }.contains(languageCode):
        return languageCode
      default: break
      }
    }
    return Self.zh_Hant.rawValue
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

  var id: LocaleConstants { self }
}

enum Theme: String, CaseIterable, Identifiable {
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
    static let padding: CGFloat = 6
    static let smallButtonSize: CGSize = .init(width: 40, height: 40)
  #endif
  static let cornerRadius: CGFloat = 20
  static let maxiPhoneScreenWidth: CGFloat = 428
  static let maxiPhoneScreenHeight: CGFloat = 926
  static let tabBarHeight: CGFloat = 94
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

import SwiftUI

extension String {
  var localizedStringKey: LocalizedStringKey {
    LocalizedStringKey(self)
  }

  /// Resolve String-only control labels using the app's selected locale.
  func localized(in locale: Locale, bundle: Bundle = .main) -> String {
    let preferred = locale.identifier.replacingOccurrences(of: "_", with: "-")
    let language = Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: [preferred]).first
    let localizedBundle = language
      .flatMap { bundle.path(forResource: $0, ofType: "lproj") }
      .flatMap(Bundle.init(path:)) ?? bundle
    return localizedBundle.localizedString(forKey: self, value: self, table: nil)
  }

  #if os(macOS)
  /// macOS 27 renamed the Accessibility permission in Privacy & Security to "Device Control
  /// and Data Access" (设备控制和数据访问, 裝置控制和資料取用), apart from the Accessibility
  /// settings. Text naming the permission has a `<key>_macos27` variant, so each system
  /// shows its own name. Without a locale, the app's language (`Bundle.main`) is used, as
  /// for alerts.
  func localizedNamingAccessibilityPermission(in locale: Locale? = nil, bundle: Bundle = .main,
                                              systemUsesNewName: Bool = String.systemNamesDeviceControlAccess) -> String {
    func resolve(_ key: String) -> String {
      locale.map { key.localized(in: $0, bundle: bundle) }
        ?? bundle.localizedString(forKey: key, value: key, table: nil)
    }
    if systemUsesNewName {
      let variantKey = self + "_macos27"
      let variant = resolve(variantKey)
      if variant != variantKey { return variant }
    }
    return resolve(self)
  }

  static var systemNamesDeviceControlAccess: Bool {
    if #available(macOS 27, *) { return true }
    return false
  }
  #endif

  var url: URL? {
    return URL(string: self)
  }

  static var noValueSymbol = "--"

  func replaceEmpty(with str: String = .noValueSymbol) -> String {
    isEmpty ? str : self
  }
}

extension String {
  func fromBase64() -> String? {
    guard let data = Data(base64Encoded: self) else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  func toBase64() -> String {
    return Data(utf8).base64EncodedString()
  }
}

func copyToClipboard(text: String) {
  #if os(iOS)
    UIPasteboard.general.string = text
  #endif

  #if os(macOS)
    let pasteBoard = NSPasteboard.general
    pasteBoard.clearContents()
    pasteBoard.setString(text, forType: .string)
  #endif
}

func getClipboardString() -> String? {
  #if os(iOS)
    return UIPasteboard.general.string
  #endif

  #if os(macOS)
    let pasteBoard = NSPasteboard.general
    return pasteBoard.string(forType: .string)
  #endif
}

extension String {
  /// add percent encoding for special characters
  var percentEncoding: String {
    addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
  }
}

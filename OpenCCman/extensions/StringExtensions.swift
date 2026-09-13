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

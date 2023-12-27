import SwiftUI

extension String {
  var localizedStringKey: LocalizedStringKey {
    LocalizedStringKey(self)
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

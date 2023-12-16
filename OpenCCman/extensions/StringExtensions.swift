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
    self.isEmpty ? str : self
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
    return Data(self.utf8).base64EncodedString()
  }
}

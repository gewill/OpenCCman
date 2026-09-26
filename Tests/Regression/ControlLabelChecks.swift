import Foundation

@main
enum ControlLabelChecks {
  static func main() {
    let bundle = Bundle(path: CommandLine.arguments[1])!
    let expected = [
      ("en", "Simplified Chinese"),
      ("en_US", "Simplified Chinese"),
      ("zh-Hans", "简体中文"),
      ("zh_Hans", "简体中文"),
      ("zh-Hant", "簡體中文"),
      ("zh_Hant", "簡體中文"),
    ]
    for (identifier, label) in expected {
      let actual = "Simplified Chinese".localized(in: Locale(identifier: identifier), bundle: bundle)
      precondition(actual == label, "\(identifier): expected \(label), got \(actual)")
    }
    for identifier in ["en", "zh-Hans", "zh-Hant"] {
      let locale = Locale(identifier: identifier)
      for key in ["Simplified Chinese", "OpenCC Standard", "Taiwan Standard", "HongKong Standard", "Not convert", "Taiwan Idiom", "On", "Off", "In progress"] {
        let result = key.localized(in: locale, bundle: bundle)
        precondition(!result.isEmpty)
        if identifier != "en" { precondition(result != key, "Missing \(identifier) control label: \(key)") }
      }
      precondition("missing_test_key".localized(in: locale, bundle: bundle) == "missing_test_key")
    }
    // Locale changes must not reuse the label from the first presentation.
    let simplified = "Simplified Chinese".localized(in: Locale(identifier: "zh-Hans"), bundle: bundle)
    let traditional = "Simplified Chinese".localized(in: Locale(identifier: "zh-Hant"), bundle: bundle)
    precondition(simplified != traditional)
    print("PASS: released control labels resolve English, Simplified/Traditional Chinese, underscore locales, live locale changes and missing-key fallback")
  }
}

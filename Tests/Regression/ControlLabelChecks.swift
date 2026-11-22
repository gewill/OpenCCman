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
      for key in ["Simplified Chinese", "OpenCC Standard", "Taiwan Standard", "HongKong Standard", "Not convert", "Taiwan Idiom", "HongKong Idiom", "On", "Off", "In progress", "Online help"] {
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

    // macOS 27 renamed the Accessibility permission to Device Control and Data Access in
    // every language: each string naming it needs a macOS 27 variant with the new name.
    let names = [("en", "Accessibility", "Device Control and Data Access"),
                 ("zh-Hans", "辅助功能", "设备控制和数据访问"),
                 ("zh-Hant", "輔助使用", "裝置控制和資料取用")]
    var namingKeys: Set<String>?
    for (identifier, oldName, newName) in names {
      let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: identifier)!
      let table = NSDictionary(contentsOf: url) as! [String: String]
      let locale = Locale(identifier: identifier)
      let naming = Set(table.keys.filter { !$0.hasSuffix("_macos27") && table[$0]!.range(of: oldName, options: .caseInsensitive) != nil })
      precondition(!naming.isEmpty && naming == (namingKeys ?? naming), "\(identifier) names the permission in other strings")
      namingKeys = naming
      for key in naming {
        let older = key.localizedNamingAccessibilityPermission(in: locale, bundle: bundle, systemUsesNewName: false)
        let newer = key.localizedNamingAccessibilityPermission(in: locale, bundle: bundle, systemUsesNewName: true)
        precondition(older == table[key])
        precondition(newer.contains(newName) && newer.range(of: oldName, options: .caseInsensitive) == nil,
                     "\(identifier) \(key) needs the macOS 27 name")
      }
      for key in table.keys where key.hasSuffix("_macos27") {
        precondition(naming.contains(String(key.dropLast("_macos27".count))), "\(identifier) \(key) has no base string")
      }
    }
    // Alerts and notices look up without a locale, in the bundle's own language.
    let bundleLocale = Locale(identifier: bundle.preferredLocalizations.first!)
    for key in namingKeys! {
      for newName in [false, true] {
        precondition(key.localizedNamingAccessibilityPermission(bundle: bundle, systemUsesNewName: newName)
          == key.localizedNamingAccessibilityPermission(in: bundleLocale, bundle: bundle, systemUsesNewName: newName))
      }
    }
    // Strings without a variant read the same on every system.
    precondition("Refresh".localizedNamingAccessibilityPermission(in: Locale(identifier: "zh-Hans"), bundle: bundle, systemUsesNewName: true)
      == "Refresh".localized(in: Locale(identifier: "zh-Hans"), bundle: bundle))
    print("PASS: released control labels resolve English, Simplified/Traditional Chinese, underscore locales, live locale changes and missing-key fallback; the Accessibility permission keeps its name before macOS 27 and is Device Control and Data Access from macOS 27 in all three languages")
  }
}

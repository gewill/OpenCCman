import Combine
import Foundation

// Test-only stand-ins. `scripts/check-shortcut-transaction.sh` appends the real
// UserDefaultsKeys and the service's stored properties, init and handler setup.
private let suite = "OpenCCman.ShortcutPreferenceChecks.\(UUID().uuidString)"
enum UserDefaults {
  static let standard = Foundation.UserDefaults(suiteName: suite)!
}

enum KeyboardShortcuts {
  struct Name: Hashable { let rawValue: String }
  static var isEnabled = true
  /// The global switch as each handler registered its hot key.
  static var enabledAtRegistration: [Bool] = []
  static func onKeyUp(for name: Name, action: @escaping () -> Void) {
    enabledAtRegistration.append(isEnabled)
  }
}

extension KeyboardShortcuts.Name {
  static let convertSelectedText = Self(rawValue: "convertSelectedText")
  static let openSelectedText = Self(rawValue: "openSelectedText")
}

extension GlobalShortcutService {
  func checkAccessibilityPermission() {}
  func handleConvertShortcutPressed() {}
  func handleOpenShortcutPressed() {}

  /// A relaunch: a new service with the stored defaults, before any handler.
  static func launch() -> GlobalShortcutService {
    KeyboardShortcuts.isEnabled = true
    KeyboardShortcuts.enabledAtRegistration = []
    return GlobalShortcutService()
  }

  static func runChecks() {
    defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
    let key = UserDefaultsKeys.globalShortcutEnabled.rawValue

    var service = launch()
    precondition(service.isEnabled && KeyboardShortcuts.isEnabled,
                 "An install that never changed the switch keeps shortcuts enabled")
    precondition(KeyboardShortcuts.enabledAtRegistration == [true, true])
    precondition(UserDefaults.standard.object(forKey: key) == nil, "Launching must not store the default")

    service.isEnabled = false
    precondition(UserDefaults.standard.object(forKey: key) as? Bool == false && !KeyboardShortcuts.isEnabled,
                 "Turning the switch off is stored and applied at once")
    service = launch()
    precondition(!service.isEnabled && !KeyboardShortcuts.isEnabled, "A relaunch keeps the switch off")
    precondition(KeyboardShortcuts.enabledAtRegistration == [false, false],
                 "The stored switch applies before the handlers register their hot keys")

    service.isEnabled = true
    precondition(UserDefaults.standard.object(forKey: key) as? Bool == true && KeyboardShortcuts.isEnabled,
                 "Turning the switch on is stored and applied at once")
    service = launch()
    precondition(service.isEnabled && KeyboardShortcuts.enabledAtRegistration == [true, true],
                 "A relaunch keeps the switch on")
    print("PASS: global shortcut switch defaults on, is stored, and applies at launch before hot keys register")
  }
}

@main
enum ShortcutPreferenceChecks {
  @MainActor static func main() {
    GlobalShortcutService.runChecks()
  }
}

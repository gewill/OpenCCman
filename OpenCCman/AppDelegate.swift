#if os(iOS)
  import Foundation
  import IQKeyboardManagerSwift
  import UIKit

  class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
      IQKeyboardManager.shared.enable = true
      IQKeyboardManager.shared.shouldResignOnTouchOutside = true

      return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
      let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
      return sceneConfig
    }
  }
#endif

#if os(macOS)
  import Foundation
  import Cocoa
  import OpenCC
  import SwiftUI
  import SwiftyUserDefaults
  import KeyboardShortcuts

  class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
      // Register the text conversion service
      NSApp.servicesProvider = TextConversionService.shared

      // Initialize services
      #if os(macOS)
      _ = GlobalShortcutService.shared
      setupMenuBar()
      setupStatusBar()

      // 监听UserDefaults变化
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(userDefaultsDidChange),
        name: UserDefaults.didChangeNotification,
        object: nil
      )
      #endif
    }

    private func setupMenuBar() {
      // Add a menu item for testing the hotkey functionality
      if let mainMenu = NSApp.mainMenu {
        let testMenu = NSMenu(title: "Test")
        let testMenuItem = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        testMenuItem.submenu = testMenu

        let convertSelectedTextItem = NSMenuItem(
          title: "Convert Selected Text",
          action: #selector(convertSelectedText),
          keyEquivalent: "t"
        )
        convertSelectedTextItem.keyEquivalentModifierMask = [.command, .option]
        convertSelectedTextItem.target = self

        let openSelectedTextItem = NSMenuItem(
          title: "Open Selected Text",
          action: #selector(openSelectedText),
          keyEquivalent: "r"
        )
        openSelectedTextItem.keyEquivalentModifierMask = [.command, .option]
        openSelectedTextItem.target = self

        testMenu.addItem(convertSelectedTextItem)
        testMenu.addItem(openSelectedTextItem)
        mainMenu.addItem(testMenuItem)
      }
    }

    @objc private func convertSelectedText() {
      GlobalShortcutService.shared.convertSelectedText()
    }

    @objc private func openSelectedText() {
      GlobalShortcutService.shared.openSelectedText()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      // Bring the app to front when clicked in dock
      if !flag {
        NSApp.activate(ignoringOtherApps: true)
      }
      return true
    }

    // MARK: - Status Bar Methods

    private func setupStatusBar() {
      updateStatusBarVisibility()
    }

    @objc private func userDefaultsDidChange() {
      updateStatusBarVisibility()
    }

    private func updateStatusBarVisibility() {
      let shouldShow = appDefaults[\.showMenuBarIcon]

      if shouldShow {
        createStatusBar()
      } else {
        removeStatusBar()
      }
    }

    private func createStatusBar() {
      guard statusItem == nil else { return }

      statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

      if let button = statusItem?.button {
        button.image = NSImage(named: "StatusBarIcon")
        button.image?.isTemplate = true
        button.toolTip = "OpenCCman - Chinese Text Converter"
      }

      statusItem?.menu = createStatusMenu()
    }

    private func removeStatusBar() {
      if let statusItem = statusItem {
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
      }
    }

    private func createStatusMenu() -> NSMenu {
      let menu = NSMenu()

      // 应用名称和版本
      let titleItem = NSMenuItem(title: "OpenCCman \(Bundle.main.appVersion)", action: nil, keyEquivalent: "")
      titleItem.isEnabled = false
      menu.addItem(titleItem)

      menu.addItem(NSMenuItem.separator())

      // 转换功能
      let convertItem = NSMenuItem(
        title: NSLocalizedString("Convert", comment: ""),
        action: #selector(convertTextFromStatusBar),
        keyEquivalent: "t"
      )
      convertItem.target = self
      menu.addItem(convertItem)

      // 转换选中文本
      let convertSelectedItem = NSMenuItem(
        title: NSLocalizedString("Convert Selected Text", comment: ""),
        action: #selector(convertSelectedText),
        keyEquivalent: ""
      )
      // 动态获取快捷键设置
      if let shortcut = KeyboardShortcuts.getShortcut(for: .convertSelectedText), !shortcut.keyEquivalent.isEmpty {
        convertSelectedItem.keyEquivalent = shortcut.keyEquivalent
        convertSelectedItem.keyEquivalentModifierMask = shortcut.modifierMask
      }
      convertSelectedItem.target = self
      menu.addItem(convertSelectedItem)

      // 打开选中文本
      let openSelectedItem = NSMenuItem(
        title: NSLocalizedString("Open Selected Text", comment: ""),
        action: #selector(openSelectedText),
        keyEquivalent: ""
      )
      // 动态获取快捷键设置
      if let shortcut = KeyboardShortcuts.getShortcut(for: .openSelectedText), !shortcut.keyEquivalent.isEmpty {
        openSelectedItem.keyEquivalent = shortcut.keyEquivalent
        openSelectedItem.keyEquivalentModifierMask = shortcut.modifierMask
      }
      openSelectedItem.target = self
      menu.addItem(openSelectedItem)

      menu.addItem(NSMenuItem.separator())

      // 设置
      let settingsItem = NSMenuItem(
        title: NSLocalizedString("Settings", comment: ""),
        action: #selector(openSettingsFromStatusBar),
        keyEquivalent: ","
      )
      settingsItem.target = self
      menu.addItem(settingsItem)

      // 帮助
      let helpItem = NSMenuItem(
        title: NSLocalizedString("Help", comment: ""),
        action: #selector(openHelpFromStatusBar),
        keyEquivalent: "?"
      )
      helpItem.target = self
      menu.addItem(helpItem)

      menu.addItem(NSMenuItem.separator())

      // 退出
      let quitItem = NSMenuItem(
        title: NSLocalizedString("Quit", comment: ""),
        action: #selector(quitApp),
        keyEquivalent: "q"
      )
      quitItem.target = self
      menu.addItem(quitItem)

      return menu
    }

    // MARK: - Status Bar Menu Actions

    @objc private func convertTextFromStatusBar() {
      // 激活应用并发送转换通知
      NSApp.activate(ignoringOtherApps: true)
      NotificationCenter.default.post(name: Notification.Name("ConvertTextFromMenu"), object: nil)
    }

    @objc private func openSettingsFromStatusBar() {
      NSApp.activate(ignoringOtherApps: true)
      NotificationCenter.default.post(name: Notification.Name("OpenSettingsFromMenu"), object: nil)
    }

    @objc private func openHelpFromStatusBar() {
      NSApp.activate(ignoringOtherApps: true)
      NotificationCenter.default.post(name: Notification.Name("OpenHelpFromMenu"), object: nil)
    }

    @objc private func quitApp() {
      NSApp.terminate(nil)
    }
  }

  // MARK: - KeyboardShortcuts Extension

  extension KeyboardShortcuts.Shortcut {
    var keyEquivalent: String {
      switch self.key {
      case .t: return "t"
      case .r: return "r"
      case .o: return "o"
      case .c: return "c"
      case .comma: return ","
      case .slash: return "?"
      case .q: return "q"
      default: return ""
      }
    }

    var modifierMask: NSEvent.ModifierFlags {
      var flags: NSEvent.ModifierFlags = []
      if self.modifiers.contains(.command) { flags.insert(.command) }
      if self.modifiers.contains(.option) { flags.insert(.option) }
      if self.modifiers.contains(.control) { flags.insert(.control) }
      if self.modifiers.contains(.shift) { flags.insert(.shift) }
      return flags
    }
  }

  // MARK: - Text Conversion Service

  @objc class TextConversionService: NSObject {
      static let shared = TextConversionService()

      private override init() {
          super.init()
      }

      // MARK: - Service Handler

      @objc func convertSelectedText(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
          guard let string = pboard.string(forType: .string), !string.isEmpty else {
              error.pointee = "No text found in pasteboard" as NSString
              return
          }

          // Get current conversion options from UserDefaults
          let targetOptions = appDefaults[\.targetOptions]
          let variantOptions = appDefaults[\.variantOptions]
          let regionOptions = appDefaults[\.regionOptions]

          // Build conversion options
          var options: ChineseConverter.Options = []
          if targetOptions == .traditional {
              options.formUnion(.traditionalize)
              switch variantOptions {
              case .openCC:
                  break
              case .taiwan:
                  options.formUnion(.twStandard)
              case .hongKong:
                  options.formUnion(.hkStandard)
              }
              if regionOptions == .taiwan {
                  options.formUnion(.twIdiom)
              }
          } else {
              options.formUnion(.simplify)
          }

          do {
              let converter = try ChineseConverter(options: options)
              let convertedText = converter.convert(string)

              // Clear the pasteboard and set the converted text
              pboard.clearContents()
              pboard.setString(convertedText, forType: .string)

              // Bring the app to front and populate the input field
              DispatchQueue.main.async {
                  self.bringAppToFrontAndSetText(originalText: string, convertedText: convertedText)
              }

          } catch let conversionError {
              error.pointee = "Conversion failed: \(conversionError.localizedDescription)" as NSString
          }
      }

      // MARK: - Service Handler for Opening Text in App

      @objc func openSelectedTextInApp(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
          guard let string = pboard.string(forType: .string), !string.isEmpty else {
              error.pointee = "No text found in pasteboard" as NSString
              return
          }

          // Just bring the app to front and set the text without conversion
          DispatchQueue.main.async {
              self.bringAppToFrontAndSetTextOnly(originalText: string)
          }
      }

      // MARK: - App Integration

      private func bringAppToFrontAndSetText(originalText: String, convertedText: String) {
          // Activate the app
          NSApp.activate(ignoringOtherApps: true)

          // Post notification to update the UI
          NotificationCenter.default.post(
              name: .textConversionServiceDidReceiveText,
              object: nil,
              userInfo: [
                  "originalText": originalText,
                  "convertedText": convertedText
              ]
          )
      }

      private func bringAppToFrontAndSetTextOnly(originalText: String) {
          // Activate the app
          NSApp.activate(ignoringOtherApps: true)

          // Post notification to update the UI with just the original text
          NotificationCenter.default.post(
              name: .textServiceDidReceiveText,
              object: nil,
              userInfo: [
                  "originalText": originalText
              ]
          )
      }
  }



#endif

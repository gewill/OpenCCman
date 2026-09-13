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

  @MainActor
  class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private static let readyWindows = NSHashTable<NSWindow>.weakObjects()
    private static var pendingWindowNotification: PendingWindowNotification?

    private struct PendingWindowNotification {
      let name: Notification.Name
      let userInfo: [AnyHashable: Any]?
      weak var window: NSWindow?
    }

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
        testMenu.delegate = self
        let testMenuItem = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
        testMenuItem.submenu = testMenu

        let convertSelectedTextItem = NSMenuItem(
          title: "Convert Selected Text",
          action: #selector(convertSelectedText),
          keyEquivalent: ""
        )
        convertSelectedTextItem.setShortcut(for: .convertSelectedText)
        convertSelectedTextItem.target = self

        let openSelectedTextItem = NSMenuItem(
          title: "Open Selected Text",
          action: #selector(openSelectedText),
          keyEquivalent: ""
        )
        openSelectedTextItem.setShortcut(for: .openSelectedText)
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

    func applicationDidBecomeActive(_ notification: Notification) {
      GlobalShortcutService.shared.checkAccessibilityPermission()
    }

    func menuWillOpen(_ menu: NSMenu) {
      KeyboardShortcuts.isEnabled = false
    }

    func menuDidClose(_ menu: NSMenu) {
      KeyboardShortcuts.isEnabled = GlobalShortcutService.shared.isEnabled
    }

    @discardableResult
    static func activateMainWindow() -> NSWindow? {
      let keyWindow = NSApp.keyWindow.flatMap { $0.canBecomeMain ? $0 : nil }
      let window = keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.canBecomeMain })
      window?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return window
    }

    static func postWindowNotification(name: Notification.Name, userInfo: [AnyHashable: Any]? = nil) {
      let window = activateMainWindow()
      // Only the latest request is retained while SwiftUI creates and binds its window.
      pendingWindowNotification = nil
      guard let window, readyWindows.contains(window) else {
        pendingWindowNotification = PendingWindowNotification(name: name, userInfo: userInfo, window: window)
        return
      }
      NotificationCenter.default.post(name: name, object: window, userInfo: userInfo)
    }

    static func registerReadyWindow(_ window: NSWindow) {
      // Let Root's window state and notification subscriptions settle before delivery.
      DispatchQueue.main.async { [weak window] in
        guard let window else { return }
        readyWindows.add(window)
        guard let pending = pendingWindowNotification,
              pending.window == nil || pending.window === window else { return }
        pendingWindowNotification = nil
        NotificationCenter.default.post(name: pending.name, object: window, userInfo: pending.userInfo)
      }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      // Bring the app to front when clicked in dock
      if !flag {
        Self.activateMainWindow()
      }
      return true
    }

    // MARK: - Status Bar Methods

    private func setupStatusBar() {
      updateStatusBarVisibility()
    }

    @objc nonisolated private func userDefaultsDidChange() {
      DispatchQueue.main.async { [weak self] in
        self?.updateStatusBarVisibility()
      }
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
      menu.delegate = self

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
      convertSelectedItem.target = self
      menu.addItem(convertSelectedItem)

      // 打开选中文本
      let openSelectedItem = NSMenuItem(
        title: NSLocalizedString("Open Selected Text", comment: ""),
        action: #selector(openSelectedText),
        keyEquivalent: ""
      )
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
      Self.postWindowNotification(name: Notification.Name("ConvertTextFromMenu"))
    }

    @objc private func openSettingsFromStatusBar() {
      Self.postWindowNotification(name: Notification.Name("OpenSettingsFromMenu"))
    }

    @objc private func openHelpFromStatusBar() {
      Self.postWindowNotification(name: Notification.Name("OpenHelpFromMenu"))
    }

    @objc private func quitApp() {
      NSApp.terminate(nil)
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

          let options = ConversionConfiguration(
              target: appDefaults[\.targetOptions],
              variant: appDefaults[\.variantOptions],
              region: appDefaults[\.regionOptions]
          ).options

          do {
              let convertedText = try ChineseConversionService.convertSynchronously(string, options: options)

              // Clear the pasteboard and set the converted text
              pboard.clearContents()
              guard pboard.setString(convertedText, forType: .string) else {
                  error.pointee = "Could not write converted text to pasteboard" as NSString
                  return
              }

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

      @MainActor private func bringAppToFrontAndSetText(originalText: String, convertedText: String) {
          AppDelegate.postWindowNotification(
              name: .textConversionServiceDidReceiveText,
              userInfo: [
                  "originalText": originalText,
                  "convertedText": convertedText
              ]
          )
      }

      @MainActor private func bringAppToFrontAndSetTextOnly(originalText: String) {
          AppDelegate.postWindowNotification(
              name: .textServiceDidReceiveText,
              userInfo: [
                  "originalText": originalText
              ]
          )
      }
  }



#endif

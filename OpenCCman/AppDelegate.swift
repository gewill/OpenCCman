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

  class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ notification: Notification) {
      // Register the text conversion service
      NSApp.servicesProvider = TextConversionService.shared

      // Initialize services
      #if os(macOS)
      _ = GlobalHotkeyService.shared
      setupMenuBar()
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
          keyEquivalent: "r"
        )
        convertSelectedTextItem.keyEquivalentModifierMask = [.command, .option]
        convertSelectedTextItem.target = self

        testMenu.addItem(convertSelectedTextItem)
        mainMenu.addItem(testMenuItem)
      }
    }

    @objc private func convertSelectedText() {
      GlobalHotkeyService.shared.convertSelectedText()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      // Bring the app to front when clicked in dock
      if !flag {
        NSApp.activate(ignoringOtherApps: true)
      }
      return true
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
  }



#endif

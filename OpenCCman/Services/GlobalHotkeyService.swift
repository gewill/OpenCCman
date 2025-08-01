//
//  GlobalHotkeyService.swift
//  OpenCCman
//
//  Created by will on 2024/07/30.
//

#if os(macOS)
import Foundation
import Cocoa
import OpenCC
import SwiftUI
import SwiftyUserDefaults
import KeyboardShortcuts
import ApplicationServices
import Carbon

// MARK: - Keyboard Shortcuts Extension

extension KeyboardShortcuts.Name {
    static let convertSelectedText = Self("convertSelectedText", default: .init(.r, modifiers: [.command, .option]))
}

// MARK: - Global Hotkey Service

class GlobalHotkeyService: ObservableObject {
    static let shared = GlobalHotkeyService()

    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                setupKeyboardShortcut()
            } else {
                KeyboardShortcuts.disable(.convertSelectedText)
            }
        }
    }

    @Published var hasAccessibilityPermission = false
    @Published var hasAppleEventsPermission = false

    private init() {
        checkAccessibilityPermission()
        setupKeyboardShortcut()
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .convertSelectedText) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.handleHotkeyPressed()
        }
    }
    
    // MARK: - Hotkey Handling

    private func handleHotkeyPressed() {
        print("Hotkey pressed! Converting selected text...")
        convertSelectedText()
    }

    // MARK: - Permission Management

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
            // For simplicity, we'll consider Apple Events permission the same as Accessibility
            self.hasAppleEventsPermission = trusted
        }
    }

    private func isAccessibilityEnabled() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        return accessibilityEnabled
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }

        if !trusted {
            showAccessibilityPermissionAlert()
        }
    }

    func requestAppleEventsPermission() {
        // Since we're using Accessibility-based text capture, just request Accessibility permission
        requestAccessibilityPermission()
    }



    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "")
        alert.informativeText = NSLocalizedString("""
        OpenCCman needs accessibility permission to read selected text from other applications.

        Please:
        1. Click "Open System Preferences" below
        2. Find "OpenCCman" in the list
        3. Check the box next to it
        4. Return to OpenCCman and try again
        """, comment: "")

        alert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func showAppleEventsPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Apple Events Permission Required", comment: "")
        alert.informativeText = NSLocalizedString("""
        OpenCCman needs permission to control other applications for text conversion.

        When you click "Try Again", a system dialog will appear asking for permission.
        Click "OK" in that dialog to grant permission.

        If no dialog appears, you may need to manually enable it in:
        System Preferences → Security & Privacy → Privacy → Automation
        """, comment: "")

        alert.addButton(withTitle: NSLocalizedString("Try Again", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Try again - this should trigger the system dialog
            requestAppleEventsPermission()
        } else if response == .alertSecondButtonReturn {
            openAutomationPreferences()
        }
    }

    private func openAutomationPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Public Methods

    func convertSelectedText() {
        // Check accessibility permission first
        guard hasAccessibilityPermission else {
            print("Accessibility permission not granted")
            requestAccessibilityPermission()
            return
        }

        // Check Apple Events permission
        guard hasAppleEventsPermission else {
            print("Apple Events permission not granted")
            requestAppleEventsPermission()
            return
        }

        // Get the currently selected text using improved method
        getSelectedTextImproved { [weak self] selectedText in
            DispatchQueue.main.async {
                guard let self = self, let text = selectedText, !text.isEmpty else {
                    print("No text selected or text is empty")
                    self?.showNoTextSelectedAlert()
                    return
                }

                print("Selected text: \(text)")
                // Convert the text
                self.convertText(text)
            }
        }
    }

    private func showNoTextSelectedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("No Text Selected", comment: "")
            alert.informativeText = NSLocalizedString("Please select some Chinese text first, then try the shortcut again.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
    
    // MARK: - Text Capture

    // MARK: - Improved Text Capture (based on Easydict)

    private func getSelectedTextImproved(completion: @escaping (String?) -> Void) {
        print("Starting improved text capture process")

        // 1. Try Accessibility first
        getSelectedTextByAccessibility { [weak self] text, error in
            if let text = text, !text.isEmpty {
                print("Accessibility method succeeded")
                completion(text)
                return
            }

            print("Accessibility method failed, trying simulated key")
            // 2. If Accessibility fails, try simulated key
            self?.getSelectedTextBySimulatedKey { text in
                if let text = text, !text.isEmpty {
                    print("Simulated key method succeeded")
                    completion(text)
                    return
                }

                print("All text capture methods failed")
                completion(nil)
            }
        }
    }

    private func getSelectedTextByAccessibility(completion: @escaping (String?, Error?) -> Void) {
        print("Attempting Accessibility method")

        // For now, let's skip the complex Accessibility implementation and go straight to simulated key
        // This avoids the complex pointer handling issues
        completion(nil, NSError(domain: "GlobalHotkeyService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Accessibility method skipped, using simulated key instead"
        ]))
    }

    private func getSelectedTextBySimulatedKey(completion: @escaping (String?) -> Void) {
        print("Attempting simulated key method")

        // Store current clipboard content
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string)

        // Clear clipboard to detect new content
        pasteboard.clearContents()

        // Simulate Cmd+C using CGEvent
        simulateKeyPress(keyCode: CGKeyCode(8), modifiers: .maskCommand) { // 8 is kVK_ANSI_C
            // Wait for clipboard to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let selectedText = pasteboard.string(forType: .string)

                // Restore original clipboard after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let original = originalClipboard {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                    }
                }

                // Check if we got new content
                if let text = selectedText,
                   text != originalClipboard,
                   !text.isEmpty {
                    print("Simulated key got text: \(text)")
                    completion(text)
                } else {
                    print("Simulated key got no new text")
                    completion(nil)
                }
            }
        }
    }

    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags, completion: @escaping () -> Void) {
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            completion()
            return
        }
        keyDownEvent.flags = modifiers

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            completion()
            return
        }
        keyUpEvent.flags = modifiers

        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)

        completion()
    }
    
    // MARK: - Text Conversion
    
    private func convertText(_ text: String) {
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
            let convertedText = converter.convert(text)
            
            // Replace the selected text with converted text
            replaceSelectedText(with: convertedText)
            
            // Bring the app to front and populate the input field
            bringAppToFrontAndSetText(originalText: text, convertedText: convertedText)
            
        } catch {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Text Replacement
    
    private func replaceSelectedText(with convertedText: String) {
        // Copy converted text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(convertedText, forType: .string)
        
        // Use improved AppleScript to paste the converted text
        let script = """
        try
            tell application "System Events"
                if not running then launch
                delay 0.2
                set frontApp to name of first application process whose frontmost is true
                tell application process frontApp
                    keystroke "v" using command down
                end tell
                delay 0.1
            end tell
            return "success"
        on error errMsg
            return "error: " & errMsg
        end try
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)

        if let error = error {
            print("AppleScript paste error: \(error)")
        } else if let resultString = result?.stringValue, resultString.hasPrefix("error:") {
            print("AppleScript paste execution error: \(resultString)")
        }
    }
    
    // MARK: - App Integration
    
    private func bringAppToFrontAndSetText(originalText: String, convertedText: String) {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
        
        // Post notification to update the UI
        NotificationCenter.default.post(
            name: .globalHotkeyDidConvertText,
            object: nil,
            userInfo: [
                "originalText": originalText,
                "convertedText": convertedText
            ]
        )
    }

    // MARK: - Debug and Testing


}

// MARK: - Notification Extension

extension Notification.Name {
    static let globalHotkeyDidConvertText = Notification.Name("GlobalHotkeyDidConvertText")
}

// MARK: - Helper Functions
// KeyboardShortcuts handles all the low-level details for us!

#endif

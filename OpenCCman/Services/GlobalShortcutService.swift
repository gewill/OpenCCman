//
//  GlobalShortcutService.swift
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
    static let convertSelectedText = Self("convertSelectedText", default: .init(.t, modifiers: [.command, .option]))
    static let openSelectedText = Self("openSelectedText", default: .init(.r, modifiers: [.command, .option]))
}

// MARK: - Global Shortcut Service

class GlobalShortcutService: ObservableObject {
    static let shared = GlobalShortcutService()

    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                setupKeyboardShortcuts()
            } else {
                KeyboardShortcuts.disable(.convertSelectedText)
                KeyboardShortcuts.disable(.openSelectedText)
            }
        }
    }

    @Published var hasAccessibilityPermission = false

    private init() {
        checkAccessibilityPermission()
        setupKeyboardShortcuts()
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .convertSelectedText) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.handleConvertShortcutPressed()
        }

        KeyboardShortcuts.onKeyUp(for: .openSelectedText) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.handleOpenShortcutPressed()
        }
    }
    
    // MARK: - Shortcut Handling

    private func handleConvertShortcutPressed() {
        print("Convert shortcut pressed! Converting selected text...")
        convertSelectedText()
    }

    private func handleOpenShortcutPressed() {
        print("Open shortcut pressed! Opening selected text...")
        openSelectedText()
    }

    // MARK: - Permission Management

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
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





    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "")

        // Build the informative text using structured localization keys
        let intro = NSLocalizedString("accessibility_permission_intro", comment: "")
        let instructionsTitle = NSLocalizedString("accessibility_permission_instructions_title", comment: "")
        let step1 = NSLocalizedString("accessibility_permission_step1", comment: "")
        let step2 = NSLocalizedString("accessibility_permission_step2", comment: "")
        let step3 = NSLocalizedString("accessibility_permission_step3", comment: "")
        let step4 = NSLocalizedString("accessibility_permission_step4", comment: "")

        alert.informativeText = "\(intro)\n\n\(instructionsTitle)\n\(step1)\n\(step2)\n\(step3)\n\(step4)"

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

    // Apple Events permission methods removed - using Accessibility-only approach

    // MARK: - Public Methods

    func convertSelectedText() {
        // Check accessibility permission first
        guard hasAccessibilityPermission else {
            print("Accessibility permission not granted")
            requestAccessibilityPermission()
            return
        }

        // For sandbox apps, we only need Accessibility permission
        // The simulated key method works with just Accessibility permission

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

    func openSelectedText() {
        // Check accessibility permission first
        guard hasAccessibilityPermission else {
            print("Accessibility permission not granted")
            requestAccessibilityPermission()
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
                // Open the text in app without conversion
                self.bringAppToFrontAndSetTextOnly(originalText: text)
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

    // MARK: - Mac App Store Sandbox-Optimized Text Capture

    /// Optimized text capture for Mac App Store sandbox environment
    /// Uses simulated Cmd+C which works reliably with proper entitlements:
    /// - com.apple.security.automation.apple-events
    /// - Accessibility permission from user
    /// This approach is more reliable than Accessibility API for sandbox apps
    private func getSelectedTextImproved(completion: @escaping (String?) -> Void) {
        print("🔄 Starting Mac App Store optimized text capture")

        // Simulated key method is the gold standard for sandbox apps
        // It works consistently across all applications and doesn't require
        // complex Accessibility API calls that can be problematic in sandbox
        getSelectedTextBySimulatedKey { text in
            if let text = text, !text.isEmpty {
                print("✅ Text capture successful")
                completion(text)
            } else {
                print("⚠️ No text captured - ensure text is selected first")
                completion(nil)
            }
        }
    }

    // Accessibility method removed - simulated key is more reliable for sandbox apps

    private func getSelectedTextBySimulatedKey(completion: @escaping (String?) -> Void) {
        print("Using sandbox-optimized simulated key method")

        // Store current clipboard content to restore later
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string)
        let originalChangeCount = pasteboard.changeCount

        // Clear clipboard to ensure we can detect new content
        pasteboard.clearContents()

        // Simulate Cmd+C using CGEvent (works reliably in sandbox)
        simulateKeyPress(keyCode: CGKeyCode(8), modifiers: .maskCommand) { // 8 is kVK_ANSI_C
            // Wait for clipboard to update (optimized timing for sandbox)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let selectedText = pasteboard.string(forType: .string)
                let newChangeCount = pasteboard.changeCount

                // Restore original clipboard content after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let original = originalClipboard {
                        pasteboard.clearContents()
                        pasteboard.setString(original, forType: .string)
                    }
                }

                // Check if we got new content (more robust detection)
                if newChangeCount > originalChangeCount,
                   let text = selectedText,
                   text != originalClipboard,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("✅ Captured text: \(text.prefix(50))...")
                    completion(text)
                } else {
                    print("⚠️ No text captured - ensure text is selected")
                    completion(nil)
                }
            }
        }
    }

    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags, completion: @escaping () -> Void) {
        // Create key down event (sandbox-compatible)
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("❌ Failed to create key down event")
            completion()
            return
        }
        keyDownEvent.flags = modifiers

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("❌ Failed to create key up event")
            completion()
            return
        }
        keyUpEvent.flags = modifiers

        // Post events to system (works in sandbox with proper entitlements)
        keyDownEvent.post(tap: .cghidEventTap)

        // Small delay between key down and up for better reliability
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            keyUpEvent.post(tap: .cghidEventTap)
            completion()
        }
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

            print("📝 Original text: \(text)")
            print("🔄 Converted text: \(convertedText)")

            // Always try to replace the selected text in-place first
            // This works for editable fields like text editors, browsers, etc.
            replaceSelectedText(with: convertedText)

            // Also bring the app to front and populate the input field for reference
            // This provides a backup and shows the conversion result
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.bringAppToFrontAndSetText(originalText: text, convertedText: convertedText)
            }

        } catch {
            print("❌ Conversion failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Text Replacement
    
    private func replaceSelectedText(with convertedText: String) {
        print("🔄 Attempting to replace selected text with converted text")

        // Store original clipboard content
        let pasteboard = NSPasteboard.general
        let originalClipboard = pasteboard.string(forType: .string)

        // Copy converted text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(convertedText, forType: .string)

        // Use CGEvent to simulate Cmd+V for more reliable pasting
        // This works in most editable fields including text editors, browsers, etc.
        simulateKeyPress(keyCode: CGKeyCode(9), modifiers: .maskCommand) { // 9 is kVK_ANSI_V
            print("✅ Paste command sent - text should be replaced in editable field")

            // Restore original clipboard content after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if let original = originalClipboard {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                    print("🔄 Original clipboard content restored")
                } else {
                    // If there was no original content, clear the clipboard
                    pasteboard.clearContents()
                    print("🧹 Clipboard cleared (no original content)")
                }
            }
        }
    }
    
    // MARK: - App Integration
    
    private func bringAppToFrontAndSetText(originalText: String, convertedText: String) {
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Post notification to update the UI
        NotificationCenter.default.post(
            name: .globalShortcutDidConvertText,
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

    // MARK: - Debug and Testing


}

// MARK: - Notification Extension

extension Notification.Name {
    static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

// MARK: - Helper Functions
// KeyboardShortcuts handles all the low-level details for us!

#endif

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

@MainActor
private struct ShortcutTextCapture {
    let text: String
    let selection: ShortcutSelection?
}

// AX identity is only a guard for automatic replacement. Applications that do
// not expose a focused editable element and selected text still get the result
// in OpenCCman, where the user can copy it manually.
@MainActor
private struct ShortcutSelection {
    let window: AXUIElement
    let element: AXUIElement
    let range: CFRange
    let text: String

    static func capture(in application: NSRunningApplication) -> Self? {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else {
            return nil
        }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.25)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue,
              CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return nil }
        let window = windowValue as! AXUIElement
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }
        let focused = focusedValue as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, 0.25)

        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        let axRange = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axRange, .cfRange, &range), range.length > 0 else { return nil }

        var textValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &textValue) == .success,
              let text = textValue as? String,
              !text.isEmpty else { return nil }
        return Self(window: window, element: focused, range: range, text: text)
    }

    func matches(in application: NSRunningApplication, text expectedText: String? = nil) -> Bool {
        guard let current = Self.capture(in: application) else { return false }
        return CFEqual(window, current.window)
            && CFEqual(element, current.element)
            && range.location == current.range.location
            && range.length == current.range.length
            && text == current.text
            && (expectedText == nil || text == expectedText)
    }
}

// MARK: - Global Shortcut Service

@MainActor
class GlobalShortcutService: ObservableObject {
    static let shared = GlobalShortcutService()

    @Published var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            KeyboardShortcuts.isEnabled = isEnabled
        }
    }

    @Published private(set) var hasAccessibilityPermission = false
    private var isPerformingAction = false

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
        convertSelectedText()
    }

    private func handleOpenShortcutPressed() {
        openSelectedText()
    }

    // MARK: - Permission Management

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        checkAccessibilityPermission()
        if !hasAccessibilityPermission {
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

    // MARK: - Public Methods

    func convertSelectedText() {
        performAction(convert: true)
    }

    func openSelectedText() {
        performAction(convert: false)
    }

    private func performAction(convert: Bool) {
        guard !isPerformingAction else { return }
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return
        }
        guard let sourceApplication = NSWorkspace.shared.frontmostApplication else { return }

        isPerformingAction = true
        Task {
            defer { isPerformingAction = false }
            guard let capture = await getSelectedText(from: sourceApplication, forReplacement: convert),
                  !capture.text.isEmpty else {
                showNoTextSelectedAlert()
                return
            }

            if convert {
                await convertText(capture, in: sourceApplication)
            } else {
                bringAppToFrontAndSetTextOnly(originalText: capture.text)
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

    private func getSelectedText(
        from application: NSRunningApplication,
        forReplacement: Bool
    ) async -> ShortcutTextCapture? {
        let pasteboard = NSPasteboard.general
        guard let originalClipboard = PasteboardSnapshot(pasteboard) else { return nil }
        let originalChangeCount = originalClipboard.changeCount
        let selection = forReplacement ? ShortcutSelection.capture(in: application) : nil

        // A copy changes ownership even when its text matches the existing clipboard.
        // Leave the current contents intact if the source application cannot copy.
        guard pasteboard.changeCount == originalChangeCount,
              await simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_C), in: application) else { return nil }
        for _ in 0..<20 {
            guard (try? await Task.sleep(nanoseconds: 50_000_000)) != nil else { return nil }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else { return nil }
            let copiedChangeCount = pasteboard.changeCount
            if copiedChangeCount != originalChangeCount {
                let text = pasteboard.string(forType: .string)
                originalClipboard.restore(to: pasteboard, ifUnchangedSince: copiedChangeCount)
                guard let text else { return nil }
                // The copied text can still be converted when AX does not expose
                // a stable selection, but it must never be pasted automatically.
                let verifiedSelection = selection?.matches(in: application, text: text) == true ? selection : nil
                return ShortcutTextCapture(text: text, selection: verifiedSelection)
            }
        }
        return nil
    }

    private func simulateKeyPress(
        keyCode: CGKeyCode,
        in application: NSRunningApplication,
        matching selection: ShortcutSelection? = nil
    ) async -> Bool {
        if let selection, !selection.matches(in: application) { return false }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
              let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        keyDownEvent.flags = .maskCommand
        keyUpEvent.flags = .maskCommand
        keyDownEvent.postToPid(application.processIdentifier)
        // Always balance key down with key up, even if the task was cancelled.
        try? await Task.sleep(nanoseconds: 10_000_000)
        keyUpEvent.postToPid(application.processIdentifier)
        return true
    }

    // MARK: - Text Conversion
    
    private func convertText(_ capture: ShortcutTextCapture, in application: NSRunningApplication) async {
        let options = ConversionConfiguration(
            target: appDefaults[\.targetOptions],
            variant: appDefaults[\.variantOptions],
            region: appDefaults[\.regionOptions]
        ).options

        do {
            let convertedText = try await ChineseConversionService.shared.convert(capture.text, options: options)
            if let selection = capture.selection {
                await replaceSelectedText(with: convertedText, in: application, matching: selection)
            }
            bringAppToFrontAndSetText(originalText: capture.text, convertedText: convertedText)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Text Replacement

    private func replaceSelectedText(
        with convertedText: String,
        in application: NSRunningApplication,
        matching selection: ShortcutSelection
    ) async {
        // Conversion may finish after focus or selection moved within the same app.
        guard selection.matches(in: application) else { return }
        let pasteboard = NSPasteboard.general
        guard let originalClipboard = PasteboardSnapshot(pasteboard),
              pasteboard.changeCount == originalClipboard.changeCount else { return }
        let replacementChangeCount = pasteboard.clearContents()
        let written = pasteboard.setString(convertedText, forType: .string)
        defer {
            originalClipboard.restore(to: pasteboard, ifUnchangedSince: replacementChangeCount)
        }
        guard written,
              await simulateKeyPress(keyCode: CGKeyCode(kVK_ANSI_V), in: application, matching: selection) else { return }
        // Event posting has no paste-completion callback. Allow the receiving app to read first.
        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    // MARK: - App Integration
    
    private func bringAppToFrontAndSetText(originalText: String, convertedText: String) {
        AppDelegate.postWindowNotification(
            name: .globalShortcutDidConvertText,
            userInfo: [
                "originalText": originalText,
                "convertedText": convertedText
            ]
        )
    }

    private func bringAppToFrontAndSetTextOnly(originalText: String) {
        AppDelegate.postWindowNotification(
            name: .textServiceDidReceiveText,
            userInfo: [
                "originalText": originalText
            ]
        )
    }

}

// Preserve every item and representation, including rich text, images, and file URLs.
// Refuse a partial snapshot rather than replacing clipboard data we cannot restore.
struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]
    let changeCount: Int

    init?(_ pasteboard: NSPasteboard) {
        let changeCount = pasteboard.changeCount
        var copies: [NSPasteboardItem] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type), copy.setData(data, forType: type) else { return nil }
            }
            copies.append(copy)
        }
        guard pasteboard.changeCount == changeCount else { return nil }
        items = copies
        self.changeCount = changeCount
    }

    func restore(to pasteboard: NSPasteboard, ifUnchangedSince changeCount: Int) {
        // Another copy belongs to the user and must survive our delayed restoration.
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

// MARK: - Helper Functions
// KeyboardShortcuts handles all the low-level details for us!

#endif

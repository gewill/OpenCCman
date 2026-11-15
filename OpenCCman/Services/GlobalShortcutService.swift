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

// MARK: - Sandbox-compatible shortcut transaction

// Read hardware activity, never text or event payloads. Session counters may
// include our own synthetic keys, so they cannot distinguish a user interrupt.
// Our private CGEvent source does not update the hardware state table.
struct ShortcutInputActivity: Equatable {
    var counters: [UInt32]
    var hasHeldInput = false

    static func read() -> Self {
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged, .scrollWheel]
        let modifiers: Set<CGKeyCode> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        let keyHeld = (0..<128).contains { code in
            !modifiers.contains(CGKeyCode(code)) && CGEventSource.keyState(.hidSystemState, key: CGKeyCode(code))
        }
        let buttonHeld = [CGMouseButton.left, .right, .center].contains {
            CGEventSource.buttonState(.hidSystemState, button: $0)
        }
        return Self(counters: types.map {
            CGEventSource.counterForEventType(.hidSystemState, eventType: $0)
        }, hasHeldInput: keyHeld || buttonHeld)
    }

}

enum ShortcutFailure: Error {
    case sourceChanged, inputChanged, clipboardChanged, selectionChanged
    case copyUnavailable, permissionRequired, conversionFailed, busy

    var messageKey: String {
        switch self {
        case .sourceChanged: return "shortcut_cancelled_source"
        case .inputChanged: return "shortcut_cancelled_input"
        case .clipboardChanged: return "shortcut_cancelled_clipboard"
        case .selectionChanged: return "shortcut_cancelled_selection"
        case .copyUnavailable: return "shortcut_copy_unavailable"
        case .permissionRequired: return "shortcut_permission_required"
        case .conversionFailed: return "shortcut_conversion_failed"
        case .busy: return "shortcut_busy"
        }
    }
}

@MainActor
final class ShortcutClipboardTransaction {
    private let pasteboard: NSPasteboard
    private let sourceIsFrontmost: () -> Bool
    private let readActivity: () -> ShortcutInputActivity
    private let sendKey: (CGKeyCode) async -> Bool
    private let expectedActivity: ShortcutInputActivity
    private var expectedClipboardCount: Int
    private let started = ProcessInfo.processInfo.systemUptime

    convenience init(application: NSRunningApplication) {
        self.init(pasteboard: .general, sourceIsFrontmost: {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
                && !application.isTerminated
        }, readActivity: ShortcutInputActivity.read, sendKey: { keyCode in
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier,
                  let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return false }
            source.localEventsSuppressionInterval = 0
            down.flags = .maskCommand
            up.flags = .maskCommand
            // Use the same system event route as 1.1, not AXUIElement access.
            down.post(tap: .cghidEventTap)
            try? await Task.sleep(nanoseconds: 10_000_000)
            up.post(tap: .cghidEventTap)
            return true
        })
    }

    // The injected transport lets regression checks use a private pasteboard;
    // production always uses the initializer above and the actual source PID.
    init(pasteboard: NSPasteboard, sourceIsFrontmost: @escaping () -> Bool,
         readActivity: @escaping () -> ShortcutInputActivity,
         sendKey: @escaping (CGKeyCode) async -> Bool) {
        self.pasteboard = pasteboard
        self.sourceIsFrontmost = sourceIsFrontmost
        self.readActivity = readActivity
        self.sendKey = sendKey
        expectedActivity = readActivity()
        expectedClipboardCount = pasteboard.changeCount
    }

    private func checkTarget() throws {
        guard !Task.isCancelled, sourceIsFrontmost() else { throw ShortcutFailure.sourceChanged }
        let activity = readActivity()
        guard ProcessInfo.processInfo.systemUptime - started < 5,
              !activity.hasHeldInput, activity == expectedActivity else { throw ShortcutFailure.inputChanged }
    }

    private func checkClipboard() throws {
        guard pasteboard.changeCount == expectedClipboardCount else { throw ShortcutFailure.clipboardChanged }
    }

    func capture() async throws -> String {
        try await copySelection()
    }

    private func copySelection() async throws -> String {
        try checkTarget()
        try checkClipboard()
        guard let original = PasteboardSnapshot(pasteboard) else { throw ShortcutFailure.clipboardChanged }
        try checkClipboard()
        guard await sendKey(CGKeyCode(kVK_ANSI_C)) else { throw ShortcutFailure.copyUnavailable }
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            try checkTarget()
            let copiedCount = pasteboard.changeCount
            if copiedCount != expectedClipboardCount {
                let text = pasteboard.string(forType: .string)
                guard pasteboard.changeCount == copiedCount else { throw ShortcutFailure.clipboardChanged }
                guard let restoredCount = original.restore(to: pasteboard, ifUnchangedSince: copiedCount) else {
                    throw ShortcutFailure.clipboardChanged
                }
                expectedClipboardCount = restoredCount
                guard let text, !text.isEmpty else { throw ShortcutFailure.copyUnavailable }
                return text
            }
        }
        throw ShortcutFailure.copyUnavailable
    }

    func replace(originalText: String, with convertedText: String) async throws {
        // Re-copy immediately before pasting. No selection / changed selection /
        // clipboard ownership / user activity all fail closed. AX is not required.
        let current = try await copySelection()
        guard current == originalText else { throw ShortcutFailure.selectionChanged }
        try checkTarget()
        try checkClipboard()
        guard let original = PasteboardSnapshot(pasteboard) else { throw ShortcutFailure.clipboardChanged }
        try checkClipboard()
        let ownership = pasteboard.clearContents()
        defer { original.restore(to: pasteboard, ifUnchangedSince: ownership) }
        guard pasteboard.setString(convertedText, forType: .string),
              pasteboard.changeCount == ownership else { throw ShortcutFailure.clipboardChanged }
        try checkTarget()
        guard await sendKey(CGKeyCode(kVK_ANSI_V)) else { throw ShortcutFailure.copyUnavailable }
        // Posting is not a paste-completion callback. Keep the text available even
        // if our task is cancelled after sending the event, without blocking UI.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { continuation.resume() }
        }
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

    /// Keyboard settings hold the shortcuts users assign to Services. The convert
    /// service is an alternative that does not require Accessibility permission.
    func openKeyboardShortcutSettings() {
        let address: String
        if #available(macOS 13, *) {
            address = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
        } else {
            address = "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
        }
        NSWorkspace.shared.open(URL(string: address)!)
    }

    // MARK: - Public Methods

    func convertSelectedText() {
        performAction(convert: true)
    }

    func openSelectedText() {
        performAction(convert: false)
    }

    private func performAction(convert: Bool) {
        guard !isPerformingAction else { report(.busy); return }
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else { report(.permissionRequired); return }
        guard let sourceApplication = NSWorkspace.shared.frontmostApplication else { return }

        let transaction = ShortcutClipboardTransaction(application: sourceApplication)
        isPerformingAction = true
        Task {
            defer { isPerformingAction = false }
            do {
                let text = try await transaction.capture()
                if convert {
                    let result: String
                    do {
                        result = try await ChineseConversionService.shared.convert(text, options: ConversionConfiguration.saved.options)
                    } catch {
                        report(.conversionFailed)
                        return
                    }
                    try await transaction.replace(originalText: text, with: result)
                    // Keep the original app and its input focused on success.
                    if UserDefaults.standard.bool(forKey: UserDefaultsKeys.shortcutSuccessToast.rawValue) {
                        ShortcutToast.shared.show(NSLocalizedString("shortcut_paste_sent", comment: ""), success: true)
                    }
                } else {
                    bringAppToFrontAndSetTextOnly(originalText: text)
                }
            } catch let error as ShortcutFailure {
                report(error)
            } catch {
                report(.inputChanged)
            }
        }
    }

    private func report(_ failure: ShortcutFailure) {
        let enabled = UserDefaults.standard.object(forKey: UserDefaultsKeys.shortcutFailureToast.rawValue) as? Bool ?? true
        if enabled {
            ShortcutToast.shared.show(NSLocalizedString(failure.messageKey, comment: ""), success: false)
        }
    }

    // MARK: - App Integration
    
    private func bringAppToFrontAndSetTextOnly(originalText: String) {
        AppDelegate.postWindowNotification(
            name: .textServiceDidReceiveText,
            userInfo: [
                "originalText": originalText
            ]
        )
    }

}

// A local HUD, not a system notification: no permission prompt, activation,
// mouse interception, or document text. Only one panel/timer stays active.
@MainActor
private final class ShortcutToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class ShortcutToastCard: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        // Resolve semantic colors in this view's appearance, including dark mode.
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.shadowColor = NSColor.black.cgColor
        }
        layer?.cornerRadius = 12
        layer?.borderWidth = 0
        layer?.masksToBounds = false
        layer?.shadowOpacity = 0.10
        layer?.shadowRadius = 10
        layer?.shadowOffset = NSSize(width: 0, height: -3)
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)
    }
}

@MainActor
final class ShortcutToast {
    static let shared = ShortcutToast()
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(_ message: String, success: Bool) {
        dismissal?.cancel()
        panel?.orderOut(nil)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let scale = AppTextSize(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKeys.macTextSize.rawValue))?.multiplier ?? 1
        let inset: CGFloat = 18
        let maximumWidth = min(380 * scale, frame.width - 64)
        let label = NSTextField(wrappingLabelWithString: message)
        let font = NSFont.systemFont(ofSize: 13 * scale, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2 * scale
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph
        ]
        let singleLineWidth = (message as NSString).size(withAttributes: attributes).width
        let width = min(maximumWidth, max(200 * scale, ceil(singleLineWidth) + 80 * scale))
        let textWidth = width - 60 * scale
        label.font = font
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.attributedStringValue = NSAttributedString(string: message, attributes: attributes)
        label.preferredMaxLayoutWidth = textWidth
        label.setAccessibilityIdentifier("shortcut-toast-message")
        let bounds = (message as NSString).boundingRect(with: NSSize(width: textWidth, height: 600),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
        let cellHeight = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth, height: 600)).height ?? bounds.height
        let textHeight = ceil(max(bounds.height, cellHeight)) + 2 * scale
        let height = max(44 * scale, textHeight + 24 * scale)
        let hud = ShortcutToastPanel(contentRect: NSRect(x: frame.midX - (width + 2 * inset) / 2,
            y: frame.minY + 60 - inset, width: width + 2 * inset, height: height + 2 * inset),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        hud.isReleasedWhenClosed = false
        hud.level = .floating
        hud.isOpaque = false
        hud.backgroundColor = .clear
        // Transparent padding keeps a single subtle card shadow from clipping.
        // The window has no native shadow or material bezel to double the edge.
        hud.hasShadow = false
        hud.hidesOnDeactivate = false
        hud.ignoresMouseEvents = true
        hud.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let root = NSView(frame: NSRect(x: 0, y: 0, width: width + 2 * inset, height: height + 2 * inset))
        let card = ShortcutToastCard(frame: NSRect(x: inset, y: inset, width: width, height: height))
        card.wantsLayer = true
        let symbol = NSImageView(frame: NSRect(x: 16 * scale, y: (height - 16 * scale) / 2,
            width: 16 * scale, height: 16 * scale))
        symbol.image = NSImage(systemSymbolName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill", accessibilityDescription: nil)
        symbol.imageScaling = .scaleProportionallyUpOrDown
        symbol.contentTintColor = success ? .systemGreen : .systemOrange
        label.frame = NSRect(x: 42 * scale, y: 12 * scale, width: textWidth, height: height - 24 * scale)
        card.addSubview(symbol)
        card.addSubview(label)
        root.addSubview(card)
        hud.contentView = root
        panel = hud
        hud.orderFrontRegardless()
        dismissal = Task { [weak self, weak hud] in
            do { try await Task.sleep(nanoseconds: success ? 2_500_000_000 : 4_000_000_000) }
            catch { return }
            guard self?.panel === hud else { return }
            hud?.orderOut(nil)
            self?.panel = nil
        }
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

    @discardableResult
    func restore(to pasteboard: NSPasteboard, ifUnchangedSince changeCount: Int) -> Int? {
        // Another copy belongs to the user and must survive our delayed restoration.
        guard pasteboard.changeCount == changeCount else { return nil }
        let ownership = pasteboard.clearContents()
        if !items.isEmpty, !pasteboard.writeObjects(items) { return nil }
        return ownership
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let globalShortcutDidConvertText = Notification.Name("GlobalShortcutDidConvertText")
}

// MARK: - Helper Functions
// KeyboardShortcuts handles all the low-level details for us!

#endif

import AppKit
import Carbon

@MainActor
private final class Fixture {
    let board = NSPasteboard.withUniqueName()
    // Mouse-down, mouse-drag and scroll counters, as ShortcutInputActivity.read() returns them.
    var activity = ShortcutInputActivity(counters: [20, 0, 0, 4000, 0, 0, 4400])
    var frontmost = true
    var selection = "繁體原文"
    var posted: [CGKeyCode] = []
    var copied = 0
    var pasteResult: String?
    var pasteTypes: [NSPasteboard.PasteboardType] = []
    var afterCopy: (() -> Void)?
    var afterPaste: (() -> Void)?
    var copyWorks = true
    /// Seconds before the host's copy reaches the clipboard (nil: immediately).
    var copyDelay: TimeInterval?
    /// Whether the host reads the clipboard for ⌘V, and how late.
    var pasteReads = true
    var pasteDelay: TimeInterval?
    /// Seconds after ⌘V before an input method or clipboard tool reads the new text, as
    /// some read every clipboard change regardless of the transient marker (nil: none).
    var backgroundReadDelay: TimeInterval?
    var backgroundRead: String?
    /// A paste replaces the selection and leaves only a caret.
    var pasteCollapsesSelection = true
    var emptySelectionMetadata = false
    var clock: TimeInterval = 1_000

    init() {
        board.setString("original clipboard", forType: .string)
    }

    private func hostCopies() {
        // Like apps, ⌘C with only a caret copies nothing.
        guard !selection.isEmpty else { return }
        board.clearContents()
        let item = NSPasteboardItem()
        item.setString(selection, forType: .string)
        if emptySelectionMetadata {
            // VS Code stores {"isFromEmptySelection":true,…} in Chromium web custom data.
            let json = #"{"version":1,"isFromEmptySelection":true,"multicursorText":null,"mode":"plaintext"}"#
            item.setData(json.data(using: .utf16LittleEndian)!, forType: NSPasteboard.PasteboardType("org.chromium.web-custom-data"))
        }
        board.writeObjects([item])
    }

    func transaction(pasteHold: TimeInterval = 0.4) -> ShortcutClipboardTransaction {
        ShortcutClipboardTransaction(pasteboard: board, sourceIsFrontmost: { self.frontmost },
            readActivity: { self.activity },
            sendKey: { key in
                self.posted.append(key)
                if key == CGKeyCode(kVK_ANSI_C) {
                    self.copied += 1
                    if self.copyWorks {
                        if let delay = self.copyDelay {
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.hostCopies() }
                        } else {
                            self.hostCopies()
                        }
                    }
                    self.afterCopy?()
                } else if key == CGKeyCode(kVK_ANSI_V) {
                    self.pasteTypes = self.board.types ?? []
                    if let delay = self.backgroundReadDelay {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.backgroundRead = self.board.string(forType: .string)
                        }
                    }
                    if self.pasteReads {
                        if let delay = self.pasteDelay {
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.hostPastes() }
                        } else {
                            self.hostPastes()
                        }
                    }
                    self.afterPaste?()
                }
                return true
            }, now: { self.clock }, pasteHold: pasteHold)
    }

    private func hostPastes() {
        pasteResult = board.string(forType: .string)
        if pasteCollapsesSelection { selection = "" }
    }

    func release() { board.releaseGlobally() }
}

private func pause(_ seconds: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

@main
enum ShortcutTransactionChecks {
    @MainActor
    static func main() async throws {
        // End-to-end transaction: two copies, a paste the app reads, full clipboard restoration.
        let C = CGKeyCode(kVK_ANSI_C), V = CGKeyCode(kVK_ANSI_V)
        let success = Fixture(); defer { success.release() }
        let rich = NSPasteboardItem(); rich.setString("original clipboard", forType: .string)
        let rtf = Data("{\\rtf1 preserved}".utf8); rich.setData(rtf, forType: .rtf)
        success.board.clearContents(); success.board.writeObjects([rich])
        let transaction = success.transaction()
        let copy = try await transaction.capture()
        precondition(copy == ShortcutCopy(text: "繁體原文"))
        let outcome1 = try await transaction.replace(originalText: copy.text, with: "简体结果")
        precondition(outcome1 == .pasted)
        precondition(success.posted == [C, C, V, C])
        precondition(success.pasteResult == "简体结果")
        // The temporary text is marked transient; restorations are marked auto-generated.
        precondition(success.pasteTypes.contains(.shortcutTransient), "Converted text must be transient")
        precondition(success.board.string(forType: .string) == "original clipboard")
        precondition(success.board.data(forType: .rtf) == rtf)
        precondition(success.board.types?.contains(.shortcutAutoGenerated) == true)

        // Every cancellation leaves the user's clipboard as it was.
        try await rejected(.selectionChanged) { fixture in fixture.selection = "另一段文字" }
        try await rejected(.sourceChanged) { fixture in fixture.frontmost = false }
        // A click, a drag or a scroll inside the same app, or a held key.
        try await rejected(.inputChanged) { fixture in fixture.activity.counters[0] &+= 1 }
        try await rejected(.inputChanged) { fixture in fixture.activity.counters[3] &+= 1 }
        try await rejected(.inputChanged) { fixture in fixture.activity.counters[6] &+= 1 }
        try await rejected(.inputChanged) { fixture in fixture.activity.hasHeldInput = true }
        // Clicking away and back to identical text must still fail after user input.
        try await rejected(.inputChanged) { fixture in fixture.activity.counters[0] &+= 2 }
        // Typing over the selection is caught by the re-copy, without key-down counts.
        try await rejected(.copyUnavailable) { fixture in fixture.selection = "" }
        // The 5 s limit covers the whole transaction.
        try await rejected(.inputChanged) { fixture in fixture.clock += ShortcutClipboardTransaction.timeLimit }
        try await rejected(.clipboardChanged, keepsLatest: "latest user copy") { fixture in
            fixture.board.clearContents(); fixture.board.setString("latest user copy", forType: .string)
        }
        // A user copy of identical clipboard text is still a new ownership.
        try await rejected(.clipboardChanged, keepsLatest: "original clipboard") { fixture in
            fixture.board.clearContents(); fixture.board.setString("original clipboard", forType: .string)
        }
        // Interruption right after the host copied: the copy is undone first.
        try await rejected(.inputChanged) { fixture in
            fixture.afterCopy = { fixture.activity.counters[1] &+= 1 }
        }
        try await rejected(.sourceChanged) { fixture in
            fixture.afterCopy = { fixture.frontmost = false }
        }
        try await rejected(.copyUnavailable) { fixture in fixture.copyWorks = false }

        // A host copy that lands after the app switch is still undone.
        let late = Fixture(); defer { late.release() }
        late.copyDelay = 0.12
        late.afterCopy = { late.frontmost = false }
        do {
            _ = try await late.transaction().capture()
            preconditionFailure("Expected cancellation")
        } catch let error as ShortcutFailure {
            precondition(error == .sourceChanged, "Unexpected cancellation: \(error)")
        }
        await pause(0.4)
        precondition(late.board.string(forType: .string) == "original clipboard", "Late copy must be undone")

        // VS Code copies the whole line for an empty selection: no selection, nothing pasted.
        let emptySelection = Fixture(); defer { emptySelection.release() }
        emptySelection.emptySelectionMetadata = true
        do {
            _ = try await emptySelection.transaction().capture()
            preconditionFailure("Expected no selection")
        } catch let error as ShortcutFailure {
            precondition(error == .copyUnavailable)
        }
        precondition(emptySelection.board.string(forType: .string) == "original clipboard")

        // The app ignored ⌘V (read-only text): report it so the result is shown instead.
        let readOnly = Fixture(); defer { readOnly.release() }
        readOnly.pasteReads = false
        let ignored = readOnly.transaction(); let ignoredText = try await ignored.capture().text
        let outcome2 = try await ignored.replace(originalText: ignoredText, with: "结果")
        precondition(outcome2 == .notAccepted)
        precondition(readOnly.posted.last == CGKeyCode(kVK_ANSI_V))
        precondition(readOnly.board.string(forType: .string) == "original clipboard")

        // A slow app still reads the converted text, not the restored clipboard.
        let slow = Fixture(); defer { slow.release() }
        slow.pasteDelay = 0.25
        let slowTransaction = slow.transaction(pasteHold: 1)
        let slowText = try await slowTransaction.capture().text
        let outcome3 = try await slowTransaction.replace(originalText: slowText, with: "慢速结果")
        precondition(outcome3 == .pasted)
        precondition(slow.pasteResult == "慢速结果", "A slow paste must not get the old clipboard")
        precondition(slow.board.string(forType: .string) == "original clipboard")

        // An input method reading every clipboard change takes the text before the slow
        // app does: that first read must not end the hold and restore the clipboard early.
        let watched = Fixture(); defer { watched.release() }
        watched.backgroundReadDelay = 0.05
        watched.pasteDelay = 0.3
        let watchedTransaction = watched.transaction(pasteHold: 1)
        let watchedText = try await watchedTransaction.capture().text
        let outcome4 = try await watchedTransaction.replace(originalText: watchedText, with: "慢速结果")
        precondition(outcome4 == .pasted)
        precondition(watched.backgroundRead == "慢速结果")
        precondition(watched.pasteResult == "慢速结果", "A read by another process must not end the hold")
        precondition(watched.board.string(forType: .string) == "original clipboard")

        // An unrelated reader must not hide a refused paste in a native read-only host.
        let verifiedRefusal = Fixture(); defer { verifiedRefusal.release() }
        verifiedRefusal.backgroundReadDelay = 0.05
        verifiedRefusal.pasteReads = false
        let refused = verifiedRefusal.transaction(); let refusedText = try await refused.capture().text
        let outcome5 = try await refused.replace(originalText: refusedText, with: "结果")
        precondition(outcome5 == .notAccepted, "A selection that survives the paste means it was refused")
        precondition(verifiedRefusal.backgroundRead == "结果" && verifiedRefusal.pasteResult == nil)
        precondition(verifiedRefusal.posted == [C, C, V, C])
        precondition(verifiedRefusal.board.string(forType: .string) == "original clipboard")

        // After a real paste only a caret is left, so the second copy finds nothing.
        let verifiedPaste = Fixture(); defer { verifiedPaste.release() }
        verifiedPaste.backgroundReadDelay = 0.05
        let checked = verifiedPaste.transaction(); let checkedText = try await checked.capture().text
        let outcome6 = try await checked.replace(originalText: checkedText, with: "结果")
        precondition(outcome6 == .pasted && verifiedPaste.pasteResult == "结果")
        precondition(verifiedPaste.posted == [C, C, V, C])
        precondition(verifiedPaste.board.string(forType: .string) == "original clipboard")

        // Input during the hold skips the second copy and keeps the result as pasted.
        let movedOn = Fixture(); defer { movedOn.release() }
        movedOn.backgroundReadDelay = 0.05
        movedOn.pasteReads = false
        movedOn.afterPaste = { movedOn.activity.counters[0] &+= 1 }
        let skipped = movedOn.transaction(); let skippedText = try await skipped.capture().text
        let outcome7 = try await skipped.replace(originalText: skippedText, with: "结果")
        precondition(outcome7 == .pasted && movedOn.posted == [C, C, V])
        precondition(movedOn.board.string(forType: .string) == "original clipboard")

        // Clipboard data that cannot be read is refused before any key is sent.
        let unreadable = Fixture(); defer { unreadable.release() }
        unreadable.board.declareTypes([.string], owner: nil)
        do {
            _ = try await unreadable.transaction().capture()
            preconditionFailure("Expected unreadable clipboard")
        } catch let error as ShortcutFailure {
            precondition(error == .clipboardUnreadable)
        }
        precondition(unreadable.posted.isEmpty)

        // A new user copy after sending V survives delayed clipboard restoration.
        let laterCopy = Fixture(); defer { laterCopy.release() }
        let later = laterCopy.transaction(); let original = try await later.capture()
        laterCopy.afterPaste = {
            laterCopy.board.clearContents(); laterCopy.board.setString("user copied later", forType: .string)
        }
        _ = try await later.replace(originalText: original.text, with: "结果")
        precondition(laterCopy.board.string(forType: .string) == "user copied later")

        // Hosts that paste somewhere other than over the selection keep the result in OpenCCman.
        let line = ShortcutCopy(text: "繁體原文\n"), plain = ShortcutCopy(text: "繁體原文")
        precondition(!ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: "com.apple.Terminal", copy: plain))
        precondition(!ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: "com.googlecode.iterm2", copy: plain))
        precondition(!ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: "com.jetbrains.intellij", copy: line))
        precondition(ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: "com.jetbrains.intellij", copy: plain))
        precondition(ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: "com.apple.TextEdit", copy: line))
        precondition(ShortcutPastePolicy.allowsAutomaticPaste(bundleIdentifier: nil, copy: plain))

        print("PASS: shortcut transaction success with transient and restore markers, clipboard restored on every cancellation (including a copy that lands after the app switch), changed selection, app switch, mouse/scroll activity and held keys, same-text return, typing over the selection, 5 s limit, clipboard ownership, no copy response, VS Code empty selection, ignored paste, slow paste (also after another process read the text first), refused paste found by a second copy even with a background reader (and skipped after input), unreadable clipboard, later copy preservation, paste policy.")
    }

    @MainActor
    private static func rejected(_ expected: ShortcutFailure, keepsLatest latest: String? = nil,
        change: (Fixture) -> Void) async throws {
        let fixture = Fixture(); defer { fixture.release() }
        let transaction = fixture.transaction(); let text = try await transaction.capture().text
        change(fixture)
        do {
            _ = try await transaction.replace(originalText: text, with: "must not paste")
            preconditionFailure("Expected cancellation")
        } catch let error as ShortcutFailure {
            precondition(error == expected, "Unexpected cancellation: \(error), expected \(expected)")
        }
        precondition(fixture.pasteResult == nil, "Cancelled operations must not send V")
        precondition(!fixture.posted.contains(CGKeyCode(kVK_ANSI_V)))
        let clipboard = fixture.board.string(forType: .string)
        precondition(clipboard == (latest ?? "original clipboard"),
                     "Clipboard after \(expected): \(clipboard ?? "nil")")
    }
}

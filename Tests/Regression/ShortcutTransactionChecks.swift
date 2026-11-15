import AppKit
import Carbon

@MainActor
private final class Fixture {
    let board = NSPasteboard.withUniqueName()
    var activity = ShortcutInputActivity(counters: [100, 20, 0, 0, 0, 0, 0, 0])
    var frontmost = true
    var selection = "繁體原文"
    var posted: [CGKeyCode] = []
    var copied = 0
    var pasteResult: String?
    var afterCopy: (() -> Void)?
    var afterPaste: (() -> Void)?
    var copyWorks = true

    init() {
        board.setString("original clipboard", forType: .string)
    }

    func transaction() -> ShortcutClipboardTransaction {
        ShortcutClipboardTransaction(pasteboard: board, sourceIsFrontmost: { self.frontmost },
            readActivity: { self.activity }, sendKey: { key in
                self.posted.append(key)
                if key == CGKeyCode(kVK_ANSI_C) {
                    self.copied += 1
                    if self.copyWorks {
                        self.board.clearContents()
                        self.board.setString(self.selection, forType: .string)
                    }
                    self.afterCopy?()
                } else if key == CGKeyCode(kVK_ANSI_V) {
                    self.pasteResult = self.board.string(forType: .string)
                    self.afterPaste?()
                }
                return true
            })
    }

    func release() { board.releaseGlobally() }
}

@main
enum ShortcutTransactionChecks {
    @MainActor
    static func main() async throws {
        // End-to-end transaction: two copies, a paste, full clipboard restoration.
        let success = Fixture(); defer { success.release() }
        let rich = NSPasteboardItem(); rich.setString("original clipboard", forType: .string)
        let rtf = Data("{\\rtf1 preserved}".utf8); rich.setData(rtf, forType: .rtf)
        success.board.clearContents(); success.board.writeObjects([rich])
        let transaction = success.transaction()
        let text = try await transaction.capture()
        try await transaction.replace(originalText: text, with: "简体结果")
        precondition(success.posted == [CGKeyCode(kVK_ANSI_C), CGKeyCode(kVK_ANSI_C), CGKeyCode(kVK_ANSI_V)])
        precondition(success.pasteResult == "简体结果")
        precondition(success.board.string(forType: .string) == "original clipboard")
        precondition(success.board.data(forType: .rtf) == rtf)

        // Even a programmatic selection change without input activity must fail.
        try await rejected(.selectionChanged) { fixture, _ in fixture.selection = "另一段文字" }
        try await rejected(.sourceChanged) { fixture, _ in fixture.frontmost = false }
        // Arrow key / text edit, or mouse selection change inside the same app.
        try await rejected(.inputChanged) { fixture, _ in fixture.activity.counters[0] &+= 1 }
        try await rejected(.inputChanged) { fixture, _ in fixture.activity.counters[1] &+= 1 }
        try await rejected(.inputChanged) { fixture, _ in fixture.activity.hasHeldInput = true }
        // Moving away and back to identical text must still fail after user input.
        try await rejected(.inputChanged) { fixture, _ in fixture.activity.counters[0] &+= 2 }
        try await rejected(.clipboardChanged) { fixture, _ in
            fixture.board.clearContents(); fixture.board.setString("latest user copy", forType: .string)
        }
        // A user copy of identical clipboard text is still a new ownership.
        try await rejected(.clipboardChanged) { fixture, _ in
            fixture.board.clearContents(); fixture.board.setString("original clipboard", forType: .string)
        }
        // Interruption during re-copy also prevents V, not just before conversion.
        try await rejected(.inputChanged) { fixture, _ in
            fixture.afterCopy = { fixture.activity.counters[1] &+= 1 }
        }
        try await rejected(.sourceChanged) { fixture, _ in
            fixture.afterCopy = { fixture.frontmost = false }
        }
        try await rejected(.copyUnavailable) { fixture, _ in fixture.copyWorks = false }

        // A new user copy after sending V survives delayed clipboard restoration.
        let laterCopy = Fixture(); defer { laterCopy.release() }
        let later = laterCopy.transaction(); let original = try await later.capture()
        laterCopy.afterPaste = {
            laterCopy.board.clearContents(); laterCopy.board.setString("user copied later", forType: .string)
        }
        try await later.replace(originalText: original, with: "结果")
        precondition(laterCopy.board.string(forType: .string) == "user copied later")
        print("PASS: shortcut transaction success, RTF restore, changed selection, app switch, keyboard/mouse activity, same-text return, clipboard ownership, interruption during re-copy, no copy response, later copy preservation.")
    }

    @MainActor
    private static func rejected(_ expected: ShortcutFailure,
        change: (Fixture, ShortcutClipboardTransaction) -> Void) async throws {
        let fixture = Fixture(); defer { fixture.release() }
        let transaction = fixture.transaction(); let text = try await transaction.capture()
        change(fixture, transaction)
        do {
            try await transaction.replace(originalText: text, with: "must not paste")
            preconditionFailure("Expected cancellation")
        } catch let error as ShortcutFailure {
            precondition(error.messageKey == expected.messageKey, "Unexpected cancellation: \(error)")
        }
        precondition(fixture.pasteResult == nil, "Cancelled operations must not send V")
        precondition(!fixture.posted.contains(CGKeyCode(kVK_ANSI_V)))
    }
}

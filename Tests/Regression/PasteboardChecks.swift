import AppKit

@main
enum PasteboardChecks {
  static func main() {
    // A private named pasteboard never reads or alters the user's general clipboard.
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }

    let textItem = NSPasteboardItem()
    textItem.setString("原始文字", forType: .string)
    let richText = Data("{\\rtf1 rich text}".utf8)
    textItem.setData(richText, forType: .rtf)
    let fileItem = NSPasteboardItem()
    let imageBytes = Data([0x89, 0x50, 0x4e, 0x47, 0, 1, 2, 255])
    fileItem.setData(imageBytes, forType: .png)
    let fileURL = "file:///tmp/OpenCCman-pasteboard-regression.txt"
    fileItem.setString(fileURL, forType: .fileURL)
    precondition(board.writeObjects([textItem, fileItem]))

    let original = PasteboardSnapshot(board)!
    precondition(original.changeCount == board.changeCount)
    let temporaryOwnership = board.clearContents()
    precondition(board.setString("converted text", forType: .string))
    precondition(board.changeCount == temporaryOwnership,
                 "setString must retain the ownership returned by clearContents")
    original.restore(to: board, ifUnchangedSince: temporaryOwnership)
    precondition(board.pasteboardItems?.count == 2, "Preserve every clipboard item")
    precondition(board.pasteboardItems?[0].string(forType: .string) == "原始文字")
    precondition(board.pasteboardItems?[0].data(forType: .rtf) == richText,
                 "Preserve rich text alongside plain text")
    precondition(board.pasteboardItems?[1].data(forType: .png) == imageBytes,
                 "Preserve image data byte-for-byte")
    precondition(board.pasteboardItems?[1].string(forType: .fileURL) == fileURL,
                 "Preserve file URL representations")

    let beforePaste = PasteboardSnapshot(board)!
    let pastedOwnership = board.clearContents()
    board.setString("temporary paste", forType: .string)
    board.clearContents()
    board.setString("user copied afterwards", forType: .string)
    let userOwnership = board.changeCount
    beforePaste.restore(to: board, ifUnchangedSince: pastedOwnership)
    precondition(board.string(forType: .string) == "user copied afterwards",
                 "A delayed restore must preserve a later user copy")
    precondition(board.changeCount == userOwnership,
                 "A skipped restore must not claim pasteboard ownership")

    board.clearContents()
    board.setString("user copied afterwards", forType: .string)
    precondition(board.changeCount != userOwnership,
                 "Copying identical text is still an ownership change")

    board.clearContents()
    let empty = PasteboardSnapshot(board)!
    let emptyTemporaryOwnership = board.clearContents()
    board.setString("temporary", forType: .string)
    empty.restore(to: board, ifUnchangedSince: emptyTemporaryOwnership)
    precondition(board.pasteboardItems?.isEmpty ?? true, "Restore an originally empty clipboard")

    print("PASS: multi-item text/RTF/image/file URL preservation, ownership checks, later user copy, identical text, empty clipboard.")
  }
}

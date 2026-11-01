import Foundation
import UniformTypeIdentifiers

/// Real Foundation providers, without a pasteboard, host app, or service stub.
@MainActor func checkProviders() async throws {
  // A broken cancellation continuation must fail this executable rather than
  // hang CI. Normal progress is signalled by the loader, never by a sleep.
  let watchdog = DispatchWorkItem {
    fatalError("NSItemProvider regression exceeded its 10-second completion deadline")
  }
  DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: watchdog)
  defer { watchdog.cancel() }

  let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCCman-providers-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }

  let filename = "含 空格#文稿.txt"
  let url = directory.appendingPathComponent(filename)
  let text = "\r\n鼠标\0台湾\r\n\n👨‍👩‍👧‍👦e\u{301}\n"
  try (Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)).write(to: url)
  let urlProvider = NSItemProvider(object: url as NSURL)
  precondition(urlProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
  let importedFile = try await TextFileService.read(urlProvider)
  precondition(importedFile.text == text, "NSURL providers preserve whitespace/Unicode/NUL and remove one BOM")
  precondition(importedFile.sourceFilename == filename, "File URLs must decode spaces and escaped punctuation")
  precondition(importedFile.exportFilename == "含 空格#文稿-converted.txt")

  let stringProvider = NSItemProvider(object: text as NSString)
  precondition(!stringProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
  let importedString = try await TextFileService.read(stringProvider)
  precondition(importedString.text == text, "NSString providers preserve plain text exactly")
  precondition(importedString.sourceFilename == nil)
  precondition(importedString.exportFilename == "OpenCCman-converted.txt")

  // Finder drops a TXT as plain text alone: no file URL, no suggested name,
  // only an in-place file representation of the original file.
  let finderProvider = inPlacePlainTextProvider(url)
  precondition(!finderProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
  precondition(finderProvider.suggestedName == nil)
  let importedInPlace = try await TextFileService.read(finderProvider)
  precondition(importedInPlace.text == text, "In-place plain-text files read like file URLs")
  precondition(importedInPlace.sourceFilename == filename, "In-place plain-text drops keep the original filename")

  let largeURL = directory.appendingPathComponent("大文件.txt")
  try Data(repeating: 0x61, count: TextFileService.maximumBytes + 1).write(to: largeURL)
  guard case let .largeFile(largeSource) = try await TextFileService.prepare(inPlacePlainTextProvider(largeURL)) else {
    preconditionFailure("A large in-place plain-text drop must stay on the Mac large-file route")
  }
  precondition(largeSource.sourceFilename == "大文件.txt")
  try largeSource.close()

  // An in-place file that is not a TXT is still read as text only, as before.
  let markdownURL = directory.appendingPathComponent("notes.md")
  try Data(text.utf8).write(to: markdownURL)
  let importedMarkdown = try await TextFileService.read(inPlacePlainTextProvider(markdownURL))
  precondition(importedMarkdown.text == text && importedMarkdown.sourceFilename == nil,
               "Non-TXT in-place files fall back to their text without a filename")

  let loaderStarted = ProviderLoaderSignal()
  let silentProvider = NSItemProvider()
  silentProvider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { _ in
    // Intentionally never invoke the completion callback, including on cancel.
    Task { @MainActor in loaderStarted.signal() }
    return Progress(totalUnitCount: 1)
  }
  let pendingRead = Task { try await TextFileService.read(silentProvider) }
  await loaderStarted.wait()
  pendingRead.cancel()
  do {
    _ = try await pendingRead.value
    preconditionFailure("Cancelling an unresolved provider must throw CancellationError")
  } catch is CancellationError {
    // Completion proves the service resumed its own continuation on cancel.
  }
  print("PASS: real NSURL/NSString/in-place plain-text providers and cancellation without a provider callback")
}

/// Mirrors the provider SwiftUI hands over for a Finder drop: plain text only,
/// served in place from the original file.
private func inPlacePlainTextProvider(_ url: URL) -> NSItemProvider {
  let provider = NSItemProvider()
  provider.registerFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, fileOptions: [.openInPlace],
                                      visibility: .all) { completion in
    completion(url, false, nil)
    return nil
  }
  return provider
}

@MainActor private final class ProviderLoaderSignal {
  private var signalled = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    guard !signalled else { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func signal() {
    signalled = true
    let continuation = continuation
    self.continuation = nil
    continuation?.resume()
  }
}

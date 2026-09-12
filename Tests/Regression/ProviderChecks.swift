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
  print("PASS: real NSURL/NSString providers and cancellation without a provider callback")
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

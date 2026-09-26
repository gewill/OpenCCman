#if os(macOS)
import Foundation
import OpenCC
import UniformTypeIdentifiers

func checkStreamingFiles() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCCman-stream-files-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let input = directory.appendingPathComponent("含 空格#文稿.txt")
  let output = directory.appendingPathComponent("converted.txt")
  let preserved = Data("已有文件：不能丢失".utf8)
  let body = "\r\n头发干杯鼠标\0\0⿰木木👨‍👩‍👧‍👦e\u{301}\n\r\n"
  let options: [ChineseConverter.Options] = [
    .simplify, .traditionalize, [.traditionalize, .twStandard],
    [.traditionalize, .hkStandard], [.traditionalize, .twStandard, .twIdiom],
    [.traditionalize, .twIdiom], [.traditionalize, .hkStandard, .twIdiom]
  ]
  for option in options {
    // Place phrases across actual 256 KiB file reads, including a split scalar.
    let text = String(repeating: "a", count: StreamingTextFileService.bufferBytes - 5) + body + body
    let data = Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    try data.write(to: input)
    try preserved.write(to: output)
    let source = try OpenedTextFile(url: input)
    let observations = FileProgressRecorder()
    let result = try await StreamingTextFileService.convert(source: source, destination: output, options: option) {
      observations.append($0, total: $1)
    }
    let expected = try ChineseConversionService.convertSynchronously(text, options: option)
    let actual = try Data(contentsOf: output)
    precondition(actual == Data(expected.utf8), "Streaming files must exactly match whole conversion in all seven configurations")
    precondition(result.inputBytes == UInt64(data.count) && result.outputBytes == UInt64(actual.count))
    precondition(observations.isMonotonic(total: UInt64(data.count)))
  }
  for bytes in [Data(), Data([0x61]), Data([0x61, 0x62]), Data([0xEF, 0xBB, 0xBF])] {
    try bytes.write(to: input)
    let result = try await StreamingTextFileService.convert(source: OpenedTextFile(url: input), destination: output, options: .traditionalize)
    let actual = try Data(contentsOf: output)
    precondition(actual == (bytes.count == 3 ? Data() : bytes))
    precondition(result.outputBytes == UInt64(actual.count))
  }

  // A real provider's file representation remains consumable after its URL dies.
  try Data(repeating: 0x61, count: TextFileService.maximumBytes + 1).write(to: input)
  let provider = NSItemProvider()
  provider.suggestedName = input.lastPathComponent
  provider.registerFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, fileOptions: [], visibility: .all) { completion in
    completion(input, false, nil)
    return nil
  }
  guard case .largeFile(let prepared) = try await TextFileService.prepare(provider) else {
    preconditionFailure("A large provider file must route without loading its full body")
  }
  precondition(prepared.byteCount == UInt64(TextFileService.maximumBytes + 1))
  try FileManager.default.removeItem(at: input)
  let providerResult = try await StreamingTextFileService.convert(source: prepared, destination: output, options: .traditionalize)
  precondition(providerResult.inputBytes == UInt64(TextFileService.maximumBytes + 1))
  precondition(providerResult.outputBytes == providerResult.inputBytes)

  try Data(body.utf8).write(to: input)
  for alias in [input, directory.appendingPathComponent("hard-link.txt"), directory.appendingPathComponent("symbolic-link.txt")] {
    if alias.lastPathComponent == "hard-link.txt" { try FileManager.default.linkItem(at: input, to: alias) }
    if alias.lastPathComponent == "symbolic-link.txt" { try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: input) }
    do {
      _ = try await StreamingTextFileService.convert(source: OpenedTextFile(url: input), destination: alias, options: .traditionalize)
      preconditionFailure("Source/destination aliases must be rejected")
    } catch StreamingTextFileService.FileError.sameFile {}
    try requireFileBytes(input, Data(body.utf8))
  }

  for invalid in [Data([0xFF]), Data([0xEF, 0xBB]), Data([0xED, 0xA0, 0x80]), Data([0xF0, 0x80, 0x80, 0x80])] {
    try invalid.write(to: input)
    try preserved.write(to: output)
    do {
      _ = try await StreamingTextFileService.convert(source: OpenedTextFile(url: input), destination: output, options: .traditionalize)
      preconditionFailure("Invalid UTF-8 must fail without publishing partial output")
    } catch TextFileService.FileError.invalidUTF8 {}
    try requireFileBytes(output, preserved)
  }

  for fault in [
    StreamingTextFileService.Hooks(beforeRead: { throw POSIXError(.EIO) }),
    StreamingTextFileService.Hooks(beforeWrite: { throw POSIXError(.ENOSPC) }),
    StreamingTextFileService.Hooks(beforeCommit: { throw POSIXError(.EACCES) })
  ] {
    try Data(body.utf8).write(to: input)
    try preserved.write(to: output)
    let temporaryDirectories = FileTemporaryRecorder()
    var hooks = fault
    hooks.temporaryDirectoryCreated = { temporaryDirectories.append($0) }
    do {
      _ = try await StreamingTextFileService.convert(source: OpenedTextFile(url: input), destination: output, options: .traditionalize, hooks: hooks)
      preconditionFailure("Injected read/write/commit failures must propagate")
    } catch is POSIXError {}
    try requireFileBytes(output, preserved)
    precondition(temporaryDirectories.allRemoved, "I/O failure must clean the actual replacement directory before returning")
  }

  // Cleanup failures carry both errors; never report a dirty cancellation as
  // successfully cleaned. Remove the injected residue explicitly in this test.
  try Data(body.utf8).write(to: input)
  try preserved.write(to: output)
  do {
    _ = try await StreamingTextFileService.convert(
      source: OpenedTextFile(url: input), destination: output, options: .traditionalize,
      hooks: .init(beforeWrite: { throw POSIXError(.ENOSPC) }, beforeCleanup: { throw POSIXError(.EACCES) }))
    preconditionFailure("Cleanup failure must be visible")
  } catch let error as StreamingTextFileService.CleanupError {
    precondition((error.primaryError as? POSIXError)?.code == .ENOSPC)
    precondition((error.cleanupError as? POSIXError)?.code == .EACCES)
    precondition(FileManager.default.fileExists(atPath: error.temporaryDirectory.path))
    try FileManager.default.removeItem(at: error.temporaryDirectory)
  }
  try requireFileBytes(output, preserved)

  try Data(body.utf8).write(to: input)
  let sourceChanged = try OpenedTextFile(url: input)
  try Data((body + "变化").utf8).write(to: input)
  do {
    _ = try await StreamingTextFileService.convert(source: sourceChanged, destination: output, options: .traditionalize)
    preconditionFailure("A modified source must be rejected")
  } catch TextFileService.FileError.sourceChanged {}
  try requireFileBytes(output, preserved)

  let replacedSource = try OpenedTextFile(url: input)
  try Data(body.utf8).write(to: input, options: .atomic)
  do {
    _ = try await StreamingTextFileService.convert(source: replacedSource, destination: output, options: .traditionalize)
    preconditionFailure("Replacing a still-present source path must be detected")
  } catch TextFileService.FileError.sourceChanged {}
  try requireFileBytes(output, preserved)

  let changedDestination = Data("其他窗口保存的新内容".utf8)
  do {
    _ = try await StreamingTextFileService.convert(
      source: OpenedTextFile(url: input), destination: output, options: .traditionalize,
      hooks: .init(beforeCommit: { try changedDestination.write(to: output) }))
    preconditionFailure("A changed destination must be preserved")
  } catch StreamingTextFileService.FileError.destinationChanged {}
  try requireFileBytes(output, changedDestination)

  // Cancel while the worker is paused both during I/O and immediately before
  // commit. No continuation may return while that worker still owns the files.
  for beforeCommit in [false, true] {
    try Data(body.utf8).write(to: input)
    try preserved.write(to: output)
    let gate = FileWorkerGate()
    let temporaryDirectories = FileTemporaryRecorder()
    var hooks = beforeCommit
      ? StreamingTextFileService.Hooks(beforeCommit: { gate.block() })
      : StreamingTextFileService.Hooks(beforeRead: { gate.block() })
    hooks.temporaryDirectoryCreated = { temporaryDirectories.append($0) }
    let workerHooks = hooks
    let source = try OpenedTextFile(url: input)
    let task = Task { try await StreamingTextFileService.convert(source: source, destination: output, options: .traditionalize, hooks: workerHooks) }
    await gate.waitUntilBlocked()
    task.cancel()
    try requireFileBytes(output, preserved)
    gate.release()
    do {
      _ = try await task.value
      preconditionFailure("Cancellation before commit must not publish output")
    } catch is CancellationError {}
    try requireFileBytes(output, preserved)
    precondition(temporaryDirectories.allRemoved, "Cancellation must await replacement-directory cleanup")
  }
  print("PASS: bounded file streaming, seven configurations, BOM/NUL/Unicode, real provider lifetime, aliases, invalid UTF-8, I/O faults, changed files and cancellation before commit")
}

private func requireFileBytes(_ url: URL, _ expected: Data) throws {
  let actual = try Data(contentsOf: url)
  precondition(actual == expected)
}

private final class FileTemporaryRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var directories: [URL] = []
  func append(_ url: URL) {
    lock.lock()
    directories.append(url)
    lock.unlock()
  }
  var allRemoved: Bool {
    lock.lock()
    defer { lock.unlock() }
    return !directories.isEmpty && directories.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) }
  }
}

private final class FileProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [(UInt64, UInt64)] = []
  func append(_ processed: UInt64, total: UInt64) {
    lock.lock()
    values.append((processed, total))
    lock.unlock()
  }
  func isMonotonic(total: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return values.first?.0 == 0 && values.last?.0 == total
      && values.allSatisfy { $0.1 == total && $0.0 <= total }
      && zip(values, values.dropFirst()).allSatisfy { $0.0.0 <= $0.1.0 }
  }
}

private final class FileWorkerGate: @unchecked Sendable {
  private let lock = NSLock()
  private let semaphore = DispatchSemaphore(value: 0)
  private var entered = false
  private var continuation: CheckedContinuation<Void, Never>?

  func block() {
    lock.lock()
    guard !entered else { lock.unlock(); return }
    entered = true
    let continuation = continuation
    self.continuation = nil
    lock.unlock()
    continuation?.resume()
    semaphore.wait()
  }
  func release() { semaphore.signal() }
  func waitUntilBlocked() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      let entered = entered
      if !entered { self.continuation = continuation }
      lock.unlock()
      if entered { continuation.resume() }
    }
  }
}
#endif

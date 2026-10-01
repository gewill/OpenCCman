import Foundation
import OpenCC

/// A synchronous, bounded read/convert/write loop for caller-owned handles.
/// Call only on a dedicated worker queue: file I/O and OpenCC are blocking.
/// The caller validates file identity and owns synchronization, closing,
/// cleanup and publication. A successful pump result is not a saved file.
enum StreamingConversionPump {
  static let bufferBytes = 256 * 1024

  struct Result: Equatable, Sendable {
    let inputBytes: UInt64
    let outputBytes: UInt64
  }

  struct Hooks: Sendable {
    var beforeRead: @Sendable () throws -> Void = {}
    var beforeWrite: @Sendable () throws -> Void = {}
    var beforeOutputWrite: @Sendable (Int) throws -> Void = { _ in }
  }

  static func run(
    input: FileHandle,
    output: FileHandle,
    expectedInputBytes: UInt64,
    options: ChineseConverter.Options,
    cancellation: StreamingConversionCancellation,
    progress: @Sendable (UInt64, UInt64) -> Void = { _, _ in },
    hooks: Hooks = Hooks(),
    chunkSize: Int = bufferBytes
  ) throws -> Result {
    precondition(chunkSize > 0 && chunkSize <= bufferBytes)
    try cancellation.check()
    let stream = try ChineseConversionService.converter(options: options).makeStream()
    try cancellation.check()
    var inputBytes: UInt64 = 0
    var outputBytes: UInt64 = 0
    var prefix = Data()
    var hasConsumedPrefix = false
    progress(0, expectedInputBytes)

    func write(_ bytes: Data) throws {
      try cancellation.check()
      guard !bytes.isEmpty else { return }
      try hooks.beforeWrite()
      try hooks.beforeOutputWrite(bytes.count)
      try output.write(contentsOf: bytes)
      outputBytes += UInt64(bytes.count)
    }

    do {
      while true {
        let didRead = try autoreleasepool { () throws -> Bool in
          try cancellation.check()
          try hooks.beforeRead()
          guard var bytes = try input.read(upToCount: chunkSize), !bytes.isEmpty else { return false }
          inputBytes += UInt64(bytes.count)
          guard inputBytes <= expectedInputBytes else { throw TextFileService.FileError.sourceChanged }
          try cancellation.check()
          if !hasConsumedPrefix {
            // A short read may divide the three-byte BOM. Retain only this
            // prefix; all other context belongs to the same OpenCC stream.
            let consumed = min(bytes.count, 3 - prefix.count)
            prefix.append(bytes.prefix(consumed))
            bytes.removeFirst(consumed)
            if prefix.count < 3 { return true }
            hasConsumedPrefix = true
            if !prefix.starts(with: [0xEF, 0xBB, 0xBF]) { try write(stream.append(prefix)) }
            prefix.removeAll(keepingCapacity: false)
          }
          try write(stream.append(bytes))
          progress(inputBytes, expectedInputBytes)
          return true
        }
        if !didRead { break }
      }
      try cancellation.check()
      guard inputBytes == expectedInputBytes else { throw TextFileService.FileError.sourceChanged }
      if !hasConsumedPrefix, !prefix.isEmpty { try write(stream.append(prefix)) }
      try write(stream.finish())
      try cancellation.check()
      return Result(inputBytes: inputBytes, outputBytes: outputBytes)
    } catch ConversionError.invalidUTF8 {
      throw TextFileService.FileError.invalidUTF8
    }
  }
}

/// Cancellation may arrive from any thread while a worker owns the handles.
/// It never closes those handles. The caller releases resources before it
/// resumes its async continuation; commit provides a single publication point.
final class StreamingConversionCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var cancelled = false
  private var committed = false
  private var coordinator: NSFileCoordinator?

  func cancel() {
    lock.lock()
    if !committed { cancelled = true }
    let coordinator = committed ? nil : coordinator
    lock.unlock()
    coordinator?.cancel()
  }

  func setCoordinator(_ coordinator: NSFileCoordinator?) {
    lock.lock()
    self.coordinator = coordinator
    let cancelled = cancelled
    lock.unlock()
    if cancelled { coordinator?.cancel() }
  }

  func check() throws {
    lock.lock()
    let cancelled = cancelled
    lock.unlock()
    if cancelled { throw CancellationError() }
  }

  func commit(_ operation: () throws -> Void) throws {
    lock.lock()
    defer { lock.unlock() }
    if cancelled { throw CancellationError() }
    try operation()
    committed = true
  }
}

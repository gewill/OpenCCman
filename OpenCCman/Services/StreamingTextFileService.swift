#if os(macOS)
import Darwin
import Foundation
import OpenCC
import os

/// Blocking file and C++ work lives on one dedicated queue, outside Swift's
/// cooperative executor. Only the small progress values cross back to the UI.
enum StreamingTextFileService {
  static let bufferBytes = StreamingConversionPump.bufferBytes
  private static let queue = DispatchQueue(label: "OpenCCman.streaming-text-file", qos: .userInitiated)

  struct Result: Sendable {
    let destination: URL
    let inputBytes: UInt64
    let outputBytes: UInt64
  }

  enum FileError: String, LocalizedError {
    case sameFile = "file_error_same_destination"
    case invalidDestination = "file_error_destination"
    case destinationChanged = "file_error_destination_changed"
    case capacity = "large_file_capacity"
    case experimentalCapacity = "mac_file_experimental_capacity"
    case insufficientSpace = "mac_file_insufficient_space"

    var errorDescription: String? { NSLocalizedString(rawValue, comment: "File conversion error") }
  }

  struct CleanupError: LocalizedError {
    let primaryError: Error
    let cleanupError: Error
    let temporaryDirectory: URL

    var errorDescription: String? {
      NSLocalizedString("file_error_temporary_cleanup_failed", comment: "File conversion cleanup error")
    }
    var failureReason: String? { primaryError.localizedDescription }
  }

  /// Fault injection at real I/O boundaries for regression checks. Production
  /// uses the empty defaults; hooks cannot bypass validation or atomic commit.
  struct Hooks: Sendable {
    var temporaryDirectoryCreated: @Sendable (URL) -> Void = { _ in }
    var beforeRead: @Sendable () throws -> Void = {}
    var beforeWrite: @Sendable () throws -> Void = {}
    var beforeCommit: @Sendable () throws -> Void = {}
    var beforeCleanup: @Sendable () throws -> Void = {}
    var availableBytes: @Sendable (URL) throws -> Int64? = {
      var url = $0
      url.removeAllCachedResourceValues()
      return try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        .volumeAvailableCapacityForImportantUsage
    }
  }

  static func convert(
    source: OpenedTextFile,
    destination: URL,
    options: ChineseConverter.Options,
    capacity: MacFileCapacity = .standard,
    progress: @escaping @Sendable (UInt64, UInt64) -> Void = { _, _ in },
    hooks: Hooks = Hooks()
  ) async throws -> Result {
    let cancellation = StreamingConversionCancellation()
    let optionsRawValue = options.rawValue
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        queue.async {
          // run's cleanup has completed before resuming, including cancellation.
          // The coordinator can now safely release the single-task slot.
          do {
            let result = try run(source: source, destination: destination, options: ChineseConverter.Options(rawValue: optionsRawValue),
                                 capacity: capacity, progress: progress, cancellation: cancellation, hooks: hooks)
            continuation.resume(returning: result)
          } catch ConversionError.invalidUTF8 {
            continuation.resume(throwing: TextFileService.FileError.invalidUTF8)
          } catch { continuation.resume(throwing: error) }
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  private static func run(
    source: OpenedTextFile,
    destination: URL,
    options: ChineseConverter.Options,
    capacity: MacFileCapacity,
    progress: @Sendable (UInt64, UInt64) -> Void,
    cancellation: StreamingConversionCancellation,
    hooks: Hooks
  ) throws -> Result {
    defer { try? source.close() }
    try cancellation.check()
    guard source.byteCount <= capacity.maximumInputBytes else {
      throw capacity == .standard ? FileError.capacity : FileError.experimentalCapacity
    }
    guard destination.isFileURL else { throw FileError.invalidDestination }
    let destinationScoped = destination.startAccessingSecurityScopedResource()
    defer { if destinationScoped { destination.stopAccessingSecurityScopedResource() } }

    let input = try source.beginReading()
    try source.verifyUnchanged(input)
    let destinationFingerprint = try TextFileFingerprint.read(url: destination, followSymlink: false)
    if let resolved = try TextFileFingerprint.read(url: destination), source.fingerprint.isSameFile(as: resolved) {
      throw FileError.sameFile
    }
    // Do not replace a symlink itself or an unrelated nonregular filesystem item.
    if let destinationFingerprint, !destinationFingerprint.isRegular { throw FileError.invalidDestination }
    let fileManager = FileManager.default
    let replacementDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                    appropriateFor: destination, create: true)
    hooks.temporaryDirectoryCreated(replacementDirectory)
    let temporaryURL = replacementDirectory.appendingPathComponent(UUID().uuidString + ".txt")
    do {
      guard let estimated = MacFileCapacity.estimatedStorageBytes(for: source.byteCount) else {
        throw FileError.insufficientSpace
      }
      let storage = StorageMonitor(directory: replacementDirectory, query: hooks.availableBytes)
      try storage.require(estimated)
      let output = try openOutput(at: temporaryURL)
      defer { try? output.close() }
      let result = try StreamingConversionPump.run(
        input: input, output: output, expectedInputBytes: source.byteCount,
        options: options, cancellation: cancellation, progress: progress,
        hooks: .init(beforeRead: hooks.beforeRead, beforeWrite: hooks.beforeWrite,
                     beforeOutputWrite: { try storage.beforeWrite($0) }))
      try source.verifyUnchanged(input)
      // Detect synchronization/close failures before making the output visible.
      try output.synchronize()
      try output.close()
      try source.close()
      try cancellation.check()
      try hooks.beforeCommit()
      let coordinator = NSFileCoordinator(filePresenter: nil)
      cancellation.setCoordinator(coordinator)
      defer { cancellation.setCoordinator(nil) }
      var coordinationError: NSError?
      var commitResult: Swift.Result<Void, Error>?
      coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { coordinatedURL in
        commitResult = Swift.Result {
          // Coordination can wait for another document writer. Only hold the
          // cancellation lock inside its accessor, never while waiting for it.
          try cancellation.commit {
            guard try TextFileFingerprint.read(url: coordinatedURL, followSymlink: false) == destinationFingerprint else {
              throw FileError.destinationChanged
            }
            try atomicCommit(temporaryURL, to: coordinatedURL, replacing: destinationFingerprint != nil)
          }
        }
      }
      if let commitResult { try commitResult.get() }
      else {
        try cancellation.check()
        throw coordinationError ?? CocoaError(.fileWriteUnknown)
      }
      // The data has moved out of staging. Failure to remove this now-empty
      // directory must not turn a committed export into a reported failure.
      do { try fileManager.removeItem(at: replacementDirectory) }
      catch {
        Logger(subsystem: "OpenCCman", category: "FileConversion")
          .error("Could not remove empty conversion directory: \(error.localizedDescription, privacy: .private)")
      }
      // A cancellation after the atomic commit cannot undo a completed export.
      return Result(destination: destination, inputBytes: result.inputBytes, outputBytes: result.outputBytes)
    } catch {
      let primaryError = error
      do {
        try hooks.beforeCleanup()
        // Explicitly unlink private output before removing its directory. Do not
        // silently leave converted text behind after cancellation or failure.
        let status = temporaryURL.withUnsafeFileSystemRepresentation { path -> Int32 in
          guard let path else { return -1 }
          return unlink(path)
        }
        if status != 0 && errno != ENOENT { throw TextFileFingerprint.posixError() }
        try fileManager.removeItem(at: replacementDirectory)
      } catch {
        throw CleanupError(primaryError: primaryError, cleanupError: error, temporaryDirectory: replacementDirectory)
      }
      throw primaryError
    }
  }

  private static func openOutput(at url: URL) throws -> FileHandle {
    let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else { return -1 }
      return open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, S_IRUSR | S_IWUSR)
    }
    guard descriptor >= 0 else { throw TextFileFingerprint.posixError() }
    return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
  }

  /// Confined to the file worker. Query the destination volume, not the source
  /// or app-container volume; neither a nil estimate nor an early pass promises
  /// that later writes will succeed.
  private final class StorageMonitor: @unchecked Sendable {
    let directory: URL
    let query: @Sendable (URL) throws -> Int64?
    private var remaining: UInt64 = 0
    init(directory: URL, query: @escaping @Sendable (URL) throws -> Int64?) {
      self.directory = directory
      self.query = query
    }
    func require(_ bytes: UInt64) throws {
      if let available = try query(directory), available < 0 || UInt64(available) < bytes {
        throw FileError.insufficientSpace
      }
    }
    func beforeWrite(_ count: Int) throws {
      let count = UInt64(count)
      if count >= remaining {
        let (required, overflow) = count.addingReportingOverflow(64 * 1024 * 1024)
        guard !overflow else { throw FileError.insufficientSpace }
        try require(required)
        remaining = 4 * 1024 * 1024
      }
      remaining -= min(remaining, count)
    }
  }

  private static func atomicCommit(_ temporary: URL, to destination: URL, replacing: Bool) throws {
    let status = temporary.withUnsafeFileSystemRepresentation { temporaryPath in
      destination.withUnsafeFileSystemRepresentation { destinationPath -> Int32 in
        guard let temporaryPath, let destinationPath else { return -1 }
        // EXCL closes the race where a previously absent destination appears.
        return renamex_np(temporaryPath, destinationPath, replacing ? 0 : UInt32(RENAME_EXCL))
      }
    }
    guard status == 0 else { throw TextFileFingerprint.posixError() }
  }
}
#endif

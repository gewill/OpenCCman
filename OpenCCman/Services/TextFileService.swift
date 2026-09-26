import Darwin
import Foundation
import UniformTypeIdentifiers

/// Owns the opened descriptor and its security scope, including provider files
/// whose temporary URL disappears after the provider callback returns.
final class OpenedTextFile: @unchecked Sendable {
  let sourceURL: URL
  let sourceFilename: String
  let byteCount: UInt64
  let fingerprint: TextFileFingerprint

  private let lock = NSLock()
  private var handle: FileHandle?
  private var scoped: Bool
  private var claimed = false

  var exportFilename: String {
    TextFileService.ImportedText(text: "", sourceFilename: sourceFilename).exportFilename
  }

  init(url: URL, sourceFilename: String? = nil) throws {
    let filename: String
    if let sourceFilename, sourceFilename.lowercased().hasSuffix(".txt") {
      filename = (sourceFilename as NSString).lastPathComponent
    } else {
      filename = url.lastPathComponent
    }
    guard url.isFileURL, (filename as NSString).pathExtension.lowercased() == "txt" else {
      throw TextFileService.FileError.unsupportedFile
    }
    let scoped = url.startAccessingSecurityScopedResource()
    do {
      // Nonblocking open prevents a disguised FIFO from hanging before fstat
      // can reject it. This flag has no effect on regular-file reads.
      let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
        guard let path else { return -1 }
        return open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
      }
      guard descriptor >= 0 else { throw TextFileFingerprint.posixError() }
      let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
      do {
        let fingerprint = try TextFileFingerprint.read(descriptor: handle.fileDescriptor)
        guard fingerprint.isRegular else { throw TextFileService.FileError.unsupportedFile }
        self.handle = handle
        self.fingerprint = fingerprint
        byteCount = fingerprint.size
      } catch {
        try? handle.close()
        throw error
      }
    } catch {
      if scoped { url.stopAccessingSecurityScopedResource() }
      throw error
    }
    self.sourceURL = url
    self.sourceFilename = filename
    self.scoped = scoped
  }

  /// Only one worker may consume an import. The worker owns all descriptor I/O
  /// until close; other threads may read the immutable metadata only.
  func beginReading() throws -> FileHandle {
    lock.lock()
    defer { lock.unlock() }
    guard !claimed, let handle else { throw TextFileService.FileError.sourceUnavailable }
    claimed = true
    return handle
  }

  func verifyUnchanged(_ handle: FileHandle) throws {
    guard try TextFileFingerprint.read(descriptor: handle.fileDescriptor) == fingerprint else {
      throw TextFileService.FileError.sourceChanged
    }
    // Missing provider paths are valid while the descriptor remains open. An
    // existing path that now identifies another file is an observable change.
    if let current = try TextFileFingerprint.read(url: sourceURL), !current.isSameFile(as: fingerprint) {
      throw TextFileService.FileError.sourceChanged
    }
  }

  func close() throws {
    lock.lock()
    let handle = handle
    self.handle = nil
    let scoped = scoped
    self.scoped = false
    lock.unlock()
    defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
    try handle?.close()
  }

  deinit { try? close() }
}

/// Nanosecond modification times detect in-place writes. Link count and ctime
/// are intentionally excluded: a provider is allowed to unlink its temporary
/// path while our descriptor still holds the unchanged contents alive.
struct TextFileFingerprint: Equatable, Sendable {
  let device: dev_t
  let inode: ino_t
  let size: UInt64
  let modifiedSeconds: Int
  let modifiedNanoseconds: Int
  let isRegular: Bool

  init(_ value: stat) {
    device = value.st_dev
    inode = value.st_ino
    size = UInt64(max(0, value.st_size))
    modifiedSeconds = value.st_mtimespec.tv_sec
    modifiedNanoseconds = value.st_mtimespec.tv_nsec
    isRegular = value.st_mode & S_IFMT == S_IFREG
  }

  static func read(descriptor: Int32) throws -> Self {
    var value = stat()
    guard fstat(descriptor, &value) == 0 else { throw posixError() }
    return Self(value)
  }

  static func read(url: URL, followSymlink: Bool = true) throws -> Self? {
    var value = stat()
    let status = url.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else { return -1 }
      return followSymlink ? stat(path, &value) : lstat(path, &value)
    }
    if status != 0 {
      if errno == ENOENT { return nil }
      throw posixError()
    }
    return Self(value)
  }

  func isSameFile(as other: Self) -> Bool { device == other.device && inode == other.inode }

  static func posixError() -> Error { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}

enum TextFileService {
  static let maximumBytes = 10 * 1024 * 1024
  private static let queue = DispatchQueue(label: "OpenCCman.text-file", qos: .userInitiated)

  struct ImportedText: Sendable {
    let text: String
    let sourceFilename: String?

    var exportFilename: String {
      guard let sourceFilename else { return "OpenCCman-converted.txt" }
      let stem = (sourceFilename as NSString).deletingPathExtension
      return "\(stem.isEmpty ? "OpenCCman" : stem)-converted.txt"
    }
  }

  enum PreparedImport: Sendable {
    case text(ImportedText)
    case largeFile(OpenedTextFile)
  }

  enum FileError: String, LocalizedError {
    case unsupportedFile = "file_error_type"
    case tooLarge = "file_error_size"
    case invalidUTF8 = "file_error_encoding"
    case multipleItems = "file_error_single_item"
    case sourceChanged = "file_error_source_changed"
    case sourceUnavailable = "file_error_source_unavailable"

    var errorDescription: String? { NSLocalizedString(rawValue, comment: "Text import error") }
  }

  static func decode(_ data: Data) throws -> String {
    guard data.count <= maximumBytes else { throw FileError.tooLarge }
    let bytes = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
    guard let text = String(data: bytes, encoding: .utf8) else { throw FileError.invalidUTF8 }
    return text
  }

  static func read(_ url: URL) async throws -> ImportedText {
    guard case .text(let text) = try await load(url, allowLargeFile: false) else { throw FileError.tooLarge }
    return text
  }

  static func read(_ provider: NSItemProvider) async throws -> ImportedText {
    guard case .text(let text) = try await load(provider, allowLargeFile: false) else { throw FileError.tooLarge }
    return text
  }

  static func prepare(_ url: URL) async throws -> PreparedImport {
    try await load(url, allowLargeFile: true)
  }

  static func prepare(_ provider: NSItemProvider) async throws -> PreparedImport {
    try await load(provider, allowLargeFile: true)
  }

  private static func load(_ url: URL, allowLargeFile: Bool) async throws -> PreparedImport {
    let cancellation = ReadCancellation()
    return try await withTaskCancellationHandler(operation: {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        guard cancellation.install(continuation) else { return }
        queue.async {
          do {
            try cancellation.check()
            let source = try OpenedTextFile(url: url)
            cancellation.finish(.success(try prepare(source, allowLargeFile: allowLargeFile, cancellation: cancellation)))
          } catch { cancellation.finish(.failure(error)) }
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  private static func load(_ provider: NSItemProvider, allowLargeFile: Bool) async throws -> PreparedImport {
    let cancellation = ReadCancellation()
    return try await withTaskCancellationHandler(operation: {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        guard cancellation.install(continuation) else { return }
        // Open inside the callback, before a provider can remove its file URL.
        let providerFilename = provider.suggestedName
        let receiveFile: @Sendable (URL?, Error?) -> Void = { url, error in
          do {
            try cancellation.check()
            if let error { throw error }
            guard let url else { throw FileError.unsupportedFile }
            let source = try OpenedTextFile(url: url, sourceFilename: providerFilename)
            queue.async {
              do { cancellation.finish(.success(try prepare(source, allowLargeFile: allowLargeFile, cancellation: cancellation))) }
              catch { cancellation.finish(.failure(error)) }
            }
          } catch { cancellation.finish(.failure(error)) }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          let progress = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
            let url = data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            receiveFile(url, error)
          }
          cancellation.setProgress(progress)
        } else if provider.suggestedName?.lowercased().hasSuffix(".txt") == true {
          let progress = provider.loadFileRepresentation(forTypeIdentifier: UTType.plainText.identifier, completionHandler: receiveFile)
          cancellation.setProgress(progress)
        } else {
          let progress = provider.loadObject(ofClass: NSString.self) { item, error in
            queue.async {
              do {
                try cancellation.check()
                if let error { throw error }
                guard let text = item as? String else { throw FileError.unsupportedFile }
                guard text.utf8.count <= maximumBytes else { throw FileError.tooLarge }
                cancellation.finish(.success(.text(ImportedText(text: text, sourceFilename: nil))))
              } catch { cancellation.finish(.failure(error)) }
            }
          }
          cancellation.setProgress(progress)
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  private static func prepare(_ source: OpenedTextFile, allowLargeFile: Bool, cancellation: ReadCancellation) throws -> PreparedImport {
    try cancellation.check()
    if source.byteCount > UInt64(maximumBytes) {
      #if os(macOS)
        if allowLargeFile { return .largeFile(source) }
      #endif
      throw FileError.tooLarge
    }
    let handle = try source.beginReading()
    defer { try? source.close() }
    var data = Data()
    while true {
      try cancellation.check()
      // Bound allocation even if the file grows after opening.
      let count = min(64 * 1024, maximumBytes - data.count + 1)
      guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
      data.append(chunk)
      guard data.count <= maximumBytes else { throw FileError.tooLarge }
    }
    try cancellation.check()
    try source.verifyUnchanged(handle)
    let text = try decode(data)
    try source.close()
    return .text(ImportedText(text: text, sourceFilename: source.sourceFilename))
  }

  private final class ReadCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var progress: Progress?
    private var continuation: CheckedContinuation<PreparedImport, Error>?
    private var finished = false

    func install(_ continuation: CheckedContinuation<PreparedImport, Error>) -> Bool {
      lock.lock()
      let cancelled = cancelled
      if !cancelled { self.continuation = continuation }
      lock.unlock()
      if cancelled { continuation.resume(throwing: CancellationError()) }
      return !cancelled
    }

    func finish(_ result: Result<PreparedImport, Error>) {
      lock.lock()
      guard !finished else { lock.unlock(); return }
      finished = true
      let continuation = continuation
      self.continuation = nil
      progress = nil
      lock.unlock()
      continuation?.resume(with: result)
    }

    func check() throws {
      lock.lock()
      let cancelled = cancelled
      lock.unlock()
      if cancelled { throw CancellationError() }
    }

    func cancel() {
      lock.lock()
      cancelled = true
      finished = true
      let progress = progress
      self.progress = nil
      let continuation = continuation
      self.continuation = nil
      lock.unlock()
      // Providers may never call back after cancellation; close any late file
      // through its owner instead of waiting forever for the provider.
      continuation?.resume(throwing: CancellationError())
      progress?.cancel()
    }

    func setProgress(_ progress: Progress) {
      lock.lock()
      if !finished { self.progress = progress }
      let cancelled = cancelled
      lock.unlock()
      if cancelled { progress.cancel() }
    }
  }
}

import Foundation
import UniformTypeIdentifiers

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

  enum FileError: String, LocalizedError {
    case unsupportedFile = "file_error_type"
    case tooLarge = "file_error_size"
    case invalidUTF8 = "file_error_encoding"
    case multipleItems = "file_error_single_item"

    var errorDescription: String? { NSLocalizedString(rawValue, comment: "Text import error") }
  }

  static func decode(_ data: Data) throws -> String {
    guard data.count <= maximumBytes else { throw FileError.tooLarge }
    let bytes = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data[...]
    guard let text = String(data: bytes, encoding: .utf8) else { throw FileError.invalidUTF8 }
    return text
  }

  static func read(_ url: URL) async throws -> ImportedText {
    let cancellation = ReadCancellation()
    return try await withTaskCancellationHandler(operation: {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        guard cancellation.install(continuation) else { return }
        queue.async {
          do {
            try cancellation.check()
            let source = try OpenFile(url: url)
            cancellation.finish(.success(try source.read(cancellation: cancellation)))
          } catch { cancellation.finish(.failure(error)) }
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  static func read(_ provider: NSItemProvider) async throws -> ImportedText {
    let cancellation = ReadCancellation()
    return try await withTaskCancellationHandler(operation: {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        guard cancellation.install(continuation) else { return }
        // Open the file inside the provider callback. The descriptor stays valid
        // if the provider deletes its temporary URL after the callback returns.
        let providerFilename = provider.suggestedName
        let receiveFile: @Sendable (URL?, Error?) -> Void = { url, error in
          do {
            try cancellation.check()
            if let error { throw error }
            guard let url else { throw FileError.unsupportedFile }
            let source = try OpenFile(url: url, sourceFilename: providerFilename)
            queue.async {
              do { cancellation.finish(.success(try source.read(cancellation: cancellation))) }
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
                cancellation.finish(.success(ImportedText(text: text, sourceFilename: nil)))
              } catch { cancellation.finish(.failure(error)) }
            }
          }
          cancellation.setProgress(progress)
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  private final class OpenFile: @unchecked Sendable {
    let url: URL
    let handle: FileHandle
    let scoped: Bool
    let sourceFilename: String

    init(url: URL, sourceFilename: String? = nil) throws {
      let filename: String
      if let sourceFilename, sourceFilename.lowercased().hasSuffix(".txt") {
        filename = (sourceFilename as NSString).lastPathComponent
      } else {
        filename = url.lastPathComponent
      }
      guard url.isFileURL, (filename as NSString).pathExtension.lowercased() == "txt" else { throw FileError.unsupportedFile }
      let scoped = url.startAccessingSecurityScopedResource()
      do {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw FileError.unsupportedFile }
        if let size = values.fileSize, size > maximumBytes { throw FileError.tooLarge }
        handle = try FileHandle(forReadingFrom: url)
      } catch {
        if scoped { url.stopAccessingSecurityScopedResource() }
        throw error
      }
      self.url = url
      self.scoped = scoped
      self.sourceFilename = filename
    }

    func read(cancellation: ReadCancellation) throws -> ImportedText {
      var data = Data()
      while true {
        try cancellation.check()
        // Read at most limit + 1 even when size metadata is missing or stale.
        let count = min(64 * 1024, maximumBytes - data.count + 1)
        guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { break }
        data.append(chunk)
        guard data.count <= maximumBytes else { throw FileError.tooLarge }
      }
      try cancellation.check()
      return ImportedText(text: try decode(data), sourceFilename: sourceFilename)
    }

    deinit {
      try? handle.close()
      if scoped { url.stopAccessingSecurityScopedResource() }
    }
  }

  private final class ReadCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var progress: Progress?
    private var continuation: CheckedContinuation<ImportedText, Error>?
    private var finished = false

    func install(_ continuation: CheckedContinuation<ImportedText, Error>) -> Bool {
      lock.lock()
      let cancelled = cancelled
      if !cancelled { self.continuation = continuation }
      lock.unlock()
      if cancelled { continuation.resume(throwing: CancellationError()) }
      return !cancelled
    }

    func finish(_ result: Result<ImportedText, Error>) {
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
      // A provider is allowed to stop without calling back after cancellation.
      // Resume here, and ignore a late callback through finish's single gate.
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

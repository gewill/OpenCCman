import Foundation
import UniformTypeIdentifiers

/// Reads the text a host shares. Hosts disagree on the form: Safari's selection
/// cannot be coerced to NSString, Files passes a file URL without a name, and
/// others pass a String, attributed text or UTF-8 data. Every form keeps the
/// editor's 10 MiB limit and UTF-8 rules.
enum TextActionInput {
  static func read(_ items: [NSExtensionItem]) async throws -> String {
    let providers = items.flatMap { $0.attachments ?? [] }
    if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
      return try await read(provider)
    }
    // Some hosts fill in only the item's attributed text, with no attachment.
    guard let text = items.lazy.compactMap({ $0.attributedContentText?.string }).first else {
      throw TextFileService.FileError.unsupportedFile
    }
    return text
  }

  static func read(_ provider: NSItemProvider) async throws -> String {
    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      return try await readFile(provider)
    }
    let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
    switch item {
    case let text as String:
      return text
    case let text as NSAttributedString:
      return text.string
    case let data as Data:
      return try TextFileService.decode(data)
    case let url as URL where url.isFileURL:
      return try await TextFileService.read(url).text
    default:
      throw TextFileService.FileError.unsupportedFile
    }
  }

  /// The system's copy of a shared file exists only during the callback, so
  /// its size is checked and its bytes are read there.
  private static func readFile(_ provider: NSItemProvider) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.plainText.identifier) { url, error in
        continuation.resume(with: Result {
          if let error { throw error }
          guard let url else { throw TextFileService.FileError.unsupportedFile }
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= TextFileService.maximumBytes else { throw TextFileService.FileError.tooLarge }
          return try TextFileService.decode(Data(contentsOf: url))
        })
      }
    }
  }
}

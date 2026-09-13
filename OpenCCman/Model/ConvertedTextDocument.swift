import SwiftUI
import UniformTypeIdentifiers

/// A value snapshot: subsequent edits/conversions cannot alter an open export.
struct ConvertedTextDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  let text: String

  init(text: String) { self.text = text }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw TextFileService.FileError.unsupportedFile
    }
    text = try TextFileService.decode(data)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

import Foundation
import OpenCC

/// State of the Share sheet action. Like the Shortcuts action it is free and
/// unlimited: it reads neither purchases nor the daily quota.
@MainActor
final class TextActionModel: ObservableObject {
  enum Phase: Equatable {
    case loading
    case converting
    case converted
    case failed(String)
  }

  static let presetKey = "textActionPreset"
  /// The preview is a prefix only; Copy, Share and Done always use the full result.
  static let previewCharacters = 3_000

  @Published private(set) var phase: Phase = .loading
  @Published private(set) var result: String?
  @Published private(set) var inputCharacterCount = 0
  @Published var preset: ConversionConfiguration.Preset {
    didSet {
      guard preset != oldValue else { return }
      defaults.set(preset.rawValue, forKey: Self.presetKey)
      convert()
    }
  }

  private var input: String?
  private var task: Task<Void, Never>?
  private var generation = 0
  private let defaults: Foundation.UserDefaults

  init(defaults: Foundation.UserDefaults = .standard) {
    self.defaults = defaults
    preset = defaults.string(forKey: Self.presetKey).flatMap(ConversionConfiguration.Preset.init(rawValue:))
      ?? .traditional
  }

  deinit { task?.cancel() }

  var preview: (text: String, isTruncated: Bool)? {
    guard let result else { return nil }
    let prefix = result.prefix(Self.previewCharacters)
    return (String(prefix), prefix.endIndex != result.endIndex)
  }

  /// Reads the host's text once, then converts it with the remembered preset.
  func receive(_ read: @escaping () async throws -> String) {
    generation += 1
    let current = generation
    task?.cancel()
    phase = .loading
    task = Task {
      do {
        let text = try await read()
        guard current == generation else { return }
        guard text.utf8.count <= TextFileService.maximumBytes else { throw TextFileService.FileError.tooLarge }
        guard !text.isEmpty else { throw TextFileService.FileError.unsupportedFile }
        input = text
        inputCharacterCount = text.count
        convert()
      } catch {
        guard current == generation else { return }
        phase = .failed(Self.message(for: error))
      }
    }
  }

  private func convert() {
    guard let input else { return }
    generation += 1
    let current = generation
    task?.cancel()
    result = nil
    phase = .converting
    let options = preset.configuration.options
    task = Task {
      do {
        let worker = Task.detached(priority: .userInitiated) { try Self.convertInChunks(input, options: options) }
        let converted = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
        // A preset changed while this ran; only the newest conversion may publish.
        guard current == generation else { return }
        result = converted
        phase = .converted
      } catch {
        guard current == generation, !(error is CancellationError) else { return }
        phase = .failed(String(format: NSLocalizedString("text_action_conversion_failed", comment: ""),
                               error.localizedDescription))
      }
    }
  }

  /// Same output as converting the whole string, but OpenCC only ever holds one
  /// chunk's segments: a whole 10 MiB conversion briefly needs several copies of
  /// the text, too many for an extension's memory limit.
  nonisolated static func convertInChunks(_ text: String, options: ChineseConverter.Options,
                                          chunkBytes: Int = 256 * 1024) throws -> String {
    let stream = try ChineseConversionService.converter(options: options).makeStream()
    var output = Data()
    output.reserveCapacity(text.utf8.count)
    var text = text
    try text.withUTF8 { bytes in
      var offset = 0
      while offset < bytes.count {
        try Task.checkCancellation()
        let end = min(offset + chunkBytes, bytes.count)
        output.append(try stream.append(Data(bytes[offset..<end])))
        offset = end
      }
    }
    output.append(try stream.finish())
    try Task.checkCancellation()
    guard let result = String(data: output, encoding: .utf8) else { throw TextFileService.FileError.invalidUTF8 }
    return result
  }

  static func message(for error: Error) -> String {
    if case TextFileService.FileError.unsupportedFile = error {
      return NSLocalizedString("text_action_empty", comment: "No text was shared")
    }
    return error.localizedDescription
  }
}

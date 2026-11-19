import Foundation
import OpenCC

actor ChineseConversionService {
  static let shared = ChineseConversionService()

  private static let cache = ConverterCache()

  // NSServices must return synchronously. Share construction with the background
  // path: SwiftyOpenCC's dictionary cache does not synchronize all of its reads.
  nonisolated static func converter(_ configuration: ChineseConverter.Configuration) throws -> ChineseConverter {
    try cache.converter(configuration)
  }

  nonisolated static func convertSynchronously(_ text: String, configuration: ChineseConverter.Configuration) throws -> String {
    let converter = try converter(configuration)
    // The pinned wrapper passes byte lengths and preserves NUL in its bridge.
    // Avoid a second full UTF-8 scan, especially for NSString-backed input.
    return converter.convert(text)
  }

  func convert(_ text: String, configuration: ChineseConverter.Configuration) throws -> String {
    try Task.checkCancellation()
    // Keep phrase context and every original separator intact.
    let result = try Self.convertSynchronously(text, configuration: configuration)
    try Task.checkCancellation()
    return result
  }

  // ChineseConverter is immutable and thread-safe. Only its construction and
  // this cache need a lock. The app offers fourteen official configurations.
  private final class ConverterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var converters: [String: ChineseConverter] = [:]

    func converter(_ configuration: ChineseConverter.Configuration) throws -> ChineseConverter {
      lock.lock()
      defer { lock.unlock() }
      if let converter = converters[configuration.rawValue] {
        return converter
      }
      let converter = try ChineseConverter(configuration: configuration)
      converters[configuration.rawValue] = converter
      return converter
    }
  }
}

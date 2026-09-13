import Foundation
import OpenCC

actor ChineseConversionService {
  static let shared = ChineseConversionService()

  private static let cache = ConverterCache()

  // NSServices must return synchronously. Share construction with the background
  // path: SwiftyOpenCC's dictionary cache does not synchronize all of its reads.
  nonisolated static func converter(options: ChineseConverter.Options) throws -> ChineseConverter {
    try cache.converter(options: options)
  }

  nonisolated static func convertSynchronously(_ text: String, options: ChineseConverter.Options) throws -> String {
    let converter = try converter(options: options)
    // The dependency bridges through a null-terminated C string. Convert each
    // null-delimited span so pasted U+0000 cannot silently discard the suffix.
    guard text.utf8.contains(0) else { return converter.convert(text) }
    return text.split(separator: "\0", omittingEmptySubsequences: false)
      .map { converter.convert(String($0)) }
      .joined(separator: "\0")
  }

  func convert(_ text: String, options: ChineseConverter.Options) throws -> String {
    try Task.checkCancellation()
    // Keep phrase context and every original separator intact.
    let result = try Self.convertSynchronously(text, options: options)
    try Task.checkCancellation()
    return result
  }

  // ChineseConverter is immutable and thread-safe. Only its construction and
  // this cache need a lock. The app exposes seven distinct option combinations.
  private final class ConverterCache: @unchecked Sendable {
    private let lock = NSLock()
    private var converters: [Int: ChineseConverter] = [:]

    func converter(options: ChineseConverter.Options) throws -> ChineseConverter {
      lock.lock()
      defer { lock.unlock() }
      if let converter = converters[options.rawValue] {
        return converter
      }
      let converter = try ChineseConverter(options: options)
      converters[options.rawValue] = converter
      return converter
    }
  }
}

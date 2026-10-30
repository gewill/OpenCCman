import CryptoKit
import Foundation
import OpenCC

/// Mac-only reference: one whole-text convert call, no application stream/pump.
@main enum MobileCapacityOracle {
  static func main() throws {
    let args = CommandLine.arguments
    guard args.count == 4 else { throw CocoaError(.fileReadInvalidFileName) }
    let modes: [String: ChineseConverter.Options] = [
      "simplified": .simplify,
      "traditional": .traditionalize,
      "traditional-taiwan-idiom": [.traditionalize, .twIdiom],
      "taiwan": [.traditionalize, .twStandard],
      "taiwan-idiom": [.traditionalize, .twStandard, .twIdiom],
      "hong-kong": [.traditionalize, .hkStandard],
      "hong-kong-taiwan-idiom": [.traditionalize, .hkStandard, .twIdiom],
    ]
    guard let options = modes[args[2]] else { throw CocoaError(.fileReadUnknown) }
    let input = try Data(contentsOf: URL(fileURLWithPath: args[1]))
    // File semantics strip exactly one initial UTF-8 BOM. Interior U+FEFF stays.
    let payload = input.starts(with: [0xef, 0xbb, 0xbf]) ? input.dropFirst(3) : input[...]
    guard let text = String(data: payload, encoding: .utf8) else {
      throw CocoaError(.fileReadInapplicableStringEncoding)
    }
    let converter = try ChineseConverter(options: options)
    let result = Data(converter.convert(text).utf8)
    func hash(_ data: Data) -> String {
      SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    let report: [String: Any] = ["mode": args[2], "options_raw": options.rawValue,
      "input_bytes": input.count, "input_sha256": hash(input),
      "output_bytes": result.count, "output_sha256": hash(result),
      "method": "one whole-text ChineseConverter.convert; strip one initial UTF-8 BOM"]
    let encoded = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    try encoded.write(to: URL(fileURLWithPath: args[3]), options: .withoutOverwriting)
  }
}

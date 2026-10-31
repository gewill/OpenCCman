import CryptoKit
import Foundation
import OpenCC

/// Independent whole-file Mac reference. This target never calls makeStream.
@main enum StreamingPumpOracle {
  static func main() throws {
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let source = directory.appendingPathComponent("oracle-input.txt")
    try StreamingPumpCapacityFixture.write(to: source)
    defer { try? FileManager.default.removeItem(at: source) }
    let sourceHash = try StreamingPumpCapacityFixture.hash(source)
    let options: [ChineseConverter.Options] = [
      .simplify, .traditionalize, [.traditionalize, .twStandard], [.traditionalize, .hkStandard],
      [.traditionalize, .twStandard, .twIdiom], [.traditionalize, .twIdiom],
      [.traditionalize, .hkStandard, .twIdiom]
    ]
    var references: [[String: Any]] = []
    for option in options {
      try autoreleasepool {
        var data = try Data(contentsOf: source)
        data.removeFirst(3)
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let converted = try ChineseConversionService.convertSynchronously(text, options: option)
        let bytes = Data(converted.utf8)
        references.append([
          "options": option.rawValue, "output_bytes": bytes.count,
          "output_sha256": SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        ])
      }
    }
    let report: [String: Any] = [
      "oracle": "Pinned wrapper whole-text convert; no streaming reference",
      "input_bytes": StreamingPumpCapacityFixture.byteCount,
      "input_sha256": sourceHash, "references": references
    ]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      .write(to: directory.appendingPathComponent("oracle.json"))
    print("PASS: seven independent whole-file reference hashes for 100 MiB")
  }
}

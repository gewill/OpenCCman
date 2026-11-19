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
    // Every configuration the source × target settings offer (#305), keyed by the
    // record code (the old option bits for configurations offered before).
    let options: [ChineseConverter.Configuration] = [
      .s2t, .t2s, .s2tw, .s2twp, .s2hk, .s2hkp, .tw2s, .tw2sp, .hk2s, .hk2sp, .t2tw, .t2hk, .tw2t, .hk2t
    ]
    var references: [[String: Any]] = []
    for option in options {
      try autoreleasepool {
        var data = try Data(contentsOf: source)
        data.removeFirst(3)
        guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        let converted = try ChineseConversionService.convertSynchronously(text, configuration: option)
        let bytes = Data(converted.utf8)
        references.append([
          "options": option.recordCode, "output_bytes": bytes.count,
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

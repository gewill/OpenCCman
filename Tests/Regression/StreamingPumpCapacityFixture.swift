import CryptoKit
import Foundation

/// Deterministic 100 MiB fixture, generated in bounded blocks on the simulator.
/// Only the separate Mac oracle reads it whole to compute reference conversion.
enum StreamingPumpCapacityFixture {
  static let byteCount: UInt64 = 100 * 1024 * 1024
  static var tile: Data {
    var bytes = Data(String(repeating: "显存顯存头发干杯鼠标\0⿰木木👨‍👩‍👧‍👦e\u{301}\r\n", count: 256).utf8)
    bytes.append(Data(repeating: 0x61, count: 64 * 1024 - bytes.count - 1))
    bytes.append(0x0A)
    return bytes
  }

  static func write(to url: URL) throws {
    try Data().write(to: url)
    let output = try FileHandle(forWritingTo: url)
    defer { try? output.close() }
    let bom = Data([0xEF, 0xBB, 0xBF])
    try output.write(contentsOf: bom)
    var remaining = byteCount - UInt64(bom.count)
    let bytes = tile
    while remaining > 0 {
      let count = min(bytes.count, Int(remaining))
      try output.write(contentsOf: bytes.prefix(count))
      remaining -= UInt64(count)
    }
    try output.synchronize()
    try output.close()
  }

  static func hash(_ url: URL) throws -> String {
    let input = try FileHandle(forReadingFrom: url)
    defer { try? input.close() }
    var digest = SHA256()
    while let bytes = try input.read(upToCount: 256 * 1024), !bytes.isEmpty {
      digest.update(data: bytes)
    }
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
  }
}

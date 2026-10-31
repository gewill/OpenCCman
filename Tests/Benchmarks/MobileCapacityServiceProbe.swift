import CryptoKit
import Foundation
import OpenCC

/// Actual mobile file service hosted on Mac; no UIKit/device-memory claims.
@main enum MobileCapacityServiceProbe {
  static func main() async throws {
    let a = CommandLine.arguments
    guard a.count == 7, let raw = Int(a[2]), let expectedBytes = UInt64(a[4]) else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let root = URL(fileURLWithPath: a[5], isDirectory: true)
    let service = MobileLargeFileService(root: root, protection: .init(available: true))
    let ready = try await service.convert(source: URL(fileURLWithPath: a[1]), options: .init(rawValue: raw))
    guard ready.outputBytes == expectedBytes else {
      throw NSError(domain: "CapacityProbe.outputBytes", code: 1, userInfo: [NSLocalizedDescriptionKey: "actual=\(ready.outputBytes) expected=\(expectedBytes)"])
    }
    let url = try await service.exportURL(for: ready.id)
    var digest = SHA256()
    let reader = try FileHandle(forReadingFrom: url)
    defer { try? reader.close() }
    while let chunk = try reader.read(upToCount: 256 * 1024), !chunk.isEmpty {
      digest.update(data: chunk)
    }
    try reader.close()
    let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
    guard hash == a[3] else {
      throw NSError(domain: "CapacityProbe.outputHash", code: 2, userInfo: [NSLocalizedDescriptionKey: "actual=\(hash) expected=\(a[3])"])
    }
    let originalIdentity = try TextFileFingerprint.read(url: url, followSymlink: false)
    let recovered = MobileLargeFileService(root: root, protection: .init(available: true))
    let recovery = try await recovered.recover()
    guard case .ready(let reread) = recovery,
          reread.id == ready.id, reread.exportFilename == ready.exportFilename,
          reread.inputBytes == ready.inputBytes, reread.outputBytes == ready.outputBytes,
          reread.optionsRawValue == ready.optionsRawValue, !reread.cleanupPending,
          originalIdentity != nil,
          try TextFileFingerprint.read(url: reread.url, followSymlink: false) == originalIdentity else {
      throw NSError(domain: "CapacityProbe.recovery", code: 3, userInfo: [NSLocalizedDescriptionKey: "actual=\(recovery) expected=\(ready)"])
    }
    try await recovered.discard(ready.id)
    guard try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty else {
      throw MobileLargeFileService.JobError.invalidStore
    }
    let data = try JSONSerialization.data(withJSONObject: [
      "input_bytes": ready.inputBytes, "output_bytes": ready.outputBytes,
      "output_sha256": hash, "options_raw": raw, "recovery_equal": true,
      "private_directory_empty": true, "host": "macOS service-only",
    ], options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: a[6]), options: .withoutOverwriting)
  }
}

// Targeted processing benchmark, not an application launch or UI latency test.
import AppKit
import CryptoKit
import Foundation
import OpenCC

@main enum ByteScanBenchmark {
  private static func emit(_ fields: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
  }

  private static func hash(_ bytes: Data) -> String {
    SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
  }

  // Conversion body from develop f8f40f2. Both paths share the unchanged cache.
  @inline(never) private static func baseline(_ text: String, options: ChineseConverter.Options) throws -> String {
    let converter = try ChineseConversionService.converter(options: options)
    guard text.utf8.contains(0) else { return converter.convert(text) }
    return text.split(separator: "\0", omittingEmptySubsequences: false)
      .map { converter.convert(String($0)) }
      .joined(separator: "\0")
  }

  @inline(never) private static func current(_ text: String, options: ChineseConverter.Options) throws -> String {
    try ChineseConversionService.convertSynchronously(text, options: options)
  }

  static func main() throws {
    _ = NSApplication.shared
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    let modes: [(String, ChineseConverter.Options)] = [
      ("s2t", .traditionalize), ("t2s", .simplify),
      ("s2tw", [.traditionalize, .twStandard]),
      ("s2twp", [.traditionalize, .twStandard, .twIdiom]),
      ("s2hk", [.traditionalize, .hkStandard]),
      ("legacy-s2t-tw-idiom", [.traditionalize, .twIdiom]),
      ("legacy-s2hk-tw-idiom", [.traditionalize, .hkStandard, .twIdiom])
    ]
    emit(["event": "metadata", "protocol": 1,
          "os": ProcessInfo.processInfo.operatingSystemVersionString,
          "physicalMemoryBytes": ProcessInfo.processInfo.physicalMemory,
          "logicalProcessors": ProcessInfo.processInfo.processorCount,
          "scope": "warm processing only; not NSPerformService, launch, rendering, or per-algorithm memory",
          "order": "five pairs, alternate baseline/current first; fresh input before each timed call"])
    let sentence = "简体中文 軟體 软件 鼠标 滑鼠 網路 网络 内存 記憶體 里面 香港 台湾 😀 e\u{301}\r\n\r\n"
    var completed = 0
    for size in [1_048_576, 10_485_760] {
      let count = size / sentence.utf8.count
      let text = String(repeating: sentence, count: count)
        + String(repeating: " ", count: size - count * sentence.utf8.count)
      let inputBytes = Data(text.utf8)
      precondition(inputBytes.count == size)
      for (mode, options) in modes {
        // Prepare and validate references outside the measured interval.
        let converter = try ChineseConversionService.converter(options: options)
        let expected = Data(converter.convert(text).utf8)
        precondition(expected != inputBytes, "Unchanged text must not pass a conversion fixture")
        let warmedBaseline = try baseline(text, options: options)
        let warmedCurrent = try current(text, options: options)
        precondition(Data(warmedBaseline.utf8) == expected)
        precondition(Data(warmedCurrent.utf8) == expected)
        for representation in ["native", "pasteboard"] {
          board.clearContents()
          precondition(board.setString(text, forType: .string))
          emit(["event": "case", "mode": mode, "representation": representation,
                "inputBytes": size, "inputSHA256": hash(inputBytes),
                "expectedBytes": expected.count, "expectedSHA256": hash(expected)])
          for pair in 1...5 {
            let order = pair.isMultiple(of: 2) ? ["current", "baseline"] : ["baseline", "current"]
            for (position, algorithm) in order.enumerated() {
              try autoreleasepool {
                // Do not scan, hash, or compare the input before starting its timer.
                let input = representation == "native"
                  ? String(decoding: inputBytes, as: UTF8.self) : board.string(forType: .string)!
                let contiguous = input.isContiguousUTF8
                let start = DispatchTime.now().uptimeNanoseconds
                let output = try algorithm == "baseline"
                  ? baseline(input, options: options) : current(input, options: options)
                let end = DispatchTime.now().uptimeNanoseconds
                let outputBytes = Data(output.utf8)
                precondition(outputBytes == expected, "A timed result differed from the reference")
                emit(["event": "sample", "mode": mode, "representation": representation,
                      "inputBytes": size, "pair": pair, "position": position, "algorithm": algorithm,
                      "inputWasContiguousUTF8": contiguous,
                      "elapsedMS": Double(end - start) / 1_000_000,
                      "outputMatchesExpected": true, "outputSHA256": hash(outputBytes)])
                completed += 1
              }
            }
          }
        }
      }
    }
    precondition(completed == 280)
    emit(["event": "run_completed", "samples": completed])
  }
}

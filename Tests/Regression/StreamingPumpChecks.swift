import Darwin
import Foundation
import OpenCC

/// Runs against the actual platform-neutral pump on both macOS and iOS.
func checkStreamingPump() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stream-pump-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let source = directory.appendingPathComponent("source.txt")
  let destination = directory.appendingPathComponent("partial.txt")
  let text = "\r\n头发干杯显存顯存鼠标\0⿰木木👨‍👩‍👧‍👦e\u{301}中\u{FEFF}文\n\n"

  for options in streamingPumpOptions {
    for size in [1, 2, 3, 7, 31, StreamingConversionPump.bufferBytes] {
      // Tiny reads split the BOM, UTF-8 scalars, IDS and dictionary phrases.
      // The production-sized read also crosses a real 256 KiB boundary.
      let fixture = size == StreamingConversionPump.bufferBytes
        ? String(repeating: "a", count: size - 5) + text + text
        : text + text
      let bytes = Data([0xEF, 0xBB, 0xBF]) + Data(fixture.utf8)
      try bytes.write(to: source)
      let expected = try ChineseConversionService.convertSynchronously(fixture, options: options)
      let recorder = PumpProgressRecorder()
      let result = try await runStreamingPump(source: source, destination: destination, expectedBytes: UInt64(bytes.count),
                                              options: options, chunkSize: size, progress: { recorder.append($0, $1) })
      let actual = try Data(contentsOf: destination)
      precondition(actual == Data(expected.utf8), "The pump must match independent whole-text conversion")
      precondition(result.inputBytes == UInt64(bytes.count) && result.outputBytes == UInt64(actual.count))
      precondition(recorder.valid(total: UInt64(bytes.count)))
    }
    var seed: UInt64 = 0x257
    for _ in 0..<6 {
      // Reproducible pseudo-random block sizes and starting offsets exercise
      // different boundaries without making CI failures irreproducible.
      seed = seed &* 6364136223846793005 &+ 1
      let size = Int(seed >> 32) % 1024 + 1
      let fixture = String(repeating: "a", count: Int(seed % 97)) + text + text
      let bytes = Data(fixture.utf8)
      try bytes.write(to: source)
      let result = try await runStreamingPump(source: source, destination: destination,
                                              expectedBytes: UInt64(bytes.count), options: options, chunkSize: size)
      let expected = try ChineseConversionService.convertSynchronously(fixture, options: options)
      let actual = try Data(contentsOf: destination)
      precondition(actual == Data(expected.utf8) && result.outputBytes == UInt64(actual.count))
    }
  }

  for bytes in [Data(), Data([0x61]), Data([0x61, 0x62]), Data([0xEF, 0xBB, 0xBF])] {
    try bytes.write(to: source)
    let result = try await runStreamingPump(source: source, destination: destination, expectedBytes: UInt64(bytes.count), chunkSize: 1)
    let actual = try Data(contentsOf: destination)
    precondition(actual == (bytes.count == 3 ? Data() : bytes))
    precondition(result.outputBytes == UInt64(actual.count))
  }

  let expanded = "显存顯存"
  try Data(expanded.utf8).write(to: source)
  let expandedResult = try await runStreamingPump(source: source, destination: destination,
                                                 expectedBytes: UInt64(expanded.utf8.count),
                                                 options: [.traditionalize, .twStandard, .twIdiom], chunkSize: 1)
  precondition(expandedResult.outputBytes > expandedResult.inputBytes,
               "Output is allowed to grow; the buffer reserve is not a file capacity")

  for bytes in [Data([0xFF]), Data([0xEF, 0xBB]), Data([0xED, 0xA0, 0x80]),
                Data([0xF0, 0x80, 0x80, 0x80]), Data(text.utf8) + Data([0xE4])] {
    try bytes.write(to: source)
    do {
      _ = try await runStreamingPump(source: source, destination: destination, expectedBytes: UInt64(bytes.count), chunkSize: 1)
      preconditionFailure("Malformed or truncated UTF-8 must fail, including at finish")
    } catch TextFileService.FileError.invalidUTF8 {}
  }

  let bytes = Data(text.utf8)
  try bytes.write(to: source)
  for expected in [UInt64(bytes.count - 1), UInt64(bytes.count + 1)] {
    do {
      _ = try await runStreamingPump(source: source, destination: destination, expectedBytes: expected, chunkSize: 7)
      preconditionFailure("Both source growth and truncation must fail")
    } catch TextFileService.FileError.sourceChanged {}
  }
  for fault in [StreamingConversionPump.Hooks(beforeRead: { throw POSIXError(.EIO) }),
                StreamingConversionPump.Hooks(beforeWrite: { throw POSIXError(.ENOSPC) })] {
    do {
      _ = try await runStreamingPump(source: source, destination: destination, expectedBytes: UInt64(bytes.count), hooks: fault)
      preconditionFailure("Actual read/write boundary failures must propagate")
    } catch is POSIXError {}
  }

  let preCancelled = StreamingConversionCancellation()
  preCancelled.cancel()
  do {
    _ = try await runStreamingPump(source: source, destination: destination,
                                  expectedBytes: UInt64(bytes.count), cancellation: preCancelled)
    preconditionFailure("A cancelled operation cannot start")
  } catch is CancellationError {}

  let duringRead = StreamingConversionCancellation()
  let hook = StreamingConversionPump.Hooks(beforeRead: { duringRead.cancel() })
  do {
    _ = try await runStreamingPump(source: source, destination: destination,
                                  expectedBytes: UInt64(bytes.count), cancellation: duringRead, hooks: hook)
    preconditionFailure("Cancellation while reading must stop before a successful result")
  } catch is CancellationError {}

  let cancelledCommit = StreamingConversionCancellation()
  cancelledCommit.cancel()
  do {
    try cancelledCommit.commit { preconditionFailure("Cancelled output must not publish") }
    preconditionFailure("Cancelled commit must throw")
  } catch is CancellationError {}
  let completedCommit = StreamingConversionCancellation()
  try completedCommit.commit {}
  completedCommit.cancel()
  try completedCommit.check() // Cancellation cannot revoke completed publication.

  print("PASS: shared stream pump; seven configurations, split BOM/UTF-8/phrases, IDS/NUL/Unicode, output expansion, byte counts, faults, cancellation and caller-owned handles")
}

let streamingPumpOptions: [ChineseConverter.Options] = [
  .simplify, .traditionalize, [.traditionalize, .twStandard], [.traditionalize, .hkStandard],
  [.traditionalize, .twStandard, .twIdiom], [.traditionalize, .twIdiom],
  [.traditionalize, .hkStandard, .twIdiom]
]

/// The caller closes handles only after the worker has completed, even on error.
/// Seeking/synchronizing before close explicitly detects accidental pump close.
func runStreamingPump(
  source: URL, destination: URL, expectedBytes: UInt64,
  options: ChineseConverter.Options = .traditionalize,
  chunkSize: Int = StreamingConversionPump.bufferBytes,
  cancellation: StreamingConversionCancellation = StreamingConversionCancellation(),
  hooks: StreamingConversionPump.Hooks = .init(),
  progress: @escaping @Sendable (UInt64, UInt64) -> Void = { _, _ in }
) async throws -> StreamingConversionPump.Result {
  try Data().write(to: destination)
  let input = try FileHandle(forReadingFrom: source)
  let output = try FileHandle(forWritingTo: destination)
  defer { try? input.close(); try? output.close() }
  let result: Swift.Result<StreamingConversionPump.Result, Error> = await withCheckedContinuation { continuation in
    DispatchQueue(label: "OpenCCman.streaming-pump-check").async {
      precondition(!Thread.isMainThread)
      continuation.resume(returning: Result {
        try StreamingConversionPump.run(input: input, output: output, expectedInputBytes: expectedBytes,
                                        options: options, cancellation: cancellation,
                                        progress: progress, hooks: hooks, chunkSize: chunkSize)
      })
    }
  }
  try input.seek(toOffset: 0)
  try output.synchronize()
  return try result.get()
}

private final class PumpProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var observations: [(UInt64, UInt64)] = []
  func append(_ input: UInt64, _ total: UInt64) {
    lock.lock()
    observations.append((input, total))
    lock.unlock()
  }
  func valid(total: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return observations.first?.0 == 0 && observations.last?.0 == total
      && observations.allSatisfy { $0.0 <= total && $0.1 == total }
      && zip(observations, observations.dropFirst()).allSatisfy { $0.0.0 <= $0.1.0 }
  }
}

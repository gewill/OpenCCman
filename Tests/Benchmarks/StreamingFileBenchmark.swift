import CryptoKit
import Darwin
import Foundation
import OpenCC

/// A fresh-process, file-to-file benchmark. The oracle uses the existing whole
/// converter on bounded, independently delimited tiles, never the new stream.
@main enum StreamingFileBenchmark {
  static func main() async throws {
    let args = CommandLine.arguments
    guard args.count == 5, let byteCount = UInt64(args[1]), byteCount > 0,
          ["single", "multiline", "unmatched"].contains(args[2]) else {
      fatalError("Usage: StreamingFileBenchmark <bytes> <single|multiline|unmatched> <directory> <report.json>")
    }
    let directory = URL(fileURLWithPath: args[3], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let input = directory.appendingPathComponent("source.txt")
    let output = directory.appendingPathComponent("converted.txt")
    let cancellationOutput = directory.appendingPathComponent("cancelled.txt")
    let staging = StagingRegistry(url: directory.appendingPathComponent("staging.json"))
    defer {
      // Python also owns this invocation's unique fixture directory and removes
      // it on child crash/timeout, when a Swift defer cannot run.
      for url in [input, output, cancellationOutput] { try? FileManager.default.removeItem(at: url) }
    }
    let converter = try ChineseConversionService.converter(options: .traditionalize)
    let separator = args[2] == "multiline" ? "\r\n\n" : "|ASCII-boundary|"
    let tile = args[2] == "unmatched" ? String(repeating: "a", count: 64 * 1024) :
      String(repeating: "头发干杯鼠标数据库服务器 汉字😀e\u{301}⿰木木" + separator, count: 1024)
    let convertedTile = converter.convert(tile)
    precondition(converter.convert(tile + tile) == convertedTile + convertedTile,
                 "The benchmark oracle requires independent tile boundaries")
    let bytes = Data(tile.utf8)
    let converted = Data(convertedTile.utf8)
    var inputHash = SHA256()
    var expectedHash = SHA256()
    var expectedBytes: UInt64 = 0
    guard FileManager.default.createFile(atPath: input.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
    let writer = try FileHandle(forWritingTo: input)
    defer { try? writer.close() }
    var remaining = byteCount
    while remaining >= UInt64(bytes.count) {
      try autoreleasepool {
        try writer.write(contentsOf: bytes)
        inputHash.update(data: bytes)
        expectedHash.update(data: converted)
      }
      expectedBytes += UInt64(converted.count)
      remaining -= UInt64(bytes.count)
    }
    var tail = Data(bytes.prefix(Int(remaining)))
    while String(data: tail, encoding: .utf8) == nil { tail.removeLast() }
    tail.append(Data(repeating: 0x61, count: Int(remaining) - tail.count))
    let convertedTail = Data(converter.convert(String(data: tail, encoding: .utf8)!).utf8)
    precondition(converter.convert(tile + String(data: tail, encoding: .utf8)!) == convertedTile + String(data: convertedTail, encoding: .utf8)!)
    try writer.write(contentsOf: tail)
    try writer.close()
    inputHash.update(data: tail)
    expectedHash.update(data: convertedTail)
    expectedBytes += UInt64(convertedTail.count)

    let source = try OpenedTextFile(url: input)
    let samples = MemorySamples()
    samples.start()
    defer { _ = samples.stop() }
    let start = DispatchTime.now().uptimeNanoseconds
    let result = try await StreamingTextFileService.convert(
      source: source, destination: output, options: .traditionalize,
      hooks: .init(temporaryDirectoryCreated: { staging.record($0) }))
    let duration = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    // Serial stop drains any active sampler and prevents further records. Hash
    // verification and the cancellation probe cannot contaminate these samples.
    let conversionMemory = samples.stop()
    precondition(conversionMemory["samples", default: 0] > 0, "Memory sampling must succeed")
    var actualHash = SHA256()
    let reader = try FileHandle(forReadingFrom: output)
    defer { try? reader.close() }
    while try autoreleasepool(invoking: { () throws -> Bool in
      guard let data = try reader.read(upToCount: 256 * 1024), !data.isEmpty else { return false }
      actualHash.update(data: data)
      return true
    }) {}
    try reader.close()
    let expected = hex(expectedHash.finalize())
    let actual = hex(actualHash.finalize())
    precondition(actual == expected && result.inputBytes == byteCount && result.outputBytes == expectedBytes,
                 "Complete output must match the independent whole-converter oracle")
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else { throw POSIXError(.EIO) }
    // Capture process high-water before the extra cancellation run. It includes
    // oracle preparation and output verification, unlike conversion_memory.
    let processMaxRSS = usage.ru_maxrss
    let cancellation = try await measureCancellation(input: input, destination: cancellationOutput, staging: staging)
    let report: [String: Any] = [
      "protocol": 2, "configuration": "s2t", "corpus": args[2], "input_bytes": byteCount,
      "output_bytes": result.outputBytes, "input_sha256": hex(inputHash.finalize()),
      "expected_sha256": expected, "actual_sha256": actual, "equal": true,
      "conversion_and_commit_ms": duration, "process_max_rss_bytes": processMaxRSS,
      "conversion_memory": conversionMemory, "cancellation": cancellation,
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "hardware": sysctlString("hw.model"), "cpu_model": sysctlString("machdep.cpu.brand_string"),
      "physical_memory_bytes": ProcessInfo.processInfo.physicalMemory,
      "note": "Fresh process, preloaded converter used to prepare oracle, local filesystem, unsandboxed service harness with a small staging-registry write for crash cleanup. Conversion samples exclude fixture generation, output verification, and the extra cancellation run. Process RSS includes preparation/verification but is captured before cancellation. No UI or minimum-system acceptance."
    ]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      .write(to: URL(fileURLWithPath: args[4]), options: .atomic)
    print("PASS: \(args[2]) \(byteCount) bytes, full hash equal, \(Int(duration)) ms, cancellation cleanup verified")
  }

  private static func measureCancellation(input: URL, destination: URL, staging: StagingRegistry) async throws -> [String: Any] {
    let preserved = Data("Keep this existing destination unchanged.\n".utf8)
    try preserved.write(to: destination)
    let probe = CancellationProbe()
    let source = try OpenedTextFile(url: input)
    let task = Task {
      await probe.waitUntilInstalled()
      return try await StreamingTextFileService.convert(
        source: source, destination: destination, options: .traditionalize,
        progress: { processed, _ in
          // This callback follows a successful conversion/write of the block.
          if processed > 0 { probe.cancelAfterWrittenBlock(processedBytes: processed) }
        },
        hooks: .init(temporaryDirectoryCreated: {
          staging.record($0)
          probe.recordTemporaryDirectory($0)
        }))
    }
    probe.install { task.cancel() }
    defer { probe.clearCancellation() }
    do {
      _ = try await task.value
      preconditionFailure("The cancellation benchmark must cancel before commit")
    } catch is CancellationError {}
    let completedAt = DispatchTime.now().uptimeNanoseconds
    let state = probe.snapshot()
    guard let requestedAt = state.requestedAt, let temporaryDirectory = state.temporaryDirectory else {
      preconditionFailure("Cancellation must be requested after a written block and temporary output creation")
    }
    let targetPreserved = try Data(contentsOf: destination) == preserved
    let temporaryRemoved = !FileManager.default.fileExists(atPath: temporaryDirectory.path)
    precondition(targetPreserved && temporaryRemoved,
                 "Cancellation must return only after cleanup and preserve an existing destination")
    return [
      "requested_after_input_bytes": state.processedBytes,
      "request_to_cleanup_completion_ms": Double(completedAt - requestedAt) / 1_000_000,
      "existing_destination_preserved": targetPreserved,
      "temporary_output_removed": temporaryRemoved,
      "note": "Additional conversion in the same process, cancelled after the first written block; timing ends when the async service returns after cleanup. Excluded from successful-conversion memory samples and process high-water."
    ]
  }

  private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
    digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func sysctlString(_ name: String) -> String {
    var count = 0
    guard sysctlbyname(name, nil, &count, nil, 0) == 0, count > 0 else { return "unavailable" }
    var value = [CChar](repeating: 0, count: count)
    guard sysctlbyname(name, &value, &count, nil, 0) == 0 else { return "unavailable" }
    return String(cString: value)
  }
}

/// All mutable sampler state is confined to this dedicated serial queue.
private final class MemorySamples: @unchecked Sendable {
  private let queue = DispatchQueue(label: "stream-benchmark-memory")
  private var timer: DispatchSourceTimer?
  private var running = false
  private var rss: UInt64 = 0
  private var footprint: UInt64 = 0
  private var baselineRSS: UInt64 = 0
  private var baselineFootprint: UInt64 = 0
  private var count: UInt64 = 0
  private var failures: UInt64 = 0

  func start() {
    queue.sync {
      running = true
      record()
      let timer = DispatchSource.makeTimerSource(queue: queue)
      timer.schedule(deadline: .now() + .milliseconds(10), repeating: .milliseconds(10))
      timer.setEventHandler { [weak self] in
        guard let self, self.running else { return }
        self.record()
      }
      self.timer = timer
      timer.resume()
    }
  }

  func stop() -> [String: UInt64] {
    queue.sync {
      if running {
        running = false
        timer?.cancel()
        timer = nil
        record()
      }
      return ["peak_rss_bytes": rss, "peak_physical_footprint_bytes": footprint, "samples": count,
              "baseline_rss_bytes": baselineRSS, "baseline_physical_footprint_bytes": baselineFootprint,
              "failed_samples": failures, "sample_interval_ms": 10]
    }
  }

  private func record() {
    var info = task_vm_info_data_t()
    var size = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &size)
      }
    }
    guard status == KERN_SUCCESS else { failures += 1; return }
    if count == 0 {
      baselineRSS = info.resident_size
      baselineFootprint = info.phys_footprint
    }
    rss = max(rss, info.resident_size)
    footprint = max(footprint, info.phys_footprint)
    count += 1
  }
}

private final class CancellationProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var cancellation: (@Sendable () -> Void)?
  private var installedContinuation: CheckedContinuation<Void, Never>?
  private var reachedBlock = false
  private var requestedAt: UInt64?
  private var processedBytes: UInt64 = 0
  private var temporaryDirectory: URL?

  func install(_ action: @escaping @Sendable () -> Void) {
    lock.lock()
    cancellation = action
    let shouldCancel = reachedBlock && requestedAt == nil
    if shouldCancel { requestedAt = DispatchTime.now().uptimeNanoseconds }
    let continuation = installedContinuation
    installedContinuation = nil
    lock.unlock()
    if shouldCancel { action() }
    continuation?.resume()
  }

  func waitUntilInstalled() async {
    await withCheckedContinuation { continuation in
      lock.lock()
      let installed = cancellation != nil
      if !installed { installedContinuation = continuation }
      lock.unlock()
      if installed { continuation.resume() }
    }
  }

  func cancelAfterWrittenBlock(processedBytes: UInt64) {
    lock.lock()
    guard !reachedBlock else { lock.unlock(); return }
    reachedBlock = true
    self.processedBytes = processedBytes
    let action = cancellation
    if action != nil { requestedAt = DispatchTime.now().uptimeNanoseconds }
    lock.unlock()
    action?()
  }

  func recordTemporaryDirectory(_ url: URL) {
    lock.lock()
    temporaryDirectory = url
    lock.unlock()
  }

  func clearCancellation() {
    lock.lock()
    cancellation = nil
    lock.unlock()
  }

  func snapshot() -> (requestedAt: UInt64?, processedBytes: UInt64, temporaryDirectory: URL?) {
    lock.lock()
    defer { lock.unlock() }
    return (requestedAt, processedBytes, temporaryDirectory)
  }
}

/// The parent owns cleanup if this process crashes or times out. Record the
/// directory's identity before the service creates any converted-text output.
private final class StagingRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private let url: URL
  private var directories: [[String: Any]] = []

  init(url: URL) { self.url = url }

  func record(_ directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
      guard let device = attributes[.systemNumber] as? NSNumber,
            let inode = attributes[.systemFileNumber] as? NSNumber else {
        preconditionFailure("Cannot record generated staging directory identity")
      }
      directories.append(["path": directory.path, "device": device, "inode": inode])
      try JSONSerialization.data(withJSONObject: directories, options: [.sortedKeys]).write(to: url, options: .atomic)
    } catch {
      // No output file exists yet. Do not proceed to generate large temporary
      // output unless the supervising process can recover it after a crash.
      preconditionFailure("Cannot record generated staging directory: \(error)")
    }
  }
}

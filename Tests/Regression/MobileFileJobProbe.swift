import Darwin
import Foundation
import OpenCC

/// Launched only by check-mobile-file-jobs.py in an isolated temporary root.
/// SIGKILL deliberately skips Swift cleanup; a different process then recovers.
@main enum MobileFileJobProbe {
  static func main() async throws {
    let arguments = CommandLine.arguments
    let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let mode = arguments[1]
    if mode == "capacity-refresh" {
      try await checkCapacityRefresh(root: root, reportURL: URL(fileURLWithPath: arguments[3]))
      return
    }
    let hooks = MobileLargeFileService.Hooks(boundary: { stage in
      if mode == stage.rawValue {
        raise(SIGKILL)
        // Signal delivery can be asynchronous across threads. Do not execute
        // another filesystem operation while the process is being killed.
        while true { pause() }
      }
    })
    let service = MobileLargeFileService(root: root, protection: .init(available: true), hooks: hooks)
    if mode == "recover-empty" {
      guard try await service.recover() == .empty else { throw MobileLargeFileService.JobError.invalidJournal }
      print("PASS: fresh process removed incomplete job")
    } else if mode == "recover-ready" {
      guard case .ready(let ready) = try await service.recover() else { throw MobileLargeFileService.JobError.invalidJournal }
      guard try Data(contentsOf: ready.url) == Data("滑鼠\0漢字\r\n".utf8) else { throw MobileLargeFileService.JobError.invalidJournal }
      try await service.discard(ready.id)
      print("PASS: fresh process validated and exported complete result")
    } else {
      _ = try await service.convert(source: URL(fileURLWithPath: arguments[3]), options: [.traditionalize, .twIdiom])
      guard mode == "ready" else { throw MobileLargeFileService.JobError.invalidJournal }
      raise(SIGKILL)
    }
  }

  /// Real filesystem integration, opt-in because live capacity is an estimate
  /// affected by other processes. The observer forwards the production query;
  /// it never supplies simulated availableBytes values.
  static func checkCapacityRefresh(root: URL, reportURL: URL) async throws {
    let fm = FileManager.default
    try fm.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? fm.removeItem(at: root) }
    let observations = CapacityObservations()
    let query = MobileLargeFileService.Hooks().availableBytes
    guard let initial = try query(root), initial > 1024 * 1024 * 1024 else {
      throw MobileLargeFileService.JobError.insufficientSpace
    }
    let service = MobileLargeFileService(root: root.appendingPathComponent("jobs"),
      protection: .init(available: true), hooks: .init(availableBytes: { url in
        let bytes = try query(url)
        observations.record(bytes)
        return bytes
      }))
    let source = root.appendingPathComponent("source.txt")
    try Data("头发\0\r\n".utf8).write(to: source)
    let first = try await service.convert(source: source, options: .traditionalize)
    let before = observations.values.last!!
    let allocation = root.appendingPathComponent("owned-pressure.bin")
    try Data().write(to: allocation, options: .withoutOverwriting)
    let file = try FileHandle(forWritingTo: allocation)
    defer { try? file.close() }
    var buffer = Data(count: 1024 * 1024)
    buffer.withUnsafeMutableBytes { arc4random_buf($0.baseAddress!, $0.count) }
    for _ in 0..<256 { try file.write(contentsOf: buffer) }
    try file.synchronize()
    try file.close()
    let allocated = try allocation.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize!
    _ = try await service.exportURL(for: first.id)
    let atExport = observations.values.last!!
    try await service.discard(first.id)
    let secondStart = observations.values.count
    let second = try await service.convert(source: source, options: .traditionalize)
    let atSecondPreflight = observations.values[secondStart]!
    // At least half of the 256 MiB allocation must be observed. This is a local
    // integration assertion, not a claim about exact purgeable capacity.
    precondition(before - atExport > 128 * 1024 * 1024, "Export reused stale capacity")
    precondition(before - atSecondPreflight > 128 * 1024 * 1024, "Second task reused stale capacity")
    try await service.discard(second.id)
    let report: [String: Any] = ["allocated_bytes": allocated,
      "before_allocation": before, "export_after_allocation": atExport,
      "second_task_preflight": atSecondPreflight, "query_count": observations.values.count,
      "same_service_instance": true, "query": "production default; observation only; no capacity stub",
      "source_unchanged": try Data(contentsOf: source) == Data("头发\0\r\n".utf8)]
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
      .write(to: reportURL, options: .withoutOverwriting)
    print("PASS: same service default capacity refreshed at export and next-task preflight after real 256 MiB write")
  }
}

private final class CapacityObservations: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: [Int64?] = []
  func record(_ bytes: Int64?) { lock.lock(); stored.append(bytes); lock.unlock() }
  var values: [Int64?] { lock.lock(); defer { lock.unlock() }; return stored }
}

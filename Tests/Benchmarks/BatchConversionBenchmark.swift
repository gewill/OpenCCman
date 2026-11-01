// Runs the real Mac batch coordinator and streaming service, without any UI
// host. Measures wall time, process footprint and main-actor responsiveness.
import Darwin
import Foundation
import OpenCC

@main enum BatchConversionBenchmark {
  @MainActor static func main() async throws {
    let arguments = CommandLine.arguments
    precondition(arguments.count == 4, "usage: INPUT OUTPUT REPORT")
    let input = URL(fileURLWithPath: arguments[1])
    let output = URL(fileURLWithPath: arguments[2])
    let report = URL(fileURLWithPath: arguments[3])
    let urls = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "txt" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
    let inputBytes = urls.reduce(UInt64(0)) { $0 + UInt64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    var reported: [String] = []
    let coordinator = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false },
                                                    reportError: { reported.append("\($0)") })
    let configuration = ConversionConfiguration(target: .traditional, variant: .taiwan, region: .taiwan)
    try coordinator.offer(urls, configuration: configuration, qualified: true, owner: UUID(), window: nil)
    let footprintBefore = footprint()
    var peakFootprint = footprintBefore
    var worstMainActorDelay = 0.0
    var samples = 0
    let start = ProcessInfo.processInfo.systemUptime
    coordinator.start(outputDirectory: output)
    var previous = ProcessInfo.processInfo.systemUptime
    // A 10 ms main-actor tick: any delay beyond it is time the main actor was busy.
    while coordinator.phase != .finished {
      try await Task.sleep(nanoseconds: 10_000_000)
      let now = ProcessInfo.processInfo.systemUptime
      worstMainActorDelay = max(worstMainActorDelay, now - previous - 0.010)
      previous = now
      samples += 1
      peakFootprint = max(peakFootprint, footprint())
    }
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    let queue = coordinator.queue!
    let outputBytes = queue.items.reduce(UInt64(0)) {
      if case let .succeeded(_, bytes) = $1.state { return $0 + bytes } else { return $0 }
    }
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let mib = 1024.0 * 1024.0
    let result: [String: Any] = [
      "files": urls.count,
      "succeeded": queue.succeededCount,
      "failed": queue.failedCount,
      "input_bytes": inputBytes,
      "output_bytes": outputBytes,
      "largest_input_bytes": urls.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.max() ?? 0,
      "elapsed_seconds": elapsed,
      "input_mib_per_second": Double(inputBytes) / mib / elapsed,
      "footprint_before_mib": Double(footprintBefore) / mib,
      "footprint_peak_mib": Double(peakFootprint) / mib,
      "max_rss_mib": Double(usage.ru_maxrss) / mib,
      "main_actor_worst_delay_ms": worstMainActorDelay * 1000,
      "main_actor_samples": samples,
      "reported_errors": reported,
      "configuration": "traditional / Taiwan standard / Taiwan idiom",
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: report)
    print(String(decoding: data, as: UTF8.self))
    precondition(queue.succeededCount == urls.count, "Every benchmark file must convert")
  }

  /// Physical footprint, the value Activity Monitor and jetsam report.
  static func footprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    return status == KERN_SUCCESS ? info.phys_footprint : 0
  }
}

import Darwin
import Foundation
import OpenCC

/// Independent Release probe. The main-actor timer is not an App frame-time test.
@main enum ConversionDiffBenchmark {
  @MainActor static func main() async throws {
    let args = CommandLine.arguments
    guard args.count == 6, let count = Int(args[2]), let cap = Int(args[3]),
          let cells = Int(args[4]), let hunkCap = Int(args[5]) else {
      fatalError("Usage: DiffBenchmark corpus.txt prefixCharacters characterCap cellCap hunkCap")
    }
    let source = String(try String(contentsOfFile: args[1], encoding: .utf8).prefix(count))
    let options: ChineseConverter.Options = [.traditionalize, .twStandard, .twIdiom]
    let result = try await ChineseConversionService.shared.convert(source, options: options)
    var before = rusage()
    getrusage(RUSAGE_SELF, &before)
    var gaps: [Double] = []
    var sampledOnMainThread = true
    let heartbeat = Task { @MainActor in
      while !Task.isCancelled {
        let start = DispatchTime.now().uptimeNanoseconds
        do { try await Task.sleep(nanoseconds: 1_000_000) } catch { return }
        gaps.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
        sampledOnMainThread = sampledOnMainThread && Thread.isMainThread
      }
    }
    // Allow the timer to begin before starting the worker.
    await Task.yield()
    let start = DispatchTime.now().uptimeNanoseconds
    let outcome = await Task.detached {
      ConversionDiff.compute(source: source, result: result,
                             limits: .init(characters: cap, cells: cells, hunks: hunkCap),
                             cancelled: { Task.isCancelled })
    }.value
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    heartbeat.cancel()
    await heartbeat.value
    var after = rusage()
    getrusage(RUSAGE_SELF, &after)
    let hunks: Int?
    switch outcome {
    case let .computed(changes):
      let a = Array(source), b = Array(result)
      var restored = "", cursor = 0
      for h in changes {
        restored += String(a[cursor..<h.source.lowerBound])
        restored += String(b[h.result])
        cursor = h.source.upperBound
      }
      restored += String(a[cursor...])
      precondition(restored.utf8.elementsEqual(result.utf8), "Byte-exact reconstruction")
      hunks = changes.count
    case .notComputed: hunks = nil
    case .cancelled: fatalError("Unexpected cancellation")
    }
    let record: [String: Any] = [
      "source_characters": source.count, "result_characters": result.count,
      "source_bytes": source.utf8.count, "result_bytes": result.utf8.count,
      "outcome": hunks == nil ? "notComputed" : "computed",
      "hunks": hunks.map { $0 as Any } ?? NSNull(), "elapsed_ms": elapsed,
      "process_peak_before_bytes": before.ru_maxrss, "process_peak_after_bytes": after.ru_maxrss,
      "main_actor_timer_samples": gaps.count,
      "main_actor_timer_max_gap_ms": gaps.max().map { $0 as Any } ?? NSNull(),
      "timer_on_main_thread": gaps.isEmpty ? NSNull() : sampledOnMainThread as Any,
    ]
    print(String(data: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), encoding: .utf8)!)
    let sample = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
    let actual = try await ChineseConversionService.shared.convert(sample, options: options)
    precondition(actual.utf8.elementsEqual("滑鼠裡面的矽二極體壞了，導致游標解析度降低。".utf8))
    for separator in ["\r\n", "\r", "\u{2028}", "\u{2029}", "\0", "\u{FEFF}"] {
      let converted = try await ChineseConversionService.shared.convert(separator + "鼠标" + separator, options: options)
      precondition(converted.utf8.elementsEqual((separator + "滑鼠" + separator).utf8))
    }
    print("PASS: pinned OpenCC sample and literal separator preservation; complete diff reconstructs output")
  }
}

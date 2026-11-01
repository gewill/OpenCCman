import Foundation

@main
struct BatchConversionChecks {
  static func main() throws {
    checkAdmission()
    try checkNaming()
    checkQueue()
    print("PASS: batch admission (100-file limit without truncation, skips, duplicates), Finder-style naming without overwrite, sequential queue, failure continuation and cancellation")
  }

  private static func candidate(_ name: String, _ bytes: UInt64? = 10, regular: Bool = true) -> BatchConversionQueue.Candidate {
    .init(url: URL(fileURLWithPath: "/batch-checks/\(name)"), byteCount: bytes, isRegularFile: regular)
  }

  private static func checkAdmission() {
    let hundred = (1...100).map { candidate("\($0).txt") }
    precondition((try? BatchConversionQueue(candidates: hundred))?.convertibleCount == 100)
    do {
      _ = try BatchConversionQueue(candidates: hundred + [candidate("101.txt")])
      preconditionFailure("101 files must be rejected")
    } catch BatchConversionQueue.AdmissionError.tooManyFiles(let count) {
      precondition(count == 101, "The rejection reports the real count; nothing is truncated")
    } catch { preconditionFailure("Unexpected error \(error)") }
    do {
      _ = try BatchConversionQueue(candidates: [])
      preconditionFailure("An empty selection must be rejected")
    } catch BatchConversionQueue.AdmissionError.empty {} catch { preconditionFailure("\(error)") }

    let limit = BatchConversionPolicy.maximumFileBytes
    precondition(limit == 1024 * 1024 * 1024, "Batch uses the standard Mac file limit, never the experimental one")
    let queue = try! BatchConversionQueue(candidates: [
      candidate("a.txt", limit), candidate("big.txt", limit + 1), candidate("notes.md"),
      candidate("folder.txt", regular: false), candidate("UPPER.TXT"), candidate("a.txt"),
      candidate("unknown.txt", nil),
    ])
    let states = queue.items.map(\.state)
    precondition(states == [
      .waiting, .skipped(.tooLarge), .skipped(.unsupportedType), .skipped(.unsupportedType),
      .waiting, .skipped(.duplicate), .waiting,
    ], "Unexpected admission states \(states)")
    precondition(queue.items.map(\.id) == Array(0..<7), "Items keep the selection order")
    precondition(queue.convertibleCount == 3 && queue.skippedCount == 4)
  }

  private static func checkNaming() throws {
    precondition(BatchOutputNamer.baseName(for: "稿件.txt") == "稿件-converted.txt")
    // Same as single-file export: a dot file has no extension to remove.
    precondition(BatchOutputNamer.baseName(for: ".txt") == ".txt-converted.txt")
    precondition(BatchOutputNamer.baseName(for: "a.b.TXT") == "a.b-converted.txt")
    precondition(BatchOutputNamer.numbered("a-converted.txt", 1) == "a-converted.txt")
    precondition(BatchOutputNamer.numbered("a-converted.txt", 2) == "a-converted 2.txt")
    precondition(BatchOutputNamer.numbered("a-converted.txt", 12) == "a-converted 12.txt")

    // Existing files, including a differently cased name, are never reused.
    let disk: Set<String> = ["a-converted.txt", "a-converted 2.txt", "B-CONVERTED.TXT"].map(BatchOutputNamer.key).reduce(into: []) { $0.insert($1) }
    let exists: (String) -> Bool = { disk.contains(BatchOutputNamer.key($0)) }
    var namer = BatchOutputNamer()
    try expectEqual(namer.reserve(for: "a.txt", exists: exists), "a-converted 3.txt")
    try expectEqual(namer.reserve(for: "b.txt", exists: exists), "b-converted 2.txt")
    // Same source name from two folders, and a case-only difference in one batch.
    try expectEqual(namer.reserve(for: "c.txt", exists: exists), "c-converted.txt")
    try expectEqual(namer.reserve(for: "c.txt", exists: exists), "c-converted 2.txt")
    try expectEqual(namer.reserve(for: "C.txt", exists: exists), "C-converted 3.txt")
    // Composed and decomposed é are the same name on APFS.
    try expectEqual(namer.reserve(for: "caf\u{E9}.txt", exists: exists), "caf\u{E9}-converted.txt")
    try expectEqual(namer.reserve(for: "cafe\u{301}.txt", exists: exists), "cafe\u{301}-converted 2.txt")

    // A commit race reserves a new name on retry; the raced name stays taken.
    var raced: Set<String> = []
    var retry = BatchOutputNamer()
    let first = try retry.reserve(for: "r.txt") { raced.contains($0) }
    raced.insert(first)
    try expectEqual(retry.reserve(for: "r.txt") { raced.contains($0) }, "r-converted 2.txt")

    var full = BatchOutputNamer()
    do {
      _ = try full.reserve(for: "x.txt") { _ in true }
      preconditionFailure("Naming must stop instead of looping forever")
    } catch BatchOutputNamer.NamingError.exhausted {}
    struct Unreadable: Error {}
    do {
      _ = try full.reserve(for: "x.txt") { _ in throw Unreadable() }
      preconditionFailure("Directory errors must surface")
    } catch is Unreadable {}
  }

  private static func expectEqual(_ actual: String, _ expected: String) {
    precondition(actual == expected, "Expected \(expected), got \(actual)")
  }

  private static func checkQueue() {
    var queue = try! BatchConversionQueue(candidates: ["1", "2", "3", "4"].map { candidate("\($0).txt") } + [candidate("skip.md")])
    precondition(queue.nextWaitingIndex == 0 && !queue.isFinished)
    queue.begin(0)
    queue.finish(0, as: .succeeded(outputFilename: "1-converted.txt", outputBytes: 9))
    queue.begin(1)
    queue.finish(1, as: .failed("Invalid UTF-8"))
    // A failure does not stop the next file.
    precondition(queue.nextWaitingIndex == 2)
    queue.begin(2)
    queue.cancelRemaining()
    precondition(queue.items.map(\.state) == [
      .succeeded(outputFilename: "1-converted.txt", outputBytes: 9), .failed("Invalid UTF-8"),
      .cancelled, .cancelled, .skipped(.unsupportedType),
    ], "Cancellation keeps finished results and stops the rest")
    precondition(queue.isFinished && queue.nextWaitingIndex == nil)
    precondition(queue.succeededCount == 1 && queue.failedCount == 1 && queue.cancelledCount == 2 && queue.skippedCount == 1)
    precondition(queue.finishedCount == 5)

    var lost = try! BatchConversionQueue(candidates: ["1", "2", "3"].map { candidate("\($0).txt") })
    lost.begin(0)
    lost.finish(0, as: .failed("Folder unavailable"))
    lost.failRemaining("Folder unavailable")
    precondition(lost.items.allSatisfy { $0.state == .failed("Folder unavailable") } && lost.isFinished)
  }
}

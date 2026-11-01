#if os(macOS)
import Foundation
import OpenCC

/// Real files in a temporary directory: exact output, source/target protection,
/// naming races, cancellation, folder loss and the global file-task slot.
enum BatchCoordinatorChecks {
  private actor Blocker {
    var started = false
    private var continuation: CheckedContinuation<Void, Never>?

    func run(source: OpenedTextFile, destination: URL) async throws -> StreamingTextFileService.Result {
      await withCheckedContinuation { continuation in
        self.continuation = continuation
        started = true
      }
      try Task.checkCancellation()
      return StreamingTextFileService.Result(destination: destination, inputBytes: source.byteCount, outputBytes: 0)
    }

    func release() { continuation?.resume(); continuation = nil }
  }

  private static let configuration = ConversionConfiguration(target: .traditional, variant: .taiwan, region: .taiwan)

  @MainActor
  static func run() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("OpenCCman-batch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try await checkSlotAndAuthorization(root)
    try await checkRealBatch(root)
    try await checkRaceAndDiskFull(root)
    try await checkCancellation(root)
    try await checkFolderProblems(root)
    print("PASS: batch coordinator exact output, source/target protection, naming race, disk full, cancellation, read-only and lost folders, Pro and global task slot")
  }

  private static func write(_ data: Data, _ url: URL) throws -> URL {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    return url
  }

  private static func directoryNames(_ url: URL) throws -> Set<String> {
    Set(try FileManager.default.contentsOfDirectory(atPath: url.path))
  }

  @MainActor private static func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(30)
    while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 2_000_000) }
    precondition(condition(), "Timed out waiting for the batch")
  }

  @MainActor private static func checkSlotAndAuthorization(_ root: URL) async throws {
    let input = try write(Data("鼠标".utf8), root.appendingPathComponent("slot/a.txt"))
    var large: MacLargeFileCoordinator!
    let batch = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { large.isBusy }, reportError: { _ in })
    large = MacLargeFileCoordinator(enabled: true, qualified: { true }, otherTaskBusy: { batch.isBusy }, reportError: { _ in })

    do {
      try batch.offer([input], configuration: configuration, qualified: false, owner: UUID(), window: nil)
      preconditionFailure("Free access must not start a batch")
    } catch MacBatchConversionCoordinator.StartError.requiresPro {}
    precondition(!batch.isBusy)
    do {
      let many = (0...BatchConversionPolicy.maximumFiles).map { root.appendingPathComponent("slot/\($0).txt") }
      try batch.offer(many, configuration: configuration, qualified: true, owner: UUID(), window: nil)
      preconditionFailure("101 files must be rejected without truncation")
    } catch MacBatchConversionCoordinator.StartError.tooManyFiles(let count) {
      precondition(count == BatchConversionPolicy.maximumFiles + 1)
    }

    try batch.offer([input], configuration: configuration, qualified: true, owner: UUID(), window: nil)
    do {
      try large.offer(OpenedTextFile(url: input), configuration: configuration, qualified: true, owner: UUID(), window: nil)
      preconditionFailure("A large file must not start while a batch holds the slot")
    } catch MacLargeFileCoordinator.StartError.busy {}
    do {
      try batch.offer([input], configuration: configuration, qualified: true, owner: UUID(), window: nil)
      preconditionFailure("A second window must not start another batch")
    } catch MacBatchConversionCoordinator.StartError.busy {}
    batch.cancel()
    precondition(!batch.isBusy)
    try large.offer(OpenedTextFile(url: input), configuration: configuration, qualified: true, owner: UUID(), window: nil)
    do {
      try batch.offer([input], configuration: configuration, qualified: true, owner: UUID(), window: nil)
      preconditionFailure("A batch must not start while a large file holds the slot")
    } catch MacBatchConversionCoordinator.StartError.busy {}
    large.cancel()
    precondition(!large.isBusy)

    // Entitlement is checked again after the folder panel.
    var qualified = true
    let lapsing = MacBatchConversionCoordinator(qualified: { qualified }, otherTaskBusy: { false }, reportError: { _ in })
    try lapsing.offer([input], configuration: configuration, qualified: true, owner: UUID(), window: nil)
    qualified = false
    let output = root.appendingPathComponent("slot-out")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    lapsing.start(outputDirectory: output)
    precondition(lapsing.phase == .reviewing && lapsing.startFailure != nil && lapsing.queue?.convertibleCount == 1)
    let untouched = try directoryNames(output)
    precondition(untouched.isEmpty)
    lapsing.cancel()
  }

  @MainActor private static func checkRealBatch(_ root: URL) async throws {
    let sources = root.appendingPathComponent("real")
    let output = root.appendingPathComponent("real-out")
    let fixtures: [(String, Data)] = [
      ("bom.txt", Data([0xEF, 0xBB, 0xBF]) + Data("鼠标里面的硅二极管坏了，导致光标分辨率降低。".utf8)),
      ("crlf.txt", Data("软件\r\n内存\r\n\r\n硬盘".utf8)),
      ("mixed.txt", Data("汉字\r丁\u{2028}戊\u{2029}👩🏽‍💻e\u{301}\0甲\n头发".utf8)),
      ("empty.txt", Data()),
      ("invalid.txt", Data([0xE6, 0xB1, 0x89, 0xFF, 0xFE])),
      ("a/same.txt", Data("打印机".utf8)),
      ("b/same.txt", Data("出租车".utf8)),
    ]
    var urls = try fixtures.map { try write($0.1, sources.appendingPathComponent($0.0)) }
    // Existing targets: a regular file and a symlink to a source in the output folder.
    let preserved = Data("已有文件：不能被替换".utf8)
    _ = try write(preserved, output.appendingPathComponent("bom-converted.txt"))
    let notes = try write(Data("视频".utf8), output.appendingPathComponent("notes.txt"))
    try FileManager.default.createSymbolicLink(at: output.appendingPathComponent("notes-converted.txt"), withDestinationURL: notes)
    urls.append(notes)
    let before = try urls.map { try Data(contentsOf: $0) }

    let batch = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in })
    try batch.offer(urls, configuration: configuration, qualified: true, owner: UUID(), window: nil)
    precondition(batch.queue?.convertibleCount == urls.count)
    batch.start(outputDirectory: output)
    try await waitUntil { batch.phase == .finished }
    let states = batch.queue!.items.map(\.state)
    let expectedNames = ["bom-converted 2.txt", "crlf-converted.txt", "mixed-converted.txt", "empty-converted.txt",
                         nil, "same-converted.txt", "same-converted 2.txt", "notes-converted 2.txt"]
    for (state, name) in zip(states, expectedNames) {
      if let name {
        guard case let .succeeded(actual, _) = state, actual == name else { preconditionFailure("Expected \(name), got \(state)") }
      } else {
        guard case let .failed(reason) = state else { preconditionFailure("Invalid UTF-8 must fail, got \(state)") }
        precondition(reason.contains(TextFileService.FileError.invalidUTF8.localizedDescription))
      }
    }
    precondition(batch.queue!.succeededCount == 7 && batch.queue!.failedCount == 1 && batch.progress == 1)

    // Every output equals single-file streaming conversion and, for these
    // editor-sized files, the editor path (decode, then whole-text conversion).
    let reference = root.appendingPathComponent("reference")
    try FileManager.default.createDirectory(at: reference, withIntermediateDirectories: true)
    for (index, name) in expectedNames.enumerated() {
      guard let name else { continue }
      let single = reference.appendingPathComponent("\(index).txt")
      _ = try await StreamingTextFileService.convert(source: OpenedTextFile(url: urls[index]), destination: single, options: configuration.options)
      let actual = try Data(contentsOf: output.appendingPathComponent(name))
      let singleOutput = try Data(contentsOf: single)
      precondition(actual == singleOutput, "Batch output must match single-file conversion: \(name)")
      let editor = try ChineseConversionService.convertSynchronously(TextFileService.decode(before[index]), options: configuration.options)
      precondition(actual == Data(editor.utf8), "Batch output must match the editor path: \(name)")
    }
    let afterSources = try urls.map { try Data(contentsOf: $0) }
    precondition(afterSources == before, "Sources must not change")
    let existing = try Data(contentsOf: output.appendingPathComponent("bom-converted.txt"))
    precondition(existing == preserved, "Existing targets must not change")
    let link = try FileManager.default.destinationOfSymbolicLink(atPath: output.appendingPathComponent("notes-converted.txt").path)
    precondition(link == notes.path)
    let names = try directoryNames(output)
    precondition(names == Set(["bom-converted.txt", "notes.txt", "notes-converted.txt"] + expectedNames.compactMap { $0 }),
                 "No temporary file or partial output may remain: \(names)")
    batch.cancel()
    precondition(!batch.isBusy)
  }

  @MainActor private static func checkRaceAndDiskFull(_ root: URL) async throws {
    let output = root.appendingPathComponent("race-out")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let race = try write(Data("鼠标".utf8), root.appendingPathComponent("race/race.txt"))
    let full = try write(Data(String(repeating: "鼠标", count: 1000).utf8), root.appendingPathComponent("race/full.txt"))
    let after = try write(Data("软件".utf8), root.appendingPathComponent("race/after.txt"))
    let rival = Data("另一个程序写入的文件".utf8)
    let batch = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in }) { source, destination, options, progress in
      var hooks = StreamingTextFileService.Hooks()
      if destination.lastPathComponent == "race-converted.txt" {
        // Another writer takes the reserved name before conversion opens it.
        try rival.write(to: destination)
      }
      if source.sourceFilename == "full.txt" { hooks.availableBytes = { _ in 0 } }
      return try await StreamingTextFileService.convert(source: source, destination: destination, options: options,
                                                        replacingExisting: false, progress: progress, hooks: hooks)
    }
    try batch.offer([race, full, after], configuration: configuration, qualified: true, owner: UUID(), window: nil)
    batch.start(outputDirectory: output)
    try await waitUntil { batch.phase == .finished }
    let states = batch.queue!.items.map(\.state)
    guard case .succeeded("race-converted 2.txt", _) = states[0] else { preconditionFailure("A raced name must be renumbered: \(states[0])") }
    guard case let .failed(reason) = states[1],
          reason.contains(StreamingTextFileService.FileError.insufficientSpace.localizedDescription) else {
      preconditionFailure("Disk full must fail that file: \(states[1])")
    }
    guard case .succeeded("after-converted.txt", _) = states[2] else { preconditionFailure("A failure must not stop the batch: \(states[2])") }
    let rivalAfter = try Data(contentsOf: output.appendingPathComponent("race-converted.txt"))
    precondition(rivalAfter == rival, "The rival file must not be replaced")
    let raceNames = try directoryNames(output)
    precondition(raceNames == ["race-converted.txt", "race-converted 2.txt", "after-converted.txt"],
                 "Disk full must leave no partial output")
    batch.cancel()
  }

  @MainActor private static func checkCancellation(_ root: URL) async throws {
    let output = root.appendingPathComponent("cancel-out")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let urls = try (1...3).map { try write(Data("鼠标".utf8), root.appendingPathComponent("cancel/\($0).txt")) }
    let blocker = Blocker()
    let owner = UUID()
    let batch = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in }) { source, destination, _, _ in
      try await blocker.run(source: source, destination: destination)
    }
    try batch.offer(urls, configuration: configuration, qualified: true, owner: owner, window: nil)
    batch.start(outputDirectory: output)
    let deadline = Date().addingTimeInterval(5)
    while !(await blocker.started), Date() < deadline { await Task.yield() }
    precondition(batch.queue?.items[0].state == .converting)
    batch.cancel()
    precondition(batch.phase == .cancelling && batch.isWorking, "Keep the slot until the active file has cleaned up")
    await blocker.release()
    try await waitUntil { batch.phase == .finished }
    precondition(batch.queue!.items.allSatisfy { $0.state == .cancelled }, "Cancel stops the active and all waiting files")
    let cancelledNames = try directoryNames(output)
    precondition(cancelledNames.isEmpty)
    batch.cancel()
    precondition(!batch.isBusy)

    // Closing the owner window cancels and releases the slot.
    let closing = Blocker()
    let closed = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in }) { source, destination, _, _ in
      try await closing.run(source: source, destination: destination)
    }
    try closed.offer(urls, configuration: configuration, qualified: true, owner: owner, window: nil)
    closed.start(outputDirectory: output)
    while !(await closing.started) { await Task.yield() }
    closed.ownerDidClose(owner)
    precondition(closed.isBusy)
    await closing.release()
    try await waitUntil { !closed.isBusy }
  }

  @MainActor private static func checkFolderProblems(_ root: URL) async throws {
    let urls = try (1...3).map { try write(Data("鼠标".utf8), root.appendingPathComponent("folder/\($0).txt")) }
    let readOnly = root.appendingPathComponent("read-only")
    try FileManager.default.createDirectory(at: readOnly, withIntermediateDirectories: true)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnly.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnly.path) }
    let batch = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in })
    try batch.offer(urls, configuration: configuration, qualified: true, owner: UUID(), window: nil)
    batch.start(outputDirectory: readOnly)
    precondition(batch.phase == .reviewing && batch.startFailure == MacBatchConversionCoordinator.StartError.folderUnavailable.localizedDescription,
                 "A read-only folder is refused before any file starts")
    let readOnlyNames = try directoryNames(readOnly)
    precondition(batch.queue?.convertibleCount == 3 && readOnlyNames.isEmpty)
    batch.cancel()

    let lost = root.appendingPathComponent("lost-out")
    try FileManager.default.createDirectory(at: lost, withIntermediateDirectories: true)
    let losing = MacBatchConversionCoordinator(qualified: { true }, otherTaskBusy: { false }, reportError: { _ in }) { _, _, _, _ in
      try FileManager.default.removeItem(at: lost)
      throw POSIXError(.ENOENT)
    }
    try losing.offer(urls, configuration: configuration, qualified: true, owner: UUID(), window: nil)
    losing.start(outputDirectory: lost)
    try await waitUntil { losing.phase == .finished }
    let reason = MacBatchConversionCoordinator.StartError.folderUnavailable.localizedDescription
    precondition(losing.queue!.items.allSatisfy { $0.state == .failed(reason) }, "A lost folder ends the batch with its reason")
    losing.cancel()
  }
}
#endif

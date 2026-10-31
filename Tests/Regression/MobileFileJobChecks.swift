import Darwin
import Foundation
import OpenCC

func checkMobileFileJobs() async throws {
  let fm = FileManager.default
  let directory = fm.temporaryDirectory.appendingPathComponent("mobile-jobs-\(UUID().uuidString)")
  try fm.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fm.removeItem(at: directory) }
  try checkMobileCapacityCache(directory)
  let source = directory.appendingPathComponent("稿件.txt")
  let text = "头发干杯显存鼠标\0👨‍👩‍👧‍👦e\u{301}\r\n\n"
  let bytes = Data([0xef, 0xbb, 0xbf]) + Data(text.utf8)
  try bytes.write(to: source)
  let expected = Data(try ChineseConversionService.convertSynchronously(text, options: .traditionalize).utf8)
  let gate = LargeFileProtectionGate(available: true)
  func root() -> URL { directory.appendingPathComponent(UUID().uuidString) }
  func service(_ url: URL, hooks: MobileLargeFileService.Hooks = .init()) -> MobileLargeFileService {
    MobileLargeFileService(root: url, protection: gate, hooks: hooks)
  }
  func empty(_ url: URL) throws -> Bool { try fm.contentsOfDirectory(atPath: url.path).isEmpty }

  let store = root()
  let first = service(store)
  try requireMobileJob(await first.recover() == .empty)
  let ready = try await first.convert(source: source, options: .traditionalize)
  try requireMobileJob(Data(contentsOf: ready.url) == expected)
  precondition(ready.exportFilename == "稿件-converted.txt")
  precondition(ready.url.lastPathComponent == ready.exportFilename)
  precondition(ready.optionsRawValue == ChineseConverter.Options.traditionalize.rawValue)
  try requireMobileJob(Data(contentsOf: source) == bytes)
  precondition(!fm.fileExists(atPath: ready.url.deletingLastPathComponent().appendingPathComponent("input.txt").path))
  try requireMobileJob(await first.exportURL(for: ready.id) == ready.url)
  do {
    _ = try await first.convert(source: source, options: .simplify)
    preconditionFailure("An unexported result reserves the only job slot")
  } catch MobileLargeFileService.JobError.pendingResult {}
  do { try await first.discard(UUID()); preconditionFailure("Late callbacks must not delete the current result") }
  catch MobileLargeFileService.JobError.staleJob {}
  gate.setAvailable(false)
  try requireMobileJob(await service(store).recover() == .protectedDataUnavailable)
  precondition(fm.fileExists(atPath: ready.url.path))
  gate.setAvailable(true)
  let restarted = service(store)
  try requireMobileJob(await restarted.recover() == .ready(ready))
  try await restarted.discard(ready.id)
  try requireMobileJob(empty(store))

  let stages: [MobileLargeFileService.Stage] = [.snapshotRead, .snapshotWrite, .snapshotSync,
    .conversionRead, .conversionWrite, .outputSync, .beforeCommit, .afterOutputRename, .beforeJournalRename]
  for stage in stages {
    let store = root()
    let instance = service(store, hooks: .init(boundary: { if $0 == stage { throw POSIXError(.ENOSPC) } }))
    do { _ = try await instance.convert(source: source, options: .traditionalize); preconditionFailure("Injected I/O must fail") }
    catch let error as POSIXError { precondition(error.code == .ENOSPC) }
    try requireMobileJob(empty(store), "No partial or ready record survives a failed job")
    try requireMobileJob(Data(contentsOf: source) == bytes)
  }
  for stage in [MobileLargeFileService.Stage.snapshotRead, .conversionRead, .beforeCommit] {
    let store = root()
    let barrier = MobileJobBarrier()
    let instance = service(store, hooks: .init(boundary: { if $0 == stage { barrier.pauseOnce() } }))
    let task = Task { try await instance.convert(source: source, options: .traditionalize) }
    try await barrier.waitUntilPaused()
    task.cancel()
    barrier.resume()
    do { _ = try await task.value; preconditionFailure("Cancellation before publication wins") }
    catch is CancellationError {}
    try requireMobileJob(empty(store), "Continuation resumes only after worker cleanup")
  }
  // Publication owns the cancellation lock: cancellation from another thread
  // must not deadlock or change the completed job into a reported failure.
  let commitStore = root()
  let commitBarrier = MobileJobBarrier()
  let commitService = service(commitStore, hooks: .init(boundary: { if $0 == .afterOutputRename { commitBarrier.pauseOnce() } }))
  let committedTask = Task { try await commitService.convert(source: source, options: .traditionalize) }
  try await commitBarrier.waitUntilPaused()
  let cancelFinished = DispatchSemaphore(value: 0)
  DispatchQueue.global().async { committedTask.cancel(); cancelFinished.signal() }
  commitBarrier.resume()
  let committed = try await committedTask.value
  precondition(cancelFinished.wait(timeout: .now() + 5) == .success)
  try requireMobileJob(await commitService.recover() == .ready(committed))
  try await commitService.discard(committed.id)

  let noSpace = root()
  do {
    _ = try await service(noSpace, hooks: .init(availableBytes: { _ in 0 })).convert(source: source, options: .simplify)
    preconditionFailure("Known insufficient space is rejected")
  } catch MobileLargeFileService.JobError.insufficientSpace {}
  try requireMobileJob(empty(noSpace))
  let unknown = service(root(), hooks: .init(availableBytes: { _ in nil }))
  let unknownReady = try await unknown.convert(source: source, options: .traditionalize)
  try await unknown.discard(unknownReady.id)

  let changedStore = root()
  do {
    _ = try await service(changedStore, hooks: .init(boundary: {
      if $0 == .snapshotWrite { try Data("changed".utf8).write(to: source) }
    })).convert(source: source, options: .traditionalize)
    preconditionFailure("A changing source cannot publish a snapshot")
  } catch TextFileService.FileError.sourceChanged {}
  try requireMobileJob(empty(changedStore))
  try bytes.write(to: source)

  let cleanupStore = root()
  do {
    _ = try await service(cleanupStore, hooks: .init(boundary: {
      if $0 == .snapshotRead { throw POSIXError(.EIO) }
      if $0 == .cleanup { throw POSIXError(.EACCES) }
    })).convert(source: source, options: .traditionalize)
    preconditionFailure("Cleanup errors must remain observable")
  } catch let error as MobileLargeFileService.CleanupError {
    precondition((error.primary as? POSIXError)?.code == .EIO)
    precondition((error.cleanup as? POSIXError)?.code == .EACCES)
  }
  try requireMobileJob(!(try empty(cleanupStore)))
  try requireMobileJob(await service(cleanupStore).recover() == .empty)
  try requireMobileJob(empty(cleanupStore))

  let protectedStore = root()
  do {
    _ = try await service(protectedStore, hooks: .init(boundary: {
      if $0 == .conversionRead { gate.setAvailable(false) }
    })).convert(source: source, options: .traditionalize)
    preconditionFailure("Protection loss must stop the worker")
  } catch let error as MobileLargeFileService.CleanupError {
    guard case MobileLargeFileService.JobError.protectedDataUnavailable = error.primary else { throw error }
  }
  try requireMobileJob(await service(protectedStore).recover() == .protectedDataUnavailable)
  gate.setAvailable(true)
  try requireMobileJob(await service(protectedStore).recover() == .empty)
  try requireMobileJob(empty(protectedStore))

  let inputCleanupStore = root()
  let inputCleanup = service(inputCleanupStore, hooks: .init(boundary: {
    if $0 == .inputCleanup { throw POSIXError(.EACCES) }
  }))
  let pendingCleanup = try await inputCleanup.convert(source: source, options: .traditionalize)
  precondition(pendingCleanup.cleanupPending)
  guard case .ready(let retriedCleanup) = try await service(inputCleanupStore).recover() else {
    preconditionFailure("A committed result survives failed input cleanup")
  }
  precondition(!retriedCleanup.cleanupPending)
  try requireMobileJob(Data(contentsOf: retriedCleanup.url) == expected)

  let oversized = directory.appendingPathComponent("oversized.txt")
  fm.createFile(atPath: oversized.path, contents: nil)
  let sparse = try FileHandle(forWritingTo: oversized)
  try sparse.truncate(atOffset: FileConversionPolicy.mobileMaximumBytes + 1)
  try sparse.close()
  let oversizedStore = root()
  do { _ = try await service(oversizedStore).convert(source: oversized, options: .simplify); preconditionFailure("100 MiB + 1 is rejected before copy") }
  catch MobileLargeFileService.JobError.inputTooLarge {}
  try requireMobileJob(empty(oversizedStore))

  let serialStore = root()
  let serialService = service(serialStore)
  // Two concurrently submitted jobs share the same queue and persistent slot.
  async let a = serialService.convert(source: source, options: .simplify)
  async let b = serialService.convert(source: source, options: .traditionalize)
  var successes = 0
  do { _ = try await a; successes += 1 } catch MobileLargeFileService.JobError.pendingResult {}
  do { _ = try await b; successes += 1 } catch MobileLargeFileService.JobError.pendingResult {}
  precondition(successes == 1)

  // Recovery follows no symlinks, and does not enumerate unrelated namespaces.
  let outside = directory.appendingPathComponent("outside.txt")
  try Data("keep".utf8).write(to: outside)
  let symlinkStore = root()
  try fm.createDirectory(at: symlinkStore, withIntermediateDirectories: true)
  let incomplete = symlinkStore.appendingPathComponent("job-" + UUID().uuidString)
  try fm.createDirectory(at: incomplete, withIntermediateDirectories: true)
  try fm.createSymbolicLink(at: incomplete.appendingPathComponent("output.partial"), withDestinationURL: outside)
  let unrelated = symlinkStore.appendingPathComponent("unrelated")
  try fm.createSymbolicLink(at: unrelated, withDestinationURL: directory)
  try requireMobileJob(await service(symlinkStore).recover() == .empty)
  try requireMobileJob(Data(contentsOf: outside) == Data("keep".utf8))
  precondition(fm.fileExists(atPath: unrelated.path))
  let hostile = symlinkStore.appendingPathComponent("job-" + UUID().uuidString)
  try fm.createSymbolicLink(at: hostile, withDestinationURL: directory)
  do { _ = try await service(symlinkStore).recover(); preconditionFailure("A job directory cannot be a symlink") }
  catch MobileLargeFileService.JobError.invalidStore {}

  // Same-length corruption is detected by streaming SHA256, not just size.
  let damagedStore = root()
  let damaged = try await service(damagedStore).convert(source: source, options: .traditionalize)
  try Data(repeating: 0x61, count: Int(damaged.outputBytes)).write(to: damaged.url)
  do { _ = try await service(damagedStore).recover(); preconditionFailure("Corrupt ready output cannot be exported") }
  catch MobileLargeFileService.JobError.invalidJournal {}
  precondition(fm.fileExists(atPath: damaged.url.path), "An invalid journal requires explicit handling, not automatic deletion")
  let repair = service(damagedStore)
  try await repair.discardStoredJobs()
  try requireMobileJob(await repair.recover() == .empty)
  try requireMobileJob(empty(damagedStore))
  try await checkMobileExperimentalJobs()
  print("PASS: mobile job snapshot, recovery, full hash, nine I/O faults, cancellation/commit races, space, cleanup failures and symlink boundaries")
}

private func checkMobileExperimentalJobs() async throws {
  let fm = FileManager.default
  let directory = fm.temporaryDirectory.appendingPathComponent("mobile-experimental-\(UUID())")
  try fm.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? fm.removeItem(at: directory) }
  let source = directory.appendingPathComponent("capacity.txt")
  fm.createFile(atPath: source.path, contents: Data("头发鼠标\0\r\n".utf8))
  let handle = try FileHandle(forWritingTo: source)
  defer { try? handle.close() }
  func store(_ root: URL, hooks: MobileLargeFileService.Hooks = .init()) -> MobileLargeFileService {
    .init(root: root, protection: .init(available: true), hooks: hooks)
  }
  enum Probe: Error { case reachedRead }
  // Sparse files test routing before expensive copying. These are boundary
  // checks, not evidence that a full 1 GiB conversion succeeded.
  let sizes: [UInt64] = [FileConversionPolicy.mobileMaximumBytes, FileConversionPolicy.mobileMaximumBytes + 1,
                        256 * 1024 * 1024, 512 * 1024 * 1024, FileConversionPolicy.mobileExperimentalMaximumBytes]
  for size in sizes {
    try handle.truncate(atOffset: size)
    let root = directory.appendingPathComponent(UUID().uuidString)
    let service = store(root, hooks: .init(boundary: { if $0 == .snapshotRead { throw Probe.reachedRead } },
                                          availableBytes: { _ in Int64.max }))
    do { _ = try await service.convert(source: source, options: .traditionalize, capacity: .experimental); preconditionFailure("Read probe must stop") }
    catch Probe.reachedRead {}
    try requireMobileJob(fm.contentsOfDirectory(atPath: root.path).isEmpty)
    try requireMobileJob(TextFileFingerprint.read(url: source)?.size == size)
  }
  try handle.truncate(atOffset: FileConversionPolicy.mobileExperimentalMaximumBytes + 1)
  let tooLarge = directory.appendingPathComponent("too-large")
  do {
    _ = try await store(tooLarge, hooks: .init(boundary: { if $0 == .snapshotRead { preconditionFailure("Must reject before reading") } }))
      .convert(source: source, options: .traditionalize, capacity: .experimental)
    preconditionFailure("The experimental upper bound is finite")
  } catch MobileLargeFileService.JobError.experimentalInputTooLarge {}
  try requireMobileJob(fm.contentsOfDirectory(atPath: tooLarge.path).isEmpty)

  // Real just-over-standard conversion, persisted policy, recovery, and export.
  try handle.truncate(atOffset: FileConversionPolicy.mobileMaximumBytes + 1)
  let root = directory.appendingPathComponent("roundtrip")
  let instance = store(root)
  let ready = try await instance.convert(source: source, options: .traditionalize, capacity: .experimental)
  precondition(ready.capacity == .experimental)
  let original = try String(contentsOf: source, encoding: .utf8)
  let oracle = Data(try ChineseConversionService.convertSynchronously(original, options: .traditionalize).utf8)
  try requireMobileJob(Data(contentsOf: ready.url) == oracle, "Compare the entire output with independent whole-text conversion")
  let restored = store(root)
  try requireMobileJob(await restored.recover() == .ready(ready))
  try requireMobileJob(await restored.exportURL(for: ready.id) == ready.url)
  try await restored.discard(ready.id)
  try requireMobileJob(fm.contentsOfDirectory(atPath: root.path).isEmpty)

  // Space may disappear after a successful preflight. The write-stage monitor
  // observes it, reports failure, and removes only this task's temporary files.
  try Data("头发\0👨‍👩‍👧‍👦\r\n".utf8).write(to: source)
  for stage in [MobileLargeFileService.Stage.snapshotWrite, .conversionWrite] {
    let root = directory.appendingPathComponent(UUID().uuidString)
    let budget = MobileSpaceProbe()
    do {
      _ = try await store(root, hooks: .init(boundary: { if $0 == stage { budget.exhaust() } },
                                           availableBytes: { _ in budget.read() }))
        .convert(source: source, options: .traditionalize, capacity: .experimental)
      preconditionFailure("Disk space lost during work must be detected")
    } catch MobileLargeFileService.JobError.insufficientSpace {}
    try requireMobileJob(fm.contentsOfDirectory(atPath: root.path).isEmpty)
  }

  // Legacy results still restore, but a missing/unknown policy never grants a
  // larger allowance, and corrupt output lengths cannot overflow export math.
  let journalRoot = directory.appendingPathComponent("journal")
  let smallReady = try await store(journalRoot).convert(source: source, options: .traditionalize)
  let journalURL = smallReady.url.deletingLastPathComponent().appendingPathComponent("ready.json")
  let legacy = try JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as! [String: Any]
  precondition(legacy["schema"] as? Int == 1 && legacy["capacity"] == nil, "Standard results remain backward-readable")
  try JSONSerialization.data(withJSONObject: legacy).write(to: journalURL)
  try requireMobileJob(await store(journalRoot).recover() == .ready(smallReady))
  let experimentalRoot = directory.appendingPathComponent("experimental-journal")
  let experimentalReady = try await store(experimentalRoot).convert(source: source, options: .traditionalize, capacity: .experimental)
  let experimentalJournalURL = experimentalReady.url.deletingLastPathComponent().appendingPathComponent("ready.json")
  let valid = try JSONSerialization.jsonObject(with: Data(contentsOf: experimentalJournalURL)) as! [String: Any]
  precondition(valid["schema"] as? Int == 2 && valid["capacity"] as? String == "experimental")
  try requireMobileJob(await store(experimentalRoot).recover() == .ready(experimentalReady))
  var invalids: [[String: Any]] = []
  var missing = valid; missing.removeValue(forKey: "capacity"); invalids.append(missing)
  var unknown = valid; unknown["capacity"] = "unlimited"; invalids.append(unknown)
  var unwrittenStandard = valid; unwrittenStandard["capacity"] = "standard"; invalids.append(unwrittenStandard)
  var unwrittenLegacy = valid; unwrittenLegacy["schema"] = 1; invalids.append(unwrittenLegacy)
  var oversizedLegacy = legacy; oversizedLegacy["inputBytes"] = FileConversionPolicy.mobileMaximumBytes + 1; invalids.append(oversizedLegacy)
  var oversizedExperimental = valid; oversizedExperimental["capacity"] = "experimental"; oversizedExperimental["inputBytes"] = FileConversionPolicy.mobileExperimentalMaximumBytes + 1; invalids.append(oversizedExperimental)
  var overflow = valid; overflow["outputBytes"] = UInt64.max; invalids.append(overflow)
  for invalid in invalids {
    let destination = invalid["id"] as? String == smallReady.id.uuidString ? journalURL : experimentalJournalURL
    try JSONSerialization.data(withJSONObject: invalid).write(to: destination)
    do { _ = try await store(destination.deletingLastPathComponent().deletingLastPathComponent()).recover(); preconditionFailure("Invalid capacity journal must be rejected") }
    catch MobileLargeFileService.JobError.invalidJournal {}
    precondition(fm.fileExists(atPath: smallReady.url.path), "Recovery must not delete an unverified complete result")
    precondition(fm.fileExists(atPath: experimentalReady.url.path), "Recovery must preserve experimental results too")
  }
  print("PASS: mobile 100 MiB/256 MiB/512 MiB/1 GiB admission, 1 GiB+1 rejection, full 100 MiB+1 oracle/recovery/export, mid-write space loss and legacy/corrupt journals")
}

/// Exercise the real default query against a removed directory. This models
/// storage becoming unavailable without depending on volatile free-space values.
private func checkMobileCapacityCache(_ directory: URL) throws {
  let query = MobileLargeFileService.Hooks().availableBytes
  let queue = DispatchQueue(label: "OpenCCman.capacity-cache-test")
  let url = directory.appendingPathComponent("capacity-cache").standardizedFileURL
  for _ in 0..<2 {
    try queue.sync {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
      _ = try query(url)
      try FileManager.default.removeItem(at: url)
    }
    try queue.sync {
      do {
        _ = try query(url)
        throw NSError(domain: "OpenCCman.CapacityCacheRegression", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Default query returned cached capacity after its directory disappeared"])
      } catch let error as NSError where error.domain == NSCocoaErrorDomain
          && error.code == CocoaError.fileReadNoSuchFile.rawValue {}
    }
  }
  print("PASS: default capacity query detects a removed directory across worker blocks, then succeeds after recreation")
}

private final class MobileSpaceProbe: @unchecked Sendable {
  private let lock = NSLock()
  private var available: Int64 = Int64.max
  func exhaust() { lock.lock(); available = 0; lock.unlock() }
  func read() -> Int64 { lock.lock(); defer { lock.unlock() }; return available }
}

private final class MobileJobBarrier: @unchecked Sendable {
  private let lock = NSLock()
  private var paused = false
  private let release = DispatchSemaphore(value: 0)
  func pauseOnce() {
    lock.lock()
    if paused { lock.unlock(); return }
    paused = true
    lock.unlock()
    precondition(release.wait(timeout: .now() + 20) == .success, "Test barrier timed out")
  }
  func waitUntilPaused() async throws {
    for _ in 0..<2000 {
      if isPaused() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    preconditionFailure("Worker did not reach the requested boundary")
  }
  private func isPaused() -> Bool { lock.lock(); defer { lock.unlock() }; return paused }
  func resume() { release.signal() }
}

private func requireMobileJob(_ value: Bool, _ message: String = "Mobile job assertion failed", file: StaticString = #file, line: UInt = #line) throws { precondition(value, message, file: file, line: line) }

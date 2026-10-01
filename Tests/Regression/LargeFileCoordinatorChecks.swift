#if os(macOS)
import Foundation
import OpenCC

enum LargeFileCoordinatorChecks {
  private actor Worker {
    var started = false
    private var continuation: CheckedContinuation<Void, Never>?
    let commitWins: Bool
    let failure: Error?

    init(commitWins: Bool = false, failure: Error? = nil) {
      self.commitWins = commitWins
      self.failure = failure
    }

    func run(source: OpenedTextFile, destination: URL,
             progress: @Sendable (UInt64, UInt64) -> Void) async throws -> StreamingTextFileService.Result {
      progress(source.byteCount, source.byteCount)
      await withCheckedContinuation { continuation in
        self.continuation = continuation
        started = true
      }
      if let failure { throw failure }
      if !commitWins { try Task.checkCancellation() }
      progress(source.byteCount, source.byteCount)
      return StreamingTextFileService.Result(
        destination: destination, inputBytes: source.byteCount, outputBytes: source.byteCount)
    }

    func finishCleanup() { continuation?.resume(); continuation = nil }
  }

  @MainActor
  static func run() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let input = directory.appendingPathComponent("source.txt")
    let output = directory.appendingPathComponent("converted.txt")
    try Data("头发与鼠标".utf8).write(to: input)
    let configuration = ConversionConfiguration(target: .traditional, variant: .taiwan, region: .taiwan)
    let owner = UUID()
    let worker = Worker()
    var reportedErrors: [NSError] = []
    let coordinator = MacLargeFileCoordinator(enabled: true, qualified: { true }, reportError: { reportedErrors.append($0 as NSError) }) { source, destination, _, _, progress in
      try await worker.run(source: source, destination: destination, progress: progress)
    }
    let source = try OpenedTextFile(url: input)
    do {
      try coordinator.offer(source, configuration: configuration, qualified: false, owner: owner, window: nil)
      preconditionFailure("Free access must not reserve a large-file task")
    } catch MacLargeFileCoordinator.StartError.requiresPro {}
    precondition(!coordinator.isBusy)
    try coordinator.offer(source, configuration: configuration, qualified: true, owner: owner, window: nil)
    precondition(coordinator.session?.configuration == configuration)
    precondition(coordinator.session?.qualifiedAtStart == true)
    do {
      try coordinator.offer(source, configuration: configuration, qualified: true, owner: UUID(), window: nil)
      preconditionFailure("A second window must not replace the current file")
    } catch MacLargeFileCoordinator.StartError.busy {}
    coordinator.ownerDidClose(UUID())
    precondition(coordinator.phase == .confirmation)
    coordinator.start(destination: output)
    await waitForWorker(worker)
    await waitUntil { coordinator.processedBytes == source.byteCount }
    precondition(coordinator.progress < 1, "Reading the last byte is not a committed output")
    coordinator.cancel()
    precondition(coordinator.phase == .cancelling && coordinator.isBusy,
                 "Cancellation must retain the application reservation until worker cleanup")
    coordinator.ownerDidClose(owner)
    precondition(coordinator.isBusy)
    await worker.finishCleanup()
    await waitUntil { !coordinator.isBusy }
    precondition(reportedErrors.isEmpty, "Normal owner-window cancellation stays silent")
    do {
      _ = try source.beginReading()
      preconditionFailure("Cleanup must release the retained file even when another reference exists")
    } catch TextFileService.FileError.sourceUnavailable {}

    // Atomic commit can win a cancellation race. The UI must display the saved
    // file, not overwrite a successful result with a synthetic cancellation.
    let committingWorker = Worker(commitWins: true)
    let committing = MacLargeFileCoordinator(enabled: true, qualified: { true }, operation: { source, destination, _, _, progress in
      try await committingWorker.run(source: source, destination: destination, progress: progress)
    })
    try committing.offer(OpenedTextFile(url: input), configuration: configuration,
                         qualified: true, owner: owner, window: nil)
    committing.start(destination: output)
    await waitForWorker(committingWorker)
    committing.cancel()
    await committingWorker.finishCleanup()
    await waitUntil { committing.phase == .completed }
    precondition(committing.destination == output && committing.progress == 1)
    precondition(committing.isBusy, "Keep success visible until the user closes it")
    committing.cancel()
    precondition(!committing.isBusy)

    let failing = MacLargeFileCoordinator(enabled: true, qualified: { true }, operation: { _, _, _, _, _ in
      throw TextFileService.FileError.invalidUTF8
    })
    try failing.offer(OpenedTextFile(url: input), configuration: configuration,
                      qualified: true, owner: owner, window: nil)
    failing.start(destination: output)
    await waitUntil { failing.phase == .failed }
    precondition(failing.failureDescription != nil && failing.isBusy)
    failing.cancel()
    precondition(!failing.isBusy)

    let cleanupFailure = StreamingTextFileService.CleanupError(
      primaryError: CancellationError(), cleanupError: CocoaError(.fileWriteNoPermission),
      temporaryDirectory: directory.appendingPathComponent("private-conversion"))
    let cleanupWorker = Worker(failure: cleanupFailure)
    let cleanup = MacLargeFileCoordinator(enabled: true, qualified: { true }, reportError: { reportedErrors.append($0 as NSError) }) { source, destination, _, _, progress in
      try await cleanupWorker.run(source: source, destination: destination, progress: progress)
    }
    try cleanup.offer(OpenedTextFile(url: input), configuration: configuration,
                      qualified: true, owner: owner, window: nil)
    cleanup.start(destination: output)
    await waitForWorker(cleanupWorker)
    cleanup.ownerDidClose(owner)
    await cleanupWorker.finishCleanup()
    await waitUntil { !cleanup.isBusy }
    precondition(reportedErrors.count == 1, "A closed owner must not hide cleanup failures")
    precondition(reportedErrors[0].localizedRecoverySuggestion?.contains(cleanupFailure.temporaryDirectory.path) == true,
                 "Show the private recovery path to the user, rather than in a public log")

    let terminatingWorker = Worker()
    let terminating = MacLargeFileCoordinator(enabled: true, qualified: { true }, reportError: { reportedErrors.append($0 as NSError) }) { source, destination, _, _, progress in
      try await terminatingWorker.run(source: source, destination: destination, progress: progress)
    }
    try terminating.offer(OpenedTextFile(url: input), configuration: configuration,
                          qualified: true, owner: owner, window: nil)
    terminating.start(destination: output)
    await waitForWorker(terminatingWorker)
    var readyToTerminate = false
    let termination = Task {
      await terminating.prepareForTermination()
      readyToTerminate = true
    }
    await waitUntil { terminating.phase == .cancelling }
    precondition(!readyToTerminate && terminating.isBusy,
                 "Quit and language restart must wait until the file worker finishes cleanup")
    await terminatingWorker.finishCleanup()
    await termination.value
    precondition(readyToTerminate && !terminating.isBusy && reportedErrors.count == 1)

    let disabled = MacLargeFileCoordinator(enabled: false)
    let disabledSource = try OpenedTextFile(url: input)
    do {
      try disabled.offer(disabledSource, configuration: configuration,
                         qualified: true, owner: owner, window: nil)
      preconditionFailure("An explicitly disabled coordinator must reject file tasks")
    } catch TextFileService.FileError.tooLarge {}
    precondition(!disabled.isBusy)
    do {
      _ = try disabledSource.beginReading()
      preconditionFailure("A disabled feature must release the rejected descriptor")
    } catch TextFileService.FileError.sourceUnavailable {}
    // Sparse files exercise the real opened-descriptor metadata boundary
    // without allocating or converting a GiB of test data.
    let sparse = directory.appendingPathComponent("capacity.txt")
    _ = FileManager.default.createFile(atPath: sparse.path, contents: nil)
    let writer = try FileHandle(forWritingTo: sparse)
    try writer.truncate(atOffset: MacLargeFileCoordinator.maximumBytes)
    let exactLimit = try OpenedTextFile(url: sparse)
    try coordinator.offer(exactLimit, configuration: configuration,
                          qualified: true, owner: owner, window: nil)
    precondition(coordinator.session?.byteCount == MacLargeFileCoordinator.maximumBytes)
    coordinator.cancel()
    try writer.truncate(atOffset: MacLargeFileCoordinator.maximumBytes + 1)
    try writer.close()
    let overLimit = try OpenedTextFile(url: sparse)
    do {
      try coordinator.offer(overLimit, configuration: configuration,
                            qualified: false, owner: owner, window: nil)
      preconditionFailure("Capacity must be checked before Pro eligibility")
    } catch MacLargeFileCoordinator.StartError.exceedsCapacity {}
    try overLimit.close()
    let model = HomeViewModel()
    model.inputText = "Original draft"
    model.resultText = "Original result"
    model.importFile(sparse)
    await waitUntil { !model.isImporting }
    precondition(model.error as? MacLargeFileCoordinator.StartError == .exceedsCapacity,
                 "Production must reject files above the 1 GiB direct-export limit")
    precondition(!model.showingProAlert, "Files above the supported capacity must not open the paywall")
    precondition(model.inputText == "Original draft" && model.resultText == "Original result")
    try await checkExperimental(directory, configuration: configuration)
    print("PASS: one Mac file task across windows; 1 GiB capacity; entitlement/configuration snapshot; owner close and quit cleanup; recovery report; commit race and failure state")
  }

  @MainActor private static func checkExperimental(_ directory: URL, configuration: ConversionConfiguration) async throws {
    let input = directory.appendingPathComponent("experimental.txt")
    let output = directory.appendingPathComponent("experimental-out.txt")
    FileManager.default.createFile(atPath: input.path, contents: nil)
    let writer = try FileHandle(forWritingTo: input)
    defer { try? writer.close() }
    var gate = true
    var pro = true
    let worker = Worker(commitWins: true)
    let coordinator = MacLargeFileCoordinator(enabled: true, experimentalEnabled: { gate }, qualified: { pro }, operation: {
      source, destination, _, capacity, progress in
      precondition(capacity == .experimental)
      return try await worker.run(source: source, destination: destination, progress: progress)
    })
    for size: UInt64 in [2 * 1024 * 1024 * 1024, 4 * 1024 * 1024 * 1024 + 1, FileConversionPolicy.macExperimentalMaximumBytes] {
      try writer.truncate(atOffset: size)
      try coordinator.offer(OpenedTextFile(url: input), configuration: configuration, qualified: true, owner: UUID(), window: nil)
      precondition(coordinator.session?.byteCount == size)
      coordinator.chooseDestination()
      precondition(coordinator.phase == .capacityConfirmation)
      coordinator.start(destination: output)
      precondition(coordinator.phase == .capacityConfirmation, "Cannot bypass the per-file confirmation")
      let neverStarted = await worker.started
      precondition(!neverStarted)
      coordinator.cancel()
      precondition(!coordinator.isBusy)
    }
    try writer.truncate(atOffset: FileConversionPolicy.macExperimentalMaximumBytes + 1)
    let oversized = try OpenedTextFile(url: input)
    defer { try? oversized.close() }
    do {
      try coordinator.offer(oversized, configuration: configuration, qualified: false, owner: UUID(), window: nil)
      preconditionFailure("8 GiB+1 must be rejected before Pro")
    } catch MacLargeFileCoordinator.StartError.exceedsExperimentalCapacity {}
    try writer.truncate(atOffset: 4 * 1024 * 1024 * 1024 + 1)
    func offer() throws {
      try coordinator.offer(OpenedTextFile(url: input), configuration: configuration, qualified: true, owner: UUID(), window: nil)
      coordinator.chooseDestination()
      precondition(coordinator.phase == .capacityConfirmation)
    }
    try offer()
    let stale = coordinator.session!.id
    coordinator.cancel()
    try offer()
    coordinator.confirmExperimentalCapacity(for: stale)
    precondition(coordinator.phase == .capacityConfirmation, "Old confirmation cannot authorize the newly selected file")
    gate = false
    coordinator.confirmExperimentalCapacity(for: coordinator.session!.id)
    precondition(coordinator.phase == .failed)
    coordinator.cancel()
    gate = true
    try offer()
    coordinator.confirmExperimentalCapacity(for: coordinator.session!.id)
    pro = false
    coordinator.start(destination: output)
    precondition(coordinator.phase == .failed, "Recheck Pro after confirming and choosing a destination")
    coordinator.cancel()
    pro = true
    try offer()
    coordinator.confirmExperimentalCapacity(for: coordinator.session!.id)
    coordinator.start(destination: output)
    await waitForWorker(worker)
    await waitUntil { coordinator.processedBytes == 4 * 1024 * 1024 * 1024 + 1 }
    await worker.finishCleanup()
    await waitUntil { coordinator.phase == .completed }
    precondition(coordinator.progress == 1 && coordinator.outputBytes == 4 * 1024 * 1024 * 1024 + 1)
    coordinator.cancel()
    precondition(MacFileCapacity.estimatedStorageBytes(for: UInt64.max) == nil)
    precondition(MacFileCapacity.estimatedStorageBytes(for: FileConversionPolicy.macExperimentalMaximumBytes) == 16 * 1024 * 1024 * 1024 + 64 * 1024 * 1024)
    print("PASS: Mac experimental 2/4/8 GiB metadata, +1 rejection, per-file consent, stale responses, gate/Pro recheck and >32-bit progress; metadata and state tests only")
  }

  private static func waitForWorker(_ worker: Worker) async {
    let deadline = Date().addingTimeInterval(5)
    while !(await worker.started), Date() < deadline { await Task.yield() }
    let started = await worker.started
    precondition(started)
  }

  @MainActor private static func waitUntil(_ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(5)
    while !condition(), Date() < deadline { await Task.yield() }
    precondition(condition())
  }
}
#endif

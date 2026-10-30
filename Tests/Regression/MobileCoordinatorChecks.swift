import Foundation
import OpenCC

@MainActor
func checkMobileCoordinator() async throws {
  let fm = FileManager.default
  let root = fm.temporaryDirectory.appendingPathComponent("mobile-coordinator-\(UUID().uuidString)")
  try fm.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? fm.removeItem(at: root) }
  let sourceURL = root.appendingPathComponent("source.txt")
  fm.createFile(atPath: sourceURL.path, contents: Data("鼠标".utf8))
  let handle = try FileHandle(forWritingTo: sourceURL)
  try handle.truncate(atOffset: UInt64(FileConversionPolicy.editorMaximumBytes + 1))
  try handle.close()
  let service = MobileLargeFileService(root: root.appendingPathComponent("jobs"), protection: .init(available: true))
  var qualified = false
  var began = 0
  var ended = 0
  let coordinator = MobileLargeFileCoordinator(factory: { service }, isQualified: { qualified },
                                               beginWork: { began += 1 }, endWork: { ended += 1 })
  coordinator.recover()
  coordinator.recover()
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .idle)
  let source = try OpenedTextFile(url: sourceURL)
  let owner = UUID()
  let otherOwner = UUID()
  let configuration = ConversionConfiguration.Preset.taiwan.configuration
  do { try coordinator.offer(source, configuration: configuration, owner: owner); preconditionFailure("Pro is required") }
  catch MobileLargeFileCoordinator.StartError.requiresPro {}
  qualified = true
  try coordinator.offer(source, configuration: configuration, owner: owner)
  let duplicate = try OpenedTextFile(url: sourceURL)
  do { try coordinator.offer(duplicate, configuration: configuration, owner: otherOwner); preconditionFailure("One reservation across windows") }
  catch MobileLargeFileCoordinator.StartError.busy {}
  try duplicate.close()
  qualified = false
  do { try coordinator.start(); preconditionFailure("Recheck Pro at start") }
  catch MobileLargeFileCoordinator.StartError.requiresPro {}
  precondition(began == 0)
  qualified = true
  try coordinator.start()
  try coordinator.start()
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .ready && began == 1 && ended == 1)
  precondition(coordinator.ready?.optionsRawValue == configuration.options.rawValue)
  precondition(!coordinator.claimPresentation(otherOwner))
  coordinator.ownerDidClose(owner)
  precondition(coordinator.claimPresentation(otherOwner))
  let ready = coordinator.ready!
  // Closing the owner during asynchronous export preparation must not later
  // publish a picker URL into the replacement window.
  coordinator.prepareExport()
  let abandonedPreparation = coordinator.exportAttemptID!
  coordinator.ownerDidClose(otherOwner)
  precondition(coordinator.claimPresentation(owner))
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .ready && coordinator.exportURL == nil)
  precondition(coordinator.exportAttemptID == nil && coordinator.ready?.id == ready.id)
  coordinator.exportFinished(id: ready.id, attemptID: abandonedPreparation, succeeded: true)
  precondition(fm.fileExists(atPath: ready.url.path))

  // Closing an already-presented picker also leaves a retryable result. Its
  // late success must not delete the file used by a new window's attempt.
  coordinator.prepareExport()
  await coordinator.waitUntilSettled()
  let abandonedPicker = coordinator.exportAttemptID!
  coordinator.ownerDidClose(owner)
  precondition(coordinator.phase == .ready && coordinator.exportURL == nil)
  precondition(coordinator.claimPresentation(otherOwner))
  coordinator.prepareExport()
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .exporting && coordinator.exportURL == ready.url)
  coordinator.exportFinished(id: ready.id, attemptID: abandonedPicker, succeeded: true)
  precondition(coordinator.phase == .exporting && fm.fileExists(atPath: ready.url.path))
  let firstAttempt = coordinator.exportAttemptID!
  coordinator.exportFinished(id: UUID(), attemptID: firstAttempt, succeeded: true)
  precondition(coordinator.ready?.id == ready.id)
  coordinator.exportFinished(id: ready.id, attemptID: firstAttempt, succeeded: false)
  precondition(coordinator.phase == .ready && fm.fileExists(atPath: ready.url.path))
  coordinator.prepareExport()
  await coordinator.waitUntilSettled()
  let secondAttempt = coordinator.exportAttemptID!
  coordinator.exportFinished(id: ready.id, attemptID: firstAttempt, succeeded: true)
  precondition(coordinator.phase == .exporting, "A previous attempt must not finish this one")
  coordinator.exportPresentationDismissed(attemptID: secondAttempt)
  precondition(coordinator.phase == .ready && coordinator.ready != nil)
  coordinator.exportFinished(id: ready.id, attemptID: secondAttempt, succeeded: true)
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .completed && coordinator.ready == nil)
  precondition(!fm.fileExists(atPath: ready.url.path))

  // The confirmation describes this opened identity, not an arbitrarily newer
  // file found at the URL when the user eventually presses Convert.
  let changing = try OpenedTextFile(url: sourceURL)
  try coordinator.offer(changing, configuration: configuration, owner: owner)
  try Data("changed".utf8).write(to: sourceURL)
  try coordinator.start()
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .failed && began == 2 && ended == 2)
  guard coordinator.failure as? TextFileService.FileError == .sourceChanged else {
    preconditionFailure("The confirmed source change must be reported")
  }
  try await checkMobileCapacityConfirmation()
  print("PASS: mobile coordinator Pro recheck, single reservation, frozen configuration, resource pairing, owner transfer, stale export callbacks, save cancellation/retry and source identity")
}

@MainActor
private func checkMobileCapacityConfirmation() async throws {
  let fm = FileManager.default
  let root = fm.temporaryDirectory.appendingPathComponent("mobile-capacity-confirmation-\(UUID())")
  try fm.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? fm.removeItem(at: root) }
  let input = root.appendingPathComponent("large.txt")
  fm.createFile(atPath: input.path, contents: nil)
  let handle = try FileHandle(forWritingTo: input)
  defer { try? handle.close() }
  try handle.truncate(atOffset: FileConversionPolicy.mobileMaximumBytes + 1)
  let jobs = root.appendingPathComponent("jobs")
  let service = MobileLargeFileService(root: jobs, protection: .init(available: true))
  var enabled = false
  var qualified = true
  var began = 0
  var ended = 0
  let coordinator = MobileLargeFileCoordinator(factory: { service }, isQualified: { qualified },
    allowsExperimentalCapacity: { enabled }, beginWork: { began += 1 }, endWork: { ended += 1 })
  coordinator.recover()
  await coordinator.waitUntilSettled()
  let owner = UUID()
  let source = try OpenedTextFile(url: input)
  do { try coordinator.offer(source, configuration: ConversionConfiguration.Preset.traditional.configuration, owner: owner); preconditionFailure("Experimental gate defaults closed") }
  catch MobileLargeFileCoordinator.StartError.exceedsCapacity {}
  enabled = true
  try coordinator.offer(source, configuration: ConversionConfiguration.Preset.traditional.configuration, owner: owner)
  let cancelledID = coordinator.session!.id
  try coordinator.start()
  precondition(coordinator.phase == .capacityConfirmation && coordinator.isAwaitingConfirmation)
  precondition(began == 0)
  try requireMobileCapacity(fm.contentsOfDirectory(atPath: jobs.path).isEmpty)
  try coordinator.start()
  try coordinator.confirmCapacityAttempt(sessionID: UUID())
  precondition(began == 0, "Repeated start and stale confirmation cannot bypass the warning")
  coordinator.cancel()
  await coordinator.waitUntilSettled()
  precondition(coordinator.session == nil && coordinator.presentationOwner == nil)
  do { _ = try source.beginReading(); preconditionFailure("Cancelling confirmation releases the opened input") }
  catch TextFileService.FileError.sourceUnavailable {}
  try requireMobileCapacity(fm.contentsOfDirectory(atPath: jobs.path).isEmpty)

  let next = try OpenedTextFile(url: input)
  try coordinator.offer(next, configuration: ConversionConfiguration.Preset.traditional.configuration, owner: owner)
  try coordinator.start()
  try coordinator.confirmCapacityAttempt(sessionID: cancelledID)
  precondition(coordinator.phase == .capacityConfirmation && began == 0)
  qualified = false
  do { try coordinator.confirmCapacityAttempt(sessionID: coordinator.session!.id); preconditionFailure("Pro is rechecked after warning") }
  catch MobileLargeFileCoordinator.StartError.requiresPro {}
  precondition(coordinator.phase == .confirmation && began == 0)
  qualified = true
  try coordinator.start()
  enabled = false
  do { try coordinator.confirmCapacityAttempt(sessionID: coordinator.session!.id); preconditionFailure("Gate is rechecked") }
  catch MobileLargeFileCoordinator.StartError.exceedsCapacity {}
  enabled = true
  try coordinator.start()
  coordinator.ownerDidClose(owner)
  await coordinator.waitUntilSettled()
  precondition(coordinator.session == nil && began == 0, "Closing the warning's scene releases its source without a job")

  // Confirmed metadata is still checked by the worker; growing a file cannot
  // turn consent for this identity into permission for a newer source.
  let changing = try OpenedTextFile(url: input)
  try coordinator.offer(changing, configuration: ConversionConfiguration.Preset.traditional.configuration, owner: owner)
  try coordinator.start()
  let confirmedID = coordinator.session!.id
  try handle.truncate(atOffset: FileConversionPolicy.mobileMaximumBytes + 2)
  try coordinator.confirmCapacityAttempt(sessionID: confirmedID)
  try coordinator.confirmCapacityAttempt(sessionID: confirmedID)
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .failed && began == 1 && ended == 1)
  precondition(coordinator.failure as? TextFileService.FileError == .sourceChanged)
  try requireMobileCapacity(fm.contentsOfDirectory(atPath: jobs.path).isEmpty)
  try coordinator.validateSize(FileConversionPolicy.mobileExperimentalMaximumBytes)
  do { try coordinator.validateSize(FileConversionPolicy.mobileExperimentalMaximumBytes + 1); preconditionFailure("1 GiB + 1 is rejected") }
  catch MobileLargeFileCoordinator.StartError.exceedsExperimentalCapacity {}
  print("PASS: per-session experimental confirmation, closed gate, no job before consent, cancel/scene release, stale response, Pro/gate recheck and source growth")
}

private func requireMobileCapacity(_ value: Bool) { precondition(value) }

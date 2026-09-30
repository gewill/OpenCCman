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
  coordinator.prepareExport()
  await coordinator.waitUntilSettled()
  precondition(coordinator.phase == .exporting && coordinator.exportURL == ready.url)
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
  print("PASS: mobile coordinator Pro recheck, single reservation, frozen configuration, resource pairing, owner transfer, stale export callbacks, save cancellation/retry and source identity")
}

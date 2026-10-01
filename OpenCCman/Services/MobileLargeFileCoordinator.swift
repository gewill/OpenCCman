import Combine
import Foundation
import OpenCC

/// App-wide presentation state. The editor owns none of this task's text or
/// resources. UIKit supplies finite-background/idle-timer handling separately.
@MainActor
final class MobileLargeFileCoordinator: ObservableObject {
  enum Phase: Equatable {
    case recovering, idle, confirmation, capacityConfirmation, preparing, converting, cancelling
    case interrupted, ready, exporting, completed, failed, waitingForUnlock
  }
  struct Session: Identifiable {
    let id: UUID
    let filename: String
    let inputBytes: UInt64
    let optionsRawValue: Int
  }
  enum StartError: Error { case busy, requiresPro, exceedsCapacity, exceedsExperimentalCapacity, notLargeFile }
  typealias Factory = @Sendable () async throws -> MobileLargeFileService

  @Published private(set) var phase: Phase = .recovering
  @Published private(set) var session: Session?
  @Published private(set) var presentationOwner: UUID?
  @Published private(set) var ready: MobileLargeFileService.Ready?
  @Published private(set) var processedBytes: UInt64 = 0
  @Published private(set) var failure: Error?
  @Published private(set) var exportURL: URL?
  private(set) var exportAttemptID: UUID?

  private let factory: Factory
  private let isQualified: @MainActor () -> Bool
  private let allowsExperimentalCapacity: @MainActor () -> Bool
  private let beginWork: @MainActor () -> Void
  private let endWork: @MainActor () -> Void
  private var service: MobileLargeFileService?
  private var source: OpenedTextFile?
  private var task: Task<Void, Never>?
  private var operationID: UUID?
  private var ownsWorkResources = false

  init(factory: @escaping Factory,
       isQualified: @escaping @MainActor () -> Bool,
       allowsExperimentalCapacity: @escaping @MainActor () -> Bool = { false },
       beginWork: @escaping @MainActor () -> Void = {},
       endWork: @escaping @MainActor () -> Void = {}) {
    self.factory = factory
    self.isQualified = isQualified
    self.allowsExperimentalCapacity = allowsExperimentalCapacity
    self.beginWork = beginWork
    self.endWork = endWork
  }

  var isWorking: Bool { phase == .preparing || phase == .converting || phase == .cancelling }
  var isAwaitingConfirmation: Bool { phase == .confirmation || phase == .capacityConfirmation }
  var requiresCapacityConfirmation: Bool {
    (session?.inputBytes ?? 0) > FileConversionPolicy.mobileMaximumBytes
  }

  func validateSize(_ bytes: UInt64) throws {
    if allowsExperimentalCapacity() {
      guard bytes <= FileConversionPolicy.mobileExperimentalMaximumBytes else { throw StartError.exceedsExperimentalCapacity }
    } else {
      guard bytes <= FileConversionPolicy.mobileMaximumBytes else { throw StartError.exceedsCapacity }
    }
  }
  var progress: Double {
    guard let total = session?.inputBytes, total > 0 else { return 0 }
    return ready == nil ? min(0.99, Double(processedBytes) / Double(total)) : 1
  }

  /// Startup and protected-data-available notifications may both arrive; only
  /// one recovery runs and no recovery may remove a live worker's files.
  func recover() {
    guard task == nil, source == nil, ready == nil,
          phase == .recovering || phase == .waitingForUnlock || phase == .failed else { return }
    phase = .recovering
    failure = nil
    let id = UUID()
    operationID = id
    task = Task {
      do {
        let store: MobileLargeFileService
        if let service { store = service } else { store = try await factory() }
        service = store
        let result = try await store.recover()
        guard operationID == id else { return }
        switch result {
        case .empty: session = nil; phase = .idle
        case .protectedDataUnavailable: phase = .waitingForUnlock
        case .ready(let recovered): accept(recovered, owner: nil)
        }
      } catch { failure = error; phase = .failed }
      task = nil
      operationID = nil
    }
  }

  /// Ownership transfers only on success; the caller closes a rejected source.
  func offer(_ source: OpenedTextFile, configuration: ConversionConfiguration, owner: UUID) throws {
    guard task == nil, ready == nil, self.source == nil, service != nil,
          phase == .idle || phase == .completed || phase == .interrupted || phase == .failed else { throw StartError.busy }
    guard source.byteCount > UInt64(FileConversionPolicy.editorMaximumBytes) else { throw StartError.notLargeFile }
    try validateSize(source.byteCount)
    guard isQualified() else { throw StartError.requiresPro }
    self.source = source
    presentationOwner = owner
    session = Session(id: UUID(), filename: source.sourceFilename,
                      inputBytes: source.byteCount, optionsRawValue: configuration.options.rawValue)
    processedBytes = 0
    failure = nil
    phase = .confirmation
  }

  func start() throws {
    guard phase == .confirmation, let session, task == nil else { return }
    try validateSize(session.inputBytes)
    guard isQualified() else { throw StartError.requiresPro }
    if requiresCapacityConfirmation {
      phase = .capacityConfirmation
      return
    }
    try beginConversion(capacity: .standard)
  }

  /// The alert captures this session ID. A delayed response cannot authorize a
  /// newer file; every new offer must go through both steps again.
  func confirmCapacityAttempt(sessionID: UUID) throws {
    guard phase == .capacityConfirmation, session?.id == sessionID, task == nil else { return }
    phase = .confirmation
    guard allowsExperimentalCapacity() else { throw StartError.exceedsCapacity }
    try beginConversion(capacity: .experimental)
  }

  private func beginConversion(capacity: MobileFileCapacity) throws {
    guard phase == .confirmation, let source, let session, let service, task == nil else { return }
    // Qualification is frozen only when actual work starts, not when offered.
    guard isQualified() else { throw StartError.requiresPro }
    try validateSize(session.inputBytes)
    let id = UUID()
    operationID = id
    phase = .preparing
    ownsWorkResources = true
    let throttle = MobileFileProgressThrottle()
    task = Task {
      do {
        let result = try await service.convert(
          source: source.sourceURL, options: .init(rawValue: session.optionsRawValue),
          capacity: capacity,
          expectedSource: source.fingerprint,
          snapshotReady: { try source.close() },
          progress: { [weak self] processed, _ in
            guard throttle.shouldDeliver() else { return }
            Task { @MainActor in
              guard let self, self.operationID == id,
                    self.phase == .preparing || self.phase == .converting else { return }
              self.phase = .converting
              self.processedBytes = processed
            }
          })
        // The service decides commit versus cancellation. Do not discard a
        // published result merely because Task.isCancelled became true later.
        if operationID == id { accept(result, owner: presentationOwner) }
      } catch {
        if operationID == id {
          failure = error is CancellationError ? nil : error
          phase = error is CancellationError ? .interrupted : .failed
        }
      }
      await Self.close(source)
      self.source = nil
      finishWork()
      task = nil
      operationID = nil
    }
    // Install the task before beginWork: an immediately expired background
    // lease must be able to cancel it rather than only changing the phase.
    beginWork()
  }

  func cancel() {
    if isWorking {
      phase = .cancelling
      // Task.cancel may acquire the service commit lock. Dispatch it off the
      // main thread, including background-expiration callbacks.
      if let task { DispatchQueue.global(qos: .userInitiated).async { task.cancel() } }
    } else if isAwaitingConfirmation, let source {
      phase = .cancelling
      task = Task {
        await Self.close(source)
        self.source = nil
        self.session = nil
        self.presentationOwner = nil
        self.phase = .interrupted
        self.task = nil
      }
    }
  }

  func ownerDidClose(_ owner: UUID) {
    guard presentationOwner == owner else { return }
    presentationOwner = nil
    if isWorking || isAwaitingConfirmation { cancel() }
    if phase == .exporting {
      // The window owns the system picker, not the completed file. Invalidate
      // its attempt before another window takes over, including preparation
      // that is still awaiting the file worker.
      exportAttemptID = nil
      exportURL = nil
      phase = .ready
    }
    // Completed output remains recoverable by another window.
  }

  func claimPresentation(_ owner: UUID) -> Bool {
    guard session != nil || phase == .failed || phase == .waitingForUnlock,
          presentationOwner == nil || presentationOwner == owner else { return false }
    presentationOwner = owner
    return true
  }

  func prepareExport() {
    guard let ready, let service, task == nil, phase == .ready || phase == .failed else { return }
    failure = nil
    phase = .exporting
    let attempt = UUID()
    exportAttemptID = attempt
    task = Task {
      do {
        let url = try await service.exportURL(for: ready.id)
        if exportAttemptID == attempt { exportURL = url }
      } catch {
        if exportAttemptID == attempt {
          failure = error; phase = .ready; exportAttemptID = nil
        }
      }
      task = nil
    }
  }

  /// Cancellation keeps the complete result; only confirmed system success
  /// removes it. The caller must pass the ID captured when presenting.
  func exportFinished(id: UUID, attemptID: UUID, succeeded: Bool) {
    guard ready?.id == id, exportAttemptID == attemptID, task == nil else { return }
    exportAttemptID = nil
    exportURL = nil
    if succeeded { discardResult() } else { phase = .ready }
  }

  /// SwiftUI dismissal can arrive before the document picker's success delegate.
  /// Retain the attempt identity so its later authoritative result can win.
  /// A newer attempt or explicit deletion invalidates this identity.
  func exportPresentationDismissed(attemptID: UUID) {
    guard exportAttemptID == attemptID, ready != nil, task == nil else { return }
    exportURL = nil
    phase = .ready
  }

  func discardResult() {
    guard let ready, let service, task == nil else { return }
    exportURL = nil
    exportAttemptID = nil
    task = Task {
      do {
        try await service.discard(ready.id)
        self.ready = nil
        session = nil
        presentationOwner = nil
        failure = nil
        phase = .completed
      } catch { failure = error; phase = .ready }
      task = nil
    }
  }

  func dismissPresentation() {
    guard task == nil, !isWorking, !isAwaitingConfirmation, phase != .exporting else { return }
    presentationOwner = nil
  }

  /// Only after the UI confirms deleting private jobs; editor files are outside
  /// this store. Failed deletion remains an error and can be retried.
  func resetStoredJobs() {
    guard task == nil, source == nil, ready == nil, let service else { return }
    task = Task {
      do {
        try await service.discardStoredJobs()
        session = nil
        presentationOwner = nil
        failure = nil
        phase = .idle
      } catch { failure = error; phase = .failed }
      task = nil
    }
  }

  func waitUntilSettled() async { await task?.value }

  private func accept(_ result: MobileLargeFileService.Ready, owner: UUID?) {
    ready = result
    presentationOwner = owner
    session = Session(id: result.id, filename: result.exportFilename,
                      inputBytes: result.inputBytes, optionsRawValue: result.optionsRawValue)
    processedBytes = result.inputBytes
    phase = .ready
  }
  private func finishWork() {
    if ownsWorkResources { ownsWorkResources = false; endWork() }
  }
  private nonisolated static func close(_ source: OpenedTextFile) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .utility).async {
        try? source.close()
        continuation.resume()
      }
    }
  }
}

private final class MobileFileProgressThrottle: @unchecked Sendable {
  private let lock = NSLock()
  private var lastTime: TimeInterval?
  func shouldDeliver() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let now = ProcessInfo.processInfo.systemUptime
    if let lastTime, now - lastTime < 0.1 { return false }
    lastTime = now
    return true
  }
}

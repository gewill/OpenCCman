import Combine
import Foundation
import OpenCC

/// App-wide presentation state. The editor owns none of this task's text or
/// resources. UIKit supplies finite-background/idle-timer handling separately.
@MainActor
final class MobileLargeFileCoordinator: ObservableObject {
  enum Phase: Equatable {
    case recovering, idle, confirmation, preparing, converting, cancelling
    case interrupted, ready, exporting, completed, failed, waitingForUnlock
  }
  struct Session: Identifiable {
    let id: UUID
    var owner: UUID?
    let filename: String
    let inputBytes: UInt64
    let optionsRawValue: Int
  }
  enum StartError: Error { case busy, requiresPro, exceedsCapacity, notLargeFile }
  typealias Factory = @Sendable () async throws -> MobileLargeFileService

  @Published private(set) var phase: Phase = .recovering
  @Published private(set) var session: Session?
  @Published private(set) var ready: MobileLargeFileService.Ready?
  @Published private(set) var processedBytes: UInt64 = 0
  @Published private(set) var failure: Error?
  @Published private(set) var exportURL: URL?

  private let factory: Factory
  private let isQualified: @MainActor () -> Bool
  private let beginWork: @MainActor () -> Void
  private let endWork: @MainActor () -> Void
  private var service: MobileLargeFileService?
  private var source: OpenedTextFile?
  private var task: Task<Void, Never>?
  private var operationID: UUID?
  private var ownsWorkResources = false

  init(factory: @escaping Factory,
       isQualified: @escaping @MainActor () -> Bool,
       beginWork: @escaping @MainActor () -> Void = {},
       endWork: @escaping @MainActor () -> Void = {}) {
    self.factory = factory
    self.isQualified = isQualified
    self.beginWork = beginWork
    self.endWork = endWork
  }

  var isWorking: Bool { phase == .preparing || phase == .converting || phase == .cancelling }
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
    guard source.byteCount <= FileConversionPolicy.mobileMaximumBytes else { throw StartError.exceedsCapacity }
    guard isQualified() else { throw StartError.requiresPro }
    self.source = source
    session = Session(id: UUID(), owner: owner, filename: source.sourceFilename,
                      inputBytes: source.byteCount, optionsRawValue: configuration.options.rawValue)
    processedBytes = 0
    failure = nil
    phase = .confirmation
  }

  func start() throws {
    guard phase == .confirmation, let source, let session, let service, task == nil else { return }
    // Qualification is frozen only when actual work starts, not when offered.
    guard isQualified() else { throw StartError.requiresPro }
    let id = UUID()
    operationID = id
    phase = .preparing
    ownsWorkResources = true
    let throttle = MobileFileProgressThrottle()
    task = Task {
      do {
        let result = try await service.convert(
          source: source.sourceURL, options: .init(rawValue: session.optionsRawValue),
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
        if operationID == id { accept(result, owner: self.session?.owner) }
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
    } else if phase == .confirmation, let source {
      phase = .cancelling
      task = Task {
        await Self.close(source)
        self.source = nil
        self.session = nil
        self.phase = .interrupted
        self.task = nil
      }
    }
  }

  func ownerDidClose(_ owner: UUID) {
    guard session?.owner == owner else { return }
    session?.owner = nil
    if isWorking || phase == .confirmation { cancel() }
    // Completed output remains recoverable by another window.
  }

  func claimPresentation(_ owner: UUID) -> Bool {
    guard session != nil, session?.owner == nil || session?.owner == owner else { return false }
    session?.owner = owner
    return true
  }

  func prepareExport() {
    guard let ready, let service, task == nil, phase == .ready || phase == .failed else { return }
    failure = nil
    phase = .exporting
    task = Task {
      do { exportURL = try await service.exportURL(for: ready.id) }
      catch { failure = error; phase = .ready }
      task = nil
    }
  }

  /// Cancellation keeps the complete result; only confirmed system success
  /// removes it. The caller must pass the ID captured when presenting.
  func exportFinished(id: UUID, succeeded: Bool) {
    guard ready?.id == id, phase == .exporting, task == nil else { return }
    exportURL = nil
    if succeeded { discardResult() } else { phase = .ready }
  }

  func discardResult() {
    guard let ready, let service, task == nil else { return }
    exportURL = nil
    task = Task {
      do {
        try await service.discard(ready.id)
        self.ready = nil
        session = nil
        failure = nil
        phase = .completed
      } catch { failure = error; phase = .ready }
      task = nil
    }
  }

  func waitUntilSettled() async { await task?.value }

  private func accept(_ result: MobileLargeFileService.Ready, owner: UUID?) {
    ready = result
    session = Session(id: result.id, owner: owner, filename: result.exportFilename,
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

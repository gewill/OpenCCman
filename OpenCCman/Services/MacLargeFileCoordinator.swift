#if os(macOS)
import AppKit
import Combine
import Foundation
import OpenCC
import UniformTypeIdentifiers

/// Limits main-actor work before enqueueing it, rather than dropping updates
/// after an unbounded backlog of UI tasks has already accumulated.
private final class FileProgressThrottle: @unchecked Sendable {
  private let lock = NSLock()
  private var lastTime: TimeInterval = 0
  private var lastFraction = -1.0

  func shouldDeliver(processed: UInt64, total: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let now = ProcessInfo.processInfo.systemUptime
    let fraction = total == 0 ? 0 : Double(processed) / Double(total)
    guard lastFraction < 0 || now - lastTime >= 0.1 || fraction - lastFraction >= 0.01 else { return false }
    lastTime = now
    lastFraction = fraction
    return true
  }
}

/// One file job across every window. Editors never own the source or output text.
@MainActor
final class MacLargeFileCoordinator: ObservableObject {
  static let shared = MacLargeFileCoordinator()
  static let maximumBytes: UInt64 = 1024 * 1024 * 1024
  // Enable only after the capacity and minimum-system acceptance in #52/#16.
  nonisolated static let productionEnabled = false
  nonisolated static var isEnabled: Bool {
    #if DEBUG
      if isQABundle, ProcessInfo.processInfo.arguments.contains("-qa-enable-large-file-conversion") { return true }
    #endif
    return productionEnabled
  }

  struct Session: Identifiable {
    let id: UUID
    let owner: UUID
    let sourceFilename: String
    let byteCount: UInt64
    let exportFilename: String
    let configuration: ConversionConfiguration
    let qualifiedAtStart: Bool
  }

  enum Phase: Equatable {
    case confirmation, choosingDestination, converting, cancelling, completed, failed
  }

  enum StartError: LocalizedError, Equatable {
    case busy, requiresPro, exceedsCapacity
    var errorDescription: String? {
      let key: String
      switch self {
      case .busy: key = "large_file_busy"
      case .requiresPro: key = "pro_large_file_conversion"
      case .exceedsCapacity: key = "large_file_capacity"
      }
      return NSLocalizedString(key, comment: "")
    }
  }

  typealias Operation = @Sendable (
    OpenedTextFile, URL, ChineseConverter.Options,
    @escaping @Sendable (UInt64, UInt64) -> Void
  ) async throws -> StreamingTextFileService.Result

  @Published private(set) var session: Session?
  @Published private(set) var phase: Phase = .confirmation
  @Published private(set) var processedBytes: UInt64 = 0
  @Published private(set) var outputBytes: UInt64 = 0
  @Published private(set) var destination: URL?
  @Published private(set) var failureDescription: String?

  private let operation: Operation
  private let reportError: (Error) -> Void
  private let enabled: Bool
  private var source: OpenedTextFile?
  private var conversionTask: Task<Void, Never>?
  private var savePanel: NSSavePanel?
  private weak var ownerWindow: NSWindow?
  private var ownerClosed = false

  init(enabled: Bool = MacLargeFileCoordinator.isEnabled,
       reportError: @escaping (Error) -> Void = { NSApp.presentError($0) },
       operation: @escaping Operation = { source, destination, options, progress in
    try await StreamingTextFileService.convert(
      source: source, destination: destination, options: options, progress: progress)
  }) {
    self.operation = operation
    self.reportError = reportError
    self.enabled = enabled
  }

  var isBusy: Bool { session != nil }
  var isWorking: Bool {
    session != nil && (phase == .converting || phase == .cancelling || phase == .choosingDestination)
  }
  var progress: Double {
    guard let total = session?.byteCount, total > 0 else { return 0 }
    if phase == .completed { return 1 }
    return min(0.99, Double(processedBytes) / Double(total))
  }

  func offer(_ source: OpenedTextFile, configuration: ConversionConfiguration,
             qualified: Bool, owner: UUID, window: NSWindow?) throws {
    guard enabled else {
      try? source.close()
      throw TextFileService.FileError.tooLarge
    }
    try Self.validateSize(source.byteCount)
    guard session == nil else { throw StartError.busy }
    guard qualified else { throw StartError.requiresPro }
    self.source = source
    ownerWindow = window
    ownerClosed = false
    processedBytes = 0
    outputBytes = 0
    destination = nil
    failureDescription = nil
    phase = .confirmation
    session = Session(id: UUID(), owner: owner, sourceFilename: source.sourceFilename,
                      byteCount: source.byteCount, exportFilename: source.exportFilename,
                      configuration: configuration, qualifiedAtStart: qualified)
  }

  static func validateSize(_ byteCount: UInt64) throws {
    guard byteCount <= maximumBytes else { throw StartError.exceedsCapacity }
  }

  func chooseDestination() {
    guard let session, phase == .confirmation, let window = ownerWindow else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = session.exportFilename
    panel.title = NSLocalizedString("large_file_choose_destination", comment: "")
    panel.prompt = NSLocalizedString("large_file_convert_and_save", comment: "")
    savePanel = panel
    phase = .choosingDestination
    panel.beginSheetModal(for: window.attachedSheet ?? window) { [weak self] response in
      Task { @MainActor in
        guard let self, self.session?.id == session.id else { return }
        self.savePanel = nil
        if self.ownerClosed {
          self.clear()
        } else if response == .OK, let destination = panel.url {
          self.start(destination: destination)
        } else {
          self.phase = .confirmation
        }
      }
    }
  }

  /// Called only after the save panel has confirmed the output URL.
  func start(destination: URL) {
    guard let session, let source,
          phase == .confirmation || phase == .choosingDestination else { return }
    self.destination = destination
    phase = .converting
    let operation = self.operation
    let throttle = FileProgressThrottle()
    conversionTask = Task { [weak self] in
      do {
        #if DEBUG
          if Self.isQABundle,
             ProcessInfo.processInfo.arguments.contains("-qa-delay-large-file-conversion") {
            try await Task.sleep(nanoseconds: 3_000_000_000)
          }
        #endif
        let result = try await operation(source, destination, session.configuration.options) { [weak self] input, total in
          guard throttle.shouldDeliver(processed: input, total: total) else { return }
          Task { @MainActor in
            guard let self, self.session?.id == session.id, self.phase == .converting else { return }
            self.processedBytes = input
          }
        }
        guard let self, self.session?.id == session.id else { return }
        // The file service decides the atomic commit/cancel race. A committed
        // output remains success even if cancellation arrived during commit.
        self.processedBytes = result.inputBytes
        self.outputBytes = result.outputBytes
        self.destination = result.destination
        try? source.close()
        self.source = nil
        self.conversionTask = nil
        if self.ownerClosed { self.clear() } else { self.phase = .completed }
      } catch {
        guard let self, self.session?.id == session.id else { return }
        try? source.close()
        self.source = nil
        self.conversionTask = nil
        let displayError = Self.presentationError(error)
        if error is CancellationError {
          self.clear()
        } else if self.ownerClosed {
          self.clear()
          // A removed owner cannot show its task sheet. Cleanup failure still
          // needs an application-level report so private temporary data is not
          // silently left behind after closing the window or quitting.
          if error is StreamingTextFileService.CleanupError { self.reportError(displayError) }
        } else {
          let recovery = (displayError as NSError).localizedRecoverySuggestion
          self.failureDescription = [displayError.localizedDescription, recovery].compactMap { $0 }.joined(separator: "\n\n")
          self.phase = .failed
        }
      }
    }
  }

  func cancel() {
    switch phase {
    case .converting:
      phase = .cancelling
      conversionTask?.cancel()
    case .cancelling:
      break // Keep the global reservation until the file worker has cleaned up.
    case .choosingDestination:
      savePanel?.cancel(nil)
    case .confirmation, .completed, .failed:
      clear()
    }
  }

  func ownerDidClose(_ owner: UUID) {
    guard session?.owner == owner else { return }
    ownerClosed = true
    cancel()
  }

  /// The app delegate defers termination until the actual worker has returned.
  /// This also covers language restart, which calls NSApp.terminate normally.
  func prepareForTermination() async {
    ownerClosed = true
    let task = conversionTask
    cancel()
    await task?.value
    clear()
  }

  private static func presentationError(_ error: Error) -> Error {
    guard let cleanup = error as? StreamingTextFileService.CleanupError else { return error }
    let recovery = NSLocalizedString("large_file_cleanup_recovery", comment: "Private temporary file recovery")
      + "\n" + cleanup.temporaryDirectory.path
    return NSError(domain: "OpenCCman.LargeFileConversion", code: 1, userInfo: [
      NSLocalizedDescriptionKey: cleanup.localizedDescription,
      NSLocalizedFailureReasonErrorKey: cleanup.cleanupError.localizedDescription,
      NSLocalizedRecoverySuggestionErrorKey: recovery,
      NSUnderlyingErrorKey: cleanup,
    ])
  }

  func revealOutput() {
    guard phase == .completed, let destination else { return }
    NSWorkspace.shared.activateFileViewerSelecting([destination])
  }

  private func clear() {
    try? source?.close()
    source = nil
    conversionTask = nil
    savePanel = nil
    ownerWindow = nil
    session = nil
  }

  #if DEBUG
    nonisolated static var isQABundle: Bool {
      Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests"
    }
  #endif
}
#endif

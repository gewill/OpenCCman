#if os(macOS)
import AppKit
import Combine
import Darwin
import Foundation
import OpenCC
import UniformTypeIdentifiers

/// One sequential batch across every window, exclusive with the single large
/// file task. Each file goes through the same streaming service as single-file
/// conversion; the queue only stores URLs, never file contents.
@MainActor
final class MacBatchConversionCoordinator: ObservableObject {
  static let shared = MacBatchConversionCoordinator()
  /// Pro only; batch conversion never reserves the daily free quota.
  static var isQualified: Bool { MacLargeFileCoordinator.isQualified }
  static let maximumNameAttempts = 3

  struct Session: Identifiable {
    let id: UUID
    let owner: UUID
    let configuration: ConversionConfiguration
  }

  enum Phase: Equatable {
    case reviewing, choosingFolder, converting, cancelling, finished
  }

  enum StartError: LocalizedError, Equatable {
    case busy, requiresPro, empty, tooManyFiles(Int), folderUnavailable, dropUnavailable
    var errorDescription: String? {
      switch self {
      case .busy: return NSLocalizedString("large_file_busy", comment: "")
      case .requiresPro: return NSLocalizedString("pro_batch_conversion", comment: "")
      case .empty: return NSLocalizedString("batch_error_empty", comment: "")
      case let .tooManyFiles(count):
        return String(format: NSLocalizedString("batch_error_too_many", comment: ""),
                      count, BatchConversionPolicy.maximumFiles)
      case .folderUnavailable: return NSLocalizedString("batch_error_folder", comment: "")
      case .dropUnavailable: return NSLocalizedString("batch_error_drop", comment: "")
      }
    }
  }

  typealias Operation = @Sendable (
    OpenedTextFile, URL, ChineseConverter.Options, @escaping @Sendable (UInt64, UInt64) -> Void
  ) async throws -> StreamingTextFileService.Result

  @Published private(set) var session: Session?
  @Published private(set) var phase: Phase = .reviewing
  @Published private(set) var queue: BatchConversionQueue?
  @Published private(set) var currentProcessedBytes: UInt64 = 0
  @Published private(set) var outputDirectory: URL?
  /// Shown in the review sheet when the chosen folder or authorization fails.
  @Published private(set) var startFailure: String?

  private let operation: Operation
  private let qualified: @MainActor () -> Bool
  private let otherTaskBusy: @MainActor () -> Bool
  private let reportError: @MainActor (Error) -> Void
  private var conversionTask: Task<Void, Never>?
  private var folderPanel: NSOpenPanel?
  private weak var ownerWindow: NSWindow?
  private var ownerClosed = false

  init(qualified: @escaping @MainActor () -> Bool = { MacBatchConversionCoordinator.isQualified },
       otherTaskBusy: @escaping @MainActor () -> Bool = { MacLargeFileCoordinator.shared.isBusy },
       reportError: @escaping @MainActor (Error) -> Void = { NSApp.presentError($0) },
       operation: @escaping Operation = { source, destination, options, progress in
    try await StreamingTextFileService.convert(
      source: source, destination: destination, options: options, capacity: .standard,
      replacingExisting: false, progress: progress)
  }) {
    self.operation = operation
    self.qualified = qualified
    self.otherTaskBusy = otherTaskBusy
    self.reportError = reportError
  }

  var isBusy: Bool { session != nil }
  var isWorking: Bool { session != nil && (phase == .choosingFolder || phase == .converting || phase == .cancelling) }

  /// Finished files plus the active file's byte fraction, over files that can run.
  var progress: Double {
    guard let queue else { return 0 }
    let runnable = queue.items.filter { if case .skipped = $0.state { return false } else { return true } }
    guard !runnable.isEmpty else { return 1 }
    let finished = runnable.filter { $0.state.isFinished }.count
    var fraction = Double(finished)
    if let active = runnable.first(where: { $0.state == .converting }), let total = active.byteCount, total > 0 {
      fraction += min(0.99, Double(currentProcessedBytes) / Double(total))
    }
    return min(1, fraction / Double(runnable.count))
  }

  /// Reads only metadata. Real access happens when each file starts.
  static func candidates(for urls: [URL]) -> [BatchConversionQueue.Candidate] {
    urls.map { url in
      let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
      return .init(url: url, byteCount: values?.fileSize.map { UInt64(max(0, $0)) },
                   isRegularFile: values?.isRegularFile ?? true)
    }
  }

  func offer(_ urls: [URL], configuration: ConversionConfiguration,
             qualified: Bool, owner: UUID, window: NSWindow?) throws {
    guard session == nil, !otherTaskBusy() else { throw StartError.busy }
    guard qualified else { throw StartError.requiresPro }
    let queue: BatchConversionQueue
    do { queue = try BatchConversionQueue(candidates: Self.candidates(for: urls)) }
    catch BatchConversionQueue.AdmissionError.tooManyFiles(let count) { throw StartError.tooManyFiles(count) }
    catch { throw StartError.empty }
    ownerWindow = window
    ownerClosed = false
    currentProcessedBytes = 0
    outputDirectory = nil
    startFailure = nil
    phase = .reviewing
    self.queue = queue
    session = Session(id: UUID(), owner: owner, configuration: configuration)
  }

  func chooseOutputFolder() {
    guard let session, phase == .reviewing, queue?.convertibleCount ?? 0 > 0 else { return }
    guard validateAuthorization() else { return }
    guard let window = ownerWindow else { return }
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.title = NSLocalizedString("batch_choose_folder", comment: "")
    panel.prompt = NSLocalizedString("batch_start", comment: "")
    folderPanel = panel
    phase = .choosingFolder
    panel.beginSheetModal(for: window.attachedSheet ?? window) { [weak self] response in
      Task { @MainActor in
        guard let self, self.session?.id == session.id else { return }
        self.folderPanel = nil
        if self.ownerClosed {
          self.clear()
        } else if response == .OK, let directory = panel.url {
          self.phase = .reviewing
          self.start(outputDirectory: directory)
        } else {
          self.phase = .reviewing
        }
      }
    }
  }

  /// Authorization is checked before the folder panel and again after it.
  private func validateAuthorization() -> Bool {
    guard qualified() else {
      startFailure = StartError.requiresPro.localizedDescription
      return false
    }
    return true
  }

  /// Called only after the folder panel has confirmed the output directory.
  func start(outputDirectory directory: URL) {
    guard let session, phase == .reviewing, queue?.nextWaitingIndex != nil else { return }
    guard validateAuthorization() else { return }
    let scoped = directory.startAccessingSecurityScopedResource()
    guard Self.isWritableDirectory(directory) else {
      if scoped { directory.stopAccessingSecurityScopedResource() }
      startFailure = StartError.folderUnavailable.localizedDescription
      return
    }
    startFailure = nil
    outputDirectory = directory
    phase = .converting
    conversionTask = Task { [weak self] in
      await self?.run(session, directory: directory)
      if scoped { directory.stopAccessingSecurityScopedResource() }
    }
  }

  private enum Outcome {
    case succeeded(String, UInt64), failed(String), cancelled, folderLost(String)
  }

  private func run(_ session: Session, directory: URL) async {
    var namer = BatchOutputNamer()
    let options = session.configuration.options
    while self.session?.id == session.id, !Task.isCancelled, let index = queue?.nextWaitingIndex {
      queue?.begin(index)
      currentProcessedBytes = 0
      guard let item = queue?.items[index] else { return }
      let outcome = await convert(item, into: directory, options: options, sessionID: session.id, namer: &namer)
      guard self.session?.id == session.id else { return }
      switch outcome {
      case let .succeeded(name, bytes):
        queue?.finish(index, as: .succeeded(outputFilename: name, outputBytes: bytes))
      case let .failed(reason):
        queue?.finish(index, as: .failed(reason))
      case .cancelled:
        queue?.finish(index, as: .cancelled)
      case let .folderLost(reason):
        queue?.finish(index, as: .failed(reason))
        queue?.failRemaining(reason)
      }
    }
    guard self.session?.id == session.id else { return }
    queue?.cancelRemaining()
    conversionTask = nil
    if ownerClosed { clear() } else { phase = .finished }
  }

  private func convert(_ item: BatchConversionQueue.Item, into directory: URL,
                       options: ChineseConverter.Options, sessionID: UUID,
                       namer: inout BatchOutputNamer) async -> Outcome {
    for attempt in 1...Self.maximumNameAttempts {
      let name: String
      do {
        name = try namer.reserve(for: item.sourceFilename) { try Self.itemExists(directory.appendingPathComponent($0)) }
      } catch {
        return Self.folderOutcome(directory) ?? .failed(Self.describe(error))
      }
      let destination = directory.appendingPathComponent(name, isDirectory: false)
      let source: OpenedTextFile
      do { source = try OpenedTextFile(url: item.sourceURL) }
      catch { return .failed(Self.describe(error)) }
      let throttle = FileProgressThrottle()
      do {
        let result = try await operation(source, destination, options) { [weak self] processed, total in
          guard throttle.shouldDeliver(processed: processed, total: total) else { return }
          Task { @MainActor in
            guard let self, self.session?.id == sessionID, self.phase == .converting else { return }
            self.currentProcessedBytes = processed
          }
        }
        try? source.close()
        // The file service decides the commit/cancel race: a committed file is a success.
        return .succeeded(result.destination.lastPathComponent, result.outputBytes)
      } catch {
        try? source.close()
        if error is CancellationError { return .cancelled }
        if Self.isNameRace(error), attempt < Self.maximumNameAttempts { continue }
        if let lost = Self.folderOutcome(directory) { return lost }
        if error is StreamingTextFileService.CleanupError { reportError(MacLargeFileCoordinator.presentationError(error)) }
        return .failed(Self.describe(error))
      }
    }
    return .failed(Self.describe(StreamingTextFileService.FileError.destinationChanged))
  }

  /// Another writer created the chosen name after it was reserved.
  static func isNameRace(_ error: Error) -> Bool {
    if case StreamingTextFileService.FileError.destinationChanged? = error as? StreamingTextFileService.FileError { return true }
    return (error as? POSIXError)?.code == .EEXIST
  }

  /// lstat semantics: a symlink or any other item at the name counts as taken.
  static func itemExists(_ url: URL) throws -> Bool {
    try TextFileFingerprint.read(url: url, followSymlink: false) != nil
  }

  static func isWritableDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
      && isDirectory.boolValue && FileManager.default.isWritableFile(atPath: url.path)
  }

  private static func folderOutcome(_ directory: URL) -> Outcome? {
    isWritableDirectory(directory) ? nil : .folderLost(StartError.folderUnavailable.localizedDescription)
  }

  private static func describe(_ error: Error) -> String {
    let presented = MacLargeFileCoordinator.presentationError(error) as NSError
    return [presented.localizedDescription, presented.localizedRecoverySuggestion].compactMap { $0 }.joined(separator: "\n")
  }

  func cancel() {
    switch phase {
    case .converting:
      phase = .cancelling
      conversionTask?.cancel()
    case .cancelling:
      break // Keep the global slot until the active file has cleaned up.
    case .choosingFolder:
      folderPanel?.cancel(nil)
    case .reviewing, .finished:
      clear()
    }
  }

  func ownerDidClose(_ owner: UUID) {
    guard session?.owner == owner else { return }
    ownerClosed = true
    cancel()
  }

  /// The app delegate defers termination until the active file has cleaned up.
  func prepareForTermination() async {
    ownerClosed = true
    let task = conversionTask
    cancel()
    await task?.value
    clear()
  }

  func revealOutput() {
    guard phase == .finished, let outputDirectory, let queue else { return }
    let outputs = queue.items.compactMap { item -> URL? in
      guard case let .succeeded(name, _) = item.state else { return nil }
      return outputDirectory.appendingPathComponent(name)
    }
    if outputs.isEmpty {
      NSWorkspace.shared.activateFileViewerSelecting([outputDirectory])
    } else {
      NSWorkspace.shared.activateFileViewerSelecting(outputs)
    }
  }

  private func clear() {
    conversionTask = nil
    folderPanel = nil
    ownerWindow = nil
    session = nil
    queue = nil
    startFailure = nil
    phase = .reviewing
  }
}
#endif

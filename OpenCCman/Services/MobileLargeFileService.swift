import CryptoKit
import Darwin
import Foundation
import OpenCC

/// The UI updates this gate on protected-data notifications. Workers never
/// consult UIApplication or close another thread's file descriptors.
final class LargeFileProtectionGate: @unchecked Sendable {
  private let lock = NSLock()
  private var available: Bool
  init(available: Bool) { self.available = available }
  func setAvailable(_ value: Bool) { lock.lock(); available = value; lock.unlock() }
  func check() throws {
    lock.lock()
    let value = available
    lock.unlock()
    if !value { throw MobileLargeFileService.JobError.protectedDataUnavailable }
  }
}

/// A single instance belongs to the whole App, not an editor or window. All
/// filesystem state is confined to its serial worker; queued starts cannot
/// overwrite an unexported result. The production UI remains gated in #260.
final class MobileLargeFileService: @unchecked Sendable {
  struct Ready: Equatable, Sendable {
    let id: UUID
    let url: URL
    let exportFilename: String
    let inputBytes: UInt64
    let outputBytes: UInt64
    let optionsRawValue: Int
    let capacity: MobileFileCapacity
    let cleanupPending: Bool
  }
  enum Recovery: Equatable, Sendable { case empty, ready(Ready), protectedDataUnavailable }
  enum Stage: String, Sendable {
    case snapshotRead, snapshotWrite, snapshotSync, conversionRead, conversionWrite
    case outputSync, beforeCommit, afterOutputRename, beforeJournalRename, inputCleanup, cleanup
  }
  enum JobError: Error {
    case protectedDataUnavailable, pendingResult, invalidStore, invalidJournal, staleJob
    case insufficientSpace, inputTooLarge, experimentalInputTooLarge
  }
  struct CleanupError: Error { let primary: Error; let cleanup: Error }
  struct Hooks: Sendable {
    var boundary: @Sendable (Stage) throws -> Void = { _ in }
    // Nil means unavailable, not zero; actual writes remain authoritative.
    var availableBytes: @Sendable (URL) throws -> Int64? = {
      try $0.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        .volumeAvailableCapacityForImportantUsage
    }
  }

  private let queue = DispatchQueue(label: "OpenCCman.mobile-file-job", qos: .userInitiated)
  private let root: URL
  private let protection: LargeFileProtectionGate
  private let hooks: Hooks
  // Accessed on queue only. Recovery and deletion must use the same owner.
  private var ready: Ready?
  private var recovered = false

  init(root: URL, protection: LargeFileProtectionGate, hooks: Hooks = Hooks()) {
    self.root = root.standardizedFileURL
    self.protection = protection
    self.hooks = hooks
  }

  static func applicationSupportRoot() throws -> URL {
    try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)
      .appendingPathComponent("OpenCCman-LargeFileJobs-v1", isDirectory: true)
  }

  func recover() async throws -> Recovery {
    try await perform { _ in
      do {
        try self.protection.check()
        if !self.recovered { try self.recoverOnWorker() }
        return self.ready.map(Recovery.ready) ?? .empty
      } catch JobError.protectedDataUnavailable { return .protectedDataUnavailable }
    }
  }

  func convert(source: URL, options: ChineseConverter.Options,
               capacity: MobileFileCapacity = .standard,
               expectedSource: TextFileFingerprint? = nil,
               snapshotReady: @escaping @Sendable () throws -> Void = {},
               progress: @escaping @Sendable (UInt64, UInt64) -> Void = { _, _ in }) async throws -> Ready {
    let rawOptions = options.rawValue
    return try await perform { cancellation in
      try self.protection.check()
      if !self.recovered { try self.recoverOnWorker() }
      guard self.ready == nil else { throw JobError.pendingResult }
      return try self.convertOnWorker(source: source, options: .init(rawValue: rawOptions),
                                      capacity: capacity, cancellation: cancellation,
                                      expectedSource: expectedSource, snapshotReady: snapshotReady, progress: progress)
    }
  }

  /// Call before presenting the exporter. Its cancellation leaves ready intact.
  func exportURL(for id: UUID) async throws -> URL {
    try await perform { _ in
      try self.protection.check()
      guard let ready = self.ready, ready.id == id else { throw JobError.staleJob }
      try self.requireWriteSpace(ready.outputBytes)
      guard let fingerprint = try TextFileFingerprint.read(url: ready.url, followSymlink: false),
            fingerprint.isRegular, fingerprint.size == ready.outputBytes else { throw JobError.invalidJournal }
      return ready.url
    }
  }

  /// Both explicit delete and a successful system export callback use its ID.
  /// Duplicate/late callbacks never delete a newer result.
  func discard(_ id: UUID) async throws {
    try await perform { _ in
      try self.protection.check()
      guard self.ready?.id == id else { throw JobError.staleJob }
      try self.removeJob(self.directory(id))
      self.ready = nil
    }
  }

  /// Explicit destructive recovery, invoked only after user confirmation.
  /// Same strict namespace and no-follow cleanup rules as automatic recovery.
  func discardStoredJobs() async throws {
    try await perform { _ in
      try self.protection.check()
      try self.makeDirectory(self.root)
      for job in try FileManager.default.contentsOfDirectory(at: self.root, includingPropertiesForKeys: nil) {
        guard job.lastPathComponent.hasPrefix("job-"),
              UUID(uuidString: String(job.lastPathComponent.dropFirst(4))) != nil else { continue }
        try self.removeJob(job)
      }
      self.ready = nil
      self.recovered = false
      try self.recoverOnWorker()
    }
  }

  private func perform<T: Sendable>(
    _ operation: @escaping @Sendable (StreamingConversionCancellation) throws -> T
  ) async throws -> T {
    let cancellation = StreamingConversionCancellation()
    return try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { continuation in
        queue.async {
          do {
            try cancellation.check()
            continuation.resume(returning: try operation(cancellation))
          } catch { continuation.resume(throwing: error) }
        }
      }
    }, onCancel: { cancellation.cancel() })
  }

  private func convertOnWorker(source: URL, options: ChineseConverter.Options,
                               capacity: MobileFileCapacity,
                               cancellation: StreamingConversionCancellation,
                               expectedSource: TextFileFingerprint?,
                               snapshotReady: @Sendable () throws -> Void,
                               progress: @Sendable (UInt64, UInt64) -> Void) throws -> Ready {
    let id = UUID()
    let job = directory(id)
    try makeDirectory(job)
    do {
      let snapshot = job.appendingPathComponent("input.txt")
      let inputBytes = try snapshotSource(source, to: snapshot, capacity: capacity,
                                          expectedSource: expectedSource, cancellation: cancellation)
      try snapshotReady()
      try check(cancellation)
      let partial = job.appendingPathComponent("output.partial")
      let input = try openFile(snapshot, writing: false)
      defer { try? input.close() }
      let output = try openFile(partial, writing: true)
      defer { try? output.close() }
      let storage = MobileFileStorageMonitor { try self.requireWriteSpace($0) }
      let counts = try StreamingConversionPump.run(
        input: input, output: output, expectedInputBytes: inputBytes, options: options,
        cancellation: cancellation, progress: progress,
        hooks: .init(beforeRead: { try self.check(cancellation); try self.hooks.boundary(.conversionRead) },
                     beforeWrite: { try self.check(cancellation); try self.hooks.boundary(.conversionWrite) },
                     beforeOutputWrite: { try storage.willWrite($0) }))
      try check(cancellation)
      try hooks.boundary(.outputSync)
      try output.synchronize()
      try output.close()
      try input.close()
      let checksum = try digest(partial, cancellation: cancellation)
      let filename = Self.exportFilename(source.lastPathComponent)
      let resultURL = job.appendingPathComponent(filename)
      let journal = Journal(schema: capacity == .standard ? 1 : 2, id: id, filename: filename, inputBytes: inputBytes,
                            outputBytes: counts.outputBytes, optionsRawValue: options.rawValue,
                            sha256: checksum, capacity: capacity == .standard ? nil : capacity)
      let journalPartial = job.appendingPathComponent("ready.partial")
      let journalHandle = try openFile(journalPartial, writing: true)
      defer { try? journalHandle.close() }
      try journalHandle.write(contentsOf: JSONEncoder().encode(journal))
      try journalHandle.synchronize()
      try journalHandle.close()
      try check(cancellation)
      try hooks.boundary(.beforeCommit)
      try cancellation.commit {
        try protection.check()
        try renameExclusive(partial, resultURL)
        try hooks.boundary(.afterOutputRename)
        try hooks.boundary(.beforeJournalRename)
        // The journal is the only publication marker. A kill between the two
        // renames leaves an incomplete job, never a recoverable partial result.
        try renameExclusive(journalPartial, job.appendingPathComponent("ready.json"))
      }
      // Publication already won. Surface failed input cleanup without reporting
      // a valid conversion as failed or deleting its committed result.
      var cleanupPending = false
      do { try hooks.boundary(.inputCleanup); try unlinkFile(snapshot) }
      catch { cleanupPending = true; recovered = false }
      let result = Ready(id: id, url: resultURL, exportFilename: filename,
                         inputBytes: inputBytes, outputBytes: counts.outputBytes, optionsRawValue: options.rawValue,
                         capacity: capacity, cleanupPending: cleanupPending)
      ready = result
      return result
    } catch {
      let primary = error
      do { try removeJob(job) }
      catch {
        recovered = false
        throw CleanupError(primary: primary, cleanup: error)
      }
      throw primary
    }
  }

  private func snapshotSource(_ source: URL, to destination: URL,
                              capacity: MobileFileCapacity,
                              expectedSource: TextFileFingerprint?, cancellation: StreamingConversionCancellation) throws -> UInt64 {
    guard source.isFileURL, source.pathExtension.lowercased() == "txt" else {
      throw TextFileService.FileError.unsupportedFile
    }
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    let coordinator = NSFileCoordinator(filePresenter: nil)
    cancellation.setCoordinator(coordinator)
    defer { cancellation.setCoordinator(nil) }
    var coordinationError: NSError?
    var result: Result<UInt64, Error>?
    coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in
      result = Result {
        try check(cancellation)
        let input = try openFile(url, writing: false)
        defer { try? input.close() }
        let before = try TextFileFingerprint.read(descriptor: input.fileDescriptor)
        if let expectedSource, before != expectedSource { throw TextFileService.FileError.sourceChanged }
        guard before.isRegular else { throw TextFileService.FileError.unsupportedFile }
        guard before.size <= capacity.maximumInputBytes else {
          throw capacity == .experimental ? JobError.experimentalInputTooLarge : JobError.inputTooLarge
        }
        try requireSpace(4 * before.size + 64 * 1024 * 1024)
        let output = try openFile(destination, writing: true)
        defer { try? output.close() }
        let storage = MobileFileStorageMonitor { try self.requireWriteSpace($0) }
        var count: UInt64 = 0
        while true {
          let read = try autoreleasepool { () throws -> Bool in
            try check(cancellation)
            try hooks.boundary(.snapshotRead)
            guard let data = try input.read(upToCount: StreamingConversionPump.bufferBytes), !data.isEmpty else { return false }
            count += UInt64(data.count)
            guard count <= before.size else { throw TextFileService.FileError.sourceChanged }
            try check(cancellation)
            try hooks.boundary(.snapshotWrite)
            try storage.willWrite(data.count)
            try output.write(contentsOf: data)
            return true
          }
          if !read { break }
        }
        guard count == before.size,
              try TextFileFingerprint.read(descriptor: input.fileDescriptor) == before,
              try TextFileFingerprint.read(url: url) == before else { throw TextFileService.FileError.sourceChanged }
        try hooks.boundary(.snapshotSync)
        try output.synchronize()
        try output.close()
        try input.close()
        try check(cancellation)
        return count
      }
    }
    if let result { return try result.get() }
    try check(cancellation)
    throw coordinationError ?? CocoaError(.fileReadUnknown)
  }

  private struct Journal: Codable {
    let schema: Int
    let id: UUID
    let filename: String
    let inputBytes: UInt64
    let outputBytes: UInt64
    let optionsRawValue: Int
    let sha256: String
    let capacity: MobileFileCapacity?

    // Legacy journals had no capacity field and can only describe <=100 MiB.
    // Experimental journals explicitly record their per-job authorization.
    // Standard results retain schema 1 so the previous app can still restore them.
    var acceptedCapacity: MobileFileCapacity? {
      if schema == 1, capacity == nil { return .standard }
      if schema == 2 { return capacity }
      return nil
    }
  }

  private func recoverOnWorker() throws {
    try protection.check()
    try makeDirectory(root)
    let entries = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    var found: Ready?
    for job in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      // Only this version's UUID namespace is owned; never scan other folders.
      guard job.lastPathComponent.hasPrefix("job-"),
            let id = UUID(uuidString: String(job.lastPathComponent.dropFirst(4))) else { continue }
      try requireDirectory(job)
      try protection.check()
      let journalURL = job.appendingPathComponent("ready.json")
      guard let metadata = try TextFileFingerprint.read(url: journalURL, followSymlink: false) else {
        try removeJob(job)
        continue
      }
      guard metadata.isRegular, metadata.size <= 16 * 1024 else { throw JobError.invalidJournal }
      // I/O errors (including lock/protection) never mean corrupt data to delete.
      let data = try Data(contentsOf: journalURL)
      guard let journal = try? JSONDecoder().decode(Journal.self, from: data),
            let capacity = journal.acceptedCapacity, journal.id == id,
            journal.inputBytes <= capacity.maximumInputBytes,
            journal.outputBytes <= UInt64(Int64.max) - Self.storageReserveBytes,
            journal.optionsRawValue >= 0, journal.optionsRawValue & ~Self.optionMask == 0,
            journal.filename == (journal.filename as NSString).lastPathComponent,
            journal.filename.hasSuffix("-converted.txt"), journal.sha256.count == 64 else { throw JobError.invalidJournal }
      let resultURL = directory(id).appendingPathComponent(journal.filename)
      guard let output = try TextFileFingerprint.read(url: resultURL, followSymlink: false), output.isRegular,
            output.size == journal.outputBytes else { throw JobError.invalidJournal }
      let hash = try digest(resultURL, cancellation: StreamingConversionCancellation())
      guard hash == journal.sha256 else { throw JobError.invalidJournal }
      guard found == nil else { throw JobError.pendingResult }
      try unlinkFile(job.appendingPathComponent("input.txt"))
      found = Ready(id: id, url: resultURL, exportFilename: journal.filename,
                    inputBytes: journal.inputBytes, outputBytes: journal.outputBytes, optionsRawValue: journal.optionsRawValue,
                    capacity: capacity, cleanupPending: false)
    }
    ready = found
    recovered = true
  }

  private static let optionMask = ChineseConverter.Options.traditionalize.rawValue
    | ChineseConverter.Options.simplify.rawValue | ChineseConverter.Options.twStandard.rawValue
    | ChineseConverter.Options.hkStandard.rawValue | ChineseConverter.Options.twIdiom.rawValue

  private static func exportFilename(_ sourceFilename: String) -> String {
    var stem = (sourceFilename as NSString).deletingPathExtension
    // Leave room for the suffix within the filesystem's component limit.
    while stem.utf8.count > 220 { stem.removeLast() }
    return "\(stem.isEmpty ? "OpenCCman" : stem)-converted.txt"
  }

  private func directory(_ id: UUID) -> URL { root.appendingPathComponent("job-" + id.uuidString, isDirectory: true) }
  private func check(_ cancellation: StreamingConversionCancellation) throws {
    try cancellation.check()
    try protection.check()
  }
  private func requireSpace(_ bytes: UInt64) throws {
    if let available = try hooks.availableBytes(root), available >= 0, UInt64(available) < bytes {
      throw JobError.insufficientSpace
    }
  }
  private static let storageReserveBytes: UInt64 = 64 * 1024 * 1024
  private func requireWriteSpace(_ bytes: UInt64) throws {
    let required = bytes.addingReportingOverflow(Self.storageReserveBytes)
    guard !required.overflow else { throw JobError.insufficientSpace }
    try requireSpace(required.partialValue)
  }
  private func makeDirectory(_ url: URL) throws {
    if try TextFileFingerprint.read(url: url, followSymlink: false) == nil {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
                                              attributes: [.posixPermissions: 0o700])
    }
    try requireDirectory(url)
    var mutable = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try mutable.setResourceValues(values)
    #if os(iOS)
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    #endif
  }
  private func requireDirectory(_ url: URL) throws {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw TextFileFingerprint.posixError() }
    guard value.st_mode & S_IFMT == S_IFDIR else { throw JobError.invalidStore }
  }
  private func openFile(_ url: URL, writing: Bool) throws -> FileHandle {
    let flags = writing ? O_WRONLY | O_CREAT | O_EXCL : O_RDONLY | O_NONBLOCK
    let fd = open(url.path, flags | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw TextFileFingerprint.posixError() }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    do {
      guard try TextFileFingerprint.read(descriptor: fd).isRegular else { throw JobError.invalidStore }
      #if os(iOS)
      if writing { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path) }
      #endif
      return handle
    } catch { try? handle.close(); throw error }
  }
  private func digest(_ url: URL, cancellation: StreamingConversionCancellation) throws -> String {
    let handle = try openFile(url, writing: false)
    defer { try? handle.close() }
    var hash = SHA256()
    while try autoreleasepool(invoking: { () throws -> Bool in
      try check(cancellation)
      guard let data = try handle.read(upToCount: StreamingConversionPump.bufferBytes), !data.isEmpty else { return false }
      hash.update(data: data)
      return true
    }) {}
    try handle.close()
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
  }
  private func renameExclusive(_ from: URL, _ to: URL) throws {
    guard renamex_np(from.path, to.path, UInt32(RENAME_EXCL)) == 0 else { throw TextFileFingerprint.posixError() }
  }
  private func unlinkFile(_ url: URL) throws {
    guard unlink(url.path) == 0 || errno == ENOENT else { throw TextFileFingerprint.posixError() }
  }
  private func removeJob(_ job: URL) throws {
    try protection.check()
    try hooks.boundary(.cleanup)
    try requireDirectory(root)
    try requireDirectory(job)
    let children = try FileManager.default.contentsOfDirectory(at: job, includingPropertiesForKeys: nil)
    let names: Set<String> = ["input.txt", "output.partial", "result.txt", "ready.partial", "ready.json"]
    // Refuse unexpected contents. Never recursively follow a replaced directory
    // or symlink; unlinking a known symlink only removes that link itself.
    for child in children {
      guard names.contains(child.lastPathComponent) || child.lastPathComponent.hasSuffix("-converted.txt") else { throw JobError.invalidStore }
      var value = stat()
      guard lstat(child.path, &value) == 0 else { throw TextFileFingerprint.posixError() }
      guard value.st_mode & S_IFMT == S_IFREG || value.st_mode & S_IFMT == S_IFLNK else { throw JobError.invalidStore }
    }
    for child in children { try unlinkFile(child) }
    guard rmdir(job.path) == 0 else { throw TextFileFingerprint.posixError() }
  }
}

/// Worker-confined. Recheck available disk space at most every 4 MiB of writes
/// (and before any larger single write), without querying the volume for every
/// 256 KiB buffer. This is advisory: actual write/sync errors stay authoritative.
private final class MobileFileStorageMonitor: @unchecked Sendable {
  private var remaining = 0
  private let interval = 4 * 1024 * 1024
  private let check: (UInt64) throws -> Void
  init(check: @escaping (UInt64) throws -> Void) { self.check = check }
  func willWrite(_ bytes: Int) throws {
    if bytes >= remaining {
      try check(UInt64(max(bytes, interval)))
      remaining = interval
    }
    remaining -= min(bytes, interval)
  }
}

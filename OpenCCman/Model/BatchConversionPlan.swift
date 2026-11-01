import Foundation

/// Mac batch rules confirmed for #25: Pro only, no daily quota, one sequential
/// queue of at most 100 files, each within the standard Mac file limit.
enum BatchConversionPolicy {
  static let maximumFiles = 100
  static let maximumFileBytes = FileConversionPolicy.macMaximumBytes
}

/// Pure queue state. The coordinator owns file access; this type only records
/// what happened to each selected file so every result stays traceable.
struct BatchConversionQueue: Equatable {
  struct Candidate: Equatable {
    let url: URL
    /// nil when metadata could not be read; the worker reports the real error.
    let byteCount: UInt64?
    let isRegularFile: Bool
  }

  enum SkipReason: Equatable {
    case unsupportedType, tooLarge, duplicate
  }

  enum State: Equatable {
    case waiting
    case converting
    case succeeded(outputFilename: String, outputBytes: UInt64)
    case failed(String)
    case cancelled
    case skipped(SkipReason)

    var isFinished: Bool {
      switch self {
      case .waiting, .converting: return false
      case .succeeded, .failed, .cancelled, .skipped: return true
      }
    }
  }

  struct Item: Identifiable, Equatable {
    let id: Int
    let sourceURL: URL
    let byteCount: UInt64?
    var state: State
    var sourceFilename: String { sourceURL.lastPathComponent }
  }

  enum AdmissionError: Error, Equatable {
    case empty
    case tooManyFiles(Int)
  }

  private(set) var items: [Item]

  /// Never truncates: more than the limit rejects the whole selection.
  init(candidates: [Candidate]) throws {
    guard !candidates.isEmpty else { throw AdmissionError.empty }
    guard candidates.count <= BatchConversionPolicy.maximumFiles else {
      throw AdmissionError.tooManyFiles(candidates.count)
    }
    var seen = Set<String>()
    items = candidates.enumerated().map { index, candidate in
      let state: State
      if !seen.insert(candidate.url.standardizedFileURL.resolvingSymlinksInPath().path).inserted {
        state = .skipped(.duplicate)
      } else if candidate.url.pathExtension.lowercased() != "txt" || !candidate.isRegularFile {
        state = .skipped(.unsupportedType)
      } else if let bytes = candidate.byteCount, bytes > BatchConversionPolicy.maximumFileBytes {
        state = .skipped(.tooLarge)
      } else {
        state = .waiting
      }
      return Item(id: index, sourceURL: candidate.url, byteCount: candidate.byteCount, state: state)
    }
  }

  var nextWaitingIndex: Int? { items.firstIndex { $0.state == .waiting } }
  var convertibleCount: Int { items.filter { $0.state == .waiting }.count }
  var isFinished: Bool { items.allSatisfy { $0.state.isFinished } }
  var succeededCount: Int { count { if case .succeeded = $0 { return true } else { return false } } }
  var failedCount: Int { count { if case .failed = $0 { return true } else { return false } } }
  var cancelledCount: Int { count { $0 == .cancelled } }
  var skippedCount: Int { count { if case .skipped = $0 { return true } else { return false } } }
  /// Files that have left the waiting/converting states, for "n of m".
  var finishedCount: Int { items.filter { $0.state.isFinished }.count }

  mutating func begin(_ index: Int) {
    precondition(items[index].state == .waiting, "Only a waiting file can start")
    precondition(!items.contains { $0.state == .converting }, "The batch converts one file at a time")
    items[index].state = .converting
  }

  mutating func finish(_ index: Int, as state: State) {
    precondition(items[index].state == .converting, "Only the active file can finish")
    precondition(state.isFinished, "A file finishes with a result")
    if case .skipped = state { preconditionFailure("Skipping is decided before the batch starts") }
    items[index].state = state
  }

  /// Cancellation stops every file that has not started. Completed results stay.
  mutating func cancelRemaining() {
    for index in items.indices where items[index].state == .waiting || items[index].state == .converting {
      items[index].state = .cancelled
    }
  }

  /// A lost output folder ends the batch: remaining files fail with its reason.
  mutating func failRemaining(_ reason: String) {
    for index in items.indices where items[index].state == .waiting {
      items[index].state = .failed(reason)
    }
  }

  private func count(where predicate: (State) -> Bool) -> Int {
    items.filter { predicate($0.state) }.count
  }
}

/// Output names match single-file export ("name-converted.txt"). Collisions get
/// Finder-style numbers ("name-converted 2.txt") and never replace a file.
struct BatchOutputNamer {
  enum NamingError: Error, Equatable { case exhausted }

  static let maximumNumber = 9_999
  private var reserved = Set<String>()

  static func baseName(for sourceFilename: String) -> String {
    let stem = (sourceFilename as NSString).deletingPathExtension
    return "\(stem.isEmpty ? "OpenCCman" : stem)-converted.txt"
  }

  static func numbered(_ base: String, _ number: Int) -> String {
    guard number > 1 else { return base }
    let name = base as NSString
    let stem = name.deletingPathExtension
    let pathExtension = name.pathExtension
    return pathExtension.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(pathExtension)"
  }

  /// APFS and HFS+ are usually case- and normalization-insensitive. Compare
  /// conservatively so two names that would collide on disk never both pass.
  static func key(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }

  /// `exists` checks the real directory (without following symlinks); names
  /// assigned earlier in this batch are reserved even before they are written.
  mutating func reserve(for sourceFilename: String, exists: (String) throws -> Bool) throws -> String {
    let base = Self.baseName(for: sourceFilename)
    for number in 1...Self.maximumNumber {
      let candidate = Self.numbered(base, number)
      guard !reserved.contains(Self.key(candidate)) else { continue }
      if try exists(candidate) { continue }
      reserved.insert(Self.key(candidate))
      return candidate
    }
    throw NamingError.exhausted
  }
}

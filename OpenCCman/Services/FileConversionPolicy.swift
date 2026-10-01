import Foundation

/// Input limits are independent of the stream's buffer size and output size.
/// The mobile large-file limit is a policy for the upcoming file workflow;
/// it does not enable that workflow or raise the editor's import limit.
enum FileConversionPolicy {
  static let editorMaximumBytes = 10 * 1024 * 1024
  static let mobileMaximumBytes: UInt64 = 100 * 1024 * 1024
  static let mobileExperimentalMaximumBytes: UInt64 = 1024 * 1024 * 1024
  static let macMaximumBytes: UInt64 = 1024 * 1024 * 1024
  // Development candidate; does not enable the experimental entry point.
  static let macExperimentalMaximumBytes: UInt64 = 8 * 1024 * 1024 * 1024
}

enum MacFileCapacity: Sendable {
  case standard, experimental

  var maximumInputBytes: UInt64 {
    self == .standard ? FileConversionPolicy.macMaximumBytes : FileConversionPolicy.macExperimentalMaximumBytes
  }

  /// An estimate for staging plus a possible provider copy, not an output cap.
  static func estimatedStorageBytes(for inputBytes: UInt64) -> UInt64? {
    let (doubled, overflow) = inputBytes.multipliedReportingOverflow(by: 2)
    let (required, reserveOverflow) = doubled.addingReportingOverflow(64 * 1024 * 1024)
    guard !overflow, !reserveOverflow, required <= UInt64(Int64.max) else { return nil }
    return required
  }
}

/// A per-job authorization, never a persisted preference to skip confirmation.
/// Recovery retains the policy of a completed job; it cannot start another one.
enum MobileFileCapacity: String, Codable, Sendable {
  case standard, experimental

  var maximumInputBytes: UInt64 {
    switch self {
    case .standard: return FileConversionPolicy.mobileMaximumBytes
    case .experimental: return FileConversionPolicy.mobileExperimentalMaximumBytes
    }
  }
}

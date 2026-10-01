import Foundation

/// Input limits are independent of the stream's buffer size and output size.
/// The mobile large-file limit is a policy for the upcoming file workflow;
/// it does not enable that workflow or raise the editor's import limit.
enum FileConversionPolicy {
  static let editorMaximumBytes = 10 * 1024 * 1024
  static let mobileMaximumBytes: UInt64 = 100 * 1024 * 1024
  static let mobileExperimentalMaximumBytes: UInt64 = 1024 * 1024 * 1024
  static let macMaximumBytes: UInt64 = 1024 * 1024 * 1024
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

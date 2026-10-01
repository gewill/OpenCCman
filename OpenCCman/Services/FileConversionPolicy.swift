import Foundation

/// Input limits are independent of the stream's buffer size and output size.
/// The mobile large-file limit is a policy for the upcoming file workflow;
/// it does not enable that workflow or raise the editor's import limit.
enum FileConversionPolicy {
  static let editorMaximumBytes = 10 * 1024 * 1024
  static let mobileMaximumBytes: UInt64 = 100 * 1024 * 1024
  static let macMaximumBytes: UInt64 = 1024 * 1024 * 1024
}

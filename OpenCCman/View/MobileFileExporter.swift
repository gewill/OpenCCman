#if os(iOS)
import SwiftUI
import UIKit

/// Export the complete disk file without creating a FileDocument or Data copy
/// in process memory. The system owns destination selection and replacement.
struct MobileFileExporter: UIViewControllerRepresentable {
  let jobID: UUID
  let url: URL
  let completion: @MainActor (UUID, Bool) -> Void

  func makeCoordinator() -> Delegate { Delegate(jobID: jobID, completion: completion) }

  func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

  @MainActor
  final class Delegate: NSObject, UIDocumentPickerDelegate {
    private let jobID: UUID
    private let completion: @MainActor (UUID, Bool) -> Void
    private var finished = false

    init(jobID: UUID, completion: @escaping @MainActor (UUID, Bool) -> Void) {
      self.jobID = jobID
      self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
      finish(!urls.isEmpty)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(false) }

    private func finish(_ succeeded: Bool) {
      guard !finished else { return }
      finished = true
      // This means the system export callback succeeded, not that a cloud
      // provider has finished syncing the destination to its server.
      completion(jobID, succeeded)
    }
  }
}
#endif

#if os(iOS)
import Neumorphic
import OpenCC
import SwiftUI

struct MobileLargeFileTaskView: View {
  @ObservedObject var coordinator: MobileLargeFileCoordinator
  @State private var confirmDelete = false
  @State private var exporter: Export?
  @State private var exportID: UUID?
  @State private var actionError: String?

  private struct Export: Identifiable { let id: UUID; let jobID: UUID; let url: URL }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Label(title.localizedStringKey, systemImage: symbol)
            .appFont(.title2, weight: .semibold)
            .accessibilityAddTraits(.isHeader)
          if let session = coordinator.session {
            VStack(alignment: .leading, spacing: 8) {
              Text(session.filename).appFont(.headline).textSelection(.enabled)
              Text(ByteCountFormatter.string(fromByteCount: Int64(session.inputBytes), countStyle: .file))
                .foregroundStyle(.secondary)
              configuration(session.optionsRawValue)
            }
          }
          phaseContent
          if let failure = coordinator.failure {
            Text(MobileFileError.description(failure))
              .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("mobile-file-error")
          }
          if let actionError { Text(actionError).foregroundStyle(.red) }
          actions
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(Color.Neumorphic.main.ignoresSafeArea())
      .navigationTitle(Text("large_file_title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if !coordinator.isWorking && coordinator.phase != .confirmation && coordinator.phase != .exporting {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { coordinator.dismissPresentation() }
          }
        }
      }
    }
    .navigationViewStyle(.stack)
    .neumorphicTheme(.openCCman)
    .interactiveDismissDisabled(coordinator.isWorking || coordinator.phase == .confirmation || coordinator.phase == .exporting)
    .accessibilityIdentifier("mobile-file-task")
    .confirmationDialog("mobile_file_delete_title", isPresented: $confirmDelete, titleVisibility: .visible) {
      Button("mobile_file_delete", role: .destructive) {
        if coordinator.ready != nil { coordinator.discardResult() } else { coordinator.resetStoredJobs() }
      }
      Button("Cancel", role: .cancel) {}
    } message: { Text("mobile_file_delete_message") }
    .onChange(of: coordinator.exportURL) { url in
      guard let url, let ready = coordinator.ready, let attempt = coordinator.exportAttemptID else { return }
      exportID = attempt
      exporter = Export(id: attempt, jobID: ready.id, url: url)
    }
    .sheet(item: $exporter, onDismiss: {
      if let exportID { coordinator.exportPresentationDismissed(attemptID: exportID) }
      exportID = nil
    }) { item in
      MobileFileExporter(jobID: item.jobID, url: item.url) { id, succeeded in
        coordinator.exportFinished(id: id, attemptID: item.id, succeeded: succeeded)
        exporter = nil
      }
    }
  }

  @ViewBuilder private var phaseContent: some View {
    switch coordinator.phase {
    case .confirmation:
      Text("mobile_file_explanation").foregroundStyle(.secondary)
    case .recovering, .preparing:
      ProgressView().accessibilityLabel(Text(title.localizedStringKey))
      Text("mobile_file_preparing_detail").foregroundStyle(.secondary)
    case .converting, .cancelling:
      ProgressView(value: coordinator.progress)
        .accessibilityLabel(Text("large_file_progress"))
        .accessibilityValue(Text("\(Int(coordinator.progress * 100))%"))
      Text("\(Int(coordinator.progress * 100))%").monospacedDigit()
      Text(coordinator.phase == .cancelling ? "large_file_cleanup" : "mobile_file_foreground")
        .foregroundStyle(.secondary)
    case .ready, .exporting:
      Text("mobile_file_ready_detail").foregroundStyle(.secondary)
      if let ready = coordinator.ready {
        Text(ByteCountFormatter.string(fromByteCount: Int64(ready.outputBytes), countStyle: .file)).monospacedDigit()
        if ready.cleanupPending { Text("mobile_file_cleanup_failure").foregroundStyle(.secondary) }
      }
      if coordinator.phase == .exporting { ProgressView() }
    case .interrupted:
      Text("mobile_file_interrupted_detail").foregroundStyle(.secondary)
    case .waitingForUnlock:
      Text("mobile_file_unlock_detail").foregroundStyle(.secondary)
    case .failed:
      Text("mobile_file_failed_detail").foregroundStyle(.secondary)
    case .idle, .completed:
      EmptyView()
    }
  }

  @ViewBuilder private var actions: some View {
    VStack(spacing: 12) {
      switch coordinator.phase {
      case .confirmation:
        Button {
          do { try coordinator.start() } catch { actionError = MobileFileError.description(error) }
        } label: { Text("mobile_file_convert").frame(maxWidth: .infinity) }
          .appNeumorphicButtonStyle(Capsule(), kind: .primary, role: .accent)
          .accessibilityIdentifier("mobile-file-convert")
        cancelButton
      case .preparing, .converting:
        cancelButton
      case .cancelling:
        Button("large_file_cancelling") {}.disabled(true)
          .appNeumorphicButtonStyle(Capsule())
      case .ready:
        Button { coordinator.prepareExport() } label: { Text("mobile_file_save").frame(maxWidth: .infinity) }
          .appNeumorphicButtonStyle(Capsule(), kind: .primary, role: .accent)
          .accessibilityIdentifier("mobile-file-save")
        deleteButton
      case .failed:
        if coordinator.ready == nil {
          Button("mobile_file_retry") { coordinator.recover() }
            .appNeumorphicButtonStyle(Capsule())
          deleteButton
        }
      case .waitingForUnlock:
        Button("mobile_file_retry") { coordinator.recover() }
          .appNeumorphicButtonStyle(Capsule())
      default: EmptyView()
      }
    }
  }
  private var cancelButton: some View {
    Button("Cancel") { coordinator.cancel() }
      .appNeumorphicButtonStyle(Capsule())
      .accessibilityIdentifier("mobile-file-cancel")
  }
  private var deleteButton: some View {
    Button("mobile_file_delete") { confirmDelete = true }
      .appNeumorphicButtonStyle(Capsule())
      .accessibilityIdentifier("mobile-file-delete")
  }
  private func configuration(_ raw: Int) -> some View {
    let options = ChineseConverter.Options(rawValue: raw)
    return VStack(alignment: .leading, spacing: 4) {
      Text(options.contains(.traditionalize) ? "Traditional Chinese" : "Simplified Chinese")
      if options.contains(.traditionalize) {
        Text(options.contains(.twStandard) ? "Taiwan Standard" : options.contains(.hkStandard) ? "HongKong Standard" : "OpenCC Standard")
        if options.contains(.twIdiom) { Text("Taiwan Idiom") }
      }
    }.appFont(.subheadline)
  }
  private var title: String {
    switch coordinator.phase {
    case .preparing, .recovering: return "mobile_file_preparing"
    case .converting: return "large_file_converting"
    case .cancelling: return "large_file_cancelling"
    case .ready, .exporting: return "mobile_file_ready"
    case .interrupted: return "mobile_file_interrupted"
    case .waitingForUnlock: return "mobile_file_unlock"
    case .failed: return "large_file_failed"
    default: return "large_file_title"
    }
  }
  private var symbol: String {
    switch coordinator.phase {
    case .ready, .completed: return "checkmark.circle"
    case .failed, .interrupted: return "exclamationmark.triangle"
    default: return "doc.text"
    }
  }
}

enum MobileFileError {
  static func description(_ error: Error) -> String {
    let key: String
    switch error {
    case MobileLargeFileCoordinator.StartError.busy, MobileLargeFileService.JobError.pendingResult:
      key = "mobile_file_busy"
    case MobileLargeFileCoordinator.StartError.requiresPro: key = "mobile_file_pro"
    case MobileLargeFileCoordinator.StartError.exceedsCapacity, MobileLargeFileService.JobError.inputTooLarge:
      key = "mobile_file_capacity"
    case MobileLargeFileService.JobError.insufficientSpace: key = "mobile_file_space"
    case MobileLargeFileService.JobError.protectedDataUnavailable: key = "mobile_file_unlock_detail"
    case is MobileLargeFileService.CleanupError: key = "mobile_file_cleanup_failure"
    case MobileLargeFileService.JobError.invalidJournal, MobileLargeFileService.JobError.invalidStore:
      key = "mobile_file_invalid_store"
    default: return error.localizedDescription
    }
    return NSLocalizedString(key, comment: "Mobile file workflow")
  }
}
#endif

#if os(macOS)
import SwiftUI

struct MacBatchConversionView: View {
  @ObservedObject var coordinator: MacBatchConversionCoordinator

  @ViewBuilder
  var body: some View {
    if #available(macOS 15.4, *) {
      // Let the app delegate cancel and await cleanup when the user quits.
      content.presentationPreventsAppTermination(false)
    } else {
      content
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(title.localizedStringKey, systemImage: symbol)
        .appFont(.title2, weight: .semibold)

      if let session = coordinator.session {
        configuration(session.configuration)
      }

      summary

      if let queue = coordinator.queue {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(queue.items) { item in
              BatchItemRow(item: item)
              if item.id != queue.items.last?.id { Divider() }
            }
          }
          .padding(.horizontal, 12)
        }
        .frame(minHeight: 120, maxHeight: 320)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("batch_file_list"))
        .accessibilityIdentifier("batch-file-list")
      }

      if let failure = coordinator.startFailure {
        Label(failure, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("batch-start-failure")
      }

      buttons
    }
    .padding(28)
    .appFont(.body)
    .frame(minWidth: 420, idealWidth: 560, maxWidth: 640)
    .fixedSize(horizontal: false, vertical: true)
    .interactiveDismissDisabled(coordinator.isWorking)
    .accessibilityIdentifier("batch-task")
  }

  private func configuration(_ configuration: ConversionConfiguration) -> some View {
    HStack(spacing: 6) {
      Text(configuration.target.title.localizedStringKey)
      if configuration.target == .traditional {
        Text("·")
        Text(configuration.variant.title.localizedStringKey)
        if configuration.region == .taiwan {
          Text("·")
          Text(configuration.region.title.localizedStringKey)
        }
      }
    }
    .appFont(.subheadline)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var summary: some View {
    if let queue = coordinator.queue {
      switch coordinator.phase {
      case .reviewing, .choosingFolder:
        VStack(alignment: .leading, spacing: 6) {
          Text(String(format: NSLocalizedString("batch_summary_ready", comment: ""),
                      queue.convertibleCount, queue.skippedCount))
            .appFont(.headline)
          Text("batch_explanation")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      case .converting, .cancelling:
        VStack(alignment: .leading, spacing: 8) {
          ProgressView(value: coordinator.progress)
            .accessibilityLabel(Text("batch_progress"))
            .accessibilityValue(Text(progressCount(queue)))
          HStack {
            Text(progressCount(queue))
              .monospacedDigit()
            Spacer()
            Text("\(Int(coordinator.progress * 100))%")
              .monospacedDigit()
          }
          .appFont(.subheadline)
          Text(coordinator.phase == .cancelling ? "batch_cleanup" : "batch_keep_open")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      case .finished:
        VStack(alignment: .leading, spacing: 6) {
          Text(String(format: NSLocalizedString("batch_summary_finished", comment: ""),
                      queue.succeededCount, queue.failedCount, queue.cancelledCount, queue.skippedCount))
            .appFont(.headline)
          if let folder = coordinator.outputDirectory {
            Text(String(format: NSLocalizedString("batch_output_folder", comment: ""), folder.lastPathComponent))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
      }
    }
  }

  private func progressCount(_ queue: BatchConversionQueue) -> String {
    let runnable = queue.items.filter { if case .skipped = $0.state { return false } else { return true } }
    let position = runnable.firstIndex { $0.state == .converting }.map { $0 + 1 }
      ?? runnable.filter { $0.state.isFinished }.count
    return String(format: NSLocalizedString("batch_progress_count", comment: ""), position, runnable.count)
  }

  private var buttons: some View {
    HStack {
      Spacer()
      switch coordinator.phase {
      case .reviewing:
        Button("Cancel") { coordinator.cancel() }
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("batch-cancel")
        Button("batch_choose_folder") { coordinator.chooseOutputFolder() }
          .keyboardShortcut(.defaultAction)
          .disabled((coordinator.queue?.convertibleCount ?? 0) == 0)
          .accessibilityIdentifier("batch-choose-folder")
      case .choosingFolder:
        EmptyView()
      case .converting:
        Button("Cancel") { coordinator.cancel() }
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("batch-cancel")
      case .cancelling:
        Button("large_file_cancelling") {}.disabled(true)
      case .finished:
        if coordinator.outputDirectory != nil {
          Button("large_file_show_in_finder") { coordinator.revealOutput() }
            .accessibilityIdentifier("batch-show-in-finder")
        }
        Button("Done") { coordinator.cancel() }
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("batch-done")
      }
    }
    .controlSize(.large)
  }

  private var title: String {
    switch coordinator.phase {
    case .reviewing, .choosingFolder: return "batch_title"
    case .converting: return "batch_converting"
    case .cancelling: return "large_file_cancelling"
    case .finished: return "batch_complete"
    }
  }

  private var symbol: String {
    switch coordinator.phase {
    case .finished:
      return (coordinator.queue?.failedCount ?? 0) > 0 ? "exclamationmark.triangle" : "checkmark.circle"
    default: return "doc.on.doc"
    }
  }
}

/// Status is carried by an icon and text, never by color alone.
private struct BatchItemRow: View {
  let item: BatchConversionQueue.Item

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      icon
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(item.sourceFilename)
          .lineLimit(2)
          .truncationMode(.middle)
        Text(status)
          .appFont(.subheadline)
          .foregroundStyle(statusStyle)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
      Spacer(minLength: 0)
      if let bytes = item.byteCount {
        Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
          .appFont(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("batch-item-\(item.id)")
  }

  @ViewBuilder
  private var icon: some View {
    switch item.state {
    case .waiting: Image(systemName: "clock").foregroundStyle(.secondary)
    case .converting: ProgressView().controlSize(.small)
    case .succeeded: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
    case .cancelled: Image(systemName: "xmark.circle").foregroundStyle(.secondary)
    case .skipped: Image(systemName: "minus.circle").foregroundStyle(.secondary)
    }
  }

  private var status: String {
    switch item.state {
    case .waiting: return NSLocalizedString("batch_state_waiting", comment: "")
    case .converting: return NSLocalizedString("batch_state_converting", comment: "")
    case let .succeeded(name, _):
      return String(format: NSLocalizedString("batch_state_succeeded", comment: ""), name)
    case let .failed(reason):
      return String(format: NSLocalizedString("batch_state_failed", comment: ""), reason)
    case .cancelled: return NSLocalizedString("batch_state_cancelled", comment: "")
    case .skipped(.unsupportedType): return NSLocalizedString("batch_skip_type", comment: "")
    case .skipped(.tooLarge): return NSLocalizedString("batch_skip_size", comment: "")
    case .skipped(.duplicate): return NSLocalizedString("batch_skip_duplicate", comment: "")
    }
  }

  private var statusStyle: Color {
    if case .failed = item.state { return .primary }
    return .secondary
  }
}
#endif

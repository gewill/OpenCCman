#if os(macOS)
import SwiftUI

struct MacLargeFileTaskView: View {
  @ObservedObject var coordinator: MacLargeFileCoordinator

  @ViewBuilder
  var body: some View {
    if #available(macOS 15.4, *) {
      // Let the app delegate cancel and await cleanup when the user quits.
      // SwiftUI's default sheet policy can otherwise block termination first.
      content.presentationPreventsAppTermination(false)
    } else {
      content
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 20) {
      Label(title.localizedStringKey, systemImage: symbol)
        .appFont(.title2, weight: .semibold)

      if let session = coordinator.session {
        VStack(alignment: .leading, spacing: 8) {
          Text(session.sourceFilename)
            .appFont(.headline)
            .lineLimit(2)
            .textSelection(.enabled)
          Text(ByteCountFormatter.string(fromByteCount: Int64(session.byteCount), countStyle: .file))
            .foregroundStyle(.secondary)
          HStack(spacing: 6) {
            Text(session.configuration.target.title.localizedStringKey)
            if session.configuration.target == .traditional {
              Text("·")
              Text(session.configuration.variant.title.localizedStringKey)
              if session.configuration.region == .taiwan {
                Text("·")
                Text(session.configuration.region.title.localizedStringKey)
              }
            }
          }
          .appFont(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
        }
      }

      phaseContent

      HStack {
        Spacer()
        switch coordinator.phase {
        case .confirmation:
          Button("Cancel") { coordinator.cancel() }
            .keyboardShortcut(.cancelAction)
          Button("large_file_choose_destination") { coordinator.chooseDestination() }
            .keyboardShortcut(.defaultAction)
        case .choosingDestination:
          EmptyView()
        case .converting:
          Button("Cancel") { coordinator.cancel() }
            .keyboardShortcut(.cancelAction)
        case .cancelling:
          Button("large_file_cancelling") {}.disabled(true)
        case .completed:
          Button("large_file_show_in_finder") { coordinator.revealOutput() }
          Button("Done") { coordinator.cancel() }
            .keyboardShortcut(.defaultAction)
        case .failed:
          Button("Done") { coordinator.cancel() }
            .keyboardShortcut(.defaultAction)
        }
      }
      .controlSize(.large)
    }
    .padding(28)
    .appFont(.body)
    .frame(width: 480)
    .fixedSize(horizontal: false, vertical: true)
    .interactiveDismissDisabled(coordinator.isWorking)
    .accessibilityIdentifier("large-file-task")
  }

  @ViewBuilder
  private var phaseContent: some View {
    switch coordinator.phase {
    case .confirmation, .choosingDestination:
      Text("large_file_explanation")
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    case .converting, .cancelling:
      VStack(alignment: .leading, spacing: 10) {
        ProgressView(value: coordinator.progress)
          .accessibilityLabel(Text("large_file_progress"))
        HStack {
          Text("\(Int(coordinator.progress * 100))%")
            .monospacedDigit()
          Spacer()
          Text(ByteCountFormatter.string(fromByteCount: Int64(coordinator.processedBytes), countStyle: .file))
            .monospacedDigit()
        }
        .appFont(.subheadline)
        Text(coordinator.phase == .cancelling ? "large_file_cleanup" : "large_file_keep_open")
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    case .completed:
      VStack(alignment: .leading, spacing: 8) {
        Text("large_file_saved")
        if let destination = coordinator.destination {
          Text(destination.lastPathComponent)
            .appFont(.headline)
            .textSelection(.enabled)
        }
        Text(ByteCountFormatter.string(fromByteCount: Int64(coordinator.outputBytes), countStyle: .file))
          .foregroundStyle(.secondary)
      }
    case .failed:
      VStack(alignment: .leading, spacing: 8) {
        Text(coordinator.failureDescription ?? "")
        Text("large_file_retry_import")
          .foregroundStyle(.secondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var title: String {
    switch coordinator.phase {
    case .confirmation, .choosingDestination: return "large_file_title"
    case .converting: return "large_file_converting"
    case .cancelling: return "large_file_cancelling"
    case .completed: return "large_file_complete"
    case .failed: return "large_file_failed"
    }
  }

  private var symbol: String {
    switch coordinator.phase {
    case .completed: return "checkmark.circle"
    case .failed: return "exclamationmark.triangle"
    default: return "doc.text"
    }
  }
}
#endif

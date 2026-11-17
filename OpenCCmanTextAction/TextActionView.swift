import SwiftUI

struct TextActionView: View {
  @ObservedObject var model: TextActionModel
  let cancel: () -> Void
  let done: (String) -> Void
  let copy: (String) -> Void
  let share: (String) -> Void

  @State private var copied = false

  var body: some View {
    NavigationView {
      Form {
        Section {
          Picker("text_action_preset_section", selection: $model.preset) {
            ForEach(ConversionConfiguration.Preset.allCases) { preset in
              Text(LocalizedStringKey(preset.title)).tag(preset)
            }
          }
          .pickerStyle(.inline)
          .labelsHidden()
          .accessibilityIdentifier("text-action-preset")
        } header: {
          Text("text_action_preset_section")
        }

        Section {
          resultContent
        } header: {
          Text("text_action_result_section")
        } footer: {
          footer
        }

        if let result = model.result {
          Section {
            Button {
              copy(result)
              copied = true
            } label: {
              Label(copied ? "text_action_copied" : "Copy Result",
                    systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityIdentifier("text-action-copy")
            Button {
              share(result)
            } label: {
              Label("text_action_share", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("text-action-share")
          }
        }
      }
      .navigationTitle(Text("text_action_title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: cancel)
            .accessibilityIdentifier("text-action-cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { model.result.map(done) }
            .disabled(model.result == nil)
            .accessibilityIdentifier("text-action-done")
        }
      }
    }
    .navigationViewStyle(.stack)
    .onChange(of: model.result) { _ in copied = false }
  }

  @ViewBuilder
  private var resultContent: some View {
    switch model.phase {
    case .loading:
      progress("text_action_loading")
    case .converting:
      progress("text_action_converting")
    case let .failed(message):
      Label(message, systemImage: "exclamationmark.triangle")
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("text-action-failure")
    case .converted:
      if let preview = model.preview {
        // A bounded box keeps Copy and Share on screen for long results.
        ScrollView {
          Text(verbatim: preview.text)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("text-action-result")
        }
        .frame(maxHeight: 220)
      }
    }
  }

  private func progress(_ key: LocalizedStringKey) -> some View {
    HStack(spacing: 10) {
      ProgressView()
      Text(key)
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var footer: some View {
    if model.phase == .converted, let preview = model.preview {
      VStack(alignment: .leading, spacing: 6) {
        Text(String(format: NSLocalizedString("text_action_character_count", comment: ""),
                    model.inputCharacterCount.formatted()))
        if preview.isTruncated {
          Text(String(format: NSLocalizedString("text_action_preview_truncated", comment: ""),
                      TextActionModel.previewCharacters.formatted()))
        }
        Text("text_action_return_hint")
      }
    }
  }
}

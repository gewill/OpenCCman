import Neumorphic
import SwiftUI
import UniformTypeIdentifiers

struct ConversionInspector: View {
  @Environment(\.colorScheme) private var colorScheme
  var showsPresetList = false
  @EnvironmentObject private var viewModel: HomeViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      if showsPresetList {
        Text("Conversion Preset").appFont(.headline)
        if viewModel.selectedPreset == nil {
          Text("preset_custom")
            .appFont(.subheadline)
            .foregroundColor(.secondary)
            .accessibilityIdentifier("conversion-preset-custom")
        }
        ForEach(ConversionConfiguration.Preset.allCases) { preset in
          Button { viewModel.applyPreset(preset) } label: {
            HStack {
              Text(preset.title.localizedStringKey).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 8)
              if viewModel.selectedPreset == preset {
                Image(systemName: "checkmark")
              }
            }
            .padding(.horizontal, 10).padding(.vertical, AppControlMetrics.contentInset).frame(minHeight: AppControlMetrics.height)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundColor(viewModel.selectedPreset == preset && colorScheme != .dark ? Color.accentColor : Color.Neumorphic.secondary)
          .accessibilityAddTraits(viewModel.selectedPreset == preset ? .isSelected : [])
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Conversion Preset").appFont(.headline)
          Menu {
            ForEach(ConversionConfiguration.Preset.allCases) { preset in
              Button {
                viewModel.applyPreset(preset)
              } label: {
                if viewModel.selectedPreset == preset {
                  Label(preset.title.localizedStringKey, systemImage: "checkmark")
                } else {
                  Text(preset.title.localizedStringKey)
                }
              }
            }
          } label: {
            Label((viewModel.selectedPreset?.title ?? "preset_custom").localizedStringKey,
                  systemImage: "chevron.down")
          }
          .appNeumorphicButtonStyle(Capsule())
          .accessibilityLabel(Text("Conversion Preset"))
          .accessibilityValue(Text((viewModel.selectedPreset?.title ?? "preset_custom").localizedStringKey))
        }
      }
      SegmentView(title: "Target Language", options: HomeViewModel.Language.allCases, selected: $viewModel.targetOptions)
      Group {
        SegmentView(title: "Variant", options: HomeViewModel.Variant.allCases, selected: $viewModel.variantOptions)
        SegmentView(title: "Region Idiom", options: HomeViewModel.Region.allCases, selected: $viewModel.regionOptions)
      }
      .disabled(viewModel.targetOptions == .simplified)
    }
    .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)
  }
}

struct SourcePane: View {
  @EnvironmentObject private var viewModel: HomeViewModel
  @EnvironmentObject private var whatsNewWindow: WhatsNewWindowState
  @State private var isDropTargeted = false
  var editorHeight: CGFloat = 200
  var paneHeight: CGFloat?
  @State private var headerHeight: CGFloat = 0
  var showsConversionAction = true

  var body: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      VStack(alignment: .leading, spacing: Constant.padding) {
        HStack {
          Text("Source").appFont(.headline)
          Button {
            guard let string = getClipboardString(),
                  string.isEmpty == false
            else {
              return
            }
            viewModel.replaceSource(string)
          } label: {
            Image(systemName: "doc.on.clipboard")
          }
          .appNeumorphicButtonStyle(Circle(), kind: .icon)
          .accessibilityLabel(Text("Paste Text"))

          Spacer()
          if showsConversionAction {
            ConversionAction()
          }
        }
        HStack {
          Button {
            whatsNewWindow.showingImporter = true
          } label: {
            Label("Import TXT", systemImage: "square.and.arrow.down")
          }
          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
          .disabled(viewModel.isImporting)
          Spacer()
          if viewModel.isImporting {
            LoadingView(width: 24, label: "Import TXT")
            Button { viewModel.cancelImport() } label: {
              Text("Cancel")
            }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
          }
        }
        if let filename = viewModel.sourceFilename {
          Text(filename).appFont(.caption).lineLimit(1).truncationMode(.middle)
        }
        Text("text_file_hint")
          .appFont(.caption)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .contentShape(Rectangle())
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                      style: StrokeStyle(lineWidth: 1, dash: [4]))
              .allowsHitTesting(false)
          )
          .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            viewModel.importDroppedItems(providers)
          }
      }
      .readSize { headerHeight = $0.height }
      WorkspaceTextEditor(text: $viewModel.inputText, label: "Source")
        .accessibilityLabel(Text("Source"))
        .disabled(viewModel.isImporting)
        .frame(maxWidth: .infinity)
        .frame(height: paneHeight.map { max(180, $0 - headerHeight - 60) } ?? editorHeight)
        .padding(Constant.padding)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.secondary, lineWidth: 1)
        )
    }
    .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)
  }
}

struct ResultPane: View {
  @EnvironmentObject private var viewModel: HomeViewModel
  var editorHeight: CGFloat = 200
  var paneHeight: CGFloat?
  @State private var headerHeight: CGFloat = 0
  var export: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      VStack(alignment: .leading, spacing: Constant.padding) {
        HStack {
          Text("Result").appFont(.headline)
          Button(action: {
            copyToClipboard(text: viewModel.resultText)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
          .appNeumorphicButtonStyle(Circle(), kind: .icon)
          .accessibilityLabel(Text("Copy Result"))
          .disabled(viewModel.resultText.isEmpty)
          Button(action: export) {
            Image(systemName: "square.and.arrow.up")
          }
          .appNeumorphicButtonStyle(Circle(), kind: .icon)
          .accessibilityLabel(Text("Export TXT"))
          .disabled(viewModel.exportSnapshot == nil)
          Spacer()
          if viewModel.isLoading {
            ProgressView().accessibilityLabel(Text("Convert"))
          }
        }
        if viewModel.resultText.isEmpty, viewModel.exportSnapshot != nil {
          Text("previous_result_available").appFont(.caption).foregroundColor(.secondary)
        }
        if viewModel.resultConfigurationChanged {
          Text("workspace_result_settings_changed").appFont(.caption).foregroundColor(.secondary)
        }
        if viewModel.resultText.isEmpty, !viewModel.isLoading {
          Text("workspace_result_empty").appFont(.caption).foregroundColor(.secondary)
        }
      }
      .readSize { headerHeight = $0.height }
      WorkspaceTextEditor(text: .constant(viewModel.resultText), isEditable: false, label: "Result")
        .accessibilityLabel(Text("Result"))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: paneHeight.map { max(180, $0 - headerHeight - 60) } ?? editorHeight)
        .padding(Constant.padding)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.secondary, lineWidth: 1)
        )
    }
    .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)
  }
}

struct ConversionAction: View {
  @EnvironmentObject private var viewModel: HomeViewModel
  var body: some View {
    if viewModel.isLoading {
      Button { viewModel.cancelConversion() } label: {
        Text("Cancel")
      }
      .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 20), kind: .primary)
    } else {
      Button(action: {
        #if os(iOS)
          UIApplication.shared.endEditing()
        #endif
        viewModel.translate()
      }, label: {
        Text("Convert")
          .appFont(.headline)
      })
      .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 20), kind: .primary, role: .accent)
      .keyboardShortcut("t")
      .disabled(viewModel.isImporting || viewModel.inputText.isEmpty)
    }
  }
}

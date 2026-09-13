import Neumorphic
import SwiftUI
import UniformTypeIdentifiers

struct ConversionInspector: View {
  var showsPresetList = false
  @EnvironmentObject private var viewModel: HomeViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      if showsPresetList {
        Text("Conversion Preset").font(.headline)
        ForEach(ConversionConfiguration.Preset.allCases) { preset in
          Button { viewModel.applyPreset(preset) } label: {
            HStack {
              Text(preset.title.localizedStringKey).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 8)
              if viewModel.selectedPreset == preset {
                Image(systemName: "checkmark")
              }
            }
            .padding(.horizontal, 10).frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundColor(viewModel.selectedPreset == preset ? Color.accentColor : Color.Neumorphic.secondary)
          .accessibilityAddTraits(viewModel.selectedPreset == preset ? .isSelected : [])
        }
      } else {
        HStack {
          Text("Conversion Preset").font(.headline)
          Spacer()
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
          .neumorphicThemedButtonStyle(Capsule(), padding: 8)
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
          Text("Source").font(.headline)
          Button {
            guard let string = getClipboardString(),
                  string.isEmpty == false
            else {
              return
            }
            viewModel.replaceSource(string)
          } label: {
            Image(systemName: "doc.on.clipboard").frame(width: 32, height: 32)
          }
          .softButtonStyle(Circle(), padding: Padding.small)
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
          .softButtonStyle(RoundedRectangle(cornerRadius: 12), padding: 8)
          .disabled(viewModel.isImporting)
          Spacer()
          if viewModel.isImporting {
            LoadingView(width: 24, label: "Import TXT")
            Button("Cancel") { viewModel.cancelImport() }
              .softButtonStyle(RoundedRectangle(cornerRadius: 12), padding: 8)
          }
        }
        if let filename = viewModel.sourceFilename {
          Text(filename).font(.caption).lineLimit(1).truncationMode(.middle)
        }
        Text("text_file_hint")
          .font(.caption)
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
      TextEditor(text: $viewModel.inputText)
        .clearTextEdtorStyle()
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
          Text("Result").font(.headline)
          Button(action: {
            copyToClipboard(text: viewModel.resultText)
          }, label: {
            Image(systemName: "doc.on.doc").frame(width: 32, height: 32)
          })
          .softButtonStyle(Circle(), padding: Padding.small)
          .accessibilityLabel(Text("Copy Result"))
          .disabled(viewModel.resultText.isEmpty)
          Button(action: export) {
            Image(systemName: "square.and.arrow.up").frame(width: 32, height: 32)
          }
          .softButtonStyle(Circle(), padding: Padding.small)
          .accessibilityLabel(Text("Export TXT"))
          .disabled(viewModel.exportSnapshot == nil)
          Spacer()
          if viewModel.isLoading {
            ProgressView().accessibilityLabel(Text("Convert"))
          }
        }
        if viewModel.resultText.isEmpty, viewModel.exportSnapshot != nil {
          Text("previous_result_available").font(.caption).foregroundColor(.secondary)
        }
        if viewModel.resultConfigurationChanged {
          Text("workspace_result_settings_changed").font(.caption).foregroundColor(.secondary)
        }
        if viewModel.resultText.isEmpty, !viewModel.isLoading {
          Text("workspace_result_empty").font(.caption).foregroundColor(.secondary)
        }
      }
      .readSize { headerHeight = $0.height }
      TextEditor(text: .constant(viewModel.resultText))
        .clearTextEdtorStyle(isEditable: false)
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
      Button("Cancel") { viewModel.cancelConversion() }
        .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 10)
    } else {
      Button(action: {
        #if os(iOS)
          UIApplication.shared.endEditing()
        #endif
        viewModel.translate()
      }, label: {
        Text("Convert")
          .font(.headline)
      })
      .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 10, mainColor: Color.accentColor, textColor: Color.Neumorphic.main)
      .keyboardShortcut("t")
      .disabled(viewModel.isImporting || viewModel.inputText.isEmpty)
    }
  }
}

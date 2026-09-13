import Neumorphic
import OpenCC
import SwiftUI
import SwiftUIRouter
import UniformTypeIdentifiers

struct HomeScene: View {
  @EnvironmentObject var navigator: Navigator

  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @EnvironmentObject private var viewModel: HomeViewModel
  @EnvironmentObject private var whatsNewWindow: WhatsNewWindowState
  @State private var exportDocument: ConvertedTextDocument?
  @State private var exportFilename = "OpenCCman-converted.txt"
  @State private var isDropTargeted = false

  var body: some View {
    ZStack(alignment: .top) {
      Color.Neumorphic.main
        .ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          navi
          list
        }
      }
      if isPro == false {
        VStack {
          Spacer()
          MyAppView()
            .padding(.bottom)
        }
      }
    }
    .frame(minWidth: 300)
    .overlay(ProAlertView(showingProAlert: $viewModel.showingProAlert, showingProScene: $whatsNewWindow.showingProSheet) {
      whatsNewWindow.proSheetIsActive = false
    })
    .fileImporter(isPresented: $whatsNewWindow.showingImporter, allowedContentTypes: [.plainText]) { result in
      switch result {
      case .success(let url): viewModel.importFile(url)
      case .failure(let error): viewModel.handleFileFailure(error)
      }
    }
    .fileExporter(isPresented: $whatsNewWindow.showingExporter, document: exportDocument,
                  contentType: .plainText, defaultFilename: exportFilename) { result in
      if case .failure(let error) = result { viewModel.handleFileFailure(error) }
      exportDocument = nil
    }
    .alert(isPresented: Binding(
      get: { viewModel.error != nil },
      set: { if !$0 { viewModel.error = nil } }
    )) {
      Alert(title: Text("Error"), message: Text(viewModel.error?.localizedDescription ?? ""))
    }
  }

  var navi: some View {
    ZStack(alignment: .center) {
      HStack {
        VStack {
          HStack {
            Text("OpenCCman").font(.title)
            Button {
              navigator.navigate("/help")
            } label: {
              Image.questionmark
                .modify {
                  if #available(iOS 15.0, macOS 12.0, *) {
                    $0.symbolRenderingMode(.palette)
                      .foregroundStyle(Color.Neumorphic.secondary, Color.accent)
                  }
                }
            }
            .buttonStyle(.plain)
          }
          Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(Color.Neumorphic.secondary)
      }
      HStack {
        Button(action: {
          navigator.navigate("/pro")
        }, label: {
          Image.crown
        })
        .fixedSizeSoftButtonStyle(textColor: isPro ? .yellow : .accentColor, size: Constant.smallButtonSize)
        .keyboardShortcut("p")

        Spacer()

        Button {
          navigator.navigate("/settings")
        } label: {
          Image.settings
        }
        .fixedSizeSoftButtonStyle(size: Constant.smallButtonSize)
        .keyboardShortcut(",")
      }
      .padding(.horizontal, Constant.padding)
    }
    .padding(.vertical, Constant.padding)
  }

  var list: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      VStack(alignment: .leading, spacing: Constant.padding) {
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
        SegmentView(title: "Target Language", options: HomeViewModel.Language.allCases, selected: $viewModel.targetOptions)
        Group {
          SegmentView(title: "Variant", options: HomeViewModel.Variant.allCases, selected: $viewModel.variantOptions)
          SegmentView(title: "Region Idiom", options: HomeViewModel.Region.allCases, selected: $viewModel.regionOptions)
        }
        .disabled(viewModel.targetOptions == .simplified)
      }
      .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)

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
            Image(systemName: "doc.on.clipboard")
          }
          .softButtonStyle(Circle(), padding: Padding.small)
          .accessibilityLabel(Text("Paste Text"))

          Spacer()
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
        TextEditor(text: $viewModel.inputText)
          .clearTextEdtorStyle()
          .accessibilityLabel(Text("Source"))
          .disabled(viewModel.isImporting)
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
          .padding(Constant.padding)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)

      VStack(alignment: .leading, spacing: Constant.padding) {
        HStack {
          Text("Result").font(.headline)
          Button(action: {
            copyToClipboard(text: viewModel.resultText)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
          .softButtonStyle(Circle(), padding: Padding.small)
          .accessibilityLabel(Text("Copy Result"))
          .disabled(viewModel.resultText.isEmpty)
          Button {
            guard let snapshot = viewModel.exportSnapshot else { return }
            exportDocument = ConvertedTextDocument(text: snapshot.text)
            exportFilename = snapshot.filename
            whatsNewWindow.showingExporter = true
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
          .softButtonStyle(Circle(), padding: Padding.small)
          .accessibilityLabel(Text("Export TXT"))
          .disabled(viewModel.exportSnapshot == nil)
          Spacer()
          if viewModel.isLoading {
            LoadingView(width: 24, label: "Convert")
          }
          if !viewModel.isLoading {
            Text("\(viewModel.localProgressPercent)%")
              .modify {
                if #available(iOS 15, macOS 12, *) {
                  $0.monospacedDigit()
                }
              }
          }
        }
        if viewModel.resultText.isEmpty && viewModel.exportSnapshot != nil {
          Text("previous_result_available").font(.caption).foregroundColor(.secondary)
        }
        TextEditor(text: .constant(viewModel.resultText))
          .clearTextEdtorStyle(isEditable: false)
          .accessibilityLabel(Text("Result"))
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300, alignment: .topLeading)
          .padding(Constant.padding)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .neumorphicCard(RoundedRectangle(cornerRadius: Constant.cornerRadius), padding: Constant.padding)
      Spacer()
    }
    .foregroundColor(Color.Neumorphic.secondary)
    .padding(Constant.padding)
  }
}

#Preview {
  Router {
    HomeScene()
      .environmentObject(HomeViewModel())
      .environmentObject(WhatsNewWindowState())
  }
}

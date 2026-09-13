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

  var body: some View {
    ZStack(alignment: .top) {
      Color.Neumorphic.main
        .ignoresSafeArea()
      #if os(macOS)
      WorkspaceSurface(export: exportResult)
      #else
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          navi
          list
          if !isPro { MyAppView().padding(Constant.padding) }
        }
      }
      #endif

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

  private func exportResult() {
    guard let snapshot = viewModel.exportSnapshot else { return }
    exportDocument = ConvertedTextDocument(text: snapshot.text)
    exportFilename = snapshot.filename
    whatsNewWindow.showingExporter = true
  }

  var navi: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Text("OpenCCman").font(.title).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Menu {
          Button("Help") { navigator.navigate("/help") }
          Button("Pro") { navigator.navigate("/pro") }.keyboardShortcut("p")
          Button("Settings") { navigator.navigate("/settings") }.keyboardShortcut(",")
        } label: {
          Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(Text("workspace_more"))
      }
      Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundColor(Color.Neumorphic.secondary)
    .padding(Constant.padding)
  }

  var list: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      ConversionInspector()
      SourcePane()
      ResultPane {
        guard let snapshot = viewModel.exportSnapshot else { return }
        exportDocument = ConvertedTextDocument(text: snapshot.text)
        exportFilename = snapshot.filename
        whatsNewWindow.showingExporter = true
      }
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

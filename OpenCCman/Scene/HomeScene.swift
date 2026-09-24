import Neumorphic
import OpenCC
import SwiftUI
import SwiftUIRouter
import UniformTypeIdentifiers

struct HomeScene: View {
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
        if UserInterfaceIdiom.current == .pad {
          WorkspaceSurface(platform: .pad, export: exportResult)
        } else {
          PhoneWorkspace(export: exportResult)
        }
      #endif
    }
    .frame(minWidth: 300)
    .overlay {
      if viewModel.showingProAlert {
        // Keep pointer and touch input in the custom modal without replacing the editors.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {}
          .accessibilityHidden(true)
      }
    }
    .overlay(ProAlertView(showingProAlert: $viewModel.showingProAlert, showingProScene: $whatsNewWindow.showingProSheet) {
      whatsNewWindow.proSheetIsActive = false
    })
    .fileImporter(isPresented: $whatsNewWindow.showingImporter, allowedContentTypes: [.plainText]) { result in
      switch result {
      case let .success(url): viewModel.importFile(url)
      case let .failure(error): viewModel.handleFileFailure(error)
      }
    }
    .fileExporter(isPresented: $whatsNewWindow.showingExporter, document: exportDocument,
                  contentType: .plainText, defaultFilename: exportFilename)
    { result in
      if case let .failure(error) = result {
        viewModel.handleFileFailure(error)
      }
      exportDocument = nil
    }
    .alert(isPresented: Binding(
      get: { viewModel.error != nil },
      set: {
        if !$0 {
          viewModel.error = nil
        }
      }
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
}

#Preview {
  Router {
    HomeScene()
      .environmentObject(HomeViewModel())
      .environmentObject(WhatsNewWindowState())
  }
}

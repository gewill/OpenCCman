import Neumorphic
import OpenCC
import SwiftUI
import SwiftUIRouter
import UniformTypeIdentifiers

struct HomeScene: View {
  @EnvironmentObject private var viewModel: HomeViewModel
  @EnvironmentObject private var whatsNewWindow: WhatsNewWindowState
  #if os(iOS)
  @ObservedObject private var mobileFile = MobileFileRuntime.shared.coordinator
  #endif
  @State private var exportDocument: ConvertedTextDocument?
  @State private var exportFilename = "OpenCCman-converted.txt"

  var body: some View {
    ZStack(alignment: .top) {
      Color.Neumorphic.main
        .ignoresSafeArea()
      #if os(macOS)
        WorkspaceSurface(export: exportResult)
      #else
        WorkspaceSurface(platform: .mobile, export: exportResult)
      #endif
    }
    .frame(minWidth: 300)
    #if os(iOS)
    .safeAreaInset(edge: .bottom) {
      if MobileFileRuntime.isEnabled, mobileFile.presentationOwner == nil,
         mobileFile.ready != nil || mobileFile.phase == .failed || mobileFile.phase == .waitingForUnlock {
        Button("mobile_file_resume") { _ = mobileFile.claimPresentation(viewModel.windowOwnerID) }
          .appNeumorphicButtonStyle(Capsule())
          .accessibilityIdentifier("mobile-file-resume")
          .padding(.horizontal).padding(.bottom, 8)
      }
    }
    #endif
    #if os(macOS)
    .overlay {
      if viewModel.showingProAlert {
        // Keep pointer and touch input in the custom modal without replacing the editors.
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {}
          .accessibilityHidden(true)
      }
    }
    .overlay(ProAlertView(showingProAlert: $viewModel.showingProAlert, showingProScene: $whatsNewWindow.showingProSheet,
                          detailKey: viewModel.proAlertDetailKey) {
      whatsNewWindow.proSheetIsActive = false
    })
    #else
    .sheet(isPresented: $whatsNewWindow.showingProSheet, onDismiss: {
      whatsNewWindow.proSheetIsActive = false
    }) {
      ProScene(isPresented: true)
    }
    #endif
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
      get: {
        #if os(iOS)
        viewModel.showingProAlert || viewModel.error != nil
        #else
        viewModel.error != nil
        #endif
      },
      set: {
        if !$0 {
          #if os(iOS)
          viewModel.showingProAlert = false
          #endif
          viewModel.error = nil
        }
      }
    )) {
      #if os(iOS)
      if viewModel.showingProAlert {
        Alert(title: Text("Pro only feature"), message: Text(viewModel.proAlertDetailKey.localizedStringKey),
              primaryButton: .default(Text("Pro")) { whatsNewWindow.showingProSheet = true },
              secondaryButton: .cancel())
      } else {
        Alert(title: Text("Error"), message: Text(fileErrorDescription))
      }
      #else
      Alert(title: Text("Error"), message: Text(fileErrorDescription))
      #endif
    }
  }

  private var fileErrorDescription: String {
    guard let error = viewModel.error else { return "" }
    #if os(iOS)
    return MobileFileError.description(error)
    #else
    return error.localizedDescription
    #endif
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

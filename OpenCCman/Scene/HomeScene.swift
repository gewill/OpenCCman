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
    #if os(iOS)
    .alert(item: alertPresentation) { alert in
      switch alert {
      case let .pro(detail):
        return Alert(title: Text("Pro only feature"), message: Text(detail.localizedStringKey),
                     primaryButton: .default(Text("Pro")) { whatsNewWindow.showingProSheet = true },
                     secondaryButton: .cancel())
      case let .failure(message):
        return Alert(title: Text("Error"), message: Text(message))
      }
    }
    #else
    .alert(isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) {
      Alert(title: Text("Error"), message: Text(fileErrorDescription))
    }
    #endif
  }

  #if os(iOS)
  private enum HomeAlert: Identifiable {
    case pro(String)
    case failure(String)

    var id: String {
      switch self {
      case .pro: return "pro"
      case .failure: return "error"
      }
    }
  }

  private var alertPresentation: Binding<HomeAlert?> {
    let displayed: HomeAlert?
    if whatsNewWindow.proSheetIsActive {
      displayed = nil
    } else if viewModel.showingProAlert {
      displayed = .pro(viewModel.proAlertDetailKey)
    } else if viewModel.error != nil {
      displayed = .failure(fileErrorDescription)
    } else {
      displayed = nil
    }
    return Binding(get: { displayed }, set: { next in
      guard next == nil else { return }
      // Consume the snapshot actually presented, not whichever flag is now set.
      // A pending error survives Pro cancellation and waits for its sheet to close.
      switch displayed {
      case .pro: viewModel.showingProAlert = false
      case .failure: viewModel.error = nil
      case nil: break
      }
    })
  }
  #endif

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

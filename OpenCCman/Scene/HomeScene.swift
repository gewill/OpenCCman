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

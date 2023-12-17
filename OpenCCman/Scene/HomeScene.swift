import Neumorphic
import OpenCC
import SwiftUI
import SwiftUIRouter

struct HomeScene: View {
  @EnvironmentObject var navigator: Navigator

  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @ObservedObject var viewModel = HomeViewModel()

  var body: some View {
    ZStack(alignment: .top) {
      Color.main
        .ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          navi
          list
        }
      }
    }
    .frame(minWidth: 300)
    .overlay(ProAlertView(showingProAlert: $viewModel.showingProAlert))
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
    .background(Color.Neumorphic.main)
  }

  var list: some View {
    VStack(alignment: .leading, spacing: Constant.padding) {
      VStack(alignment: .leading) {
        SegmentView(title: "Target Language", options: HomeViewModel.Language.allCases, seleted: $viewModel.targetOptions)
        Group {
          SegmentView(title: "Variant", options: HomeViewModel.Variant.allCases, seleted: $viewModel.variantOptions)
          SegmentView(title: "Region Idiom", options: HomeViewModel.Region.allCases, seleted: $viewModel.regionOptions)
        }
        .disabled(viewModel.targetOptions == .simplified)
      }
      .padding(Constant.padding)
      .background(
        RoundedRectangle(cornerRadius: Constant.cornerRadius)
          .fill(Color.Neumorphic.main)
          .softOuterShadow()
      )

      VStack(alignment: .leading, spacing: Constant.padding) {
        HStack {
          Text("Source").font(.headline)
          Spacer()
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
        }
        TextEditor(text: $viewModel.inputText)
          .clearTextEdtorStyle()
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
          .padding(Constant.padding)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .padding(Constant.padding)
      .background(
        RoundedRectangle(cornerRadius: Constant.cornerRadius)
          .fill(Color.Neumorphic.main)
          .softOuterShadow()
      )

      VStack(alignment: .leading, spacing: Constant.padding) {
        HStack {
          Text("Result").font(.headline)
          Button(action: {
            copyToClipboard(text: viewModel.resultText)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
          .softButtonStyle(Circle(), padding: 6)
          Spacer()
        }
        Text(viewModel.resultText)
          .textSelectable()
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300, alignment: .topLeading)
          .padding(Constant.padding)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .padding(Constant.padding)
      .background(
        RoundedRectangle(cornerRadius: Constant.cornerRadius)
          .fill(Color.Neumorphic.main)
          .softOuterShadow()
      )
      Spacer()
    }
    .foregroundColor(Color.Neumorphic.secondary)
    .padding(Constant.padding)
  }
}

#Preview {
  HomeScene()
}

import Neumorphic
import OpenCC
import SwiftUI
import SwiftUIRouter

struct HomeScene: View {
  @EnvironmentObject var navigator: Navigator

  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @ObservedObject var viewModel = HomeViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      navi
      list
    }
    .overlay(ProAlertView(showingProAlert: $viewModel.showingProAlert))
  }

  var navi: some View {
    ZStack(alignment: .center) {
      HStack {
        VStack {
          Text("OpenCCman").font(.title)
          Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(Color.Neumorphic.secondary)
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
      }
      HStack {
        Button(action: {
          navigator.navigate("/pro")
        }, label: {
          Image.crown
        })
        .softButtonStyle(Circle(), padding: 6, textColor: isPro ? .yellow : .accentColor)
        .keyboardShortcut("p")

        Spacer()

        Button {
          navigator.navigate("/settings")
        } label: {
          Image.settings
        }
        .softButtonStyle(Circle(), padding: 6)
        .keyboardShortcut(",")
      }
      .padding(.horizontal, Constant.padding)
    }
    .padding(.vertical, Constant.padding)
    .background(Color.Neumorphic.main)
  }

  var list: some View {
    ZStack(alignment: .top) {
      Color.main
        .ignoresSafeArea()
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
          Text("Source").font(.headline)
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
            Button(action: {
              viewModel.translate()
            }, label: {
              Text("Convert")
                .font(.headline)
            })
            .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 10, mainColor: Color.accentColor, textColor: Color.Neumorphic.main)
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
      }
      .foregroundColor(Color.Neumorphic.secondary)
      .padding(Constant.padding)
    }
    .frame(minWidth: 300)
  }
}

#Preview {
  HomeScene()
}

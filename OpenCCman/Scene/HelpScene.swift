import SwiftUI

struct HelpScene: View {
  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system

  // MARK: - life cycle

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      navi
      list
    }.background(Color.Neumorphic.main)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Help")
        .font(.title)
        .foregroundColor(Color.Neumorphic.secondary)
      HStack {
        BackButton()
          .padding(.horizontal, Constant.padding * 2)
        Spacer()
      }
    }
    .padding(.vertical, Constant.padding)
    .foregroundColor(Color.Neumorphic.secondary)
    .background(Color.Neumorphic.main)
  }

  var list: some View {
    ZStack(alignment: .top) {
      Color.Neumorphic.main
        .ignoresSafeArea()
      VStack(alignment: .center, spacing: 10.0) {
        Link("Online help", destination: URL(string: selectedLocale.helpUrl)!)
          .padding(4)
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(Color.accent, lineWidth: 1)
          )
        Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")

        ScrollView {
          VStack(alignment: .leading, spacing: 10.0) {
            Text("help description")
          }
        }
      }
      .padding(Constant.padding)
      .foregroundColor(Color.Neumorphic.secondary)
      .ignoresSafeArea(edges: .bottom)
    }
  }
}

struct HelpView_Previews: PreviewProvider {
  static var previews: some View {
    HelpScene()
  }
}

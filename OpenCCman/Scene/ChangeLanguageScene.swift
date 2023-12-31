import SwiftUI

struct ChangeLanguageScene: View {
  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system

  var body: some View {
    VStack {
      navi
      list
    }
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Language")
        .font(.title)
        .foregroundColor(Color.Neumorphic.secondary)
      HStack {
        BackButton()
          .padding(.horizontal, Constant.padding)
        Spacer()
      }
    }
    .padding(.vertical, Constant.padding)
  }

  var list: some View {
    ScrollView {
      VStack {
        PickableView(
          options: LocaleConstants.allCases,
          initialContent: selectedLocale
        ) { item in
          selectedLocale = item
        }
      }
      .padding()
    }
  }
}

struct ChangeLanguageScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeLanguageScene()
  }
}

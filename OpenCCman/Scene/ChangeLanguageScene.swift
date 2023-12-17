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
    List {
      Picker("Language", selection: $selectedLocale) {
        ForEach(LocaleConstants.allCases) {
          Text($0.title)
        }
      }
      .pickerStyle(InlinePickerStyle())
    }
    #if os(iOS)
    .listStyle(.insetGrouped)
    #endif
  }
}

struct ChangeLanguageScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeLanguageScene()
  }
}

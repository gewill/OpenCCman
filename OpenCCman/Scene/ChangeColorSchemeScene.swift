import SwiftUI

struct ChangeColorSchemeScene: View {
  @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
  @AppStorage(UserDefaultsKeys.selectedTheme.rawValue) var selectedTheme: Theme = .system

  // MARK: - life cycle

  var body: some View {
    ZStack(alignment: .top) {
      Color("mainColor")
        .ignoresSafeArea()
      VStack(spacing: Constant.padding) {
        #if os(macOS)
        navi
        #endif
        list
      }
    }
    .appNavigation("Appearance")
  }

  var navi: some View {
    SceneHeader("Appearance")
      .foregroundColor(Color.Neumorphic.secondary)
      .padding(.vertical, Constant.padding)
  }

  var list: some View {
    ScrollView {
      VStack {
        PickableView(
          options: Theme.allCases,
          initialContent: selectedTheme
        ) { item in
          selectedTheme = item
        }
      }
      .padding()
    }
  }
}

struct ChangeColorSchemeScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeColorSchemeScene()
  }
}

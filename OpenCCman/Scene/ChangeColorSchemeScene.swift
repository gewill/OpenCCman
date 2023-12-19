import SwiftUI

struct ChangeColorSchemeScene: View {
  @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
  @AppStorage(UserDefaultsKeys.selectedTheme.rawValue) var selectedTheme: Theme = .system

  // MARK: - life cycle

  var body: some View {
    ZStack(alignment: .top) {
      Color.main
        .ignoresSafeArea()
      VStack(spacing: Constant.padding) {
        navi
        list
      }
    }
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Appearance")
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
      Picker("Appearance", selection: $selectedTheme) {
        ForEach(Theme.allCases) {
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

struct ChangeColorSchemeScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeColorSchemeScene()
  }
}

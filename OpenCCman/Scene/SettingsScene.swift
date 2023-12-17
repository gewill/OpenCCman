#if os(iOS)
  import BetterSafariView
#endif
import SwiftUI
import SwiftUIRouter

struct SettingsScene: View {
  @EnvironmentObject var navigator: Navigator
  @Environment(\.openURL) var openURL

  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system
  @AppStorage(UserDefaultsKeys.hasHapticFeedback.rawValue) var hasHapticFeedback: Bool = true
  #if os(iOS)
    @State private var presentingSafariView: Bool = false
  #endif
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false

  var body: some View {
    VStack {
      navi
      list
    }
    .background(Color.Neumorphic.main)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Settings")
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
      VStack(spacing: Padding.verLarge) {
        VStack(spacing: Constant.padding) {
          HStack(alignment: .center, spacing: 6) {
            Text("App Version")
            Spacer()
            Text(Bundle.main.appVersionInfo)
          }
          Divider()
          CellButton(title: "Review on App Store") {
            openURL(URL(string: "https://apps.apple.com/app/relationship/id1665455216")!)
          }
          Divider()
          CellButton(title: "Open Source") {
            navigator.navigate("/settings/openSource")
          }
          Divider()
          #if os(macOS)
            CellButton(title: "Review on App Store") {
              openURL(URL(string: selectedLocale.privacyUrl)!)
            }
          #elseif os(iOS)
            CellButton(title: "Privacy Policy") {
              presentingSafariView = true
            }
            .safariView(isPresented: $presentingSafariView) {
              SafariView(
                url: URL(string: selectedLocale.privacyUrl)!,
                configuration: SafariView.Configuration(
                  entersReaderIfAvailable: false,
                  barCollapsingEnabled: true
                )
              )
              .preferredBarAccentColor(Color.Neumorphic.main)
              .preferredControlAccentColor(Color.Neumorphic.secondary)
              .dismissButtonStyle(.done)
            }
          #endif
          Divider()
          CellButton(title: "Feedback") {
            navigator.navigate("/settings/feedback")
          }
        }.softRectangleStyle()

        VStack(spacing: Constant.padding) {
          CellButton(title: "Language") {
            navigator.navigate("/settings/changeLanguage")
          }
        }
        .softRectangleStyle()

        if isPro == false {
          VStack(alignment: .leading) {
            Text("My more apps:")
              .font(.headline)
            ForEach(allMyApps) { model in

              HStack(alignment: .center, spacing: 6) {
                Image(model.iconName)
                  .resizable()
                  .frame(width: 60, height: 60)
                VStack(alignment: .leading) {
                  Text(model.name.localizedStringKey)
                    .font(.headline)
                  Text(model.des.localizedStringKey)
                    .font(.body)
                }
                Spacer()

                Button(action: {
                  openURL(URL(string: model.link)!)
                }) {
                  Text("Get")
                }
                .softButtonStyle(Capsule(), padding: 12, mainColor: Color.accent, textColor: Color.Neumorphic.main)
              }
            }
          }
          .softRectangleStyle()
        }
      }
      .padding()
      .foregroundColor(Color.Neumorphic.secondary)
      .background(Color.Neumorphic.main)
    }
  }
}

struct SettingsScene_Previews: PreviewProvider {
  static var previews: some View {
    SettingsScene()
  }
}

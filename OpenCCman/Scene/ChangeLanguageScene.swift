import SwiftUI

struct ChangeLanguageScene: View {
  @Environment(\.selectedLocale) private var selectedLocale: Binding<LocaleConstants>
  @State private var showRestartAlert = false

  var body: some View {
    VStack {
      navi
      list
    }
    .alert("restart_app_title", isPresented: $showRestartAlert) {
      Button("Later", role: .cancel) {}
      Button("Restart", role: .destructive) {
        restartApp()
      }
    } message: {
      Text("restart_app_message")
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
          initialContent: selectedLocale.wrappedValue
        ) { item in
          selectLocale(item)
        }
      }
      .padding()
    }
  }

  // MARK: - private methods

  private func selectLocale(_ locale: LocaleConstants) {
    guard locale != selectedLocale.wrappedValue else { return }

    // Update SDK request headers before SwiftUI recreates localized content.
    IAPManager.shared.updatePreferredUILocale(locale)
    selectedLocale.wrappedValue = locale
    // `Bundle.main` caches its localization at launch, so the stored choice only
    // applies in full on the next one; offer the restart instead of forcing it.
    LocaleConstants.syncToUserDefaults(locale)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      showRestartAlert = true
    }
  }

  private func restartApp() {
    exit(0)
  }
}

struct ChangeLanguageScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeLanguageScene()
  }
}

import SwiftUI

#if os(macOS)
  import AppKit
#endif

struct ChangeLanguageScene: View {
  @Environment(\.selectedLocale) private var selectedLocale: Binding<LocaleConstants>
  @State private var showRestartAlert = false

  #if os(macOS)
    private let restartAlertTitle: LocalizedStringKey = "restart_app_title"
  #else
    // iOS has no way to relaunch an app, and quitting with `exit` reads as a
    // crash (Apple Technical Q&A QA1561), so the alert only says what follows.
    private let restartAlertTitle: LocalizedStringKey = "language_changed_title"
  #endif

  var body: some View {
    VStack {
      navi
      list
    }
    .alert(restartAlertTitle, isPresented: $showRestartAlert) {
      #if os(macOS)
        Button("Later", role: .cancel) {}
        Button("Restart", role: .destructive) {
          restartApp()
        }
      #else
        Button("OK", role: .cancel) {}
      #endif
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
    // applies in full on the next one. Say so; on macOS also offer the relaunch.
    LocaleConstants.syncToUserDefaults(locale)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      showRestartAlert = true
    }
  }

  #if os(macOS)
    private func restartApp() {
      // Reopening the app's own bundle is the same public call the app already
      // uses to restore a closed main window, so it stays inside the sandbox.
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.createsNewApplicationInstance = true
      NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
        DispatchQueue.main.async {
          // Leave only once the replacement is running; otherwise stay open and
          // let the stored choice apply on the next launch the user makes.
          if let error {
            NSAlert(error: error).runModal()
            return
          }
          NSApp.terminate(nil)
        }
      }
    }
  #endif
}

struct ChangeLanguageScene_Previews: PreviewProvider {
  static var previews: some View {
    ChangeLanguageScene()
  }
}

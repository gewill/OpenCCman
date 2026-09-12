import Neumorphic
import SwiftUI
import SwiftUIRouter
#if os(macOS)
  import SwiftUIIntrospect
#endif

struct RootView: View {
  @EnvironmentObject private var navigator: Navigator
  @StateObject private var viewModel = HomeViewModel()
  @State private var showAd: Bool = false
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  #if os(macOS)
    @State private var windowID: ObjectIdentifier?
  #endif

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.Neumorphic.main
        .ignoresSafeArea()

      VStack(alignment: .center, spacing: Constant.padding) {
        RootRoutes()
          .environmentObject(viewModel)
      }
    }
    .background(Color.Neumorphic.main)
    .ignoresSafeArea(.keyboard)
    .onChange(of: navigator.path) { newPath in
      print("Current path:", newPath)
    }
    .onDisappear { viewModel.cancelConversion() }
    #if os(macOS)
    .introspect(.window, on: .macOS(.v11, .v12, .v13, .v14, .v15, .v26)) { window in
      windowID = ObjectIdentifier(window)
      viewModel.window = window
      AppDelegate.registerReadyWindow(window)
    }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSettingsFromMenu"))) { notification in
      guard isTargetWindow(for: notification) else { return }
      navigator.navigate("/settings")
    }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenHelpFromMenu"))) { notification in
      guard isTargetWindow(for: notification) else { return }
      navigator.navigate("/help")
    }
    .onReceive(NotificationCenter.default.publisher(for: .textConversionServiceDidReceiveText)) { notification in
      navigateToHome(for: notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .globalShortcutDidConvertText)) { notification in
      navigateToHome(for: notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .textServiceDidReceiveText)) { notification in
      navigateToHome(for: notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .convertTextFromMenu)) { notification in
      navigateToHome(for: notification)
    }
    #endif
  }

  #if os(macOS)
  private func navigateToHome(for notification: Notification) {
    guard isTargetWindow(for: notification), navigator.path != "/home" else { return }
    navigator.navigate("/home")
  }

  private func isTargetWindow(for notification: Notification) -> Bool {
    guard let windowID,
          let targetWindow = notification.object as? NSWindow ?? NSApp.keyWindow else {
      return false
    }
    return ObjectIdentifier(targetWindow) == windowID
  }
  #endif
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    Router {
      RootView()
    }
  }
}

// MARK: - Routes

private struct RootRoutes: View {
  var body: some View {
    SwitchRoutes {
      Route("home") {
        HomeScene()
      }

      Route("help") {
        HelpScene()
      }

      Route("settings/*") {
        SettingsRoutes()
      }

      Route("pro") {
        ProScene()
      }

      Route {
        Navigate(to: "/home", replace: true)
      }
    }
  }
}

struct SettingsRoutes: View {
  var body: some View {
    SwitchRoutes {
      Route("/settings/openSource") {
        OpenSourceScene()
      }

      Route("/settings/changeLanguage") {
        ChangeLanguageScene()
      }

      Route("/settings/changeAppearance") {
        ChangeColorSchemeScene()
      }

      Route("/settings/shortcut") {
        ShortcutSettingsScene()
      }

      Route("/settings") {
        SettingsScene()
      }

      Route("/settings/feedback") {
        FeedbackScene()
      }

      Route {
        SettingsScene()
      }
    }
  }
}

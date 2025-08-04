import Neumorphic
import SwiftUI
import SwiftUIRouter
import Combine

struct RootView: View {
  @EnvironmentObject private var navigator: Navigator
  @State private var showAd: Bool = false
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @State private var cancellables = Set<AnyCancellable>()

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.Neumorphic.main
        .ignoresSafeArea()

      VStack(alignment: .center, spacing: Constant.padding) {
        RootRoutes()
      }
    }
    .background(Color.Neumorphic.main)
    .ignoresSafeArea(.keyboard)
    .onChange(of: navigator.path) { newPath in
      print("Current path:", newPath)
    }
    .onAppear {
      setupMenuBarNotifications()
    }
  }

  private func setupMenuBarNotifications() {
    #if os(macOS)
    // 监听菜单栏设置通知
    NotificationCenter.default.publisher(for: Notification.Name("OpenSettingsFromMenu"))
      .sink { _ in
        navigator.navigate("/settings")
      }
      .store(in: &cancellables)

    // 监听菜单栏帮助通知
    NotificationCenter.default.publisher(for: Notification.Name("OpenHelpFromMenu"))
      .sink { _ in
        navigator.navigate("/help")
      }
      .store(in: &cancellables)
    #endif
  }
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

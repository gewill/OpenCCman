import Neumorphic
import SwiftUI
import SwiftUIRouter

struct RootView: View {
  @EnvironmentObject private var navigator: Navigator
  @StateObject private var viewModel = HomeViewModel()
  @EnvironmentObject private var whatsNew: WhatsNewCoordinator
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  @StateObject private var whatsNewWindow = WhatsNewWindowState()
  @State private var presentationID = UUID()
  @State private var whatsNewRelease: WhatsNewRelease?
  @State private var isVisible = false
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  #if os(macOS)
    @StateObject private var windowSizing = MainWindowSizing()
    @State private var isMainWindow = false
    @State private var windowID: ObjectIdentifier?
  #endif

  var body: some View {
    ZStack(alignment: .bottom) {
      Color.Neumorphic.main
        .ignoresSafeArea()

      VStack(alignment: .center, spacing: Constant.padding) {
        RootRoutes()
          .environmentObject(viewModel)
          .environmentObject(whatsNewWindow)
      }
    }
    .background(Color.Neumorphic.main)
    .neumorphicTheme(.openCCman)
    .onChange(of: navigator.path) { newPath in
      print("Current path:", newPath)
    }
    .sheet(item: $whatsNewRelease, onDismiss: {
      whatsNew.finish(in: presentationID)
    }) { release in
      WhatsNewView(release: release)
        .environment(\.locale, locale)
        .onAppear {
          whatsNew.didAppear(in: presentationID)
          whatsNewWindow.manualRequest = nil
        }
    }
    .onAppear {
      isVisible = true
      presentWhatsNewIfReady()
    }
    .onChange(of: whatsNewEligibility) { eligibility in
      if !eligibility.canPresent, !whatsNew.hasAppeared, whatsNew.owner == presentationID {
        whatsNewRelease = nil
        whatsNew.finish(in: presentationID)
      }
      presentWhatsNewIfReady()
    }
    .onChange(of: whatsNew.owner) { _ in presentWhatsNewIfReady() }
    .onChange(of: whatsNewWindow.manualRequest) { _ in presentWhatsNewIfReady() }
    .onDisappear {
      isVisible = false
      viewModel.cancelConversion()
      whatsNewRelease = nil
      whatsNew.finish(in: presentationID)
    }
    #if os(macOS)
    .frame(minWidth: MainWindowGeometry.minimumContentSize.width,
           minHeight: MainWindowGeometry.minimumContentSize.height)
    .background(MainWindowReader { window in
      windowSizing.attach(to: window)
      windowID = ObjectIdentifier(window)
      isMainWindow = window.isMainWindow
      viewModel.window = window
      AppDelegate.registerReadyWindow(window)
    }.allowsHitTesting(false).accessibilityHidden(true))
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
      guard isTargetWindow(for: notification) else { return }
      viewModel.cancelConversion()
      viewModel.cancelImport()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { notification in
      if isTargetWindow(for: notification) {
        isMainWindow = true
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignMainNotification)) { notification in
      if isTargetWindow(for: notification) {
        isMainWindow = false
      }
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

  private var whatsNewEligibility: WhatsNewEligibility {
    var active = isVisible && scenePhase == .active
    #if os(macOS)
      active = active && isMainWindow
    #endif
    return WhatsNewEligibility(
      isActive: active,
      isHome: navigator.path == "/home",
      isSupportedRoute: navigator.path == "/home" || navigator.path == "/settings",
      isConverting: viewModel.isLoading,
      isImporting: viewModel.isImporting,
      hasFilePanel: whatsNewWindow.showingImporter || whatsNewWindow.showingExporter,
      hasAlert: viewModel.showingProAlert || viewModel.error != nil,
      hasProSheet: whatsNewWindow.proSheetIsActive,
      hasSettingsSheet: whatsNewWindow.conversionSettingsIsActive
    )
  }

  private func presentWhatsNewIfReady() {
    guard whatsNewRelease == nil else { return }
    whatsNewRelease = whatsNew.reserve(
      for: presentationID, eligibility: whatsNewEligibility,
      manually: whatsNewWindow.manualRequest != nil
    )
  }

  #if os(macOS)
    private func navigateToHome(for notification: Notification) {
      guard isTargetWindow(for: notification), navigator.path != "/home" else { return }
      navigator.navigate("/home")
    }

    private func isTargetWindow(for notification: Notification) -> Bool {
      guard let windowID,
            let targetWindow = notification.object as? NSWindow ?? NSApp.keyWindow
      else {
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
        .environmentObject(WhatsNewCoordinator(version: "1.3", skipAutomatic: true))
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
      Route("/settings/customerCenter") {
        CustomerCenterScene()
      }

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

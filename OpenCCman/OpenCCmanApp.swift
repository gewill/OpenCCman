//
//  OpenCCmanApp.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import SwiftUI
import SwiftUIRouter

@main
struct OpenCCmanApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  #endif

  #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  #endif

  #if DEBUG
    @State private var showingSizingGallery = false
  #endif

  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system
  @AppStorage(UserDefaultsKeys.selectedTheme.rawValue) var selectedTheme: Theme = .system
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @AppStorage(UserDefaultsKeys.lastCheckProDate.rawValue) var lastCheckProDate: TimeInterval = Date().yesterday.unixTimestamp

  init() {
    #if os(macOS)
      MainWindowSizing.captureInitialFrames()
    #endif
    IAPManager.shared.configure()
  }

  @StateObject private var whatsNew = WhatsNewCoordinator(
    version: Bundle.main.appVersion,
    skipAutomatic: ProcessInfo.processInfo.arguments.contains("-skip-whats-new")
  )

  var body: some Scene {
    WindowGroup {
      appContent
      .environmentObject(whatsNew)
      .environment(\.locale, Locale(identifier: selectedLocale.identifier))
      .preferredColorScheme(selectedTheme.colorScheme)
    }
    #if os(macOS)
    .windowStyle(.titleBar)
    .commands {
      #if DEBUG
        CommandMenu("Debug") {
          Button("Control sizing gallery") { showingSizingGallery.toggle() }
            .keyboardShortcut("d", modifiers: [.command, .option])
        }
      #endif
      CommandGroup(after: .toolbar) {
        Button("workspace_horizontal") { workspaceCommand("horizontal") }.keyboardShortcut("1", modifiers: [.command, .option])
        Button("workspace_vertical") { workspaceCommand("vertical") }.keyboardShortcut("2", modifiers: [.command, .option])
        Button("workspace_equal") { workspaceCommand("equal") }
        Button("workspace_settings") { workspaceCommand("inspector") }.keyboardShortcut("i", modifiers: [.command, .option])
      }
      CommandGroup(after: .textEditing) {
        Button("Convert".localizedStringKey, systemImage: "arrow.trianglehead.2.counterclockwise") {
          NotificationCenter.default.post(name: Notification.Name("ConvertTextFromMenu"), object: NSApp.keyWindow)
        }
        .keyboardShortcut("t")
      }
    }
    #endif
  }

  @ViewBuilder
  private var appContent: some View {
    #if DEBUG
      if showingSizingGallery || ProcessInfo.processInfo.arguments.contains("-control-sizing-gallery") {
        ControlSizingGallery()
      } else {
        routedApp
      }
    #else
      routedApp
    #endif
  }

  @ViewBuilder
  private var routedApp: some View {
    #if os(macOS)
      WindowContentLifetime { routes }
    #else
      routes
    #endif
  }

  private var routes: some View {
      Router {
        RootView()
          .onAppear {
            checkPro()
          }
      }
  }

  #if os(macOS)
  private func workspaceCommand(_ command: String) {
    NotificationCenter.default.post(name: .workspaceCommand, object: NSApp.keyWindow, userInfo: ["command": command])
  }
  #endif

  // MARK: - private methods

  func checkPro() {
    if Date().yesterday.unixTimestamp >= lastCheckProDate {
      IAPManager.shared.checkProLifetime { isPro in
        guard let isPro else { return }
        self.isPro = isPro
        lastCheckProDate = Date().unixTimestamp
      }
    }
  }
}

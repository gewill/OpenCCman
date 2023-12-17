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

  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @AppStorage(UserDefaultsKeys.lastCheckProDate.rawValue) var lastCheckProDate: TimeInterval = Date().yesterday.unixTimestamp

  init() {
    IAPManager.shared.configure()
  }

  var body: some Scene {
    WindowGroup {
      Router {
        RootView()
          .onAppear {
            checkPro()
          }
      }
      .environment(\.locale, Locale(identifier: selectedLocale.identifier))
    }
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)
    #endif
  }

  // MARK: - private methods

  func checkPro() {
    if Date().yesterday.unixTimestamp >= lastCheckProDate {
      IAPManager.shared.checkProLifetime { isPro in
        self.isPro = isPro
        lastCheckProDate = Date().unixTimestamp
      }
    }
  }
}

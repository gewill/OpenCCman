//
//  OpenCCmanApp.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import SwiftUI

@main
struct OpenCCmanApp: App {
  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system

  init() {
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.locale, Locale(identifier: selectedLocale.identifier))
    }
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)
    #endif
  }
}

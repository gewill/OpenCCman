//
//  OpenCCmanApp.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import SwiftUI

@main
struct OpenCCmanApp: App {
  init() {
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    #if os(macOS)
    .windowStyle(.hiddenTitleBar)
    #endif
  }
}

import SwiftUI

/// Isolated host for Apple's local StoreKit service. No app account or RevenueCat SDK.
@main
struct StoreKitHost: App {
  var body: some Scene {
    WindowGroup { Text("OpenCCman local StoreKit tests").padding() }
  }
}

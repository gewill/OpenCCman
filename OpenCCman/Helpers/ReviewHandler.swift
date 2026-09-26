import Foundation
import StoreKit
import SwiftUI

@MainActor
class ReviewHandler {
  @discardableResult
  static func requestReview() -> Bool {
    // A conversion can finish while an unread What’s New sheet is waiting for
    // the task to end. Skip this request rather than opening StoreKit right
    // after the user dismisses the cards; a later conversion may ask again.
    guard !WhatsNewRelease.hasUnreadContent(for: Bundle.main.appVersion, defaults: .standard) else {
      return false
    }
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
      #if os(iOS)
        let activeScenes = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .filter { $0.activationState == .foregroundActive }
        guard let scene = activeScenes.first(where: { $0.windows.contains(where: \.isKeyWindow) })
          ?? activeScenes.first else { return }
        // A delayed review request must not compete with What’s New or a file/purchase sheet.
        guard scene.windows.first(where: \.isKeyWindow)?.rootViewController?.presentedViewController == nil else { return }
        SKStoreReviewController.requestReview(in: scene)
      #elseif os(macOS)
        guard NSApplication.shared.isActive, let window = NSApp.keyWindow,
              window.attachedSheet == nil, window.sheetParent == nil else { return }
        SKStoreReviewController.requestReview()
      #endif
    }
    return true
  }
}

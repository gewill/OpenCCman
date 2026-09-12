import Foundation
import StoreKit
import SwiftUI

class ReviewHandler {
  static func requestReview() {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
      #if os(iOS)
        let activeScenes = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .filter { $0.activationState == .foregroundActive }
        guard let scene = activeScenes.first(where: { $0.windows.contains(where: \.isKeyWindow) })
          ?? activeScenes.first else { return }
        SKStoreReviewController.requestReview(in: scene)
      #elseif os(macOS)
        guard NSApplication.shared.isActive else { return }
        SKStoreReviewController.requestReview()
      #endif
    }
  }
}

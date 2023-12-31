import Foundation
import StoreKit
import SwiftUI

class ReviewHandler {
  static func requestReview() {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
      SKStoreReviewController.requestReview()
    }
  }
}

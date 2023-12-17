import Foundation
import Glassfy
import SwiftUI

enum FreeFeature: String, CaseIterable, Identifiable {
  case basic = "Basic features"
  case limitedTestNumbers = "Limited number of tests"

  static let maxTestNumber = 12

  var image: Image {
    switch self {
    case .basic: return Image(systemName: "ellipsis.circle")
    case .limitedTestNumbers: return Image(systemName: "12.circle")
    }
  }

  var color: Color { Color.primary }

  var id: FreeFeature { self }
}

enum ProFeature: String, CaseIterable, Identifiable {
  case adFree = "AD free"
  case unlimitedTestNumbers = "Unlimited calculations"

  var image: Image {
    switch self {
    case .adFree: return Image("AdFree")
    case .unlimitedTestNumbers: return Image("infinite")
    }
  }

  var color: Color {
    switch self {
    case .adFree: return Color.primary
    case .unlimitedTestNumbers: return Color.red
    }
  }

  var id: ProFeature { self }
}

final class IAPManager {
  enum Sku: String {
    case ios_openccman_pro_lifetime_3
  }

  enum Permission: String {
    case pro_lifetime
  }

  enum Offering: String {
    case pro_lifetime
  }

  static let shared = IAPManager()

  private init() {}

  func configure() {
    Glassfy.initialize(apiKey: "5c8f0f454192402bb96b6d1b2f841769")
  }

  func checkProLifetime(completion: @escaping (Bool) -> Void) {
    Glassfy.permissions { permissions, error in
      guard let permissions = permissions, error == nil else {
        completion(false)
        return
      }

      if let permission = permissions[Permission.pro_lifetime.rawValue],
         permission.isValid {
        completion(true)
      } else {
        completion(false)
      }
    }
  }

  func purchase(sku: Glassfy.Sku) {
    Glassfy.purchase(sku: sku) { transaction, error in
      guard let t = transaction, error == nil else {
        return
      }
    }
  }

  func getPermissions() {
    Glassfy.permissions { permissions, error in
      guard let permissions = permissions, error == nil else {
        return
      }
    }
  }

  func restorePurchases() {
    Glassfy.restorePurchases { permissions, error in
      guard let permissions = permissions, error == nil else {
        return
      }
    }
  }
}

import Foundation
import RevenueCat
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
    Purchases.configure(withAPIKey: "appl_EJkSanbpeFhoNJsZaUbpIZPduCi")
    Purchases.proxyURL = URL(string: "https://api.rc-backup.com/")!
  }

  func checkProLifetime(completion: @escaping (Bool) -> Void) {
    Purchases.shared.getCustomerInfo { customerInfo, _ in
      if let infos = customerInfo?.entitlements.active,
         let _ = infos[IAPManager.Permission.pro_lifetime.rawValue] {
        completion(true)
      } else {
        completion(false)
      }
    }
    Purchases.shared.restorePurchases()
  }
}

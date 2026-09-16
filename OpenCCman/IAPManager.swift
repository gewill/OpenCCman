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

final class IAPManager: NSObject, PurchasesDelegate {
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

  private override init() {
    super.init()
  }

  func configure() {
    guard Purchases.isConfigured == false else { return }

    let locale = LocaleConstants(
      rawValue: UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedLocale.rawValue) ?? ""
    ) ?? .system
    Purchases.proxyURL = URL(string: "https://api.rc-backup.com/")!
    Purchases.configure(with: Configuration.Builder(withAPIKey: "appl_EJkSanbpeFhoNJsZaUbpIZPduCi")
      .with(preferredUILocaleOverride: locale.identifier)
      .build())
    Purchases.shared.delegate = self
  }

  func updatePreferredUILocale(_ locale: LocaleConstants) {
    guard Purchases.isConfigured else { return }
    // Use the same effective language as the app, including its system fallback.
    Purchases.shared.overridePreferredUILocale(locale.identifier)
  }

  func checkProLifetime(completion: @escaping (Bool?) -> Void) {
    Purchases.shared.getCustomerInfo { customerInfo, _ in
      completion(customerInfo.map { $0.entitlements.active[Permission.pro_lifetime.rawValue] != nil })
    }
  }

  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    applyCustomerInfo(customerInfo)
  }

  static func isCancellation(_ error: Error?) -> Bool {
    guard let error = error as NSError? else { return false }
    return error.domain == ErrorCode.errorDomain && error.code == ErrorCode.purchaseCancelledError.rawValue
  }

  func refreshAccess() {
    Purchases.shared.getCustomerInfo { [weak self] info, error in
      self?.applyCustomerInfo(info, error: error)
    }
  }

  func applyCustomerInfo(_ info: CustomerInfo?, error: Error? = nil, cancelled: Bool = false) {
    let update = ProAccessUpdate(
      activeEntitlement: info.map { $0.entitlements.active[Permission.pro_lifetime.rawValue] != nil },
      failed: error != nil, cancelled: cancelled || Self.isCancellation(error)
    )
    let apply = {
      let defaults = UserDefaults.standard
      let key = UserDefaultsKeys.isPro.rawValue
      defaults.set(update.applying(to: defaults.bool(forKey: key)), forKey: key)
    }
    if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
  }
}

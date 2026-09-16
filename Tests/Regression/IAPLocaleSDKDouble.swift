// Compiled as a private RevenueCat module by check-iap-locale.py, never into the app.
// Records the public SDK boundary only; it does not simulate networking or UI.
import Foundation

public protocol PurchasesDelegate: AnyObject {
  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo)
}

public enum ErrorCode: Int {
  case purchaseCancelledError = 1
  public static let errorDomain = "RevenueCat.ErrorCode"
}

public struct EntitlementInfo {}
public struct EntitlementInfos { public let active: [String: EntitlementInfo] }
public struct CustomerInfo { public let entitlements: EntitlementInfos }

public struct Configuration {
  public let locale: String?
  public final class Builder {
    private var locale: String?
    public init(withAPIKey: String) {}
    public func with(preferredUILocaleOverride locale: String?) -> Builder {
      self.locale = locale
      return self
    }
    public func build() -> Configuration { Configuration(locale: locale) }
  }
}

public final class Purchases {
  public static var isConfigured = false
  public static var proxyURL: URL?
  public static var configureCount = 0
  public static var initialLocale: String?
  public static var proxyAtConfiguration: URL?
  public static var localeCalls: [String?] = []
  public static var customerInfoCalls = 0
  private static let instance = Purchases()
  public static var shared: Purchases {
    precondition(isConfigured, "Accessing Purchases.shared before configuration")
    return instance
  }
  public weak var delegate: PurchasesDelegate?

  public static func configure(with configuration: Configuration) {
    configureCount += 1
    initialLocale = configuration.locale
    proxyAtConfiguration = proxyURL
    isConfigured = true
  }

  // Allows the unchanged baseline's older configure entry to compile for a negative check.
  public static func configure(withAPIKey: String) {
    configure(with: Configuration(locale: nil))
  }

  public func overridePreferredUILocale(_ locale: String?) { Self.localeCalls.append(locale) }
  public func getCustomerInfo(completion: @escaping (CustomerInfo?, Error?) -> Void) {
    Self.customerInfoCalls += 1
    completion(nil, nil)
  }

  public static func resetForCheck() {
    isConfigured = false
    proxyURL = nil
    configureCount = 0
    initialLocale = nil
    proxyAtConfiguration = nil
    localeCalls = []
    customerInfoCalls = 0
    instance.delegate = nil
  }
}

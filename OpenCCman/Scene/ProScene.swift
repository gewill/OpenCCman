import Neumorphic
import RevenueCat
import StoreKit
import SwiftUI
import os

struct ProScene: View {
  @Environment(\.sizeCategory) private var sizeCategory
  @State var packages: [RevenueCat.Package] = []
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @State var isLoading: Bool = false
  @State var errorMessage: String = ""
  @State private var errorMessageID = UUID()
  var isPresented: Bool = false

  // MARK: - life cycle

  var body: some View {
    VStack {
      self.navi
      self.list
    }
    .appFont(.body)
  }

  var navi: some View {
    Group {
      if sizeCategory.isAccessibilityCategory {
        VStack(spacing: Constant.padding) {
          navigationActions
          Text("Pro").appFont(.title)
            .frame(maxWidth: .infinity)
        }
      } else {
        ZStack(alignment: .center) {
          Text("Pro").appFont(.title)
          navigationActions
        }
      }
    }
    .padding(.vertical, Constant.padding)
  }

  private var navigationActions: some View {
    HStack {
      BackButton(isPresented: isPresented)
        .accessibilityIdentifier("pro-sheet-close")
      Spacer()

      Button {
        self.isLoading = true
        self.errorMessage = ""
        Purchases.shared.restorePurchases { customerInfo, error in
          self.isLoading = false
          self.showError(message: IAPManager.isCancellation(error) ? nil : error?.localizedDescription)
          IAPManager.shared.applyCustomerInfo(customerInfo, error: error)
        }
      } label: {
        Text("Restore")
      }
      .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
      .disabled(self.isLoading)
    }
    .padding(.horizontal, Constant.padding)
  }

  var list: some View {
    ZStack(alignment: .center) {
      ScrollView {
        if self.errorMessage.isEmpty == false {
          Text(self.errorMessage).foregroundColor(.pink)
        }

        if self.isPro {
          proView
        } else {
          skuView
        }

        featuresView
      }
      .padding()
      if self.isLoading {
        LoadingView(width: 30)
      }
    }
    .onAppear {
      self.updateOfferingsAndPermissions()
    }
  }

  var featuresView: some View {
    Group {
      VStack(alignment: .leading, spacing: Constant.padding) {
        Text("Premium features: ")
          .appFont(.headline)
        ForEach(ProFeature.allCases) { feature in
          Divider()
          HStack {
            feature.image
              .resizable()
              .renderingMode(.template)
              .foregroundColor(feature.color)
              .frame(width: 30, height: 30)
            Text(feature.rawValue.localizedStringKey)
          }
        }
      }
      VStack(alignment: .leading, spacing: Constant.padding) {
        Text("Free features: ")
          .appFont(.headline)
        ForEach(FreeFeature.allCases) { feature in
          Divider()
          HStack {
            feature.image
              .resizable()
              .renderingMode(.template)
              .foregroundColor(feature.color)
              .frame(width: 30, height: 30)
            if feature == .limitedTestNumbers {
              Text("Calculate \(FreeFeature.maxTestNumber) times per day")
            } else {
              Text(feature.rawValue.localizedStringKey)
            }
          }
        }
      }
    }
    .foregroundColor(.primary)
    .frame(maxWidth: Constant.maxiPhoneScreenWidth, alignment: .leading)
    .padding(Constant.padding * 2)
    .background(
      RoundedRectangle(cornerRadius: Constant.cornerRadius, style: .continuous)
        .stroke(Color("separator"), lineWidth: 0.5)
    )
  }

  var proView: some View {
    CardReflectionView {
      VStack(spacing: 20) {
        Text("pro_lifetime")
          .appFont(.title)
        Text("Thanks for your support!")
      }
      .foregroundColor(.yellow)
    }
  }

  var skuView: some View {
    ForEach(packages) { package in
      VStack(spacing: 20) {
        CardReflectionView {
          VStack(spacing: 10) {
            Text(package.storeProduct.localizedTitle)
              .appFont(.title)
            Text(package.storeProduct.localizedDescription)
              .appFont(.headline)
            Text(package.localizedPriceString)
              .appFont(.title)
          }
          .foregroundColor(.white)
        }

        Button {
          self.isLoading = true
          self.errorMessage = ""
          Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
            self.isLoading = false
            let update = ProAccessUpdate(activeEntitlement: nil, failed: error != nil, cancelled: userCancelled)
            self.showError(message: update.shouldShowError ? error?.localizedDescription : nil)
            IAPManager.shared.applyCustomerInfo(customerInfo, error: error, cancelled: userCancelled)
          }
        } label: {
          Text("Buy Now")
            .appFont(.headline)
        }
        .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 30), role: .accent)
        .disabled(self.isLoading)
        .padding(.bottom, 10)
      }
    }
  }

  // MARK: -

  func updateOfferingsAndPermissions() {
    guard isLoading == false else { return }

    isLoading = true
    errorMessage = ""
    let group = DispatchGroup()
    group.enter()
    Purchases.shared.getOfferings { offerings, error in
      self.showError(message: IAPManager.isCancellation(error) ? nil : error?.localizedDescription)
      self.setOfferings(offerings)
      group.leave()
    }
    group.enter()
    Purchases.shared.getCustomerInfo { customerInfo, error in
      self.showError(message: IAPManager.isCancellation(error) ? nil : error?.localizedDescription)
      IAPManager.shared.applyCustomerInfo(customerInfo, error: error)
      group.leave()
    }
    group.notify(queue: .main) {
      self.isLoading = false
    }
  }

  func updateOfferings() {
    isLoading = true
    Purchases.shared.getOfferings { offerings, error in
      self.showError(message: IAPManager.isCancellation(error) ? nil : error?.localizedDescription)
      self.isLoading = false
      self.setOfferings(offerings)
    }
  }

  func updatePermissions() {
    Purchases.shared.getCustomerInfo { customerInfo, error in
      IAPManager.shared.applyCustomerInfo(customerInfo, error: error)
    }
  }

  func setOfferings(_ offerings: RevenueCat.Offerings?) {
    guard let offerings else {
      PriceSourceDiagnostics.record(packages)
      return
    }
    let offering = offerings.current ?? offerings.all[IAPManager.Offering.pro_lifetime.rawValue]
    let availablePackages = offering?.availablePackages ?? []
    self.packages = availablePackages
    PriceSourceDiagnostics.record(availablePackages)
  }

  func showError(message: String?) {
    if let message, message.isEmpty == false {
      let messageID = UUID()
      errorMessageID = messageID
      errorMessage = message
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        guard self.errorMessageID == messageID else { return }
        self.errorMessage = ""
      }
    }
  }
}

/// Opt-in metadata comparison for #212. It never reads an account, receipt,
/// transaction or entitlement, and it does not affect the price shown to users.
private enum PriceSourceDiagnostics {
  private struct RevenueCatPrice: Sendable {
    let productID: String
    let displayPrice: String
    let currencyCode: String?
  }

  static func record(_ packages: [RevenueCat.Package]) {
    guard ProcessInfo.processInfo.arguments.contains("-qa-price-source-diagnostics") else { return }
    let revenueCatPrices = packages.map {
      RevenueCatPrice(productID: $0.storeProduct.productIdentifier,
                      displayPrice: $0.localizedPriceString,
                      currencyCode: $0.storeProduct.currencyCode)
    }
    Task {
      let storefront = await Storefront.current
      let storefrontCurrency: String
      if #available(iOS 17.0, macOS 14.0, *) {
        storefrontCurrency = storefront?.currency?.identifier ?? "nil"
      } else {
        storefrontCurrency = "unavailable"
      }
      let productID = IAPManager.Sku.ios_openccman_pro_lifetime_3.rawValue
      let revenueCat = revenueCatPrices.first { $0.productID == productID }
      let prefix = [
        "PRICE_SOURCE",
        "storefront=\(storefront?.countryCode ?? "nil")",
        "storefrontCurrency=\(storefrontCurrency)",
        "product=\(productID)",
        "revenueCatPriceAtOffering=\(revenueCat?.displayPrice ?? "nil")",
        "revenueCatCurrency=\(revenueCat?.currencyCode ?? "nil")",
      ]
      do {
        let native = try await Product.products(for: [productID]).first { $0.id == productID }
        let line = (prefix + [
          "nativePriceAtFetch=\(native?.displayPrice ?? "nil")",
          "nativeCurrency=\(native?.priceFormatStyle.currencyCode ?? "nil")",
        ]).joined(separator: " ")
        Logger(subsystem: "OpenCCman", category: "PriceSource")
          .notice("\(line, privacy: .public)")
        print(line)
      } catch {
        let line = (prefix + ["nativeProductError=\(type(of: error))"]).joined(separator: " ")
        Logger(subsystem: "OpenCCman", category: "PriceSource")
          .error("\(line, privacy: .public)")
        print(line)
      }
    }
  }
}

struct ProScene_Previews: PreviewProvider {
  static var previews: some View {
    ProScene()
  }
}

import Neumorphic
import RevenueCat
import SwiftUI

struct ProScene: View {
  @State var packages: [RevenueCat.Package] = []
  @State var entitlementInfos: [String: RevenueCat.EntitlementInfo] = [:]
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
    .font(.body)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Pro").font(.title)
      HStack {
        BackButton(isPresented: isPresented)
        Spacer()

        Button {
          self.isLoading = true
          self.errorMessage = ""
          Purchases.shared.restorePurchases { customerInfo, error in
            self.isLoading = false
            self.showError(message: error?.localizedDescription)
            self.setEntitlementInfos(customerInfo?.entitlements.all)
          }
        } label: {
          Text("Restore")
        }
        .softButtonStyle(RoundedRectangle(cornerRadius: 12), padding: 12)
        .disabled(self.isLoading)
      }
      .padding(.horizontal, Constant.padding)
    }
    .padding(.vertical, Constant.padding)
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
          .font(.headline)
        ForEach(ProFeature.allCases) { feature in
          Divider()
          HStack {
            feature.image
              .resizable()
              .foregroundColor(feature.color)
              .frame(width: 30, height: 30)
            Text(feature.rawValue.localizedStringKey)
          }
        }
      }
      VStack(alignment: .leading, spacing: Constant.padding) {
        Text("Free features: ")
          .font(.headline)
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
    .frame(minWidth: 300, maxWidth: Constant.maxiPhoneScreenWidth)
    .padding(Constant.padding * 2)
    .background(
      RoundedRectangle(cornerRadius: Constant.cornerRadius, style: .continuous)
        .stroke(Color.separator, lineWidth: 0.5)
    )
  }

  var proView: some View {
    CardReflectionView {
      VStack(spacing: 20) {
        Text("pro_lifetime")
          .font(.title)
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
              .font(.title)
            Text(package.storeProduct.localizedDescription)
              .font(.headline)
            Text(package.localizedPriceString)
              .font(.title)
          }
          .foregroundColor(.white)
        }

        Button {
          self.isLoading = true
          self.errorMessage = ""
          Purchases.shared.purchase(package: package) { _, customerInfo, error, userCancelled in
            self.isLoading = false
            guard userCancelled == false else { return }
            self.showError(message: error?.localizedDescription)
            self.setEntitlementInfos(customerInfo?.entitlements.all)
          }
        } label: {
          Text("Buy Now")
            .font(.title)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .softButtonStyle(RoundedRectangle(cornerRadius: 30), padding: 6, mainColor: Color.accent, textColor: Color.Neumorphic.main)
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
      self.showError(message: error?.localizedDescription)
      self.setOfferings(offerings)
      group.leave()
    }
    group.enter()
    Purchases.shared.getCustomerInfo { customerInfo, error in
      self.showError(message: error?.localizedDescription)
      self.setEntitlementInfos(customerInfo?.entitlements.all)
      group.leave()
    }
    group.notify(queue: .main) {
      self.isLoading = false
    }
  }

  func updateOfferings() {
    isLoading = true
    Purchases.shared.getOfferings { offerings, error in
      self.showError(message: error?.localizedDescription)
      self.isLoading = false
      self.setOfferings(offerings)
    }
  }

  func updatePermissions() {
    Purchases.shared.getCustomerInfo { customerInfo, _ in
      self.setEntitlementInfos(customerInfo?.entitlements.all)
    }
  }

  func setEntitlementInfos(_ entitlementInfos: [String: RevenueCat.EntitlementInfo]?) {
    // A failed request is not evidence that the customer lost their entitlement.
    guard let entitlementInfos else { return }

    if let pro = entitlementInfos[IAPManager.Permission.pro_lifetime.rawValue],
       pro.isActive
    {
      isPro = true
    } else {
      isPro = false
    }

    self.entitlementInfos = entitlementInfos
  }

  func setOfferings(_ offerings: RevenueCat.Offerings?) {
    guard let offerings else { return }
    let offering = offerings.current ?? offerings.all[IAPManager.Offering.pro_lifetime.rawValue]
    self.packages = offering?.availablePackages ?? []
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

struct ProScene_Previews: PreviewProvider {
  static var previews: some View {
    ProScene()
  }
}

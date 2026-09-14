import Neumorphic
import RevenueCat
import SwiftUI
import SwiftUIRouter
#if os(iOS)
import RevenueCatUI
#endif

/// A route keeps presentation local to its window and defers What's New until return.
struct CustomerCenterScene: View {
  @EnvironmentObject private var navigator: Navigator

  var body: some View {
    Group {
      #if os(iOS)
      if #available(iOS 15.0, *) {
        CustomerCenterView(navigationOptions: .init(onCloseHandler: {
          navigator.goBack()
        }))
        .onCustomerCenterRestoreCompleted { info in
          IAPManager.shared.applyCustomerInfo(info)
        }
        .onDisappear { IAPManager.shared.refreshAccess() }
      } else {
        PurchaseSupportView()
      }
      #else
      PurchaseSupportView()
      #endif
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Native macOS and iOS 14 fallback: the official Customer Center is unavailable there.
private struct PurchaseSupportView: View {
  @EnvironmentObject private var navigator: Navigator
  @AppStorage(UserDefaultsKeys.isPro.rawValue) private var isPro = false
  @State private var isLoading = false
  @State private var messageKey: String?
  @State private var requestID = UUID()

  var body: some View {
    VStack(spacing: Constant.padding) {
      HStack {
        BackButton()
        Text("customer_center_title").font(.title2).bold()
        Spacer(minLength: 0)
      }
      .padding(Constant.padding)

      ScrollView {
        VStack(alignment: .leading, spacing: Constant.padding) {
          Text(isPro ? "pro_lifetime" : "Basic features").font(.headline)
            .accessibilityIdentifier("customer-center-access")
          Text("customer_center_lifetime_hint").foregroundColor(.secondary)
          if let messageKey {
            Text(messageKey.localizedStringKey)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityIdentifier("customer-center-message")
          }
          if isLoading { ProgressView().accessibilityLabel(Text("customer_center_loading")) }
          Button("Restore") { load(restoring: true) }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
            .disabled(isLoading)
            .accessibilityIdentifier("customer-center-restore")
          Button("customer_center_refresh") { load(restoring: false) }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
            .disabled(isLoading)
          Button("Feedback") { navigator.navigate("/settings/feedback") }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constant.padding)
      }
    }
    .background(Color.Neumorphic.main)
    .onAppear { load(restoring: false) }
    .onDisappear {
      requestID = UUID()
      isLoading = false
    }
  }

  private func load(restoring: Bool) {
    guard !isLoading else { return }
    let id = UUID()
    requestID = id
    isLoading = true
    messageKey = nil
    let completion: (CustomerInfo?, Error?) -> Void = { info, error in
      IAPManager.shared.applyCustomerInfo(info, error: error)
      DispatchQueue.main.async {
        guard requestID == id else { return }
        isLoading = false
        if error != nil, !IAPManager.isCancellation(error) {
          messageKey = "customer_center_unavailable"
        } else if error == nil, let info {
          if restoring {
            messageKey = info.entitlements.active[IAPManager.Permission.pro_lifetime.rawValue] != nil
              ? "customer_center_restored" : "customer_center_no_purchases"
          }
        } else if error == nil {
          messageKey = "customer_center_unavailable"
        }
      }
    }
    if restoring {
      // Store authentication may be prompted only after this explicit user action.
      Purchases.shared.restorePurchases(completion: completion)
    } else {
      Purchases.shared.getCustomerInfo(completion: completion)
    }
  }
}

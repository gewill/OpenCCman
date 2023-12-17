import Glassfy
import Neumorphic
import SwiftUI

struct ProScene: View {
  @State var skus: [Glassfy.Sku] = []
  @State var permissions: [Glassfy.Permission] = []
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  @State var isLoading: Bool = false
  @State var errorMessage: String = ""
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
          Glassfy.restorePurchases { permissions, error in
            self.showError(message: error?.localizedDescription)
            self.setPermissions(permissions?.all)
            self.isLoading = false
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
    ForEach(skus, id: \.skuId) { sku in
      VStack(spacing: 20) {
        CardReflectionView {
          VStack(spacing: 10) {
            Text(sku.product.localizedTitle)
              .font(.title)
            Text(sku.product.localizedDescription)
              .font(.headline)
            Text(sku.product.localizedPrice)
              .font(.title)
          }
          .foregroundColor(.white)
        }

        Button {
          self.isLoading = true
          Glassfy.purchase(sku: sku) { transaction, error in
            self.showError(message: error?.localizedDescription)
            self.isLoading = false
            guard let t = transaction, error == nil else {
              return
            }
            self.setPermissions(t.permissions.all)
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
    guard isPro == false else { return }

    isLoading = true
    let group = DispatchGroup()
    group.enter()
    Glassfy.offerings { offers, error in
      self.showError(message: error?.localizedDescription)
      group.leave()
      self.skus = offers?.all.flatMap { $0.skus } ?? []
    }
    group.enter()
    Glassfy.permissions { permissions, error in
      self.showError(message: error?.localizedDescription)
      group.leave()
      self.setPermissions(permissions?.all)
    }
    group.notify(queue: .main) {
      self.isLoading = false
    }
  }

  func updateOfferings() {
    isLoading = true
    Glassfy.offerings { offers, error in
      self.showError(message: error?.localizedDescription)
      self.isLoading = false
      self.skus = offers?.all.flatMap { $0.skus } ?? []
    }
  }

  func updatePermissions() {
    Glassfy.permissions { permissions, error in
      self.showError(message: error?.localizedDescription)
      self.setPermissions(permissions?.all)
    }
  }

  func setPermissions(_ permissions: [Glassfy.Permission]?) {
    if let permissions,
       permissions.contains(where: { $0.isValid && $0.permissionId == IAPManager.Permission.pro_lifetime.rawValue })
    {
      isPro = true
    } else {
      isPro = false
    }

    self.permissions = permissions ?? []
  }

  func showError(message: String?) {
    if let message, message.isEmpty == false {
      errorMessage = message
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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

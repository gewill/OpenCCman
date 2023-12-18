import AdSupport
import AppTrackingTransparency
import SwiftUI
import SwiftUIRouter

struct MyAppView: View {
  @EnvironmentObject var navigator: Navigator
  @Environment(\.openURL) var openURL

  @State var index = 0
  let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
  var model: MyAppModel? {
    allMyApps[index]
  }

  // MARK: - life cycle

  var body: some View {
    if let model {
      ZStack(alignment: .topLeading) {
        HStack(alignment: .center, spacing: 6) {
          Image(model.iconName)
            .resizable()
            .frame(width: 30, height: 30)
          VStack(alignment: .leading) {
            Text(model.name.localizedStringKey)
              .font(.headline)
            Text(model.des.localizedStringKey)
              .font(.body)
          }
          Spacer()

          Button(action: {
            openURL(URL(string: model.link)!)
          }) {
            Text("Get")
          }
          .softButtonStyle(Capsule(), padding: 10, mainColor: Color.accent, textColor: Color.Neumorphic.main)
        }
        .softRectangleStyle()
        .frame(width: 300)
        .onReceive(timer) { _ in
          index = (index + 1) % allMyApps.count
        }

        Button {
          navigator.navigate("/pro")
        } label: {
          Image(systemName: "xmark.circle")
            .foregroundColor(Color.gray)
            .font(.system(size: 30))
        }
        .offset(x: -10, y: -10)
        .buttonStyle(.plain)
      }
      .onAppear { requestTrack() }
    }
  }

  // MARK: - private methods

  func requestTrack() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      print(Thread.isMainThread)
      ATTrackingManager.requestTrackingAuthorization { status in
        print("ATTrackingManager.AuthorizationStatus: ", status.rawValue.description,
              ASIdentifierManager.shared().advertisingIdentifier.uuidString)
      }
    }
  }
}

struct MyAppView_Previews: PreviewProvider {
  static var previews: some View {
    MyAppView()
  }
}

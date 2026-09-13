import SwiftUI
import SwiftUIRouter

struct MyAppView: View {
  @EnvironmentObject private var navigator: Navigator
  @Environment(\.openURL) private var openURL
  @Environment(\.sizeCategory) private var sizeCategory
  @State private var index = 0
  private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

  var body: some View {
    let model = allMyApps[index]
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        Image(model.iconName).resizable().frame(width: 32, height: 32)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(model.name.localizedStringKey).font(.headline)
          Text(model.des.localizedStringKey).font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      if sizeCategory.isAccessibilityCategory {
        VStack(alignment: .leading, spacing: 8) { actions(link: model.link) }
      } else {
        HStack(spacing: 16) { actions(link: model.link) }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .softRectangleStyle()
    .onReceive(timer) { _ in index = (index + 1) % allMyApps.count }
  }

  @ViewBuilder
  private func actions(link: String) -> some View {
    Button { if let url = URL(string: link) { openURL(url) } } label: {
      Text("Get")
    }.appNeumorphicButtonStyle(Capsule())
    Button { navigator.navigate("/pro") } label: {
      Text("workspace_remove_recommendation")
    }.appNeumorphicButtonStyle(Capsule())
  }
}

import Neumorphic
import SwiftUI

struct LoadingView: View {
  let width: CGFloat
  var label: LocalizedStringKey = "In progress"

  var body: some View {
    NeumorphicCircularProgressView(value: nil, diameter: max(24, width))
      .accessibilityLabel(Text(label))
  }
}

struct LoadingView_Previews: PreviewProvider {
  static var previews: some View {
    LoadingView(width: 30)
  }
}

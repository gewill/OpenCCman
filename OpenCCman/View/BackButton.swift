import Neumorphic
import SwiftUI
import SwiftUIRouter

struct BackButton: View {
  @EnvironmentObject private var navigator: Navigator
  @Environment(\.presentationMode) private var presentationMode
  var isPresented: Bool = false

  var body: some View {
    Button {
      if isPresented,
         presentationMode.wrappedValue.isPresented {
        presentationMode.wrappedValue.dismiss()
      } else {
        navigator.goBack()
      }
    } label: {
      Image(systemName: "chevron.backward")
    }
    .fixedSizeSoftButtonStyle(Circle(), size: Constant.smallButtonSize)
  }
}

struct BackButton_Previews: PreviewProvider {
  static var previews: some View {
    BackButton()
  }
}

import SwiftUI

struct ProAlertView: View {
  @Environment(\.locale) private var locale
  @Binding var showingProAlert: Bool
  @Binding var showingProScene: Bool
  var onProDismiss: () -> Void = {}

  var body: some View {
    EmptyView()
      .alertView(title: "Pro only feature", subtitle: ProFeature.unlimitedTestNumbers.rawValue.localizedStringKey, isPresented: $showingProAlert) {
        HStack(spacing: 10) {
          Button {
            showingProScene = true
            showingProAlert = false
          } label: {
            Text("Pro")
              .frame(minWidth: 100)
          }
          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 20), role: .accent)

          Button {
            showingProAlert.toggle()
          } label: {
            Text("Cancel")
              .frame(minWidth: 100)
          }
          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 20), role: .accent)
        }
      }
      .sheet(isPresented: $showingProScene, onDismiss: onProDismiss) {
        ProScene(isPresented: true)
          .environment(\.locale, locale)
      }
      .font(.body)
  }
}

struct ProOverlayView_Previews: PreviewProvider {
  static var previews: some View {
    ProAlertView(showingProAlert: .constant(true), showingProScene: .constant(false))
  }
}

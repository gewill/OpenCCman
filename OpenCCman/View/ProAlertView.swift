import SwiftUI

struct ProAlertView: View {
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
              .frame(width: 120, height: 44)
          }
          .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 0, mainColor: Color.accent, textColor: Color.Neumorphic.main)

          Button {
            showingProAlert.toggle()
          } label: {
            Text("Cancel")
              .frame(width: 120, height: 44)
          }
          .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 0, mainColor: Color.accent, textColor: Color.Neumorphic.main)
        }
      }
      .sheet(isPresented: $showingProScene, onDismiss: onProDismiss) {
        ProScene(isPresented: true)
      }
      .font(.body)
  }
}

struct ProOverlayView_Previews: PreviewProvider {
  static var previews: some View {
    ProAlertView(showingProAlert: .constant(true), showingProScene: .constant(false))
  }
}

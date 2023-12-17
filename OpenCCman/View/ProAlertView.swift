import SwiftUI

struct ProAlertView: View {
  @Binding var showingProAlert: Bool
  @State private var showingProScene = false

  var body: some View {
    EmptyView()
      .alertView(title: "Pro only feature", subtitle: ProFeature.unlimitedTestNumbers.rawValue.localizedStringKey, isPresented: $showingProAlert) {
        HStack(spacing: 10) {
          Button {
            showingProAlert.toggle()
            showingProScene.toggle()
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
      .sheet(isPresented: $showingProScene) {
        ProScene()
      }
      .font(.body)
  }
}

struct ProOverlayView_Previews: PreviewProvider {
  static var previews: some View {
    ProAlertView(showingProAlert: .constant(true))
  }
}

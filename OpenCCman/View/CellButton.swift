import SwiftUI

struct CellButton: View {
  let title: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: {
      action()
    }) {
      HStack(alignment: .center, spacing: 6) {
        Text(title)
        Spacer()
        Image(systemName: "chevron.right")
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct CelllView_Previews: PreviewProvider {
  static var previews: some View {
    CellButton(title: "Button", action: {
      print("pressed")
    })
  }
}

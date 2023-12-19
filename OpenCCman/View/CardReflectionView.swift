import ColorfulX
import SwiftUI

struct CardReflectionView<Content: View>: View {
  @State var translation: CGSize = .zero
  @State var isDragging = false
  @State var colors: [Color] = ColorfulPreset.neon.colors
  let content: Content

  // MARK: - life cycle

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content()
  }

  var drag: some Gesture {
    DragGesture()
      .onChanged { value in
        translation = value.translation
        isDragging = true
      }
      .onEnded { _ in
        withAnimation {
          translation = .zero
          isDragging = false
        }
      }
  }

  var body: some View {
    ZStack {
      ColorfulView(color: $colors)
        .frame(height: 200)
        .frame(maxWidth: Constant.maxiPhoneScreenWidth)
        .overlay(
          ZStack {
            content
          }
        )
        .cornerRadius(20)
        .scaleEffect(0.9)
        .rotation3DEffect(.degrees(isDragging ? 10 : 0), axis: (x: -translation.height, y: translation.width, z: 0))
        .gesture(drag)
    }
  }
}

struct CardReflectionView_Previews: PreviewProvider {
  static var previews: some View {
    CardReflectionView(content: {
      Text("Logo")
        .font(.title)
        .foregroundColor(.white)
    })
    .padding()
  }
}

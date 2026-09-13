import Neumorphic
import SwiftUI

struct SoftRectangleStyle: ViewModifier {
  var cornerRadius: CGFloat
  var padding: CGFloat?
  func body(content: Content) -> some View {
    content
      .padding(.all, padding)
      .neumorphicCard(RoundedRectangle(cornerRadius: cornerRadius), padding: 0)
  }
}

extension View {
  func softRectangleStyle(cornerRadius: CGFloat = 20, padding: CGFloat? = nil) -> some View {
    modifier(SoftRectangleStyle(cornerRadius: cornerRadius, padding: padding))
  }
}

extension View {
  @ViewBuilder
  func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content?) -> some View {
    if let view = transform(self), !(view is EmptyView) {
      view
    } else {
      self
    }
  }
}

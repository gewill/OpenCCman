import Neumorphic
import SwiftUI

struct SoftRectangleStyle: ViewModifier {
  var cornerRadius: CGFloat
  var padding: CGFloat?
  func body(content: Content) -> some View {
    if let padding {
      content
        .padding(padding)
        .background(
          RoundedRectangle(cornerRadius: cornerRadius).fill(Color.main).softOuterShadow()
        )
    } else {
      content
        .padding()
        .background(
          RoundedRectangle(cornerRadius: cornerRadius).fill(Color.main).softOuterShadow()
        )
    }
  }
}

extension View {
  func softRectangleStyle(cornerRadius: CGFloat = 20, padding: CGFloat? = nil) -> some View {
    modifier(SoftRectangleStyle(cornerRadius: cornerRadius, padding: padding))
  }
}

struct SmallButtonStyle: ViewModifier {
  var size: CGSize
  var cornerRadius: CGFloat
  func body(content: Content) -> some View {
    content
      .foregroundColor(Color.secondary)
      .frame(width: size.width, height: size.height)
      .background(
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(Color.accentColor)
          .softOuterShadow()
      )
  }
}

extension View {
  func smallButtonStyle(size: CGSize = CGSize(width: 40, height: 40), cornerRadius: CGFloat = 20) -> some View {
    modifier(SmallButtonStyle(size: size, cornerRadius: cornerRadius))
  }
}

struct MacButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .foregroundColor(Color.secondary)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.accentColor)
          .softOuterShadow()
      )
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

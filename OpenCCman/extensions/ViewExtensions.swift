import SwiftUI
import SwiftUIIntrospect

extension View {
  func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
  }
}

struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

extension View {
  func hideNavigationBar(_ hidden: Bool) -> some View {
    #if os(iOS)
      navigationBarHidden(hidden)
    #else
      self
    #endif
  }

  func navigationViewStyle() -> some View {
    #if os(iOS)
      navigationViewStyle(StackNavigationViewStyle())
    #else
      navigationViewStyle(DefaultNavigationViewStyle.automatic)
    #endif
  }
}

extension View {
  func textSelectable() -> some View {
    modify {
      if #available(macOS 12.0, iOS 15.0, *) {
        $0.textSelection(.enabled)
      }
    }
  }

  func clearTextEdtorStyle() -> some View {
    #if os(macOS)
      introspect(.textEditor, on: .macOS(.v11, .v12, .v13, .v14)) { textEditor in
        textEditor.textContainerInset = .zero
        textEditor.textContainer?.lineFragmentPadding = 0
        textEditor.backgroundColor = .clear
      }
    #else
      introspect(.textEditor, on: .iOS(.v14, .v15, .v16, .v17)) { textEditor in
        textEditor.textContainerInset = .zero
        textEditor.textContainer.lineFragmentPadding = 0
        textEditor.backgroundColor = .clear
      }
    #endif
  }
}

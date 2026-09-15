import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

#if os(macOS)
  /// Introspect 26 deliberately skips later major systems. Opt in to 27 only:
  /// 27.x still exposes the NSTextView/NSWindow selectors used here, while
  /// Introspect 27 itself would raise our macOS deployment target to 12.
  @MainActor
  enum AppIntrospection {
    private static var isMacOS27: Bool {
      if #available(macOS 28, *) { return false }
      if #available(macOS 27, *) { return true }
      return false
    }

    static var textEditor: PlatformViewVersionPredicate<TextEditorType, NSTextView> {
      if isMacOS27 { return .macOS(.v26...) }
      return .macOS(.v11, .v12, .v13, .v14, .v15, .v26)
    }

    static var window: PlatformViewVersionPredicate<WindowType, NSWindow> {
      if isMacOS27 { return .macOS(.v26...) }
      return .macOS(.v11, .v12, .v13, .v14, .v15, .v26)
    }
  }
#endif

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
  static func reduce(value _: inout CGSize, nextValue _: () -> CGSize) {}
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

  func clearTextEdtorStyle(isEditable: Bool = true) -> some View {
    #if os(macOS)
      introspect(.textEditor, on: AppIntrospection.textEditor) { textEditor in
        textEditor.isEditable = isEditable
        textEditor.textContainerInset = NSSize(width: 0, height: 1)
        textEditor.textContainer?.lineFragmentPadding = 0
        textEditor.backgroundColor = .clear
      }
    #else
      introspect(.textEditor, on: .iOS(.v14, .v15, .v16, .v17, .v18, .v26)) { textEditor in
        textEditor.isEditable = isEditable
        textEditor.textContainerInset = .zero
        textEditor.textContainer.lineFragmentPadding = 0
        textEditor.backgroundColor = .clear
      }
    #endif
  }
}

#if os(macOS)
  private struct WorkspaceScrollModifier: ViewModifier {
    @StateObject private var keeper = WorkspaceScrollKeeper()
    func body(content: Content) -> some View {
      content.introspect(.textEditor, on: AppIntrospection.textEditor) { keeper.attach($0) }
    }
  }
#endif

extension View {
  @ViewBuilder
  func preserveWorkspaceScroll() -> some View {
    #if os(macOS)
      modifier(WorkspaceScrollModifier())
    #else
      self
    #endif
  }
}

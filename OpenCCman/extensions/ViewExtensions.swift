import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

#if os(macOS)
  /// Explicitly supported systems only; a future major version needs validation.
  @MainActor
  enum AppIntrospection {
    static var textEditor: PlatformViewVersionPredicate<TextEditorType, NSTextView> {
      .macOS(.v12, .v13, .v14, .v15, .v26, .v27)
    }
  }
#elseif os(iOS)
  @MainActor
  enum AppIntrospection {
    static var textEditor: PlatformViewVersionPredicate<TextEditorType, UITextView> {
      .iOS(.v15, .v16, .v17, .v18, .v26, .v27)
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

/// Shows `content` while its ideal width fits the width on offer, otherwise
/// `fallback`. A macOS 12 stand-in for `ViewThatFits(in: .horizontal)` with two
/// candidates; nest another one in `fallback` for a third.
struct WidthFittingView<Content: View, Fallback: View>: View {
  @State private var availableWidth: CGFloat = 0
  @State private var idealWidth: CGFloat = 0
  private let content: Content
  private let fallback: Fallback

  init(@ViewBuilder content: () -> Content, @ViewBuilder fallback: () -> Fallback) {
    self.content = content()
    self.fallback = fallback()
  }

  var body: some View {
    Group {
      // Until the first measurement arrives, assume the preferred layout fits.
      if availableWidth == 0 || idealWidth <= availableWidth {
        content
      } else {
        fallback
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    // Each reader handles only its own subtree's preference, so nested
    // instances never see each other's widths.
    .background {
      GeometryReader { proxy in
        Color.clear.preference(key: FittingWidthKey.self, value: proxy.size.width)
      }
      .onPreferenceChange(FittingWidthKey.self) { availableWidth = $0 }
    }
    .background(alignment: .topLeading) {
      content
        .fixedSize()
        .hidden()
        .accessibilityHidden(true)
        .background {
          GeometryReader { proxy in
            Color.clear.preference(key: FittingWidthKey.self, value: proxy.size.width)
          }
          .onPreferenceChange(FittingWidthKey.self) { idealWidth = $0 }
        }
    }
  }
}

private struct FittingWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
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
      introspect(.textEditor, on: AppIntrospection.textEditor) { textEditor in
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

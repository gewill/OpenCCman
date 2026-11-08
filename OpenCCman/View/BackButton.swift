import Neumorphic
import SwiftUI
import SwiftUIRouter

struct BackButton: View {
  @EnvironmentObject private var navigator: Navigator
  @Environment(\.presentationMode) private var presentationMode
  var isPresented: Bool = false

  var body: some View {
    Button {
      if isPresented,
         presentationMode.wrappedValue.isPresented {
        presentationMode.wrappedValue.dismiss()
      } else {
        navigator.goBack()
      }
    } label: {
      #if os(iOS)
      Label(isPresented ? LocalizedStringKey("Done") : LocalizedStringKey("Back"),
            systemImage: isPresented ? "xmark" : "chevron.backward")
      #else
      Image(systemName: "chevron.backward")
      #endif
    }
    #if os(iOS)
    .buttonStyle(.plain)
    #else
    .appNeumorphicButtonStyle(Circle(), kind: .icon)
    #endif
  }
}

/// The in-content title bar of a Mac route: the back button at the leading edge
/// and the title centered in the window. A hidden copy of the button holds the
/// same width at the trailing edge, so the title stays centered yet never slides
/// under the button; when both no longer fit on one line, the title wraps.
struct SceneHeader: View {
  let title: LocalizedStringKey
  /// Distance from the window edge to the back button.
  let buttonInset: CGFloat

  init(_ title: LocalizedStringKey, buttonInset: CGFloat = Constant.padding) {
    self.title = title
    self.buttonInset = buttonInset
  }

  var body: some View {
    HStack(spacing: 8) {
      BackButton()
      Text(title)
        .appFont(.title)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
      BackButton()
        .hidden()
        .accessibilityHidden(true)
    }
    .padding(.horizontal, buttonInset)
  }
}

/// Each existing route remains the source of navigation state. The system owns
/// only its bar and safe area; resizing never switches route or navigation host.
private struct AppNavigationModifier: ViewModifier {
  let title: LocalizedStringKey
  var showsBack: Bool
  var isPresented: Bool
  var closeIdentifier: String

  @ViewBuilder func body(content: Content) -> some View {
    #if os(iOS)
    if #available(iOS 16.0, *) {
      NavigationStack { navigationContent(content) }
    } else {
      NavigationView { navigationContent(content) }
        .navigationViewStyle(.stack)
    }
    #else
    content
    #endif
  }

  #if os(iOS)
  private func navigationContent(_ content: Content) -> some View {
    content
      .background { Color.Neumorphic.main.ignoresSafeArea() }
      .navigationTitle(Text(title))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // Keep the item present on iOS 15 as well; optional ToolbarContent
        // conformance itself requires iOS 16.
        ToolbarItem(placement: isPresented ? .cancellationAction : .navigation) {
          if showsBack {
            BackButton(isPresented: isPresented)
              .accessibilityIdentifier(closeIdentifier)
          }
        }
      }
  }
  #endif
}

extension View {
  func appNavigation(_ title: LocalizedStringKey, showsBack: Bool = true,
                     isPresented: Bool = false, closeIdentifier: String = "navigation-back") -> some View {
    modifier(AppNavigationModifier(title: title, showsBack: showsBack,
                                   isPresented: isPresented, closeIdentifier: closeIdentifier))
  }
}

struct BackButton_Previews: PreviewProvider {
  static var previews: some View {
    BackButton()
  }
}

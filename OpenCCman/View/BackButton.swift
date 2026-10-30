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

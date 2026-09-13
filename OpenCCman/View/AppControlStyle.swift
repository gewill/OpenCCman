import Neumorphic
import SwiftUI

/// Complete control bounds, including the surface, insets and shadow envelope.
/// These are default sizes, not caps on multiline or accessibility text.
enum AppControlMetrics {
  #if os(macOS)
    static let height: CGFloat = 28
    static let primaryHeight: CGFloat = 32
    static let iconSize: CGFloat = 14
    static let shadowInset: CGFloat = 2
    static let contentInset: CGFloat = 4
  #else
    static let height: CGFloat = 44
    static let primaryHeight: CGFloat = 44
    static let iconSize: CGFloat = 18
    static let shadowInset: CGFloat = 4
    static let contentInset: CGFloat = 8
  #endif
}

enum AppControlKind { case regular, primary, icon }

/// App-local adapter: Neumorphic 2.4.1's button styles enforce 44pt on macOS too.
/// Reuse its palette and shadows without adding another minimum outside our surface.
struct AppNeumorphicButtonStyle<S: InsettableShape>: ButtonStyle {
  let shape: S
  var kind: AppControlKind = .regular
  var role: NeumorphicButtonRole = .surface
  var foreground: Color?
  @Environment(\.neumorphicTheme) private var theme
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let colors = theme.resolvedButtonColors(for: role)
    let height = kind == .primary ? AppControlMetrics.primaryHeight : AppControlMetrics.height
    configuration.label
      .fixedSize(horizontal: false, vertical: true)
      .font(kind == .icon ? .system(size: AppControlMetrics.iconSize) : .body)
      .padding(.horizontal, kind == .icon ? 0 : 10)
      .padding(.vertical, kind == .icon ? 0 : AppControlMetrics.contentInset)
      .frame(width: kind == .icon ? height : nil)
      .frame(minWidth: height, minHeight: height)
      .foregroundColor(foreground ?? colors.foreground)
      .background(
        AppControlSurface(shape: shape, color: colors.surface,
                          isPressed: configuration.isPressed, isEnabled: isEnabled)
          .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
      )
      .opacity(isEnabled ? 1 : 0.55)
      // Keep this outside the animated decoration: the whole envelope is clickable.
      .contentShape(Rectangle())
  }
}

private struct AppControlSurface<S: InsettableShape>: View {
  let shape: S
  let color: Color
  let isPressed: Bool
  let isEnabled: Bool
  @Environment(\.neumorphicTheme) private var theme
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    ZStack {
      if isPressed {
        shape.fill(color)
          .softInnerShadow(shape, darkShadow: theme.darkShadowColor,
                           lightShadow: theme.lightShadowColor, radius: AppControlMetrics.shadowInset / 2)
      } else {
        shape.fill(color)
          .softOuterShadow(darkShadow: theme.darkShadowColor, lightShadow: theme.lightShadowColor,
                           offset: AppControlMetrics.shadowInset / 2,
                           radius: AppControlMetrics.shadowInset / 2)
      }
      shape.strokeBorder(theme.secondaryColor.opacity(contrast == .increased ? 0.7 : 0.18),
                         lineWidth: isEnabled && contrast != .increased ? 0 : 1)
    }
    .padding(AppControlMetrics.shadowInset)
    // Clip only decoration, never glyphs, keyboard focus rings or hit testing.
    .clipped()
    .allowsHitTesting(false)
  }
}

/// Shared segment geometry: the groove is drawn inside the item hit regions.
struct AppSegmentButtonStyle: ButtonStyle {
  let selected: Bool
  @Environment(\.neumorphicTheme) private var theme
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let colors = theme.resolvedButtonColors(for: .accent)
    configuration.label
      .font(.body.weight(selected ? .semibold : .regular))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .frame(minWidth: AppControlMetrics.height, maxWidth: .infinity, minHeight: AppControlMetrics.height)
      .foregroundColor(selected ? colors.foreground : theme.secondaryColor)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(selected ? colors.surface : (configuration.isPressed ? theme.darkShadowColor.opacity(0.12) : .clear))
          .padding(3)
          .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
          .allowsHitTesting(false)
      )
      .opacity(isEnabled ? 1 : 0.5)
      .contentShape(Rectangle())
  }
}

private struct AppSegmentTrack: ViewModifier {
  @Environment(\.neumorphicTheme) private var theme
  func body(content: Content) -> some View {
    content.background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(theme.mainColor)
        .softInnerShadow(RoundedRectangle(cornerRadius: 9, style: .continuous),
                         darkShadow: theme.darkShadowColor, lightShadow: theme.lightShadowColor, radius: 2)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .allowsHitTesting(false)
    )
  }
}

extension View {
  func appNeumorphicButtonStyle<S: InsettableShape>(
    _ shape: S, kind: AppControlKind = .regular,
    role: NeumorphicButtonRole = .surface, foreground: Color? = nil
  ) -> some View {
    buttonStyle(AppNeumorphicButtonStyle(shape: shape, kind: kind, role: role, foreground: foreground))
  }

  func appSegmentTrack() -> some View { modifier(AppSegmentTrack()) }
}

// Match the app's established blue/white accent instead of the package's gray default.
extension NeumorphicTheme {
  static var openCCman: NeumorphicTheme {
    NeumorphicTheme(mainColor: .Neumorphic.main, secondaryColor: .Neumorphic.secondary,
                    accentColor: .accentColor, onAccentColor: .white,
                    darkShadowColor: .Neumorphic.darkShadow, lightShadowColor: .Neumorphic.lightShadow)
  }
}

/// The two custom Mac switches share the same complete-bounds policy as buttons.
struct AppNeumorphicSwitchStyle: ToggleStyle {
  @Environment(\.neumorphicTheme) private var theme
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    let height = AppControlMetrics.height
    let inset = AppControlMetrics.shadowInset
    let surfaceHeight = height - 2 * inset
    let width = surfaceHeight * 5 / 3 + 2 * inset
    return Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { configuration.isOn.toggle() }
    } label: {
      ZStack(alignment: configuration.isOn ? .trailing : .leading) {
        Capsule().fill(configuration.isOn ? Color.accentColor : theme.darkShadowColor.opacity(0.3))
          .softInnerShadow(Capsule(), darkShadow: theme.darkShadowColor,
                           lightShadow: theme.lightShadowColor, radius: inset / 2)
        Circle().fill(theme.mainColor)
          .frame(width: surfaceHeight - 4, height: surfaceHeight - 4)
          .padding(2)
      }
      .padding(inset)
      .frame(width: width, height: height)
      .clipped()
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.55)
    .accessibilityValue(Text(configuration.isOn ? "On" : "Off"))
    .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
  }
}

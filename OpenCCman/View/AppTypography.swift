import SwiftUI
#if os(macOS)
  import AppKit
#endif

/// A global, app-local Mac reading-size preference. iOS keeps system Dynamic Type.
enum AppTextSize: Int, CaseIterable, Identifiable {
  case standard, large, extraLarge

  var id: Int { rawValue }
  var multiplier: CGFloat {
    switch self {
    case .standard: return 1
    case .large: return 1.25
    case .extraLarge: return 1.5
    }
  }
}

private struct AppTextSizeKey: EnvironmentKey {
  static let defaultValue = AppTextSize.standard
}

extension EnvironmentValues {
  var appTextSize: AppTextSize {
    get { self[AppTextSizeKey.self] }
    set { self[AppTextSizeKey.self] = newValue }
  }
}

enum AppTypography {
  static func font(_ style: Font.TextStyle, weight: Font.Weight? = nil,
                   size: AppTextSize = .standard) -> Font {
    #if os(macOS)
      if size != .standard {
        let (nativeStyle, defaultWeight) = macStyle(style)
        let points = NSFont.preferredFont(forTextStyle: nativeStyle).pointSize * size.multiplier
        return .system(size: points, weight: weight ?? defaultWeight)
      }
    #endif
    let font = Font.system(style)
    return weight.map { font.weight($0) } ?? font
  }

  #if os(macOS)
    private static func macStyle(_ style: Font.TextStyle) -> (NSFont.TextStyle, Font.Weight) {
      switch style {
      case .largeTitle: return (.largeTitle, .regular)
      case .title: return (.title1, .regular)
      case .title2: return (.title2, .regular)
      case .title3: return (.title3, .regular)
      case .headline: return (.headline, .semibold)
      case .subheadline: return (.subheadline, .regular)
      case .callout: return (.callout, .regular)
      case .footnote: return (.footnote, .regular)
      case .caption: return (.caption1, .regular)
      case .caption2: return (.caption2, .regular)
      default: return (.body, .regular)
      }
    }
  #endif
}

private struct AppFontModifier: ViewModifier {
  @Environment(\.appTextSize) private var textSize
  let style: Font.TextStyle
  let weight: Font.Weight?

  func body(content: Content) -> some View {
    content.font(AppTypography.font(style, weight: weight, size: textSize))
  }
}

extension View {
  func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
    modifier(AppFontModifier(style: style, weight: weight))
  }
}

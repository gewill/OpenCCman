import AppIntents
import Foundation

/// The Shortcuts action exposes only the four configurations already named in
/// the app. Advanced combinations remain available in the editor.
@available(iOS 16.0, macOS 13.0, *)
enum ShortcutConversionPreset: String, AppEnum {
  case simplified
  case traditional
  case taiwan
  case hongKong

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut_preset"
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .simplified: "preset_simplified",
    .traditional: "preset_traditional",
    .taiwan: "preset_taiwan",
    .hongKong: "preset_hong_kong",
  ]

  var configuration: ConversionConfiguration {
    switch self {
    case .simplified: return .Preset.simplified.configuration
    case .traditional: return .Preset.traditional.configuration
    case .taiwan: return .Preset.taiwan.configuration
    case .hongKong: return .Preset.hongKong.configuration
    }
  }
}

@available(iOS 16.0, macOS 13.0, *)
enum ShortcutConversionError: LocalizedError {
  case textTooLarge

  var errorDescription: String? {
    NSLocalizedString("shortcut_input_too_large", comment: "Shortcuts conversion text exceeds the supported size")
  }
}

/// Returns text to Shortcuts without opening a workspace or changing its state.
@available(iOS 16.0, macOS 13.0, *)
struct ConvertChineseTextIntent: AppIntent {
  static let title: LocalizedStringResource = "shortcut_convert_title"
  static let description = IntentDescription("shortcut_convert_description")
  static let openAppWhenRun = false

  @Parameter(title: "shortcut_input", inputConnectionBehavior: .connectToPreviousIntentResult)
  var text: String

  @Parameter(title: "shortcut_preset", default: .traditional)
  var preset: ShortcutConversionPreset

  static var parameterSummary: some ParameterSummary {
    Summary("Convert \(\.$text) using \(\.$preset)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> {
    guard text.utf8.count <= TextFileService.maximumBytes else {
      throw ShortcutConversionError.textTooLarge
    }
    let result = try await ChineseConversionService.shared.convert(text, options: preset.configuration.options)
    return .result(value: result)
  }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenCCmanAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: ConvertChineseTextIntent(),
      phrases: ["Convert Chinese text with \(.applicationName)"],
      shortTitle: "shortcut_convert_short_title",
      systemImageName: "character.book.closed"
    )
  }
}

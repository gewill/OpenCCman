import OpenCC

extension ChineseConverter.Options {
  /// Hong Kong phrases, an app-only flag that goes with `hkStandard`. `Options`
  /// cannot express `s2hkp` or `hk2sp`, so `ChineseConversionService` builds those
  /// two from `ChineseConverter.Configuration` and never hands this bit to the
  /// engine. The engine's options use bits 0, 1, 5, 6 and 10.
  static let hkIdiom = ChineseConverter.Options(rawValue: 1 << 11)
}

/// The same option mapping is used by presets and the existing advanced controls.
struct ConversionConfiguration: Equatable, Sendable {
  var target: Language
  var variant: Variant
  var region: Region
  /// Where simplified output's traditional text comes from. Kept apart from
  /// `variant`/`region`: their saved values never affected simplified output,
  /// so reusing them would silently change it after an upgrade.
  var simplifiedSource: Variant = .openCC
  /// Regional phrase reversal for simplified output: Taiwan phrases from a Taiwan
  /// source (`tw2sp`), Hong Kong phrases from a Hong Kong source (`hk2sp`).
  var simplifiedRegion: Region = .notConvert

  var options: ChineseConverter.Options {
    guard target == .traditional else {
      switch simplifiedSource {
      case .openCC: return .simplify
      case .taiwan: return simplifiedRegion == .taiwan ? [.simplify, .twStandard, .twIdiom] : [.simplify, .twStandard]
      case .hongKong: return simplifiedRegion == .taiwan ? [.simplify, .hkStandard, .hkIdiom] : [.simplify, .hkStandard]
      }
    }
    var options: ChineseConverter.Options = .traditionalize
    switch variant {
    case .openCC: break
    case .taiwan: options.formUnion(.twStandard)
    case .hongKong: options.formUnion(.hkStandard)
    }
    // A Hong Kong standard takes Hong Kong phrases (s2hkp, #304). It used Taiwan
    // phrases before, so saved settings change output after the update. The
    // OpenCC standard keeps its Taiwan phrases (a compatibility configuration).
    if region == .taiwan { options.formUnion(variant == .hongKong ? .hkIdiom : .twIdiom) }
    return options
  }

  var preset: Preset? {
    // Each target ignores the other target's saved choices.
    if target == .simplified { return simplifiedSource == .openCC ? .simplified : nil }
    return Preset.allCases.first {
      $0.configuration.target == target && $0.configuration.variant == variant && $0.configuration.region == region
    }
  }

  /// Whether the simplified idiom choice applies to the selected source.
  var offersSimplifiedRegion: Bool { simplifiedSource != .openCC }

  /// Localization keys describing the effective conversion, for task summaries.
  var summaryKeys: [String] {
    switch target {
    case .traditional:
      return [target.title, variant.title] + (region == .taiwan ? [region.title(for: variant)] : [])
    case .simplified:
      switch simplifiedSource {
      case .openCC: return [target.title]
      case .taiwan: return [target.title, "source_from_taiwan"] + (simplifiedRegion == .taiwan ? [Region.taiwan.title] : [])
      case .hongKong:
        return [target.title, "source_from_hong_kong"] + (simplifiedRegion == .taiwan ? [Region.taiwan.title(for: .hongKong)] : [])
      }
    }
  }

  enum Language: String, CaseIterable, Identifiable, Sendable {
    case simplified = "Simplified Chinese"
    case traditional = "Traditional Chinese"
    var id: Self { self }
    var title: String { rawValue }
  }

  enum Variant: String, CaseIterable, Identifiable, Sendable {
    case openCC = "OpenCC Standard"
    case taiwan = "Taiwan Standard"
    case hongKong = "HongKong Standard"
    var id: Self { self }
    var title: String { rawValue }
  }

  enum Region: String, CaseIterable, Identifiable, Sendable {
    case notConvert = "Not convert"
    /// Convert regional phrases. The raw value stays for saved settings; under a
    /// Hong Kong standard this selects Hong Kong phrases.
    case taiwan = "Taiwan Idiom"
    var id: Self { self }
    var title: String { rawValue }

    /// The label for this choice next to a given standard.
    func title(for variant: Variant) -> String {
      self == .taiwan && variant == .hongKong ? "HongKong Idiom" : title
    }
  }

  enum Preset: String, CaseIterable, Identifiable, Sendable {
    case simplified = "preset_simplified"
    case traditional = "preset_traditional"
    case taiwan = "preset_taiwan"
    case hongKong = "preset_hong_kong"
    var id: Self { self }
    var title: String { rawValue }

    var configuration: ConversionConfiguration {
      switch self {
      case .simplified: return .init(target: .simplified, variant: .openCC, region: .notConvert)
      case .traditional: return .init(target: .traditional, variant: .openCC, region: .notConvert)
      case .taiwan: return .init(target: .traditional, variant: .taiwan, region: .taiwan)
      case .hongKong: return .init(target: .traditional, variant: .hongKong, region: .notConvert)
      }
    }
  }
}

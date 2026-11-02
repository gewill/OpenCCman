import OpenCC

/// The same option mapping is used by presets and the existing advanced controls.
struct ConversionConfiguration: Equatable, Sendable {
  var target: Language
  var variant: Variant
  var region: Region
  /// Where simplified output's traditional text comes from. Kept apart from
  /// `variant`/`region`: their saved values never affected simplified output,
  /// so reusing them would silently change it after an upgrade.
  var simplifiedSource: Variant = .openCC
  /// Taiwan idiom reversal for simplified output; only a Taiwan source offers it.
  var simplifiedRegion: Region = .notConvert

  var options: ChineseConverter.Options {
    guard target == .traditional else {
      switch simplifiedSource {
      case .openCC: return .simplify
      case .taiwan: return simplifiedRegion == .taiwan ? [.simplify, .twStandard, .twIdiom] : [.simplify, .twStandard]
      case .hongKong: return [.simplify, .hkStandard]
      }
    }
    var options: ChineseConverter.Options = .traditionalize
    switch variant {
    case .openCC: break
    case .taiwan: options.formUnion(.twStandard)
    case .hongKong: options.formUnion(.hkStandard)
    }
    if region == .taiwan { options.formUnion(.twIdiom) }
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
  var offersSimplifiedRegion: Bool { simplifiedSource == .taiwan }

  /// Localization keys describing the effective conversion, for task summaries.
  var summaryKeys: [String] {
    switch target {
    case .traditional:
      return [target.title, variant.title] + (region == .taiwan ? [region.title] : [])
    case .simplified:
      switch simplifiedSource {
      case .openCC: return [target.title]
      case .taiwan: return [target.title, "source_from_taiwan"] + (simplifiedRegion == .taiwan ? [Region.taiwan.title] : [])
      case .hongKong: return [target.title, "source_from_hong_kong"]
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
    case taiwan = "Taiwan Idiom"
    var id: Self { self }
    var title: String { rawValue }
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

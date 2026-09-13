import OpenCC

/// The same option mapping is used by presets and the existing advanced controls.
struct ConversionConfiguration: Equatable, Sendable {
  var target: Language
  var variant: Variant
  var region: Region

  var options: ChineseConverter.Options {
    guard target == .traditional else { return .simplify }
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
    // Variant/idiom controls are inactive for simplified output; preserve their
    // saved values without incorrectly labelling this effective option custom.
    if target == .simplified { return .simplified }
    return Preset.allCases.first { $0.configuration == self }
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

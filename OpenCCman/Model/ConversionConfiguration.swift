import OpenCC

/// One OpenCC conversion, chosen as a source standard and a target standard like
/// the official web converter (#305), with regional phrases where OpenCC offers
/// them. Every valid choice is exactly one official configuration.
struct ConversionConfiguration: Equatable, Sendable {
  var source: Standard
  var target: Standard
  /// Regional phrases (OpenCC "p"). Kept when a combination does not offer them,
  /// so going back restores the choice; `official` ignores it there.
  var phrases: Region = .notConvert

  init(source: Standard, target: Standard, phrases: Region = .notConvert) {
    self.source = source
    self.target = Self.accepts(source: source, target: target) ? target : Self.defaultTarget(for: source)
    self.phrases = phrases
  }

  /// Whether OpenCC has a configuration from `source` to `target`. Same-standard
  /// pairs and Taiwan ↔ Hong Kong have none, as on the official web converter.
  static func accepts(source: Standard, target: Standard) -> Bool {
    switch (source, target) {
    case (.simplified, .openCC), (.simplified, .taiwan), (.simplified, .hongKong),
         (.openCC, .simplified), (.openCC, .taiwan), (.openCC, .hongKong),
         (.taiwan, .simplified), (.taiwan, .openCC),
         (.hongKong, .simplified), (.hongKong, .openCC):
      return true
    default:
      return false
    }
  }

  /// The target used when a new source makes the current target invalid.
  static func defaultTarget(for source: Standard) -> Standard {
    source == .simplified ? .openCC : .simplified
  }

  /// A new source keeps a target it can convert to, and otherwise takes the default.
  mutating func select(source: Standard) {
    self.source = source
    if !Self.accepts(source: source, target: target) { target = Self.defaultTarget(for: source) }
  }

  /// Exchanges the source and the target, keeping the text and the phrase choice.
  /// Every OpenCC configuration offered here has its reverse.
  mutating func swap() {
    (source, target) = (target, source)
  }

  /// The regional standard whose phrases can be converted: Taiwan or Hong Kong
  /// paired with Simplified Chinese (`s2twp`, `tw2sp`, `s2hkp`, `hk2sp`).
  var phraseRegion: Standard? {
    switch (source, target) {
    case (.simplified, .taiwan), (.taiwan, .simplified): return .taiwan
    case (.simplified, .hongKong), (.hongKong, .simplified): return .hongKong
    default: return nil
    }
  }

  var offersPhrases: Bool { phraseRegion != nil }

  /// The official OpenCC configuration for this choice.
  var official: ChineseConverter.Configuration {
    let converts = offersPhrases && phrases == .taiwan
    switch (source, target) {
    case (.simplified, .taiwan): return converts ? .s2twp : .s2tw
    case (.simplified, .hongKong): return converts ? .s2hkp : .s2hk
    case (.openCC, .simplified): return .t2s
    case (.openCC, .taiwan): return .t2tw
    case (.openCC, .hongKong): return .t2hk
    case (.taiwan, .simplified): return converts ? .tw2sp : .tw2s
    case (.taiwan, .openCC): return .tw2t
    case (.hongKong, .simplified): return converts ? .hk2sp : .hk2s
    case (.hongKong, .openCC): return .hk2t
    default: return .s2t // Simplified → OpenCC; `init` and `select` never keep an invalid pair.
    }
  }

  /// The choice that produces an official configuration, for configurations the
  /// app offers (not the Japanese ones).
  init?(official: ChineseConverter.Configuration) {
    switch official {
    case .s2t: self.init(source: .simplified, target: .openCC)
    case .s2tw: self.init(source: .simplified, target: .taiwan)
    case .s2twp: self.init(source: .simplified, target: .taiwan, phrases: .taiwan)
    case .s2hk: self.init(source: .simplified, target: .hongKong)
    case .s2hkp: self.init(source: .simplified, target: .hongKong, phrases: .taiwan)
    case .t2s: self.init(source: .openCC, target: .simplified)
    case .t2tw: self.init(source: .openCC, target: .taiwan)
    case .t2hk: self.init(source: .openCC, target: .hongKong)
    case .tw2s: self.init(source: .taiwan, target: .simplified)
    case .tw2sp: self.init(source: .taiwan, target: .simplified, phrases: .taiwan)
    case .tw2t: self.init(source: .taiwan, target: .openCC)
    case .hk2s: self.init(source: .hongKong, target: .simplified)
    case .hk2sp: self.init(source: .hongKong, target: .simplified, phrases: .taiwan)
    case .hk2t: self.init(source: .hongKong, target: .openCC)
    case .t2jp, .jp2t: return nil
    }
  }

  var preset: Preset? {
    Preset.allCases.first { $0.configuration.official == official }
  }

  /// The phrase choice's label, naming the regional standard it applies to.
  var phraseTitle: String? {
    guard let region = phraseRegion, phrases == .taiwan else { return nil }
    return Region.taiwan.title(for: region)
  }

  /// Writing standards on both sides. Raw values are OpenCC's abbreviations and
  /// are what the settings store.
  enum Standard: String, CaseIterable, Identifiable, Sendable {
    case simplified = "s"
    case openCC = "t"
    case taiwan = "tw"
    case hongKong = "hk"
    var id: Self { self }

    /// The localization key shown for this standard.
    var title: String {
      switch self {
      case .simplified: return "Simplified Chinese"
      case .openCC: return "standard_opencc_traditional"
      case .taiwan: return "standard_taiwan"
      case .hongKong: return "standard_hong_kong"
      }
    }
  }

  enum Region: String, CaseIterable, Identifiable, Sendable {
    case notConvert = "Not convert"
    /// Convert regional phrases. The raw value stays for saved settings; it names
    /// Hong Kong phrases when the conversion involves Hong Kong.
    case taiwan = "Taiwan Idiom"
    var id: Self { self }
    var title: String { rawValue }

    /// The label for this choice next to a given regional standard.
    func title(for region: Standard) -> String {
      self == .taiwan && region == .hongKong ? "HongKong Idiom" : title
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
      case .simplified: return .init(source: .openCC, target: .simplified)
      case .traditional: return .init(source: .simplified, target: .openCC)
      case .taiwan: return .init(source: .simplified, target: .taiwan, phrases: .taiwan)
      case .hongKong: return .init(source: .simplified, target: .hongKong)
      }
    }
  }
}

// MARK: - Settings saved before #305

extension ConversionConfiguration {
  /// The output direction saved before #305. Only read to migrate old settings.
  enum Language: String, CaseIterable, Identifiable, Sendable {
    case simplified = "Simplified Chinese"
    case traditional = "Traditional Chinese"
    var id: Self { self }
    var title: String { rawValue }
  }

  /// A regional standard saved before #305. Only read to migrate old settings.
  enum Variant: String, CaseIterable, Identifiable, Sendable {
    case openCC = "OpenCC Standard"
    case taiwan = "Taiwan Standard"
    case hongKong = "HongKong Standard"
    var id: Self { self }
    var title: String { rawValue }

    var standard: Standard {
      switch self {
      case .openCC: return .openCC
      case .taiwan: return .taiwan
      case .hongKong: return .hongKong
      }
    }
  }

  /// Settings saved before #305 kept separate choices for Traditional and
  /// Simplified output; only the saved output's choices apply. Each maps to the
  /// configuration it produced, except OpenCC Traditional with Taiwan phrases (a
  /// non-official compatibility configuration), which becomes `s2twp` (#304, #305).
  init(legacyTarget: Language, variant: Variant, region: Region,
       simplifiedSource: Variant, simplifiedRegion: Region) {
    switch legacyTarget {
    case .traditional:
      if variant == .openCC, region == .taiwan {
        self.init(source: .simplified, target: .taiwan, phrases: .taiwan)
      } else {
        self.init(source: .simplified, target: variant.standard, phrases: region)
      }
    case .simplified:
      self.init(source: simplifiedSource.standard, target: .simplified, phrases: simplifiedRegion)
    }
  }
}

// MARK: - iOS large-file job records

extension ChineseConverter.Configuration {
  /// The integer stored in iOS large-file job records. Configurations offered
  /// before #305 keep the option bits they were saved with, so earlier versions
  /// can still restore those results; the rest use codes from 4096 up, which
  /// earlier versions reject.
  var recordCode: Int {
    switch self {
    case .s2t: return 1
    case .t2s: return 2
    case .s2tw: return 33
    case .tw2s: return 34
    case .s2hk: return 65
    case .hk2s: return 66
    case .s2twp: return 1057
    case .tw2sp: return 1058
    case .s2hkp: return 2113
    case .hk2sp: return 2114
    case .t2tw: return 4096
    case .tw2t: return 4097
    case .t2hk: return 4098
    case .hk2t: return 4099
    case .t2jp: return 4100
    case .jp2t: return 4101
    }
  }

  /// Reads a record code. Results of the two retired compatibility configurations
  /// (OpenCC or Hong Kong Traditional with Taiwan phrases) are described by the
  /// official configurations that replaced them; their files are unchanged.
  init?(recordCode: Int) {
    switch recordCode {
    case 1025: self = .s2twp
    case 1089: self = .s2hkp
    default:
      guard let match = Self.allCases.first(where: { $0.recordCode == recordCode }) else { return nil }
      self = match
    }
  }
}

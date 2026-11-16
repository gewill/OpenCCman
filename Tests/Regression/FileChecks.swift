import Combine
import Foundation
import OpenCC

@MainActor func checkPresetsAndFiles() async throws {
  typealias Configuration = ChineseConverter.Configuration
  let presets: [(ConversionConfiguration.Preset, Configuration)] = [
    (.simplified, .t2s), (.traditional, .s2t), (.taiwan, .s2twp), (.hongKong, .s2hk)
  ]
  for (preset, expected) in presets {
    precondition(preset.configuration.official == expected)
    precondition(preset.configuration.preset == preset)
  }

  // Source × target (#305): the official web converter's pairs, each one official
  // configuration; phrases only between Simplified and Taiwan or Hong Kong.
  let matrix: [ConversionConfiguration.Standard: [ConversionConfiguration.Standard: (Configuration, Configuration?)]] = [
    .simplified: [.openCC: (.s2t, nil), .taiwan: (.s2tw, .s2twp), .hongKong: (.s2hk, .s2hkp)],
    .openCC: [.simplified: (.t2s, nil), .taiwan: (.t2tw, nil), .hongKong: (.t2hk, nil)],
    .taiwan: [.simplified: (.tw2s, .tw2sp), .openCC: (.tw2t, nil)],
    .hongKong: [.simplified: (.hk2s, .hk2sp), .openCC: (.hk2t, nil)],
  ]
  var offered = Set<Configuration>()
  for source in ConversionConfiguration.Standard.allCases {
    for target in ConversionConfiguration.Standard.allCases {
      guard let (plain, withPhrases) = matrix[source]?[target] else {
        precondition(!ConversionConfiguration.accepts(source: source, target: target), "\(source) → \(target) has no configuration")
        let normalized = ConversionConfiguration(source: source, target: target)
        precondition(normalized.target == ConversionConfiguration.defaultTarget(for: source), "An invalid target falls back")
        continue
      }
      precondition(ConversionConfiguration.accepts(source: source, target: target))
      for phrases in ConversionConfiguration.Region.allCases {
        let configuration = ConversionConfiguration(source: source, target: target, phrases: phrases)
        let expected = phrases == .taiwan ? (withPhrases ?? plain) : plain
        precondition(configuration.official == expected, "\(source) → \(target), \(phrases) is \(expected)")
        precondition(configuration.offersPhrases == (withPhrases != nil))
        precondition(ConversionConfiguration(official: expected)?.official == expected, "\(expected) reads back")
        offered.insert(expected)
        // Every configuration has its reverse; swapping keeps the phrase choice.
        var swapped = configuration
        swapped.swap()
        precondition(swapped.source == target && swapped.target == source && swapped.phrases == phrases)
        precondition(ConversionConfiguration.accepts(source: target, target: source))
      }
    }
  }
  precondition(offered.count == 14 && !offered.contains(.t2jp) && !offered.contains(.jp2t), "Fourteen official configurations, no Japanese")
  precondition(ConversionConfiguration(official: .t2jp) == nil && ConversionConfiguration(official: .jp2t) == nil)
  precondition(ConversionConfiguration.defaultTarget(for: .simplified) == .openCC)
  for source in [ConversionConfiguration.Standard.openCC, .taiwan, .hongKong] {
    precondition(ConversionConfiguration.defaultTarget(for: source) == .simplified)
  }
  var selection = ConversionConfiguration(source: .openCC, target: .taiwan)
  selection.select(source: .simplified)
  precondition(selection.official == .s2tw, "A new source keeps a target it can convert to")
  selection.select(source: .taiwan)
  precondition(selection.target == .simplified && selection.official == .tw2s, "Taiwan → Taiwan falls back to Simplified")
  precondition(ConversionConfiguration(source: .simplified, target: .hongKong, phrases: .taiwan).phraseTitle == "HongKong Idiom")
  precondition(ConversionConfiguration(source: .taiwan, target: .simplified, phrases: .taiwan).phraseTitle == "Taiwan Idiom")
  precondition(ConversionConfiguration(source: .openCC, target: .taiwan, phrases: .taiwan).phraseTitle == nil)
  precondition(ConversionConfiguration.Region.taiwan.title(for: .hongKong) == "HongKong Idiom")
  precondition(ConversionConfiguration.Region.taiwan.title(for: .taiwan) == "Taiwan Idiom")

  // Settings saved before #305: every state keeps the configuration it produced,
  // except OpenCC Traditional with Taiwan phrases, which moves to s2twp.
  for target in ConversionConfiguration.Language.allCases {
    for variant in ConversionConfiguration.Variant.allCases {
      for region in ConversionConfiguration.Region.allCases {
        for source in ConversionConfiguration.Variant.allCases {
          for sourceRegion in ConversionConfiguration.Region.allCases {
            let migrated = ConversionConfiguration(legacyTarget: target, variant: variant, region: region,
                                                   simplifiedSource: source, simplifiedRegion: sourceRegion)
            let expected: Configuration
            switch (target, variant, region, source, sourceRegion) {
            case (.traditional, .openCC, .notConvert, _, _): expected = .s2t
            case (.traditional, .openCC, .taiwan, _, _): expected = .s2twp
            case (.traditional, .taiwan, .notConvert, _, _): expected = .s2tw
            case (.traditional, .taiwan, .taiwan, _, _): expected = .s2twp
            case (.traditional, .hongKong, .notConvert, _, _): expected = .s2hk
            case (.traditional, .hongKong, .taiwan, _, _): expected = .s2hkp
            case (.simplified, _, _, .openCC, _): expected = .t2s
            case (.simplified, _, _, .taiwan, .notConvert): expected = .tw2s
            case (.simplified, _, _, .taiwan, .taiwan): expected = .tw2sp
            case (.simplified, _, _, .hongKong, .notConvert): expected = .hk2s
            case (.simplified, _, _, .hongKong, .taiwan): expected = .hk2sp
            }
            precondition(migrated.official == expected, "\(target) \(variant) \(region) \(source) \(sourceRegion) keeps \(expected)")
          }
        }
      }
    }
  }
  // Expected outputs from the OpenCC 1.4.2 command-line tool. The retired OpenCC +
  // Taiwan phrases configuration converts differently from s2twp, as announced.
  let simplifiedSample = "鼠标里面的软件和打印机，用的是信息技术。"
  let legacyTaiwanPhrases = try ChineseConverter(options: [.traditionalize, .twIdiom]).convert(simplifiedSample)
  let s2twp = try ChineseConversionService.convertSynchronously(simplifiedSample, configuration: .s2twp)
  precondition(s2twp == "滑鼠裡面的軟體和印表機，用的是資訊科技。" && legacyTaiwanPhrases != s2twp
               && legacyTaiwanPhrases.count == s2twp.count, "The legacy phrases differ from s2twp only in characters")
  let outputs: [(Configuration, String, String)] = [
    (.t2s, "滑鼠裡面的軟體，著衣與衞生紙。", "滑鼠里面的软体，著衣与衞生纸。"),
    (.tw2s, "滑鼠裡面的軟體，著衣與衞生紙。", "滑鼠里面的软体，着衣与衞生纸。"),
    (.tw2sp, "滑鼠裡面的軟體，著衣與衞生紙。", "鼠标里面的软件，着衣与衞生纸。"),
    (.hk2s, "滑鼠裡面的軟體，著衣與衞生紙。", "滑鼠里面的软体，著衣与卫生纸。"),
    (.hk2sp, "滑鼠裡面的軟體，著衣與衞生紙。", "鼠标里面的软体，著衣与卫生纸。"),
    (.s2hk, simplifiedSample, "鼠標裏面的軟件和打印機，用的是信息技術。"),
    (.s2hkp, simplifiedSample, "滑鼠裏面的軟件和打印機，用的是信息技術。"),
    // New with #305.
    (.t2tw, "鼠標裏面的衞生紙和著衣，爲了綫上的麪包。", "鼠標裡面的衞生紙和著衣，為了綫上的麵包。"),
    (.t2hk, "鼠標裏面的衞生紙和著衣，爲了綫上的麪包。", "鼠標裏面的衞生紙和著衣，為了綫上的麪包。"),
    (.tw2t, "鼠標裡面的衛生紙和著衣，為了線上的麵包。", "鼠標裏面的衛生紙和着衣，爲了線上的麪包。"),
    (.hk2t, "鼠標裏面的衞生紙和着衣，為了綫上的麵包。", "鼠標裏面的衛生紙和着衣，爲了線上的麵包。"),
  ]
  for (configuration, input, expected) in outputs {
    let output = try ChineseConversionService.convertSynchronously(input, configuration: configuration)
    precondition(output == expected, "\(configuration) converts like the official command-line tool")
  }

  // iOS job records: earlier configurations keep their option bits, so earlier
  // versions can restore them; retired compatibility codes read as their successors.
  let earlierCodes: [(Configuration, Int)] = [
    (.s2t, 1), (.t2s, 2), (.s2tw, 33), (.tw2s, 34), (.s2hk, 65), (.hk2s, 66),
    (.s2twp, 1057), (.tw2sp, 1058), (.s2hkp, 1 | 64 | 1 << 11), (.hk2sp, 2 | 64 | 1 << 11),
  ]
  for (configuration, code) in earlierCodes {
    precondition(configuration.recordCode == code && Configuration(recordCode: code) == configuration)
  }
  let codes = Configuration.allCases.map(\.recordCode)
  precondition(Set(codes).count == codes.count, "Record codes are unique")
  for configuration in Configuration.allCases {
    precondition(Configuration(recordCode: configuration.recordCode) == configuration)
  }
  precondition(Configuration(recordCode: 1025) == .s2twp && Configuration(recordCode: 1089) == .s2hkp)
  precondition(Configuration(recordCode: 0) == nil && Configuration(recordCode: 3) == nil && Configuration(recordCode: 1 << 13) == nil)

  // Saved settings: the first read migrates once to the new keys; later reads use them.
  let defaults = UserDefaults.standard
  let keys = ["conversionSource", "conversionTarget", "conversionPhrases", "targetOptions", "variantOptions",
              "regionOptions", "simplifiedSourceOptions", "simplifiedRegionOptions"]
  keys.forEach(defaults.removeObject(forKey:))
  precondition(ConversionConfiguration.saved.official == .s2t, "A fresh install starts with s2t, as before")
  keys.forEach(defaults.removeObject(forKey:))
  defaults.set("Simplified Chinese", forKey: "targetOptions")
  defaults.set("HongKong Standard", forKey: "simplifiedSourceOptions")
  defaults.set("Taiwan Idiom", forKey: "simplifiedRegionOptions")
  precondition(ConversionConfiguration.saved.official == .hk2sp, "Saved Hong Kong reversal with phrases stays hk2sp")
  precondition(defaults.string(forKey: "conversionSource") == "hk" && defaults.string(forKey: "conversionTarget") == "s"
               && defaults.string(forKey: "conversionPhrases") == "Taiwan Idiom", "The migration writes the new keys")
  defaults.set("Traditional Chinese", forKey: "targetOptions")
  precondition(ConversionConfiguration.saved.official == .hk2sp, "Old keys are only read once")
  precondition(defaults.string(forKey: "simplifiedSourceOptions") == "HongKong Standard", "Old keys stay for earlier versions")
  keys.forEach(defaults.removeObject(forKey:))
  defaults.set("OpenCC Standard", forKey: "variantOptions")
  defaults.set("Taiwan Idiom", forKey: "regionOptions")
  precondition(ConversionConfiguration.saved.official == .s2twp, "OpenCC Traditional with Taiwan phrases moves to s2twp")
  keys.forEach(defaults.removeObject(forKey:))

  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("文稿.txt")
  let fixtures = ["", "\r\n汉字\r\n\r\n", "👨‍👩‍👧‍👦🇹🇼e\u{301}\0鼠标\0\0\n"]
  for text in fixtures {
    for bom in [Data(), Data([0xEF, 0xBB, 0xBF])] {
      try (bom + Data(text.utf8)).write(to: file)
      let imported = try await TextFileService.read(file)
      precondition(imported.text == text, "UTF-8 import preserves exact text, removing only the BOM")
      precondition(imported.exportFilename == "文稿-converted.txt")
    }
  }
  precondition(TextFileService.ImportedText(text: "", sourceFilename: nil).exportFilename == "OpenCCman-converted.txt")
  let exactLimit = Data(repeating: 0x61, count: TextFileService.maximumBytes)
  let exactDecoded = try TextFileService.decode(exactLimit)
  precondition(exactDecoded.utf8.count == TextFileService.maximumBytes)

  let invalid = directory.appendingPathComponent("invalid.txt")
  try Data([0xFF, 0xFE, 0x80]).write(to: invalid)
  do {
    _ = try await TextFileService.read(invalid)
    preconditionFailure("Invalid UTF-8 must be rejected")
  } catch TextFileService.FileError.invalidUTF8 {}

  let large = directory.appendingPathComponent("large.txt")
  FileManager.default.createFile(atPath: large.path, contents: nil)
  let handle = try FileHandle(forWritingTo: large)
  try handle.truncate(atOffset: UInt64(TextFileService.maximumBytes + 1))
  try handle.close()
  do {
    _ = try await TextFileService.read(large)
    preconditionFailure("Oversized files must be rejected before unbounded allocation")
  } catch TextFileService.FileError.tooLarge {}
  do {
    _ = try await TextFileService.read(directory)
    preconditionFailure("Directories are not text files")
  } catch TextFileService.FileError.unsupportedFile {}

  let cancelledRead = Task { try await TextFileService.read(file) }
  cancelledRead.cancel()
  do {
    _ = try await cancelledRead.value
    preconditionFailure("Cancelled reads must not return a replacement draft")
  } catch is CancellationError {}

  UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isPro.rawValue)
  defer { UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.isPro.rawValue) }
  let model = HomeViewModel()
  model.replaceSource("保留原稿", sourceFilename: "原稿.txt")
  model.resultText = "保留结果"
  let quotaBefore = coreQuotaCount
  model.importFile(invalid)
  await waitForImport(model)
  precondition(model.inputText == "保留原稿" && model.resultText == "保留结果")
  precondition(model.error != nil && !model.isImporting)
  model.importFile(file)
  model.cancelImport()
  precondition(model.inputText == "保留原稿" && model.resultText == "保留结果")
  model.importFile(file)
  await waitForImport(model)
  precondition(model.inputText == fixtures.last! && model.resultText.isEmpty)
  precondition(model.exportSnapshot == nil, "A new imported draft cannot export an unrelated prior result")
  precondition(model.error == nil && coreQuotaCount == quotaBefore)

  model.applyPreset(.taiwan)
  precondition(model.selectedPreset == .taiwan && model.configuration.official == .s2twp)
  model.swapConversion()
  precondition(model.configuration.official == .tw2sp && model.selectedPreset == nil, "Swapping keeps phrases: s2twp ↔ tw2sp")
  precondition(model.inputText == fixtures.last!, "Swapping leaves the texts alone")
  model.conversion.select(source: .hongKong)
  precondition(model.configuration.official == .hk2sp, "Hong Kong reversal with phrases converts with hk2sp")
  model.conversion.select(source: .openCC)
  precondition(model.configuration.official == .t2s && model.selectedPreset == .simplified)
  model.conversion.target = .hongKong
  precondition(model.configuration.official == .t2hk && model.selectedPreset == nil, "OpenCC Traditional to Hong Kong is t2hk")
  model.conversion.select(source: .hongKong)
  precondition(model.conversion.target == .simplified, "Hong Kong → Hong Kong falls back to Simplified")
  model.applyPreset(.simplified)
  precondition(model.configuration.official == .t2s && model.selectedPreset == .simplified)
  await Task.yield()
  precondition(ConversionConfiguration.saved == model.configuration, "Changes are saved for new windows and Services")
  precondition(coreQuotaCount == quotaBefore, "Imports and presets never consume quota")

  model.inputText = String(repeating: "汉字鼠标\n", count: 100_000)
  model.translate()
  model.importFile(file)
  await waitForImport(model)
  // Drain the serial conversion actor: an earlier result must not overwrite the import.
  _ = try await ChineseConversionService.shared.convert("", configuration: .t2s)
  await Task.yield()
  precondition(model.inputText == fixtures.last! && model.resultText.isEmpty && !model.isLoading)
  print("PASS: presets, UTF-8/BOM/Unicode/NUL files, size limit, invalid input, cancellation and import replacement")
}

@MainActor private func waitForImport(_ model: HomeViewModel) async {
  guard model.isImporting else { return }
  await withCheckedContinuation { continuation in
    var observation: AnyCancellable?
    observation = model.$isImporting.filter { !$0 }.first().sink { _ in
      continuation.resume()
      observation?.cancel()
      observation = nil
    }
  }
}

import Foundation

/// The Share sheet action's model, run without UIKit. Reading the host's item
/// providers is covered by ProviderChecks through TextFileService.
enum TextActionChecks {
  @MainActor static func run() async throws {
    let suite = "OpenCCmanCoreChecks.TextAction"
    let defaults = Foundation.UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let quotaBefore = coreQuotaCount

    precondition(TextActionModel(defaults: defaults).preset == .traditional,
                 "Without a saved choice the action starts with the Shortcuts default")
    defaults.set("not-a-preset", forKey: TextActionModel.presetKey)
    precondition(TextActionModel(defaults: defaults).preset == .traditional,
                 "An unknown saved value falls back to the default")

    let fixtures = ["鼠标\r\n\r\n台湾\r头发", "👨‍👩‍👧‍👦🇹🇼 e\u{301} \0干杯\0\u{2028}软件\u{2029}", " \n\t "]
    for preset in ConversionConfiguration.Preset.allCases {
      for text in fixtures {
        let model = TextActionModel(defaults: defaults)
        model.preset = preset
        model.receive { text }
        try await waitUntilSettled(model)
        let expected = try await ChineseConversionService.shared.convert(text, options: preset.configuration.options)
        precondition(model.phase == .converted && model.result == expected,
                     "The action returns the same complete text as the matching app preset")
        precondition(model.inputCharacterCount == text.count)
      }
    }
    precondition(defaults.string(forKey: TextActionModel.presetKey) == ConversionConfiguration.Preset.hongKong.rawValue,
                 "The last chosen preset is remembered in the action's own defaults")
    precondition(TextActionModel(defaults: defaults).preset == .hongKong)

    // Switching presets reconverts the same input; only the newest choice publishes.
    let model = TextActionModel(defaults: defaults)
    let source = String(repeating: "鼠标里面的硅二极管坏了，导致光标分辨率降低。\n", count: 20_000)
    model.receive { source }
    try await waitUntilSettled(model)
    model.preset = .simplified
    model.preset = .taiwan
    model.preset = .traditional
    try await waitUntilSettled(model)
    let traditional = try await ChineseConversionService.shared.convert(source, options: ConversionConfiguration.Preset.traditional.configuration.options)
    precondition(model.preset == .traditional && model.result == traditional,
                 "A superseded conversion must not overwrite the newest preset's result")
    let preview = model.preview!
    precondition(preview.isTruncated && preview.text.count == TextActionModel.previewCharacters &&
                 traditional.hasPrefix(preview.text), "The preview is a prefix; the result stays complete")

    // Chunks split UTF-8 scalars and dictionary phrases; output still matches
    // converting the whole text at once.
    let options = ConversionConfiguration.Preset.taiwan.configuration.options
    let small = [String(repeating: "a", count: 255) + "鼠标" + String(repeating: "软件", count: 300), "", "👨‍👩‍👧‍👦\r\n\0头发"]
    for (text, chunks) in small.map({ ($0, [1, 2, 7, 256, 256 * 1024]) }) + [(source, [4_099, 256 * 1024])] {
      let whole = try await ChineseConversionService.shared.convert(text, options: options)
      for chunk in chunks {
        let chunked = try TextActionModel.convertInChunks(text, options: options, chunkBytes: chunk)
        precondition(chunked == whole, "Chunked conversion must equal whole-text conversion at every boundary")
      }
    }

    // A preview never splits a grapheme cluster at its boundary.
    let family = "👨‍👩‍👧‍👦"
    let clusterModel = TextActionModel(defaults: defaults)
    clusterModel.receive { String(repeating: "a", count: TextActionModel.previewCharacters - 1) + family + family }
    try await waitUntilSettled(clusterModel)
    precondition(clusterModel.preview!.text.hasSuffix(family) && clusterModel.preview!.isTruncated)

    let boundaryPrefix = String(repeating: "a", count: TextFileService.maximumBytes - "头发".utf8.count)
    let boundary = TextActionModel(defaults: defaults)
    boundary.receive { boundaryPrefix + "头发" }
    try await waitUntilSettled(boundary)
    precondition(boundary.result == boundaryPrefix + "頭髮", "Exactly 10 MiB of UTF-8 text is accepted")

    let tooLarge = TextFileService.FileError.tooLarge.localizedDescription
    try await expectFailure(String(repeating: "a", count: TextFileService.maximumBytes - 2) + "中", tooLarge,
                            "Capacity is measured in UTF-8 bytes and over-limit text is never truncated", defaults)
    try await expectFailure("", TextActionModel.message(for: TextFileService.FileError.unsupportedFile),
                            "Empty input reports that there is nothing to convert", defaults)
    let unreadable = TextActionModel(defaults: defaults)
    unreadable.receive { throw TextFileService.FileError.invalidUTF8 }
    try await waitUntilSettled(unreadable)
    precondition(unreadable.phase == .failed(TextFileService.FileError.invalidUTF8.localizedDescription) &&
                 unreadable.result == nil, "A read failure is shown without a result to return")

    precondition(coreQuotaCount == quotaBefore, "The action is free and never charges the homepage quota")
    print("PASS: free Share sheet action matches four presets, remembers its own choice, keeps the newest result, previews whole characters, accepts exactly 10 MiB and rejects over-limit, empty and unreadable input")
  }

  @MainActor private static func expectFailure(_ text: String, _ message: String, _ reason: String,
                                               _ defaults: Foundation.UserDefaults) async throws {
    let model = TextActionModel(defaults: defaults)
    model.receive { text }
    try await waitUntilSettled(model)
    precondition(model.phase == .failed(message) && model.result == nil, reason)
  }

  @MainActor private static func waitUntilSettled(_ model: TextActionModel) async throws {
    for _ in 0..<6_000 {
      if model.phase != .loading && model.phase != .converting { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    preconditionFailure("The action did not finish within 60 seconds")
  }
}

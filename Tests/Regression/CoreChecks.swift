import Combine
import Foundation
import OpenCC

@main enum CoreChecks {
  @MainActor static func main() async throws {
    defer {
      appDefaults.defaults.removePersistentDomain(forName: coreSuite)
      UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastVersionPromptedForReview.rawValue)
    }
    try await checkStreamingPump()
    try await checkMobileFileJobs()
    try await checkMobileCoordinator()
    await checkWindowNotifications()
    let fixtures = [
      "", "\n\n前段\n\n后段\n\n", "\r\n鼠标\r\n\r\n台湾\r\n",
      "前段\n\n" + String(repeating: "汉", count: 4001),
      String(repeating: "a", count: 3999) + "鼠标",
      "\n\n" + String(repeating: "甲\n\n", count: 1500) + "\n\n",
      "👨‍👩‍👧‍👦🇹🇼e\u{301} 简体中文\t鼠标\u{2028}台湾",
      "\0鼠标\0\0汉字\0 😀 e\u{301}\r\n",
      "\0\0\0", "前段\0" + String(repeating: "汉", count: 4001) + "\0后段",
      String(repeating: "鼠标里面的硅二极管坏了，导致光标分辨率降低。\n\n", count: 5000)
    ]
    let allOptions: [ChineseConverter.Options] = [
      .simplify, .traditionalize,
      [.traditionalize, .twIdiom], [.traditionalize, .twStandard],
      [.traditionalize, .twStandard, .twIdiom], [.traditionalize, .hkStandard],
      [.traditionalize, .hkStandard, .twIdiom]
    ]
    for options in allOptions {
      let converter = try ChineseConversionService.converter(options: options)
      let reusedConverter = try ChineseConversionService.converter(options: options)
      precondition(converter === reusedConverter, "Reuse the compiled converter")
      for fixture in fixtures {
        let result = try await ChineseConversionService.shared.convert(fixture, options: options)
        precondition(result == converter.convert(fixture), "Full-text conversion must preserve OpenCC semantics")
      }
      let input = "\0鼠标\0\0汉字\0 😀 e\u{301}\r\n"
      let expected: String
      if options == .simplify {
        expected = "\0鼠标\0\0汉字\0 😀 e\u{301}\r\n"
      } else if options.contains(.twIdiom) {
        expected = "\0滑鼠\0\0漢字\0 😀 e\u{301}\r\n"
      } else {
        expected = "\0鼠標\0\0漢字\0 😀 e\u{301}\r\n"
      }
      // Also exercise an input decoded by Foundation, rather than a Swift literal.
      let cocoaInput = NSString(data: Data(input.utf8), encoding: String.Encoding.utf8.rawValue)! as String
      let synchronous = try ChineseConversionService.convertSynchronously(cocoaInput, options: options)
      let asynchronous = try await ChineseConversionService.shared.convert(input, options: options)
      precondition(Data(synchronous.utf8) == Data(expected.utf8), "Every NUL and suffix must survive the byte-length bridge")
      precondition(Data(asynchronous.utf8) == Data(expected.utf8), "Background conversion shares the NUL contract")
    }
    let phrase = try await ChineseConversionService.shared.convert(fixtures[4], options: [.traditionalize, .twIdiom])
    precondition(phrase == String(repeating: "a", count: 3999) + "滑鼠", "Do not split a phrase at the old 4000-character boundary")
    let formatting = "\n\nASCII\n\n\n\r\n" + String(repeating: "x", count: 8001) + "\n\n"
    let unchanged = try await ChineseConversionService.shared.convert(formatting, options: .traditionalize)
    precondition(unchanged == formatting, "No insertion, deletion or reordering of separators")
    let nullDelimited = "\0鼠标\0\0汉字\0"
    let nullConverted = try await ChineseConversionService.shared.convert(nullDelimited, options: [.traditionalize, .twIdiom])
    precondition(nullConverted == "\0滑鼠\0\0漢字\0", "The byte-length bridge must not truncate text at U+0000")
    let synchronousNullConverted = try ChineseConversionService.convertSynchronously(nullDelimited, options: [.traditionalize, .twIdiom])
    precondition(synchronousNullConverted == nullConverted)
    print("PASS: 7 option combinations × \(fixtures.count) fixtures; fixed NUL contracts, phrase boundaries, whitespace, Unicode and converter reuse")

    let diffOptions: ChineseConverter.Options = [.traditionalize, .twStandard, .twIdiom]
    let diffSample = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
    let diffResult = try await ChineseConversionService.shared.convert(diffSample, options: diffOptions)
    precondition(diffResult.utf8.elementsEqual("滑鼠裡面的矽二極體壞了，導致游標解析度降低。".utf8))
    for separator in ["", "\r\n", "\r", "\u{2028}", "\u{2029}", "\0", "\u{FEFF}"] {
      let source = separator + diffSample + separator
      let result = try await ChineseConversionService.shared.convert(source, options: diffOptions)
      precondition(result.utf8.elementsEqual((separator + diffResult + separator).utf8))
      guard case let .computed(hunks) = ConversionDiff.compute(
        source: source, result: result, limits: .init(characters: 1000, cells: 100_000, hunks: 100)) else {
        fatalError("Real OpenCC sample must have a complete diff")
      }
      let a = Array(source), b = Array(result)
      var restored = "", cursor = 0
      for h in hunks {
        restored += String(a[cursor..<h.source.lowerBound]) + String(b[h.result])
        cursor = h.source.upperBound
      }
      restored += String(a[cursor...])
      precondition(restored.utf8.elementsEqual(result.utf8))
    }
    print("PASS: live pinned OpenCC diff oracle, separator preservation and byte-exact hunk reconstruction")

    weak var releasedModel: HomeViewModel?
    autoreleasepool {
      let model = HomeViewModel()
      releasedModel = model
    }
    precondition(releasedModel == nil, "Combine subscriptions must not retain the view model")

    let exampleModel = HomeViewModel()
    precondition(exampleModel.inputText.isEmpty && exampleModel.resultText.isEmpty && exampleModel.exportSnapshot == nil)
    precondition(exampleModel.canFillExample && coreQuotaCount == 0)
    exampleModel.fillExampleIfEmpty()
    precondition(exampleModel.inputText == HomeViewModel.exampleSourceText && coreQuotaCount == 0,
                 "Trying the example only fills the source and does not reserve quota")
    exampleModel.inputText = "My own draft"
    exampleModel.fillExampleIfEmpty()
    precondition(exampleModel.inputText == "My own draft", "The example cannot overwrite a draft")
    exampleModel.inputText = ""
    exampleModel.resultText = "Previous result"
    exampleModel.fillExampleIfEmpty()
    precondition(exampleModel.inputText.isEmpty && exampleModel.resultText == "Previous result",
                 "The example cannot discard a result")

    let clearModel = HomeViewModel()
    let otherWindow = HomeViewModel()
    otherWindow.inputText = "Another window's draft"
    precondition(!clearModel.canClearSource)
    clearModel.fillExampleIfEmpty()
    precondition(clearModel.canClearSource)
    clearModel.clearSource()
    precondition(clearModel.inputText.isEmpty && !clearModel.canClearSource && coreQuotaCount == 0,
                 "Clearing an example leaves an empty, uncharged draft")
    clearModel.replaceSource(String(repeating: "鼠标", count: 100_000), sourceFilename: "pending.txt")
    clearModel.translate()
    precondition(clearModel.isLoading)
    clearModel.clearSource()
    _ = try await ChineseConversionService.shared.convert("", options: .simplify)
    await Task.yield()
    precondition(clearModel.inputText.isEmpty && clearModel.resultText.isEmpty && clearModel.exportSnapshot == nil)
    precondition(clearModel.sourceFilename == nil && !clearModel.isLoading && coreQuotaCount == 0,
                 "Clearing a running conversion releases its reservation and ignores late output")
    precondition(otherWindow.inputText == "Another window's draft", "Clear must affect only its window")

    let pendingImport = FileManager.default.temporaryDirectory.appendingPathComponent("openccman-clear-\(UUID().uuidString).txt")
    try Data("Imported draft".utf8).write(to: pendingImport)
    defer { try? FileManager.default.removeItem(at: pendingImport) }
    clearModel.replaceSource("Draft before import", sourceFilename: "old.txt")
    clearModel.importFile(pendingImport)
    precondition(clearModel.isImporting)
    clearModel.clearSource()
    precondition(!clearModel.isImporting && clearModel.inputText.isEmpty && clearModel.sourceFilename == nil,
                 "Clear cancels an import and removes the previous filename")

    do {
      UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isPro.rawValue)
      defer { UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.isPro.rawValue) }
      clearModel.replaceSource("鼠标", sourceFilename: "draft.txt")
      clearModel.translate()
      await waitUntilIdle(clearModel)
      precondition(clearModel.exportSnapshot?.filename == "draft-converted.txt")
      clearModel.clearSource()
      precondition(clearModel.inputText.isEmpty && clearModel.resultText.isEmpty && clearModel.sourceFilename == nil)
      precondition(clearModel.exportSnapshot == nil && clearModel.resultConfiguration == nil,
                   "Clear removes result provenance and the exportable snapshot")
      precondition(coreQuotaCount == 0, "Clearing and Pro conversion do not consume free quota")
    }

    let model = HomeViewModel()
    var nonemptyResults = 0
    let observation = model.$resultText.sink { if !$0.isEmpty { nonemptyResults += 1 } }
    model.inputText = fixtures[3]
    model.translate()
    model.translate()
    await waitUntilIdle(model)
    precondition(coreQuotaCount == 1, "Repeated taps must not overlap or consume two uses")
    precondition(nonemptyResults == 1, "Publish the final text once")
    precondition(model.resultText.hasPrefix("前段\n\n"), "Do not drop the paragraph preceding a long paragraph")
    precondition(model.localProgress == 1 && model.error == nil)
    observation.cancel()
    precondition(!model.resultConfigurationChanged)
    let resultBeforeSettings = model.resultText
    let configBeforeSettings = model.configuration
    model.applyPreset(.hongKong)
    precondition(model.resultConfigurationChanged)
    precondition(model.resultText == resultBeforeSettings && coreQuotaCount == 1,
                 "Changing settings retains prior result without charging")
    model.targetOptions = configBeforeSettings.target
    model.variantOptions = configBeforeSettings.variant
    model.regionOptions = configBeforeSettings.region
    precondition(!model.resultConfigurationChanged)

    let previousExport = model.exportSnapshot
    precondition(previousExport != nil)
    model.translate()
    model.cancelConversion()
    precondition(model.exportSnapshot == previousExport, "Cancellation keeps the latest successful export")
    model.inputText = fixtures.last!
    model.translate()
    model.cancelConversion()
    model.inputText = "鼠标"
    model.regionOptions = .taiwan
    model.translate()
    await waitUntilIdle(model)
    precondition(model.resultText == "滑鼠", "Cancelled work must not overwrite its replacement")
    precondition(coreQuotaCount == 2, "Cancelled work must not consume quota")
    model.inputText = ""
    model.translate()
    precondition(!model.isLoading && coreQuotaCount == 2)
    for _ in 2..<12 { TestNumbersPerDayManager.reserve()!.commit() }
    model.inputText = "汉"
    model.translate()
    model.translate()
    precondition(model.showingProAlert && !model.isLoading, "A repeated limit action must not hide the alert")
    print("PASS: model release, repeated taps, single publication, cancellation/replacement, empty input and quota guard")
    try await checkPresetsAndFiles()
    try await checkProviders()
    try await checkStreamingFiles()
    try await LargeFileCoordinatorChecks.run()
    try await BatchCoordinatorChecks.run()
    if #available(macOS 13.0, *) {
      try await ShortcutsChecks.run()
    }
    precondition(clearModel.inputText.isEmpty && clearModel.resultText.isEmpty && clearModel.exportSnapshot == nil,
                 "A cancelled import or conversion cannot republish after other checks complete")
    try await checkDiffLifecycle()
  }

  @MainActor private static func checkDiffLifecycle() async throws {
    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isPro.rawValue)
    defer { UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.isPro.rawValue) }
    let model = HomeViewModel()
    model.applyPreset(.taiwan)
    model.inputText = HomeViewModel.exampleSourceText
    model.translate()
    await waitUntilIdle(model)
    let snapshot = model.diffSnapshot!
    let exported = model.exportSnapshot
    let quota = coreQuotaCount
    precondition(!model.showsDifferences && model.diffDisplay == nil && !model.diffComputing,
                 "Successful conversion must not calculate differences by default")
    precondition(snapshot.source == HomeViewModel.exampleSourceText && snapshot.result == model.resultText)
    precondition(snapshot.configuration == model.configuration)
    model.showsDifferences = true
    await waitForDiff(model)
    precondition(model.diffDisplay?.id == snapshot.id && !(model.diffDisplay?.sourceRanges.isEmpty ?? true))
    precondition(model.currentDiffIndex == nil, "Showing decoration alone must not request a selection change")
    model.navigateDiff(by: 1)
    precondition(model.currentDiffIndex == 0 && model.diffNavigationID != nil)
    model.navigateDiff(by: -1)
    precondition(model.currentDiffIndex == model.diffDisplay!.sourceRanges.count - 1)
    precondition(model.exportSnapshot == exported && coreQuotaCount == quota,
                 "Showing and navigating differences cannot change export or consume quota")
    model.showsDifferences = false
    model.showsDifferences = true
    precondition(model.diffComputing)
    model.inputText = "互联网"
    precondition(model.diffSnapshot == nil && model.diffDisplay == nil && !model.diffComputing)
    model.translate()
    await waitUntilIdle(model)
    await waitForDiff(model)
    precondition(model.diffSnapshot?.id != snapshot.id && model.diffDisplay?.id == model.diffSnapshot?.id)
    precondition(model.diffSnapshot?.source == "互联网", "Old worker must not overwrite the replacement snapshot")
    let replacementExport = model.exportSnapshot
    model.regionOptions = .notConvert
    precondition(model.diffSnapshot == nil && model.diffDisplay == nil)
    precondition(model.exportSnapshot == replacementExport, "Configuration invalidation preserves export semantics")
    model.translate()
    await waitUntilIdle(model)
    await waitForDiff(model)
    model.replaceSource(model.inputText)
    precondition(model.diffSnapshot == nil, "Import/paste of identical text still invalidates provenance")
    model.inputText = "e\u{301}汉"
    model.translate()
    await waitUntilIdle(model)
    model.inputText = "é汉"
    precondition(model.diffSnapshot == nil && model.resultText.isEmpty, "Canonical equality cannot hide a byte change")
    model.inputText = String(repeating: "汉", count: 50_001)
    model.translate()
    await waitUntilIdle(model)
    await waitForDiff(model)
    precondition(model.diffTooLarge && model.diffDisplay == nil && model.exportSnapshot != nil)
    model.cancelConversion()
    precondition(model.diffSnapshot == nil && !model.diffTooLarge && !model.diffComputing)
    print("PASS: real diff snapshot lifecycle, default-off, navigation, unchanged quota/export, stale worker rejection and over-limit UI state")
  }

  @MainActor private static func waitForDiff(_ model: HomeViewModel) async {
    for _ in 0..<5000 {
      if !model.diffComputing { return }
      try? await Task.sleep(nanoseconds: 1_000_000)
    }
    preconditionFailure("Difference computation did not settle within five seconds")
  }

  @MainActor private static func waitUntilIdle(_ model: HomeViewModel) async {
    guard model.isLoading else { return }
    await withCheckedContinuation { continuation in
      var observation: AnyCancellable?
      observation = model.$isLoading.filter { !$0 }.first().sink { _ in
        continuation.resume()
        observation?.cancel()
        observation = nil
      }
    }
  }
}

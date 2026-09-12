import Combine
import Foundation
import OpenCC

@main enum CoreChecks {
  @MainActor static func main() async throws {
    defer {
      appDefaults.defaults.removePersistentDomain(forName: coreSuite)
      UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastVersionPromptedForReview.rawValue)
    }
    let fixtures = [
      "", "\n\n前段\n\n后段\n\n", "\r\n鼠标\r\n\r\n台湾\r\n",
      "前段\n\n" + String(repeating: "汉", count: 4001),
      String(repeating: "a", count: 3999) + "鼠标",
      "\n\n" + String(repeating: "甲\n\n", count: 1500) + "\n\n",
      "👨‍👩‍👧‍👦🇹🇼e\u{301} 简体中文\t鼠标\u{2028}台湾",
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
    }
    let phrase = try await ChineseConversionService.shared.convert(fixtures[4], options: [.traditionalize, .twIdiom])
    precondition(phrase == String(repeating: "a", count: 3999) + "滑鼠", "Do not split a phrase at the old 4000-character boundary")
    let formatting = "\n\nASCII\n\n\n\r\n" + String(repeating: "x", count: 8001) + "\n\n"
    let unchanged = try await ChineseConversionService.shared.convert(formatting, options: .traditionalize)
    precondition(unchanged == formatting, "No insertion, deletion or reordering of separators")
    let nullDelimited = "\0鼠标\0\0汉字\0"
    let nullConverted = try await ChineseConversionService.shared.convert(nullDelimited, options: [.traditionalize, .twIdiom])
    precondition(nullConverted == "\0滑鼠\0\0漢字\0", "The C-string bridge must not truncate text at U+0000")
    let synchronousNullConverted = try ChineseConversionService.convertSynchronously(nullDelimited, options: [.traditionalize, .twIdiom])
    precondition(synchronousNullConverted == nullConverted)
    print("PASS: 7 option combinations × 8 fixtures; phrase boundaries, whitespace, Unicode and converter reuse")

    weak var releasedModel: HomeViewModel?
    autoreleasepool {
      let model = HomeViewModel()
      releasedModel = model
    }
    precondition(releasedModel == nil, "Combine subscriptions must not retain the view model")

    let model = HomeViewModel()
    var nonemptyResults = 0
    let observation = model.$resultText.sink { if !$0.isEmpty { nonemptyResults += 1 } }
    model.inputText = fixtures[3]
    model.translate()
    model.translate()
    await waitUntilIdle(model)
    precondition(TestNumbersPerDayManager.count == 1, "Repeated taps must not overlap or consume two uses")
    precondition(nonemptyResults == 1, "Publish the final text once")
    precondition(model.resultText.hasPrefix("前段\n\n"), "Do not drop the paragraph preceding a long paragraph")
    precondition(model.localProgress == 1 && model.error == nil)
    observation.cancel()

    model.inputText = fixtures.last!
    model.translate()
    model.cancelConversion()
    model.inputText = "鼠标"
    model.regionOptions = .taiwan
    model.translate()
    await waitUntilIdle(model)
    precondition(model.resultText == "滑鼠", "Cancelled work must not overwrite its replacement")
    precondition(TestNumbersPerDayManager.count == 2, "Cancelled work must not consume quota")
    model.inputText = ""
    model.translate()
    precondition(!model.isLoading && TestNumbersPerDayManager.count == 2)
    TestNumbersPerDayManager.isToMax = true
    model.inputText = "汉"
    model.translate()
    model.translate()
    precondition(model.showingProAlert && !model.isLoading, "A repeated limit action must not hide the alert")
    print("PASS: model release, repeated taps, single publication, cancellation/replacement, empty input and quota guard")
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

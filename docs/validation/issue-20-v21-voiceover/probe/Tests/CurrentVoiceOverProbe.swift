import XCTest

@MainActor
final class CurrentVoiceOverProbe: XCTestCase {
  private let bundleID = "org.gewill.OpenCCman.Issue20QA20260928"

  func testHomeAndConvertedResultSpeech() throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: bundleID)
    let service = XCUIDevice.shared.voiceOverService
    let wasEnabled = service.isEnabled
    defer {
      if !wasEnabled { try? service.disable() }
      app.terminate()
    }

    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    if app.staticTexts["What's New"].waitForExistence(timeout: 2) {
      app.buttons["Done"].tap()
    }
    let convert = app.buttons["Convert"]
    XCTAssertTrue(convert.waitForExistence(timeout: 15))

    if !wasEnabled { try service.enable() }
    let home = try speechSequence(service, count: 18)
    attach(home, name: "home-voiceover-speech")
    XCTAssertTrue(home.contains { $0.contains("Source") }, "VoiceOver must identify the source editor")
    XCTAssertTrue(home.contains { $0.contains("Result") }, "VoiceOver must identify the result editor")
    XCTAssertTrue(home.contains { $0.contains("Convert") }, "VoiceOver must expose the main conversion action")

    if !wasEnabled { try service.disable() }
    convert.tap()
    let copy = app.buttons["Copy Result"]
    let enabled = NSPredicate(format: "enabled == true")
    expectation(for: enabled, evaluatedWith: copy)
    waitForExpectations(timeout: 20)
    // The first successful conversion can present the app's rating request.
    // Dismiss it so the result editor, not the modal, is the speech target.
    if app.buttons["Not Now"].waitForExistence(timeout: 5) {
      app.buttons["Not Now"].tap()
    }
    let result = app.textViews["Result"]
    XCTAssertTrue(result.exists)
    let expected = result.value as? String ?? ""
    XCTAssertTrue(expected.contains("鼠標"), "Conversion must produce the expected traditional sample")

    if !wasEnabled { try service.enable() }
    var converted = [(try service.currentSpeech()).utterance]
    for _ in 0..<25 {
      if converted.last?.contains("鼠標裏面的硅二極管壞了") == true { break }
      converted.append((try service.moveForward()).utterance)
    }
    attach(converted, name: "converted-voiceover-speech")
    XCTAssertTrue(converted.contains { $0.contains("鼠標裏面的硅二極管壞了") },
                  "VoiceOver must speak the converted result text")
    XCTAssertFalse(converted.contains { $0.contains("Result Text field Double tap to edit") },
                   "Result must not be announced as editable")
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "converted-voiceover-window"
    screenshot.lifetime = .keepAlways
    add(screenshot)

    if !wasEnabled { try service.disable() }
    result.tap()
    XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2),
                   "Tapping the read-only result must not show a keyboard")
    XCTAssertEqual(result.value as? String, expected,
                   "Tapping the result must not alter converted text")
  }

  func testPresetSheetSpeechAndDisabledOptions() throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: bundleID)
    let service = XCUIDevice.shared.voiceOverService
    let wasEnabled = service.isEnabled
    defer {
      if !wasEnabled { try? service.disable() }
      app.terminate()
    }

    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    if app.staticTexts["What's New"].waitForExistence(timeout: 2) {
      app.buttons["Done"].tap()
    }
    let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Conversion settings")).firstMatch
    XCTAssertTrue(settings.waitForExistence(timeout: 15))
    settings.tap()
    XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
    // Each simulator test reuses the QA bundle's preferences. Establish the
    // starting preset explicitly instead of assuming a fresh installation.
    app.buttons["Traditional · OpenCC"].firstMatch.tap()

    if !wasEnabled { try service.enable() }
    let initial = try speechSequence(service, count: 16)
    attach(initial, name: "preset-sheet-initial-speech")
    XCTAssertTrue(initial.contains { $0.contains("Traditional · OpenCC") && $0.lowercased().contains("selected") },
                  "Starting preset must be announced as selected")
    XCTAssertTrue(initial.contains { $0.contains("Target Language") },
                  "Advanced settings group must be announced")

    if !wasEnabled { try service.disable() }
    let simplified = app.buttons["Simplified Chinese"].firstMatch
    XCTAssertTrue(simplified.exists)
    simplified.tap()
    XCTAssertFalse(app.buttons["OpenCC Standard"].isEnabled)
    XCTAssertFalse(app.buttons["Taiwan Idiom"].isEnabled)

    if !wasEnabled { try service.enable() }
    let selected = try speechSequence(service, count: 16)
    attach(selected, name: "preset-sheet-simplified-speech")
    XCTAssertTrue(selected.contains { $0.contains("Simplified Chinese") && $0.lowercased().contains("selected") },
                  "Selected simplified preset must be announced")
    XCTAssertTrue(selected.contains { $0.contains("OpenCC Standard") && $0.contains("dimmed") },
                  "Disabled advanced option must be announced")
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "preset-sheet-simplified"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  private func speechSequence(_ service: XCUIVoiceOverService, count: Int) throws -> [String] {
    var speech = [(try service.currentSpeech()).utterance]
    for _ in 0..<count { speech.append((try service.moveForward()).utterance) }
    return speech
  }

  private func attach(_ speech: [String], name: String) {
    let output = speech.enumerated().map { "\($0.offset): \($0.element)" }.joined(separator: "\n")
    print("OPENCCMAN_\(name)\n\(output)\nOPENCCMAN_END_\(name)")
    let attachment = XCTAttachment(string: output)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

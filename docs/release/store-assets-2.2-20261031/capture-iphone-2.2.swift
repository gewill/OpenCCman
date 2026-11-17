import XCTest

/// 2.2 iPhone store capture. Drives the isolated QA bundle through the system
/// navigation bar controls; conversion uses the real engine and editors.
final class WhatsNewPresentationTests: XCTestCase {
  private let appID = "org.gewill.OpenCCman.WhatsNewUITests"

  override func setUpWithError() throws { continueAfterFailure = false }

  private func screenshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func pause(_ seconds: TimeInterval, _ pacing: Bool) {
    if pacing { Thread.sleep(forTimeInterval: seconds) }
  }

  private func capture(locale: String, done: String, cancel: String, pacing: Bool) {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(\(locale))", "-isPro", "NO",
                           "-qa-mark-whats-new-read-at-launch", "-qa-suppress-review",
                           "-skip-launch-transition", "-lastVersionPromptedForReview", "2.2"]
    app.launch()
    defer { app.terminate() }
    let example = app.buttons["source-fill-example"]
    XCTAssertTrue(example.waitForExistence(timeout: 20), app.debugDescription)
    screenshot(app, "\(locale)-02-empty")
    pause(1.5, pacing)
    example.tap()
    let source = app.textViews["workspace-source-editor"]
    let filled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value != %@ AND value != nil", ""), object: source)
    XCTAssertEqual(XCTWaiter().wait(for: [filled], timeout: 10), .completed)
    pause(1.4, pacing)
    app.buttons["workspace-convert"].tap()
    let result = app.textViews["workspace-result-editor"]
    let converted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS %@", "二極管"), object: result)
    XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 12), .completed)
    screenshot(app, "\(locale)-01-converted")
    pause(2.0, pacing)
    app.buttons["workspace-conversion-settings"].tap()
    XCTAssertTrue(app.buttons[done].waitForExistence(timeout: 8), app.debugDescription)
    pause(0.8, true)
    screenshot(app, "\(locale)-03-presets")
    pause(2.0, pacing)
    app.buttons[done].tap()
    XCTAssertTrue(app.buttons["source-clear"].waitForExistence(timeout: 8))
    pause(0.6, true)
    app.buttons["source-clear"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    pause(0.5, true)
    screenshot(app, "\(locale)-04-clear")
    pause(2.0, pacing)
    app.alerts.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS %@", cancel)).firstMatch.tap()
    XCTAssertTrue((result.value as? String ?? "").contains("二極管"))
    pause(1.0, pacing)
  }

  func testShotsEnglish() { capture(locale: "en", done: "Done", cancel: "Cancel", pacing: false) }
  func testShotsHans() { capture(locale: "zh-Hans", done: "完成", cancel: "取消", pacing: false) }
  func testShotsHant() { capture(locale: "zh-Hant", done: "完成", cancel: "取消", pacing: false) }
  func testPreviewEnglish() { capture(locale: "en", done: "Done", cancel: "Cancel", pacing: true) }
  func testPreviewHans() { capture(locale: "zh-Hans", done: "完成", cancel: "取消", pacing: true) }
  func testPreviewHant() { capture(locale: "zh-Hant", done: "完成", cancel: "取消", pacing: true) }
}

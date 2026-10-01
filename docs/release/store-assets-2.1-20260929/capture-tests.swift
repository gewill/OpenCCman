import XCTest

final class WhatsNewPresentationTests: XCTestCase {
  private let appID = "org.gewill.OpenCCman.WhatsNewUITests"

  override func setUpWithError() throws { continueAfterFailure = false }

  private func screenshot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func capture(locale: String, fill: String, convert: String,
                       settings: String, done: String, resultLabel: String,
                       pacing: Bool = false) {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(\(locale))",
                           "-qa-mark-whats-new-read-at-launch", "-qa-suppress-review",
                           "-skip-launch-transition", "-lastVersionPromptedForReview", "2.1"]
    app.launch()
    defer { app.terminate() }
    XCTAssertTrue(app.buttons[fill].waitForExistence(timeout: 20), app.debugDescription)
    screenshot(app, "\(locale)-01-empty")
    if pacing { Thread.sleep(forTimeInterval: 1.5) }
    app.buttons[fill].tap()
    XCTAssertTrue(app.buttons["source-clear"].waitForExistence(timeout: 5))
    screenshot(app, "\(locale)-02-example")
    if pacing { Thread.sleep(forTimeInterval: 1.4) }
    app.buttons[convert].tap()
    let result = app.textViews[resultLabel]
    XCTAssertTrue(result.waitForExistence(timeout: 12))
    let converted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS %@", "二極管"), object: result)
    XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 12), .completed)
    screenshot(app, "\(locale)-03-converted")
    if pacing { Thread.sleep(forTimeInterval: 2.0) }
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", settings)).firstMatch.tap()
    XCTAssertTrue(app.buttons[done].waitForExistence(timeout: 8))
    screenshot(app, "\(locale)-04-presets")
    if pacing { Thread.sleep(forTimeInterval: 2.0) }
    app.buttons[done].tap()
    app.buttons["source-clear"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    screenshot(app, "\(locale)-05-clear-confirmation")
    if pacing { Thread.sleep(forTimeInterval: 2.0) }
    app.alerts.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS %@", locale == "en" ? "Cancel" : "取消")).firstMatch.tap()
    if pacing { Thread.sleep(forTimeInterval: 0.6) }
  }

  private func captureIpad(locale: String, fill: String, convert: String, resultLabel: String, stacked: String) {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(\(locale))", "-qa-mark-whats-new-read-at-launch",
                           "-qa-suppress-review", "-skip-launch-transition",
                           "-lastVersionPromptedForReview", "2.1"]
    app.launch()
    defer { app.terminate() }
    XCTAssertTrue(app.buttons[fill].waitForExistence(timeout: 20), app.debugDescription)
    app.buttons[fill].tap()
    app.buttons[convert].tap()
    let result = app.textViews[resultLabel]
    XCTAssertTrue(result.waitForExistence(timeout: 12))
    let converted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS %@", "二極管"), object: result)
    XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 12), .completed)
    screenshot(app, "\(locale)-ipad-01-side-by-side")
    XCTAssertTrue(app.buttons[stacked].waitForExistence(timeout: 5), app.debugDescription)
    app.buttons[stacked].tap()
    screenshot(app, "\(locale)-ipad-02-stacked")
  }

  func testIpadEnglish() {
    captureIpad(locale: "en", fill: "Try an example", convert: "Convert", resultLabel: "Result", stacked: "Stacked")
  }
  func testIpadHans() {
    captureIpad(locale: "zh-Hans", fill: "填入示例", convert: "转换", resultLabel: "结果", stacked: "上下")
  }
  func testIpadHant() {
    captureIpad(locale: "zh-Hant", fill: "填入範例", convert: "轉換", resultLabel: "結果", stacked: "上下")
  }

  func testCaptureEnglish() {
    capture(locale: "en", fill: "Try an example", convert: "Convert",
            settings: "Conversion settings", done: "Done", resultLabel: "Result", pacing: true)
  }
  func testCaptureHans() {
    capture(locale: "zh-Hans", fill: "填入示例", convert: "转换",
            settings: "转换设置", done: "完成", resultLabel: "结果", pacing: true)
  }
  func testCaptureHant() {
    capture(locale: "zh-Hant", fill: "填入範例", convert: "轉換",
            settings: "轉換設定", done: "完成", resultLabel: "結果")
  }
}

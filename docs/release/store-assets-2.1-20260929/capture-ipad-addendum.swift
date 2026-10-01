import XCTest

final class WhatsNewPresentationTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func shot(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func capture(_ locale: String, fill: String, convert: String, resultLabel: String) {
    let app = XCUIApplication(bundleIdentifier: "org.gewill.OpenCCman.WhatsNewUITests")
    app.launchArguments = ["-AppleLanguages", "(\(locale))", "-qa-mark-whats-new-read-at-launch",
                           "-qa-suppress-review", "-skip-launch-transition", "-lastVersionPromptedForReview", "2.1"]
    app.launch()
    defer { app.terminate() }
    XCTAssertTrue(app.buttons[fill].waitForExistence(timeout: 20), app.debugDescription)
    shot(app, "\(locale)-ipad-03-empty")
    app.buttons[fill].tap()
    app.buttons[convert].tap()
    let result = app.textViews[resultLabel]
    XCTAssertTrue(result.waitForExistence(timeout: 12))
    let converted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "二極管"), object: result)
    XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 12), .completed)
    app.buttons["source-clear"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    shot(app, "\(locale)-ipad-04-clear")
  }

  func testScreenshotsEnglish() { capture("en", fill: "Try an example", convert: "Convert", resultLabel: "Result") }
  func testScreenshotsHans() { capture("zh-Hans", fill: "填入示例", convert: "转换", resultLabel: "结果") }
  func testScreenshotsHant() { capture("zh-Hant", fill: "填入範例", convert: "轉換", resultLabel: "結果") }
}

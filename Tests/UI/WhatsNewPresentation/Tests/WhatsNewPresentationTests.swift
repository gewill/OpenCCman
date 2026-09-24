import XCTest

final class WhatsNewPresentationTests: XCTestCase {
  private let appID = "org.gewill.OpenCCman.WhatsNewUITests"

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launch(_ arguments: String...) -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(en)", "-qa-mark-whats-new-read-at-launch"] + arguments
    app.launch()
    XCTAssertTrue(app.buttons["Convert"].waitForExistence(timeout: 20))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    return app
  }

  private func capture(_ app: XCUIApplication, name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func expectCardsOnce(_ app: XCUIApplication) {
    let done = app.buttons["whats-new-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 15))
    capture(app, name: "cards-after-task")
    done.tap()
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: done)
    XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed)
    XCTAssertFalse(done.waitForExistence(timeout: 2), "Cards must not reopen after dismissal")
  }

  func testImportCancellationDefersCards() {
    let app = launch("-qa-unread-whats-new-on-import")
    defer { app.terminate() }
    app.buttons["Import TXT"].tap()
    let cancel = app.buttons["Cancel"].firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 15))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "native-importer-without-cards")
    cancel.tap()
    expectCardsOnce(app)
  }

  func testReviewRemainsAvailableAfterCardsWereRead() {
    let app = launch()
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.buttons["Copy Result"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    let laterReview = app.buttons["Not Now"]
    XCTAssertTrue(laterReview.waitForExistence(timeout: 10),
                  "A later successful conversion can still request a review")
    capture(app, name: "review-after-cards-were-read")
    laterReview.tap()
  }

  func testConversionSuccessDefersCards() {
    let app = launch("-qa-unread-whats-new-on-convert", "-qa-delay-conversion")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "conversion-running-without-cards")
    expectCardsOnce(app)
    XCTAssertTrue(app.buttons["Copy Result"].isEnabled)
    Thread.sleep(forTimeInterval: 3)
    XCTAssertFalse(app.buttons["Not Now"].exists,
                   "A review prompt must not immediately follow the first What’s New sheet")
    capture(app, name: "workspace-after-cards-no-review")
  }

  func testConversionCancellationDefersCardsAndKeepsResultEmpty() {
    let app = launch("-qa-unread-whats-new-on-convert", "-qa-delay-conversion")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    let cancel = app.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    cancel.tap()
    expectCardsOnce(app)
    XCTAssertFalse(app.buttons["Copy Result"].isEnabled)
    // The cancelled conversion must not write a late result after its delay.
    Thread.sleep(forTimeInterval: 3)
    XCTAssertFalse(app.buttons["Copy Result"].isEnabled)
  }

  func testConversionFailureShowsErrorBeforeCards() {
    let app = launch("-qa-unread-whats-new-on-convert", "-qa-delay-conversion", "-qa-fail-conversion")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    let alert = app.alerts["Error"]
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "conversion-error-without-cards")
    alert.buttons["OK"].tap()
    expectCardsOnce(app)
    XCTAssertFalse(app.buttons["Copy Result"].isEnabled)
  }
}

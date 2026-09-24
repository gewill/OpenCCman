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

  func testExportPanelDoesNotOverlapCards() {
    let app = launch("-qa-suppress-review", "-qa-unread-whats-new-on-export")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.buttons["Export TXT"].waitForExistence(timeout: 10))
    app.buttons["Export TXT"].tap()
    let picker = app.otherElements["Browse View (Picker)"]
    XCTAssertTrue(picker.waitForExistence(timeout: 15))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "native-exporter-without-cards")
    // The Files browser is hosted by a system extension. On iPhone its Browse
    // button can lead to a parent location before Cancel becomes available,
    // and neither control is consistently exposed in the app's XCUI tree.
    // Tap the top-left navigation control until the picker closes, then assert
    // the pending cards appear. Keep the iPad assertion above independent of
    // this iPhone-specific system navigation layout.
    if app.frame.width < 600 {
      let topLeftNavigation = app.coordinate(withNormalizedOffset: CGVector(dx: 0.115, dy: 0.105))
      for _ in 0..<3 where picker.exists {
        topLeftNavigation.tap()
        Thread.sleep(forTimeInterval: 0.7)
      }
      XCTAssertFalse(picker.exists, "The native exporter must close after cancelling")
      expectCardsOnce(app)
    }
  }

  func testQuotaAlertAndProSheetDeferCards() {
    let app = launch("-qa-exhaust-quota", "-qa-unread-whats-new-on-pro-alert")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.staticTexts["Pro only feature"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "quota-alert-without-cards")
    app.buttons["Pro"].tap()
    let close = app.buttons["pro-sheet-close"]
    XCTAssertTrue(close.waitForExistence(timeout: 15))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "pro-sheet-without-cards")
    close.tap()
    expectCardsOnce(app)
  }

  func testLandscapeCardsRemainDismissible() {
    XCUIDevice.shared.orientation = .portrait
    let app = launch("-qa-suppress-review", "-qa-unread-whats-new-on-convert")
    defer {
      XCUIDevice.shared.orientation = .portrait
      app.terminate()
    }
    app.buttons["Convert"].tap()
    let done = app.buttons["whats-new-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 15))
    XCUIDevice.shared.orientation = .landscapeLeft
    let deadline = Date().addingTimeInterval(10)
    while app.frame.width <= app.frame.height && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.2)
    }
    XCTAssertGreaterThan(app.frame.width, app.frame.height, "The simulator must finish rotating before layout assertions")
    Thread.sleep(forTimeInterval: 1)
    XCTAssertTrue(done.waitForExistence(timeout: 10))
    XCTAssertTrue(done.isHittable, "The sheet dismissal control must remain reachable in landscape")
    capture(app, name: "whats-new-landscape")
    done.tap()
    XCTAssertFalse(done.waitForExistence(timeout: 2))
  }

  func testCardsCanBeDismissedWithSystemSwipe() {
    let app = launch("-qa-suppress-review", "-qa-unread-whats-new-on-convert")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    let done = app.buttons["whats-new-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 15))
    let sheet = app.otherElements["whats-new-sheet"]
    XCTAssertTrue(sheet.exists)
    capture(app, name: "cards-before-swipe")
    sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
      .press(forDuration: 0.05,
             thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
    XCTAssertFalse(done.waitForExistence(timeout: 4), "The native sheet should dismiss after a downward drag")
    capture(app, name: "workspace-after-swipe")
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

  func testVoiceOverCardReadingOrder() throws {
    guard #available(iOS 27.0, *) else {
      throw XCTSkip("VoiceOver speech automation requires iOS 27")
    }
    let app = launch("-qa-suppress-review", "-qa-unread-whats-new-on-convert")
    defer { app.terminate() }
    app.buttons["Convert"].tap()
    XCTAssertTrue(app.buttons["whats-new-done"].waitForExistence(timeout: 15))
    capture(app, name: "voiceover-whats-new-sheet")

    let voiceOver = XCUIDevice.shared.voiceOverService
    let wasEnabled = voiceOver.isEnabled
    defer {
      if !wasEnabled {
        do {
          try voiceOver.disable()
          XCTAssertFalse(voiceOver.isEnabled, "The test must restore VoiceOver to its initial state")
        } catch {
          XCTFail("Could not restore VoiceOver: \(error)")
        }
      }
    }
    if !wasEnabled { try voiceOver.enable() }

    var utterances = [try voiceOver.currentSpeech().utterance]
    for _ in 0..<8 {
      let utterance = try voiceOver.moveForward().utterance
      if utterance == utterances.last { break }
      utterances.append(utterance)
      if utterance.hasPrefix("Done") { break }
    }
    print("VOICEOVER_UTTERANCES: \(utterances)")
    let expectedStarts = [
      "OpenCCman What’s New", "OpenCCman 2.0", "A workspace that fits your screen",
      "Your conversion, one tap away", "Bring your text files", "Stay in control", "Done"
    ]
    XCTAssertEqual(utterances.count, expectedStarts.count, "Every card must lead to the dismissal button")
    for (actual, expected) in zip(utterances, expectedStarts) {
      XCTAssertTrue(actual.hasPrefix(expected), "Expected \(expected), heard \(actual)")
    }
    XCTAssertTrue(app.buttons["whats-new-done"].isHittable)
    Thread.sleep(forTimeInterval: 1)
    capture(app, name: "voiceover-done-focus")
  }
}

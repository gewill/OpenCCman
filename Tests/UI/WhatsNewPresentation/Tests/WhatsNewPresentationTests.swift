import XCTest

final class WhatsNewPresentationTests: XCTestCase {
  private let appID = "org.gewill.OpenCCman.WhatsNewUITests"
  private var initialVoiceOverEnabled: Bool?

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {
    if #available(iOS 27.0, *), let initialVoiceOverEnabled {
      let voiceOver = XCUIDevice.shared.voiceOverService
      if voiceOver.isEnabled != initialVoiceOverEnabled {
        if initialVoiceOverEnabled { try voiceOver.enable() }
        else { try voiceOver.disable() }
      }
      XCTAssertEqual(voiceOver.isEnabled, initialVoiceOverEnabled,
                     "The test must restore the prior VoiceOver state even after an assertion fails")
      self.initialVoiceOverEnabled = nil
    }
    try super.tearDownWithError()
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
    // Wait for the system sheet animation before preserving visual evidence.
    Thread.sleep(forTimeInterval: 0.6)
    capture(app, name: "cards-after-task")
    done.tap()
    let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: done)
    XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed)
    XCTAssertFalse(done.waitForExistence(timeout: 2), "Cards must not reopen after dismissal")
  }

  func testEligibleUnreadCardsAppearOnceAcrossRelaunchAndCanBeReopenedFromSettings() {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(en)", "-qa-unread-whats-new-at-launch",
                           "-qa-assume-active-for-whats-new"]
    app.launch()
    defer { app.terminate() }

    let done = app.buttons["whats-new-done"]
    XCTAssertTrue(done.waitForExistence(timeout: 20), "An unread release should open when the home scene is eligible")
    capture(app, name: "unread-cards-on-launch")
    done.tap()
    XCTAssertFalse(done.waitForExistence(timeout: 3))

    app.terminate()
    app.launchArguments = ["-AppleLanguages", "(en)", "-qa-assume-active-for-whats-new"]
    app.launch()
    XCTAssertTrue(app.buttons["Convert"].waitForExistence(timeout: 20))
    XCTAssertFalse(done.waitForExistence(timeout: 3), "A read release must stay dismissed after relaunch")
    capture(app, name: "home-after-relaunch-without-cards")

    app.buttons["More"].tap()
    app.buttons["Settings"].tap()
    let whatsNewSettings = app.buttons["whats-new-settings"]
    XCTAssertTrue(whatsNewSettings.waitForExistence(timeout: 10))
    whatsNewSettings.tap()
    XCTAssertTrue(done.waitForExistence(timeout: 10), "Settings should allow a manual replay")
    capture(app, name: "manual-cards-from-settings")
    done.tap()
    XCTAssertFalse(done.waitForExistence(timeout: 3))
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

  private func importFixture(_ filename: String, in app: XCUIApplication) {
    app.buttons["Import TXT"].tap()
    XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 15))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    if app.buttons["Browse"].exists {
      app.buttons["Browse"].tap()
    }
    let localStorage = app.cells.matching(
      NSPredicate(format: "identifier BEGINSWITH 'DOC.sidebar.item.On My '"))
      .firstMatch
    if localStorage.waitForExistence(timeout: 5) {
      localStorage.tap()
    }
    let appFolder = app.cells["OpenCCman, Container"]
    if appFolder.waitForExistence(timeout: 5) {
      appFolder.tap()
    }
    let file = app.cells["\(filename), txt"]
    XCTAssertTrue(file.waitForExistence(timeout: 10), "The QA fixture must be visible in Files")
    file.tap()
  }

  func testImportSuccessDefersCardsUntilSourceIsReplaced() throws {
    let app = launch("-qa-unread-whats-new-on-import", "-qa-delay-import")
    defer { app.terminate() }
    importFixture("success", in: app)
    XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "import-running-without-cards")
    expectCardsOnce(app)
    let source = app.textViews["Source"].value as? String ?? ""
    XCTAssertTrue(source.contains("測試導入"))
    XCTAssertTrue(source.contains("😀"))
    XCTAssertTrue(app.staticTexts["success.txt"].exists)
    XCTAssertFalse(app.buttons["Copy Result"].isEnabled)
  }

  func testImportFailurePreservesSourceAndDefersCardsUntilAlertCloses() throws {
    let app = launch("-qa-unread-whats-new-on-import", "-qa-delay-import")
    defer { app.terminate() }
    let source = app.textViews["Source"]
    source.tap()
    source.typeText("Original draft")
    let original = source.value as? String
    XCTAssertTrue(original?.contains("Original draft") == true)
    importFixture("bad-encoding", in: app)
    XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    let alert = app.alerts["Error"]
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["whats-new-done"].exists)
    capture(app, name: "import-error-without-cards")
    alert.buttons["OK"].tap()
    expectCardsOnce(app)
    XCTAssertEqual(source.value as? String, original)
    XCTAssertFalse(app.buttons["Copy Result"].isEnabled)
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
    // On iPad, the Files browser has a top-left close control instead of the
    // iPhone's Browse/Cancel navigation. Both are outside the app XCUI tree.
    // Assert the picker disappears before checking the deferred cards.
    if app.frame.width < 600 {
      let topLeftNavigation = app.coordinate(withNormalizedOffset: CGVector(dx: 0.115, dy: 0.105))
      for _ in 0..<3 where picker.exists {
        topLeftNavigation.tap()
        Thread.sleep(forTimeInterval: 0.7)
      }
    } else {
      // iPadOS 18.6 places Cancel near 5% of the screen's height; the
      // former 7.1% point lands below the button.
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
    }
    let pickerDismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: picker)
    XCTAssertEqual(XCTWaiter().wait(for: [pickerDismissed], timeout: 10), .completed,
                   "The native exporter must close after cancelling")
    expectCardsOnce(app)
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

  func testIPadPresetSegmentsPreserveSelectionAndDisableInactiveOptions() throws {
    let app = launch("-qa-suppress-review")
    defer { app.terminate() }
    guard app.frame.width >= 600 else { throw XCTSkip("iPad-only control validation") }

    app.buttons["Conversion settings"].tap()
    let target = app.descendants(matching: .any)["conversion-segment-Target Language"]
    let variant = app.descendants(matching: .any)["conversion-segment-Variant"]
    let region = app.descendants(matching: .any)["conversion-segment-Region Idiom"]
    XCTAssertTrue(target.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(variant.waitForExistence(timeout: 10))
    XCTAssertTrue(region.waitForExistence(timeout: 10))
    let inspector = app.scrollViews.containing(.any,
      identifier: "conversion-segment-Target Language").firstMatch
    XCTAssertTrue(inspector.exists)

    func reveal(_ element: XCUIElement) {
      for _ in 0..<8 where !element.isHittable { inspector.swipeUp() }
      XCTAssertTrue(element.isHittable, "The selected control must remain reachable at this text size")
    }

    let simplified = target.buttons["Simplified Chinese"]
    let traditional = target.buttons["Traditional Chinese"]
    reveal(simplified)
    reveal(traditional)
    simplified.tap()
    XCTAssertTrue(simplified.isSelected)
    XCTAssertFalse(variant.buttons["Taiwan Standard"].isEnabled)
    XCTAssertFalse(region.buttons["Taiwan Idiom"].isEnabled)
    capture(app, name: "ipad-simplified-advanced-disabled")

    traditional.tap()
    let taiwanStandard = variant.buttons["Taiwan Standard"]
    let taiwanIdiom = region.buttons["Taiwan Idiom"]
    reveal(taiwanStandard)
    taiwanStandard.tap()
    reveal(taiwanIdiom)
    taiwanIdiom.tap()
    XCTAssertTrue(traditional.isSelected)
    XCTAssertTrue(variant.buttons["Taiwan Standard"].isSelected)
    XCTAssertTrue(region.buttons["Taiwan Idiom"].isSelected)
    capture(app, name: "ipad-taiwan-segments-selected")

    app.buttons["Done"].tap()
    app.buttons["Convert"].tap()
    let result = app.textViews["Result"]
    XCTAssertTrue(result.waitForExistence(timeout: 10))
    let converted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS %@", "滑鼠"), object: result)
    XCTAssertEqual(XCTWaiter().wait(for: [converted], timeout: 10), .completed,
                   "Taiwan idiom conversion should use the chosen segment state")
    XCTAssertTrue(app.buttons["Copy Result"].isEnabled)
    XCTAssertTrue(app.buttons["Export TXT"].isEnabled)
    capture(app, name: "ipad-taiwan-converted")
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

    // The speech service currently returns only the first 64 characters of
    // each combined card on this Simulator. Verify that the accessibility
    // element exposes the end of every detail as well as checking spoken order.
    let detailEndings = [
      "iPhone keeps a focused stacked layout.",
      "Advanced options are still available.",
      "to a location you choose.",
      "unfinished conversions do not use your daily allowance."
    ]
    for ending in detailEndings {
      let card = app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@", ending)).firstMatch
      XCTAssertTrue(card.exists, "The complete card detail must be exposed to accessibility: \(ending)")
    }

    let voiceOver = XCUIDevice.shared.voiceOverService
    let wasEnabled = voiceOver.isEnabled
    initialVoiceOverEnabled = wasEnabled
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
    capture(app, name: "voiceover-done-focus")
    var reverseUtterances: [String] = []
    for _ in 0..<(expectedStarts.count - 1) {
      let spoken = try voiceOver.moveBackward().utterance
      reverseUtterances.append(spoken)
      XCTAssertEqual(try voiceOver.currentSpeech().utterance, spoken,
                     "The VoiceOver cursor must remain on the element just read")
    }
    print("VOICEOVER_REVERSE_UTTERANCES: \(reverseUtterances)")
    let reverseExpectedStarts = [
      "Stay in control", "Bring your text files", "Your conversion, one tap away",
      "A workspace that fits your screen", "OpenCCman 2.0", "What’s New Heading"
    ]
    for (actual, expected) in zip(reverseUtterances, reverseExpectedStarts) {
      XCTAssertTrue(actual.hasPrefix(expected), "Expected \(expected) on reverse navigation, heard \(actual)")
    }
    capture(app, name: "voiceover-back-at-heading")
    XCTAssertTrue(app.buttons["whats-new-done"].isHittable)
  }
}

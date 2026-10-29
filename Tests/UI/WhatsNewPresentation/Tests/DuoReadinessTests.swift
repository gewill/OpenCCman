import XCTest

/// Uses the real installed QA application, native editors and conversion engine.
/// Resize mode is driven from the host, never by injecting geometry into the app.
final class DuoReadinessTests: XCTestCase {
  private let appID = "org.gewill.OpenCCman.WhatsNewUITests"

  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch(language: String = "en", exhausted: Bool = false,
                      pendingError: Bool = false) -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: appID)
    app.launchArguments = ["-AppleLanguages", "(\(language))", "-isPro", "NO",
      "-qa-mark-whats-new-read-at-launch", "-qa-suppress-review", "-qa-duo-trace"]
    if exhausted { app.launchArguments.append("-qa-exhaust-quota") }
    if pendingError { app.launchArguments.append("-qa-error-with-pro-alert") }
    app.launch()
    XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 20))
    return app
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    print("OPENCCMAN_DUO_CAPTURE \(name): app=\(app.frame), window=\(app.windows.firstMatch.frame)")
    // App-scoped capture can select Duo's inactive inner display while closed.
    // Keep every active simulator display, without assuming a fixed screen index.
    // This suite runs only against the isolated QA app on a dedicated device.
    for (index, screen) in XCUIScreen.screens.enumerated() {
      let image = XCTAttachment(screenshot: screen.screenshot())
      image.name = "\(name)-display-\(index)"
      image.lifetime = .keepAlways
      add(image)
    }
  }

  private func wait(_ element: XCUIElement, predicate: NSPredicate, timeout: TimeInterval = 15) {
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
  }

  private func convertExample(_ app: XCUIApplication) -> (String, String) {
    let example = app.buttons["source-fill-example"]
    XCTAssertTrue(example.waitForExistence(timeout: 10))
    example.tap()
    let source = app.textViews["workspace-source-editor"]
    wait(source, predicate: NSPredicate(format: "value != %@ AND value != nil", ""))
    let original = source.value as! String
    app.buttons["workspace-convert"].tap()
    let result = app.textViews["workspace-result-editor"]
    wait(result, predicate: NSPredicate(format: "value != %@ AND value != nil", ""))
    return (original, result.value as! String)
  }

  func testEnglishNavigationAndSettingsKeepDocument() { checkNavigation(language: "en", help: "Help", done: "Done") }
  func testSimplifiedNavigationAndSettingsKeepDocument() { checkNavigation(language: "zh-Hans", help: "帮助", done: "完成") }
  func testTraditionalNavigationAndSettingsKeepDocument() { checkNavigation(language: "zh-Hant", help: "說明", done: "完成") }

  private func checkNavigation(language: String, help: String, done: String) {
    let app = launch(language: language)
    defer { app.terminate() }
    let (original, converted) = convertExample(app)
    capture(app, "\(language)-converted-workspace")
    app.buttons["workspace-conversion-settings"].tap()
    let close = app.buttons[done]
    XCTAssertTrue(close.waitForExistence(timeout: 10))
    capture(app, "\(language)-conversion-settings")
    close.tap()
    XCTAssertTrue(app.buttons["workspace-more"].waitForExistence(timeout: 10))
    app.buttons["workspace-more"].tap()
    XCTAssertTrue(app.buttons[help].waitForExistence(timeout: 5))
    app.buttons[help].tap()
    let back = app.buttons["navigation-back"]
    XCTAssertTrue(back.waitForExistence(timeout: 10))
    capture(app, "\(language)-help-navigation")
    back.tap()
    XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.textViews["workspace-source-editor"].value as? String, original)
    XCTAssertEqual(app.textViews["workspace-result-editor"].value as? String, converted)
  }

  func testSystemProAlertCancelsAndOpensClosableSheet() {
    checkProAlert(language: "en", cancel: "Cancel", pro: "Pro")
  }

  func testSimplifiedProAlertCancelsAndOpensClosableSheet() {
    checkProAlert(language: "zh-Hans", cancel: "取消", pro: "会员")
  }

  func testTraditionalProAlertCancelsAndOpensClosableSheet() {
    checkProAlert(language: "zh-Hant", cancel: "取消", pro: "會員")
  }

  private func checkProAlert(language: String, cancel: String, pro: String) {
    let app = launch(language: language, exhausted: true)
    defer { app.terminate() }
    app.buttons["source-fill-example"].tap()
    let source = app.textViews["workspace-source-editor"]
    let original = source.value as? String
    app.buttons["workspace-convert"].tap()
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    capture(app, "\(language)-system-pro-alert")
    alert.buttons[cancel].tap()
    wait(alert, predicate: NSPredicate(format: "exists == false"))
    XCTAssertEqual(source.value as? String, original)
    app.buttons["workspace-convert"].tap()
    XCTAssertTrue(alert.waitForExistence(timeout: 10))
    alert.buttons[pro].tap()
    let close = app.buttons["pro-sheet-close"]
    XCTAssertTrue(close.waitForExistence(timeout: 15))
    capture(app, "\(language)-pro-sheet-with-system-close")
    close.tap()
    XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 10))
    XCTAssertEqual(source.value as? String, original)
  }

  func testKeyboardDismissalAndConversion() {
    let app = launch()
    defer { app.terminate() }
    let source = app.textViews["workspace-source-editor"]
    source.tap()
    let text = "汉字转换，软件与网络。🌏\n保留第二行。"
    source.typeText(text)
    let dismiss = app.buttons["workspace-dismiss-keyboard"]
    XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
    capture(app, "keyboard-and-convert")
    dismiss.tap()
    wait(app.keyboards.firstMatch, predicate: NSPredicate(format: "exists == false"))
    XCTAssertEqual(source.value as? String, text)
    app.buttons["workspace-convert"].tap()
    let result = app.textViews["workspace-result-editor"]
    wait(result, predicate: NSPredicate(format: "value CONTAINS %@", "漢字"))
    capture(app, "keyboard-dismissed-result")
  }

  func testProCancellationPreservesPendingError() { checkPendingError(opensPro: false) }
  func testProSheetDefersPendingErrorUntilReturn() { checkPendingError(opensPro: true) }

  private func checkPendingError(opensPro: Bool) {
    // Deliberately seed the two independent states; this is a conflict fixture,
    // not evidence that the timing occurs in a natural file-import flow.
    let app = launch(exhausted: true, pendingError: true)
    defer { app.terminate() }
    app.buttons["source-fill-example"].tap()
    let original = app.textViews["workspace-source-editor"].value as? String
    app.buttons["workspace-convert"].tap()
    let proAlert = app.alerts["Pro only feature"]
    XCTAssertTrue(proAlert.waitForExistence(timeout: 10))
    capture(app, "pending-error-pro-alert")
    if opensPro {
      proAlert.buttons["Pro"].tap()
      let close = app.buttons["pro-sheet-close"]
      XCTAssertTrue(close.waitForExistence(timeout: 15))
      XCTAssertFalse(app.alerts["Error"].exists, "The pending error must not compete with the Pro sheet")
      close.tap()
    } else {
      proAlert.buttons["Cancel"].tap()
    }
    let errorAlert = app.alerts["Error"]
    let exists = errorAlert.waitForExistence(timeout: 10)
    capture(app, opensPro ? "pending-error-after-pro-sheet" : "pending-error-after-pro-cancel")
    XCTAssertTrue(exists, "Dismissing Pro must not consume an error that was never shown")
    XCTAssertTrue(errorAlert.staticTexts["QA pending file error"].exists)
    errorAlert.buttons["OK"].tap()
    XCTAssertFalse(app.alerts.firstMatch.exists)
    XCTAssertEqual(app.textViews["workspace-source-editor"].value as? String, original)
  }

  func testHostResizeKeepsNativeDocument() throws {
    guard ProcessInfo.processInfo.environment["OPENCCMAN_DUO_EXTERNAL_RESIZE"] == "1" else {
      throw XCTSkip("Requires host-driven real resize session; no synthetic app geometry")
    }
    let app = launch()
    defer { app.terminate() }
    let (original, converted) = convertExample(app)
    let source = app.textViews["workspace-source-editor"]
    let result = app.textViews["workspace-result-editor"]
    source.tap()
    print("OPENCCMAN_DUO_READY_FOR_RESIZE")
    let horizontal = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      source.frame.maxX < result.frame.minX
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [horizontal], timeout: 90), .completed)
    capture(app, "native-wide-resize")
    XCTAssertEqual(source.value as? String, original)
    XCTAssertEqual(result.value as? String, converted)
    print("OPENCCMAN_DUO_READY_FOR_COMPACT")
    let vertical = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(source.frame.minX - result.frame.minX) < 10
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [vertical], timeout: 90), .completed)
    XCTAssertEqual(source.value as? String, original)
    XCTAssertEqual(result.value as? String, converted)
    capture(app, "native-compact-resize")
  }
}

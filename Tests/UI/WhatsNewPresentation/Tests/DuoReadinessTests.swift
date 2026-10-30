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

  func testHostResizeWithConversionSettingsKeepsDocument() throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["OPENCCMAN_DUO_EXTERNAL_RESIZE"] == "1" else {
      throw XCTSkip("Requires host-driven real resize; run scripts/check-duo-settings-resize.py")
    }
    let language = environment["OPENCCMAN_DUO_LANGUAGE"] ?? "en"
    XCTAssertTrue(["en", "zh-Hans", "zh-Hant"].contains(language))
    let recordingReady = FileManager.default.temporaryDirectory.appendingPathComponent("duo-settings-recording-ready")
    try? FileManager.default.removeItem(at: recordingReady)
    defer { try? FileManager.default.removeItem(at: recordingReady) }
    let app = launch(language: language)
    defer { app.terminate() }
    let (original, converted) = convertExample(app)
    let closeTitle = language == "en" ? "Done" : "完成"
    let close = app.buttons[closeTitle]
    func report(_ stage: String) {
      print("SETTINGS_RESIZE \(stage) app=\(app.frame) window=\(app.windows.firstMatch.frame) close=\(close.frame) enabled=\(close.isEnabled) hittable=\(close.isHittable)")
    }
    let externalPointer = environment["OPENCCMAN_DUO_DEVICE_HUB_POINTER"] == "1"
    func checkDocument(_ stage: String) {
      wait(close, predicate: NSPredicate(format: "exists == false"), timeout: externalPointer ? 120 : 15)
      XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 10))
      XCTAssertEqual(app.textViews["workspace-source-editor"].value as? String, original)
      XCTAssertEqual(app.textViews["workspace-result-editor"].value as? String, converted)
      capture(app, "\(language)-settings-\(stage)-dismissed")
    }
    app.buttons["workspace-conversion-settings"].tap()
    XCTAssertTrue(close.waitForExistence(timeout: 10))
    XCTAssertLessThan(app.frame.width, 500, "Start on the closed portrait display")
    report("initial")
    capture(app, "\(language)-settings-initial")
    print("OPENCCMAN_DUO_READY_FOR_RESIZE")
    let wide = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(app.frame.width - 950) < 1 && abs(app.frame.height - 669) < 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [wide], timeout: 30), .completed)
    report("wide")
    print("OPENCCMAN_DUO_READY_FOR_WIDE_CAPTURE")
    if environment["OPENCCMAN_DUO_RECORDING"] == "1" {
      let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
        FileManager.default.fileExists(atPath: recordingReady.path)
      }, object: nil)
      XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 20), .completed)
    }
    capture(app, "\(language)-settings-wide")
    XCTAssertEqual(app.buttons.matching(identifier: closeTitle).count, 1)
    XCTAssertTrue(close.isEnabled)
    // Device Hub pointer input is an explicit assisted acceptance mode. XCTest
    // still verifies dismissal and exact document values; no app state is injected.
    if externalPointer {
      print("OPENCCMAN_DUO_AWAIT_WIDE_CLOSE")
    } else {
      close.tap()
    }
    checkDocument("wide")
    if externalPointer {
      print("OPENCCMAN_DUO_AWAIT_REOPEN")
    } else {
      app.buttons["workspace-conversion-settings"].tap()
    }
    XCTAssertTrue(close.waitForExistence(timeout: externalPointer ? 120 : 10))
    print("OPENCCMAN_DUO_READY_FOR_COMPACT")
    let compact = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(app.frame.width - 400) < 1 && abs(app.frame.height - 750) < 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [compact], timeout: 30), .completed)
    report("compact")
    capture(app, "\(language)-settings-compact")
    XCTAssertEqual(app.buttons.matching(identifier: closeTitle).count, 1)
    XCTAssertTrue(close.isEnabled)
    if externalPointer {
      print("OPENCCMAN_DUO_AWAIT_COMPACT_CLOSE")
    } else {
      close.tap()
    }
    checkDocument("compact")
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

  // Additional local acceptance stays on the installed, source-verified QA binary.
  func testEnglishMoreRoutesKeepDocument() { checkMoreRoutes(language: "en", settings: "Settings", pro: "Pro") }
  func testSimplifiedMoreRoutesKeepDocument() { checkMoreRoutes(language: "zh-Hans", settings: "设置", pro: "会员") }
  func testTraditionalMoreRoutesKeepDocument() { checkMoreRoutes(language: "zh-Hant", settings: "設定", pro: "會員") }

  private func checkMoreRoutes(language: String, settings: String, pro: String) {
    let app = launch(language: language)
    defer { app.terminate() }
    let (original, converted) = convertExample(app)
    app.buttons["workspace-more"].tap()
    capture(app, "\(language)-actual-more-menu")
    XCTAssertTrue(app.buttons[settings].waitForExistence(timeout: 5))
    app.buttons[settings].tap()
    // Current 2.1 has no configured release cards. Test the actual route instead.
    XCTAssertFalse(app.buttons["whats-new-settings"].exists)
    let customer = app.buttons["customer-center-settings"]
    XCTAssertTrue(customer.waitForExistence(timeout: 10)); customer.tap()
    let dismiss = app.buttons["circled_close_button"]
    XCTAssertTrue(dismiss.waitForExistence(timeout: 20))
    capture(app, "\(language)-customer-center-no-transaction")
    dismiss.tap()
    wait(dismiss, predicate: NSPredicate(format: "exists == false"))
    XCTAssertTrue(customer.waitForExistence(timeout: 10))
    let back = app.buttons["navigation-back"]
    XCTAssertTrue(back.waitForExistence(timeout: 10))
    back.tap()
    app.buttons["workspace-more"].tap()
    XCTAssertTrue(app.buttons[pro].waitForExistence(timeout: 5))
    app.buttons[pro].tap()
    let closePro = app.buttons["pro-sheet-close"]
    XCTAssertTrue(closePro.waitForExistence(timeout: 10))
    let restore = app.buttons[language == "en" ? "Restore" : language == "zh-Hans" ? "恢复购买" : "恢復購買"]
    XCTAssertTrue(restore.waitForExistence(timeout: 10))
    if !restore.isEnabled { capture(app, "\(language)-pro-route-loading-restore-disabled") }
    wait(restore, predicate: NSPredicate(format: "enabled == true"), timeout: 30)
    XCTAssertTrue(restore.isEnabled) // Reachability only; no restore or purchase.
    capture(app, "\(language)-pro-route-restore-control")
    closePro.tap()
    wait(closePro, predicate: NSPredicate(format: "exists == false"))
    XCTAssertTrue(app.buttons["workspace-more"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.textViews["workspace-source-editor"].value as? String, original)
    XCTAssertEqual(app.textViews["workspace-result-editor"].value as? String, converted)
  }

  func testVersionWithoutReleaseDoesNotPresentCards() {
    let app = XCUIApplication(bundleIdentifier: appID)
    defer { app.terminate() }
    app.launchArguments = ["-AppleLanguages", "(en)", "-qa-unread-whats-new-at-launch",
      "-qa-assume-active-for-whats-new", "-qa-suppress-review", "-qa-duo-trace"]
    app.launch()
    XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 20))
    XCTAssertFalse(app.buttons["whats-new-done"].waitForExistence(timeout: 3))
    app.buttons["workspace-more"].tap(); app.buttons["Settings"].tap()
    XCTAssertTrue(app.staticTexts["2.1(30)"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["whats-new-settings"].exists)
    capture(app, "version-without-release-has-no-empty-replay")
  }

  func testHostResizeWithProRouteKeepsDocument() throws { try checkOverlayResize("pro") }
  func testHostResizeWithImporterKeepsDocument() throws { try checkOverlayResize("import") }
  func testHostResizeWithExporterKeepsDocument() throws { try checkOverlayResize("export") }

  private func checkOverlayResize(_ overlay: String) throws {
    guard ProcessInfo.processInfo.environment["OPENCCMAN_DUO_OVERLAY_RESIZE"] == "1" else {
      throw XCTSkip("Requires a host controller that ends its own resize session before dismissal")
    }
    let app = launch()
    defer { app.terminate() }
    let (original, converted) = convertExample(app)
    let initial = app.frame
    switch overlay {
    case "pro":
      app.buttons["workspace-more"].tap(); app.buttons["Pro"].tap()
      XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 10))
    case "import":
      app.buttons["Import TXT"].tap()
      XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 15))
    default:
      let export = app.buttons["Export TXT"]
      for _ in 0..<3 where !export.isHittable { app.swipeUp() }
      XCTAssertTrue(export.isHittable); export.tap()
      XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 15))
    }
    capture(app, "\(overlay)-before-real-resize")
    print("OPENCCMAN_OVERLAY_READY \(overlay)")
    let wide = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(app.frame.width - 950) < 1 && abs(app.frame.height - 669) < 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [wide], timeout: 30), .completed)
    capture(app, "\(overlay)-wide-real-resize")
    print("OPENCCMAN_OVERLAY_WIDE \(overlay)")
    let compact = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(app.frame.width - 400) < 1 && abs(app.frame.height - 750) < 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [compact], timeout: 30), .completed)
    capture(app, "\(overlay)-compact-real-resize")
    print("OPENCCMAN_OVERLAY_COMPACT \(overlay)")
    let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      abs(app.frame.width - initial.width) < 1 && abs(app.frame.height - initial.height) < 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter().wait(for: [restored], timeout: 30), .completed)
    // Ending the host session is explicit. This does not claim that XCTest can
    // hit controls on the Resizable display (whose reported frames are scaled).
    switch overlay {
    case "pro":
      let close = app.buttons["pro-sheet-close"]; close.tap()
      wait(close, predicate: NSPredicate(format: "exists == false"))
    case "import":
      let cancel = app.buttons["Cancel"].firstMatch; cancel.tap()
      wait(cancel, predicate: NSPredicate(format: "exists == false"))
    default:
      let picker = app.otherElements["Browse View (Picker)"]
      let cancel = app.buttons["Cancel"].firstMatch
      XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
      wait(picker, predicate: NSPredicate(format: "exists == false"))
    }
    XCTAssertTrue(app.buttons["workspace-convert"].waitForExistence(timeout: 10))
    XCTAssertEqual(app.textViews["workspace-source-editor"].value as? String, original)
    XCTAssertEqual(app.textViews["workspace-result-editor"].value as? String, converted)
    capture(app, "\(overlay)-dismissed-original-document")
    print("OPENCCMAN_OVERLAY_VERIFIED \(overlay)")
  }
}

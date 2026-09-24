import XCTest

@MainActor
final class OpenCCmanVoiceOverProbe: XCTestCase {
    func testBaselineResultEditor() throws {
        try probeResult(bundleID: "org.gewill.OpenCCman.Issue37QA20260924", expectedKeyboard: true)
    }

    func testFixedResultEditor() throws {
        try probeResult(bundleID: "org.gewill.OpenCCman.Issue20QA20260924", expectedKeyboard: false)
    }

    private func probeResult(bundleID: String, expectedKeyboard: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: bundleID)
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        defer {
            if !wasEnabled { try? service.disable() }
            app.terminate()
        }
        app.launch()
        let convert = app.buttons["Convert"]
        XCTAssertTrue(convert.waitForExistence(timeout: 15))
        convert.tap()
        let copy = app.buttons["Copy Result"]
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 15)
        if app.staticTexts["What's New"].waitForExistence(timeout: 5) {
            app.buttons["Done"].tap()
            XCTAssertFalse(app.staticTexts["What's New"].exists)
        }
        let result = app.textViews["Result"]
        XCTAssertTrue(result.exists)
        let before = result.value as? String ?? ""
        XCTAssertFalse(before.isEmpty)
        if !wasEnabled { try service.enable() }
        result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let speech = (try? service.currentSpeech().utterance) ?? "NO SPEECH"
        print("OPENCCMAN_RESULT_SPEECH \(bundleID) \(speech)")
        let spokenAttachment = XCTAttachment(string: speech)
        spokenAttachment.name = expectedKeyboard ? "before-result-speech" : "after-result-speech"
        spokenAttachment.lifetime = .keepAlways
        add(spokenAttachment)
        if !wasEnabled { try service.disable() }
        result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let keyboardShown = app.keyboards.firstMatch.waitForExistence(timeout: 2)
        print("OPENCCMAN_RESULT_KEYBOARD_SHOWN \(bundleID) \(keyboardShown)")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = expectedKeyboard ? "before-result-keyboard" : "after-result-keyboard"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        if keyboardShown {
            result.typeText("X")
        }
        let after = result.value as? String ?? ""
        print("OPENCCMAN_RESULT_VALUE_BEFORE \(before)")
        print("OPENCCMAN_RESULT_VALUE_AFTER \(after)")
        XCTAssertEqual(after, before, "Result editor must remain read-only")
        XCTAssertEqual(keyboardShown, expectedKeyboard, "Result keyboard differs from the measured baseline/fix expectation")
    }

    func testBaselineHomeSpeechSequence() throws {
        try verifyHomeSpeech(bundleID: "org.gewill.OpenCCman.Issue37QA20260924", expectsEditableResult: true)
    }

    func testFixedHomeSpeechSequence() throws {
        try verifyHomeSpeech(bundleID: "org.gewill.OpenCCman.Issue20QA20260924", expectsEditableResult: false)
    }

    func testFixedConvertedResultSpeech() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "org.gewill.OpenCCman.Issue20QA20260924")
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        defer {
            if !wasEnabled { try? service.disable() }
            app.terminate()
        }
        app.launch()
        let convert = app.buttons["Convert"]
        XCTAssertTrue(convert.waitForExistence(timeout: 15))
        convert.tap()
        let copy = app.buttons["Copy Result"]
        let enabled = NSPredicate(format: "enabled == true")
        expectation(for: enabled, evaluatedWith: copy)
        waitForExpectations(timeout: 15)
        if app.staticTexts["What's New"].waitForExistence(timeout: 5) {
            app.buttons["Done"].tap()
        }
        if !wasEnabled { try service.enable() }
        var speech = [(try service.currentSpeech()).utterance]
        for _ in 0..<20 { speech.append((try service.moveForward()).utterance) }
        let record = speech.joined(separator: "\n")
        print("OPENCCMAN_CONVERTED_VO_BEGIN\n\(record)\nOPENCCMAN_CONVERTED_VO_END")
        let attachment = XCTAttachment(string: record)
        attachment.name = "converted-result-voiceover-speech"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(speech.contains { $0.contains("鼠標裏面的硅二極管壞了") },
                      "Converted result must be spoken by VoiceOver")
    }

    private func verifyHomeSpeech(bundleID: String, expectsEditableResult: Bool) throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: bundleID)
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        defer {
            if !wasEnabled { try? service.disable() }
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        if !wasEnabled { try service.enable() }
        var speech = [String]()
        speech.append("current: " + (try service.currentSpeech()).utterance)
        for index in 0..<18 {
            speech.append("forward \(index + 1): " + (try service.moveForward()).utterance)
        }
        let record = speech.joined(separator: "\n")
        print("OPENCCMAN_VO_SPEECH_BEGIN\n\(record)\nOPENCCMAN_VO_SPEECH_END")
        let attachment = XCTAttachment(string: record)
        attachment.name = "home-voiceover-speech"
        attachment.lifetime = .keepAlways
        add(attachment)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "home-after-voiceover-navigation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(speech[11].contains("Text field"), "Source must remain editable")
        XCTAssertTrue(speech[17].contains("Result"), "Result must remain in reading order")
        XCTAssertEqual(speech[17].contains("Double tap to edit"), expectsEditableResult,
                       "Result VoiceOver editing hint should match its native read-only state")
    }
}

# What’s New: unread, relaunch, and manual replay

This regression checks one on-screen lifecycle for OpenCCman 2.0: an unread
release presents on an eligible home scene, dismissal records it as read, a
relaunch does not present it again, and Settings can reopen it manually. The
test uses the isolated `org.gewill.OpenCCman.WhatsNewUITests` Debug bundle.
The app's normal bundle and stored preferences are untouched.

On Xcode 27.0's headless iOS Simulator, the scene phase stayed `inactive`
even after `XCUIApplication.activate()`. The initial test correctly found no
automatic sheet; a temporary diagnostic read `inactive:/home` with every other
presentation blocker false. To test the rest of the UI lifecycle reliably, the
final test passes `-qa-assume-active-for-whats-new`. That argument only affects
the exact QA bundle in Debug builds. The unread setup argument is likewise
restricted to that bundle. The temporary diagnostic was removed.

The case is in `Tests/UI/WhatsNewPresentation`; it captures three screenshots
and can be recorded with `xcrun simctl io <UDID> recordVideo`. Run the full
matrix with `bash scripts/check-whats-new-ui.sh <dedicated-booted-UDID>`.

| Environment | Result |
| --- | --- |
| iPhone 15 Pro Max, iOS 18.6 Simulator, English/light | New lifecycle case passed; full suite 11 tests, 0 failures, 1 VoiceOver case skipped because it requires iOS 27 |
| iPad Air 11-inch (M4), iPadOS 26.5 Simulator, English/light | New lifecycle case passed, 1 test, 0 failures |
| macOS 27.0 host, Xcode 27.0 | Debug macOS build with resolved dependencies succeeded |

This confirms presentation, dismissal, persistence across process relaunch,
and the manual Settings entry under the injected eligible-scene condition. It
does **not** prove the real foreground transition or a signed first install.
Issue #34 remains open for a visible device/Device Hub launch, iOS 15 and
macOS 12 native sheet behavior (#16), VoiceOver and physical-device checks
(#20), and the final Xcode Cloud/TestFlight build. The iOS 15.5 Simulator
runtime installed on this macOS 27 host is unavailable because the host no
longer supports it; no minimum-OS result is claimed here.

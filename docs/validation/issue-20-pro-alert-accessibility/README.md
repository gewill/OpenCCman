# Issue #20: quota alert accessibility isolation

Date: 2026-09-24. This is one focused part of #20, not its full keyboard, editor, and release acceptance.

## Defect and change

At the 12-conversion free quota, the custom Pro alert appeared over the workspace, but VoiceOver continued through the workspace controls and editors. XCTest also reported the background Convert button as hittable while the alert was open. A user could leave the alert's choices and interact with obscured content.

The shared custom `AlertView` now marks its alert content with SwiftUI's modal accessibility trait so VoiceOver ignores sibling workspace elements. `HomeScene` overlays a transparent hit-test layer while the Pro alert is shown so pointer and touch input cannot reach the obscured workspace. The layer disappears on dismissal, leaving the editors' view identity and the window's `HomeViewModel` intact. This does not alter counting or purchase logic. [Apple's modal accessibility trait](https://developer.apple.com/documentation/swiftui/accessibilitytraits/ismodal) describes the sibling navigation behavior.

## Reproduction and results

- Baseline source: `ac030bde96ea18629f4514445dfd43088dce4408` (`develop`, containing PR #163). Its isolated iOS Debug app code (`OpenCCman.debug.dylib`) SHA-256 was `e307377cc51a9e368075b3d46124540dac464879477846e49710f2c5cad93048`.
- Candidate: this branch's `HomeScene` and `AlertView` changes, app code (`OpenCCman.debug.dylib`) SHA-256 `97eafe08022f6cf34f9f90bd47a58a8345d83b44b3c94678555f6d7cefde324b`. In this Xcode Debug configuration, the `OpenCCman` executable is only a launcher stub; the app code is in this dylib.
- Environment: Xcode 27.0 (27A266a), iPad Air 11-inch (M4) simulator, iPadOS 27.0, English, light appearance, default text size. The app used an isolated bundle identifier and preferences with the current day's quota at 12; no real purchase account was used.
- The temporary XCTest UI harness enabled VoiceOver, read `currentSpeech()` and 17 `moveForward()` utterances, then disabled VoiceOver. Baseline speech went from “Pro only feature” / “Unlimited calculations” / “Pro” / “Cancel” into “Source”, “Paste Text”, “Import TXT”, the source editor, and “Result”. Candidate speech stayed within the alert; further forward moves repeated “Cancel”. The [before](media/before-ipad-voiceover.png) and [after](media/after-ipad-voiceover.png) screenshots show the actual VoiceOver focus rectangles. The screenshots alone do not establish speech; the utterance record above comes from XCTest.
- Baseline Convert was `isHittable=true` while the alert was up. Candidate Convert was `false` during the alert and `true` after Cancel. After dismissal, the draft string was identical and tapping Convert opened the alert again. A tested `accessibilityHidden` alternative caused the button to remain unhittable after Cancel; it was not retained.
- The converted-result VoiceOver probe also passed on the baseline: after conversion, “Copy Result” and “Export TXT” became available and the converted Chinese text was spoken. This is a partial action inventory, not a full #20 pass.

The candidate iOS Simulator and macOS Debug builds passed. The captured interaction recording shows opening and dismissing the alert, but has no VoiceOver audio. VoiceOver was read back as disabled after the test.

## Remaining boundaries

This probe did not use a physical device, minimum iOS 15 / macOS 12, a signed build, Mac VoiceOver, a hardware keyboard, a Chinese input method, the file pickers, or the complete error/cancel flows. Those remain on #20 (minimum systems on #16). The draft text was measured and preserved; native editor selection and scroll position were not measured here.

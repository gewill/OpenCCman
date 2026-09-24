# Issue #20: iOS 27 result editor read-only behavior

## Reproduction and change

On iPadOS 27.0, the 26.0.0 `swiftui-introspect` pin treats iOS 27 as a future version and skips the application's `TextEditor` customization. The result pane then opens the keyboard when tapped, and VoiceOver announces it as an editable text field. The `.constant` binding restores the model text after a typing attempt, but that does not make the native view read-only.

Commit `c2d8106a394720fd3c1c5a845aa162974f5d1ccb` opts the existing `UITextView` customization into iOS 27 only. It continues to set `isEditable` from the source/result role and restores the existing clear background and insets. iOS 28 is deliberately excluded until its underlying view hierarchy is checked. The dependency pin and iOS 15 deployment target are unchanged.

## Comparable run

| Condition | Before | After |
| --- | --- | --- |
| Application source | `4e0ee5d30cb6ea64b771ff781a08266e5ac84e05`; application/project files and `Package.resolved` have no diff against base `fc0ee36f14ddd742c54afc2d1c8e49112437b5a1` | `c2d8106a394720fd3c1c5a845aa162974f5d1ccb` |
| Isolated bundle | `org.gewill.OpenCCman.Issue37QA20260924` | `org.gewill.OpenCCman.Issue20QA20260924` |
| Product code binary SHA-256 (`OpenCCman.debug.dylib`) | `05bbd308cbc3aab8118846b35897dd0a9d0afc02cc0384ada8eb78b121e638fa` | `9e8ae9ec6165b3f558b345aeceddf02ae5b4676071bb9bed63d629503e171ce5` |
| Environment | iPad Air 11-inch (M4), iPadOS 27.0 simulator (24A434), Xcode 27.0 (27A266a), 820×1180 pt, English, light, default text size | Same device and settings |
| Source and converted result | `鼠标里面的硅二极管坏了，导致光标分辨率降低。` → `鼠標裏面的硅二極管壞了，導致光標分辨率降低。` | Same text |
| Tap converted result | Keyboard appears; typed `X` is discarded by the constant binding | No keyboard; result unchanged |
| VoiceOver, empty result position | `Result Text field Double tap to edit…` | `Result` |
| VoiceOver, source position | Announces editable text field | Still announces editable text field |
| VoiceOver, converted result | Not used as a before/after speech comparison | Speaks the traditional result text |

The Xcode 27 `XCUIDevice.voiceOverService` probe navigated with `moveForward()` and captured actual utterances, rather than inferring speech from AX labels. The source and result are at the same navigation positions in [before](logs/before-home-speech.txt) and [after](logs/after-home-speech.txt); the successful converted-result reading is in [after-converted-speech.txt](logs/after-converted-speech.txt). [The two runtime result-editor tests](logs/before-after-editor.txt) passed with their respective expected keyboard states. A direct coordinate tap followed by `currentSpeech()` sometimes returned the app title or a card, so those utterances were **not** used to assert the result role; the ordered navigation tests are the speech evidence.

The before/after screenshots and 78.695-second no-audio HEVC interaction recording were captured from the same simulator test run and uploaded with `gh` to the PR. The screenshots are 1640×2360 px; the video has one HEVC stream and no audio. Local SHA-256: before screenshot `b1e89954c58724b52401e241ab0bfcc3ec0062f0e7227e141720470141c89262`, after screenshot `728c891e4fecaa0b7df097902060703959d62de4a4b4a0223473ca0ec116f9a4`, video `0ad57df332d4a11f636136087f0bc963b0bf6f0e768f3212eed76c1daabf429e`.

On the same built candidate, iPad Air 11-inch (M2) / iPadOS 18.6 was checked separately with physical HID taps: conversion produced the expected traditional result, and tapping the result after dismissing What's New did not summon a keyboard. This is a regression spot check, not iOS 15 acceptance. The initial simulator VoiceOver state was off; `voiceOverService` restored it after every test and `devicectl` read it back as off.

## Re-run

The diagnostic [XcodeGen project](probe/project.yml) and [XCUITest source](probe/Tests/OpenCCmanVoiceOverProbe.swift) use the two isolated bundle IDs above. Build/install the base and candidate with those IDs on an iOS 27 simulator, then run:

```bash
cd docs/validation/issue-20-ios27-readonly/probe
xcodegen generate
xcodebuild test -project OpenCCmanVoiceOverProbe.xcodeproj \
  -scheme OpenCCmanVoiceOverProbe \
  -destination 'platform=iOS Simulator,id=<iOS-27-device-UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:OpenCCmanVoiceOverProbe/OpenCCmanVoiceOverProbe \
  CODE_SIGNING_ALLOWED=NO
```

The project check, isolated iOS 27 Debug build, `scripts/check-introspection.py`, both before/after result-editor tests, both home-speech tests, and converted-result speech test passed. This addresses one reproducible part of #20; full VoiceOver, pure-keyboard, Chinese IME, physical-device, signed-build, and iOS 15/macOS 12 acceptance remain open in #20/#16.

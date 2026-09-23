# #20 Mac keyboard and accessibility runtime subset (2026-09-24)

This is a current-source **subset** of #20, not a complete VoiceOver or release-build acceptance. It verifies a keyboard route that the earlier focus-order report left open: the main toolbar's conversion-settings button and the preset sheet. No application source was changed.

## Identity and conditions

- Source: `develop` `f09f6ce2f1b10f8288d0eb31263e30125f41153c`.
- Host: Apple Silicon, macOS 27.0 (26A428), Xcode 27.0 (27A266a), English, light appearance, default text size, non-Pro, side-by-side workspace. The source was the app's synthetic sample `鼠标里面的硅二极管坏了，导致光标分辨率降低。`.
- Built the complete Debug macOS app with `CODE_SIGNING_ALLOWED=NO`; the build finished successfully. Build-log SHA-256: `83552d9a9a09a23722cb8f51377db05cb792d94c77a26aabcc62f8cb43e873d5`.
- The runtime copy used unique bundle `org.gewill.OpenCCman.AccessibilityQA20260924`, had `NSServices` removed from its copied Info.plist, retained the project's sandbox entitlement, and was signed ad hoc. `codesign --verify --deep --strict` passed. Main executable SHA-256: `9d121edea89d037cec830270d9335948a0bce1f86c03ff3ac9b7ee941e028d57`. This was **not** an App Store or TestFlight build.
- UI input/observations: Codex computer use, macOS accessibility tree, and actual window screenshots. [ScreenCaptureKit recording source](RecordWindow.swift) selected only this QA window, 1024 × 768 px, H.264 at 15 fps, without audio, microphone or cursor. The untrimmed recording finished normally; the [published clip](media/keyboard-preset-flow.mp4) contains the keyboard interaction from that recording.

## Observed keyboard route

The system's `Use keyboard navigation to move focus between controls` was **off** before the test and temporarily **on**. From the main window, sequential Tab navigation visited: Conversion settings → Side by side → Stacked → Convert → Pane sizes → Paste Text → Import TXT → Source. Native Source accepted an ordinary Tab as text, so **Control-Tab** moved to Result. The route then visited Get → Remove recommendations → More → the toolbar's Conversion Preset control. The toolbar focus was visible as a focus ring even though the computer-use accessibility snapshot did not emit a focused-element line for it. Pressing Space opened the actual conversion-settings sheet with initial focus on Done.

Within the sheet, Tab visited the four preset buttons, two Target Language buttons, three Variant buttons, and two Region Idiom buttons in visual order. Space selected Taiwan Standard + Idioms; the accessibility tree marked that preset, Taiwan Standard, and Taiwan Idiom as selected. Space then selected Simplified Chinese; the Variant and Region Idiom buttons were explicitly marked disabled in the accessibility tree, while their retained selection remained visible. Space restored Traditional · OpenCC and the enabled state; Escape closed the sheet. The source sample, side-by-side layout, and empty result remained intact. No conversion, purchase, import, export, or recommendation action was taken.

| Same-source state | Screenshot |
| --- | --- |
| OpenCC preset: advanced options enabled | ![OpenCC preset active](https://github.com/user-attachments/assets/598b02b8-9a55-4367-b020-f82cd50cb606) |
| Simplified preset: advanced options disabled | ![Simplified preset with advanced options disabled](https://github.com/user-attachments/assets/a32a382f-1b5c-479b-a1b4-2a58e46442bb) |

[Actual keyboard and preset interaction](https://github.com/user-attachments/assets/ade18e20-a2f5-4cf6-854b-5075809c90d9). The untrimmed capture was 56.076667 seconds; `ffmpeg -ss 28 -t 25` re-encoded the 24.949153-second published segment without audio. Local media SHA-256: `opencc-active.png` `25c825ff2264e1d28caafd94b18c733526a36ec4e143fcca7c8f77a5241f6b10`; `simplified-disabled.png` `49ceb360137f6cc321efbddefd2b1e5319f87697bdc52fa695c04e7cb8a4a160`; `keyboard-preset-flow.mp4` `c93a8c2c6aa12024dcbaf703cce538a006d10e38d7bcee3a74bd27964ca36412`. These are two UI states of the **same** source, not before/after evidence of an application change. The assets were [uploaded to #20 with `gh`](https://github.com/gewill/OpenCCman/issues/20#issuecomment-5801018472) and read back.

## VoiceOver and IME limits

System Settings showed VoiceOver **off → on → off**. A synthetic Control-Option-Right keypress did not produce a reliable cursor movement or utterance observation, so neither reading order nor actual spoken labels are marked passed. Apple documents that a user may need to [interact with groups using VO-Shift-Down](https://support.apple.com/guide/voiceover/control-your-mac-with-keyboard-commands-vo2681/10/mac/27); this test did not prove full group traversal.

The system had a selected Pinyin input source, but individual computer-use `pressKey` calls produced literal ASCII `nihao` in the QA Source field, without a visible candidate or marked-text range. This is a limitation of the **test input path**, not evidence that the app breaks a real IME. The synthetic text was restored immediately. Existing native marked-text regression tests remain a separate layer of evidence; they do not replace a physical IME session.

## Cleanup and remaining acceptance

The QA app was quit. Keyboard Navigation and VoiceOver were read back **off**, `AppleKeyboardUIMode=0`, the input source was not changed, and System Settings returned to its original AirDrop & Continuity page. The installed production app and its preferences were not operated.

#20 remains open for full keyboard routing through conversion/cancel, import/export, error dialogs and read-only copy; reliable VoiceOver speech/order and activation; genuine Chinese IME composition across layout changes; iPhone/iPad accessibility flows; and the final signed build. Minimum iOS 15 / macOS 12 execution remains a separate release gate in #16.

## Current-source file flow follow-up

A later `develop` build verified the Mac keyboard import → convert → export → invalid-encoding error path, with exact output bytes and preserved prior result. See [2026-09-24 file-flow subset](../issue-20-keyboard-file-flow/README.md); it does not resolve the VoiceOver or real IME gaps above.

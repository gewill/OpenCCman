# #34 Mac import success and invalid-UTF-8 deferral (2026-09-24)

Later iOS evidence: [iPhone and initial iPad run](ios-qa-2026-09-25.md), [iPad Files-selection follow-up](ipad-followup-2026-09-25.md).

This is a runtime acceptance slice, not completion of #34. No application source changed.

## Source and isolation

- Current `develop`: `bfb4a750ec538b32824701bd6db6319ea6d3b391`. Application and Xcode-project sources have no diff from `4e0ee5d`, the source of the passing Mac Debug build. Xcode 27.0 (27A266a), macOS 27.0, English, light appearance, default text size.
- A separate QA copy used bundle ID `org.gewill.OpenCCman.Issue34ImportSuccessQA20260924`. Its copied `NSServices` registration was removed; the app's sandbox entitlements remained. It was signed ad hoc and `codesign --verify --deep --strict` passed. Executable SHA-256: `316dfecae1dde7045317e66f990df2220d59237a77db9ed1378f22ffe2b6bd48`. The installed application and its preferences were untouched.
- The picker used separate `/tmp` folders, each containing only the indicated synthetic TXT. All UI actions used Codex computer use. The window-only ScreenCaptureKit recording was 1024×768 pixels without audio, microphone or cursor.
- The QA preference `lastPresentedWhatsNewVersion` started at `2.0` to suppress automatic presentation. With each native import panel already open, it was externally changed to `1.3` for **only the isolated QA bundle** to create a pending automatic card. This is a diagnostic state, not evidence of normal first-launch timing.

## Actual outcomes

The app first held source `旧稿` and converted result `舊稿`. During the valid TXT panel, AX showed the system `open-panel` without a What’s New sheet. Selecting `source.txt` caused the 2.0 sheet to appear. After dismissal, the source AX value was `鼠标\r\nEmoji 😀\n`, the prior result was empty, and Copy Result / Export TXT were disabled. The 19-byte fixture SHA-256 was `b8de573265404afac14be392036ca084d141f659a7943b450553ae3bb45f7c9c`; the QA preference read back `2.0`.

The valid source was converted again; the result AX value was `鼠標\r\nEmoji 😀\n`. During the invalid TXT panel, AX again showed only `open-panel`. Selecting the 22-byte `invalid-utf8.txt` (containing `0xFF`, SHA-256 `668389dc43ff9e3b188d910b863ae7572ee2c57644dec0c6a17033fc964cfa9f`) led to an error alert: “This file is not valid UTF-8. Save it as UTF-8 and try again.” No What’s New sheet overlapped the alert. After clicking OK, the 2.0 sheet appeared. Dismissing it returned to the valid source and result, with Copy Result / Export TXT still enabled; the preference again read back `2.0`. AX string inspection preserved the CRLF and trailing LF; this run did not separately export the result for byte-level file comparison.

The [issue comment](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5805009009) contains four real screenshots and both interaction videos uploaded with `gh`. The successful-import video SHA-256 is `3ee7ecc779c119c8052f0bff651a78ccc72477db0eda21fd8644daa08cf41163`; invalid-import video SHA-256 is `dae9d12b424a9709cf197a3cc0f32f57193011d004c86e48ff6280e2f0fd6ce9`. These recordings show the visible order of the picker, card and error alert; they do not establish every frame of dismissal animation or the timing of long-running imports.

## Remaining acceptance

Mac import cancellation has [separate evidence](../issue-34-file-panel/README.md), as do [export cancellation and success](../issue-34-export-panel/README.md). #34 remains open for long-running conversion/import presentation and conversion success/failure/cancel, normal Pro/error/quota combinations, iPhone/iPad interactions and VoiceOver, iOS 15/macOS 12 execution, and the final signed Xcode Cloud/TestFlight build. An ad-hoc Debug copy does not establish distribution behavior.

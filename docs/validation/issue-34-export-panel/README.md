# #34 Mac export-panel deferral (2026-09-24)

This is one runtime acceptance slice. #34 remains open. No application source changed.

## Source and setup

- `develop` source SHA: `ffcc4db9ea944121023e7742cd742bd64a836e45`. There is no application or Xcode-project diff from `4e0ee5d`, the source used for the passing Mac Debug build. Xcode 27.0 (27A266a), macOS 27.0, English, light appearance, default text size, 1024×768 pt window.
- A separate QA copy used bundle ID `org.gewill.OpenCCman.Issue34ExportQA20260924`, removed copied `NSServices`, retained the app's sandbox entitlements, and was signed ad hoc. `codesign --verify --deep --strict` passed; executable SHA-256: `2d8b2278c4343d365a1ee567bfd7430c280d42ce5003dcd706c9a1c9915fdb63`. The installed production app and its preferences were untouched.
- The dedicated `/tmp/openccman-34-export-fixtures` folder held only synthetic TXT fixtures. All UI actions used Codex computer use. The window-only ScreenCaptureKit recorder captured the QA app at 1024×768 pixels without audio, microphone, or cursor.

## Observation

The QA bundle started with `lastPresentedWhatsNewVersion=2.0` so the initial card stayed dismissed. It imported `source.txt` (`鼠标\r\nEmoji 😀\n`), then converted to `鼠標\r\nEmoji 😀\n`. While each native export panel was open, the isolated QA preference was set externally to `1.3` to create a pending automatic card. This diagnostic state is not a normal first-launch path.

In the cancellation path, the save panel was visible without the What’s New sheet. Escape closed the panel, the card appeared once, and dismissing it left the source and result intact. In the success path, the save panel was likewise alone; saving `source-converted-success-2.txt` produced the expected 19 bytes (SHA-256 `9695c7fcb4f38992883ea136b95f59bc7895f7a9a36295ab6de429d14e1fa589`), then the card appeared. Dismissing it returned to the populated workspace; the preference read back `2.0`.

The [issue comment with three real screenshots and two interaction videos](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5804745846) contains the UI evidence. The cancellation video is a 64.295-second excerpt and the success video a 20-second excerpt from longer recordings; the removed parts are static panel/card footage. Video excerpts show the visible state transitions, not an exhaustive animation-frame assertion. Video SHA-256: cancellation `a1a5a2b419d8a723e9dff7916a05d6a39c8d410e00b205ed33f88e0ed7d6c7a8`; success `3aca3769bbb7ce8e2f9bc58bfad4368df361960f6894aea0aac375`.

## Remaining acceptance

This covers only Mac export-panel cancellation and success under a diagnostic pending-card state. Conversion/import in progress, import errors, quota/error and Pro presentations, iPhone/iPad orientations and VoiceOver, iOS 15/macOS 12 execution, and the final signed Xcode Cloud/TestFlight build remain open. The ad-hoc Debug copy does not establish distribution behavior.

# Issue #34: Mac quota alert and Pro sheet deferral

2026-09-24. This is a presentation-coordination check on an isolated diagnostic app, not a purchase or distributed-build check. The [issue comment](https://github.com/gewill/OpenCCman/issues/34#issuecomment-5805173045) contains the raw window-only [recording](https://github.com/user-attachments/assets/d05cbe7f-cf37-4552-b179-11e776e873e7) and real [quota alert](https://github.com/user-attachments/assets/359fb78d-76d0-4b5d-9f64-ba786b5d2738), [Pro sheet error](https://github.com/user-attachments/assets/f108de44-c1d8-4252-ac54-3f0d3c5522ce), and [What's New](https://github.com/user-attachments/assets/3f32e80c-5eeb-4070-9f86-fcad6afd6d35) frames. The frames come from the same recording; they are UI states on one source, not a code before/after comparison.

## Source and environment

| Item | Value |
| --- | --- |
| App source | `4e0ee5d30cb6ea64b771ff781a08266e5ac84e05`; `OpenCCman/` and `OpenCCman.xcodeproj` have no diff from `7e75d82e96edc4b86e33f79f5f702dda59937c56` |
| Toolchain | Xcode 27.0 (27A266a), macOS 27.0 (26A428) |
| App | Separate ad-hoc signed `org.gewill.OpenCCman.Issue34QuotaProQA20260924`; executable SHA-256 `efb8da03f5a9bebdf71fefe6b552b2b3dd2cc62501d8cd59908d171831978d3f` |
| Window | 1024×768 pt; English, light, default text size |
| Capture | ScreenCaptureKit, only the QA app window, H.264 1024×768, 51.843 s, no audio/microphone/cursor; MP4 SHA-256 `baaadab1a9d1095217e29dc457965622818a6d2db12f93d966d187e7f1143753` |

The QA bundle used its own defaults. `testNumbersPerDay` held 12 for the current local day and `isPro` was false. I first set `lastPresentedWhatsNewVersion` to `2.0` to reach the home screen, then changed it to `1.3` **while the quota alert was open** to represent a pending card. This is a synthetic presentation state; it does not establish that 12 real conversions happened.

## Observed sequence

1. Convert showed **Pro only feature**. No What's New sheet overlaid the quota alert.
2. Pro opened the Pro sheet. Its accessibility tree exposed Back, Restore, and the feature list; the What's New sheet did not appear.
3. Back closed the Pro sheet. The parent window was visually inactive and the card remained pending. After clicking the parent window to make it main, the 2.0 card appeared once. This supports deferral until the window is eligible, **not** automatic presentation while it remains inactive.
4. Done closed the card. The isolated defaults then contained `lastPresentedWhatsNewVersion = 2.0`; the source text was intact, the result empty, and the synthetic daily count still 12.

The modified bundle ID has no matching App Store Connect products. RevenueCat consequently displayed a configuration error, whose long diagnostic text was visibly clipped in that QA sheet. This cannot validate real offering loading, purchase, restoration, or the official bundle's error layout. No purchase, restore, or feedback action was taken. The QA process exited afterward; the formal OpenCCman app and its preferences were untouched.

Issue #34 stays open for long-running conversion/import paths, iPhone/iPad VoiceOver and remaining presentation cases, iOS 15/macOS 12 behavior, and a signed Xcode Cloud/TestFlight build. Issues #14 and #71 retain their own purchase and Customer Center acceptance.

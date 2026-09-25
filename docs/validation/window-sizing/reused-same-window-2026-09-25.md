# Same-window reopening after a close (#57)

On 2026-09-25, an isolated macOS QA app showed a blank 300×412 pt window after language-change restart and further interaction. The title bar remained, but the workspace accessibility subtree was absent; creating a new window showed normal content. The pre-fix app came from `40a4e33` and used English, Dark, and 150% in the observed blank state. There are no application-source, project, or package changes between `40a4e33` and the repair branch's base `b3409ee`.

The exact `NSWindow` object identity of that UI occurrence was not recorded. A separate native regression reproduced a concrete missing case: close and reopen the **same** `NSWindow` while retaining its hosting view. Before this repair, `MainWindowLifetimeChecks` failed at `Reopened same window must remount content`; after the repair, it passed. The prior regression covered a retained host attached to a *different* `NSWindow`, but not this same-object path.

`WindowContentLifetime` now remounts closed content when its original window becomes key again or receives an update and is visible on the next main-loop turn. The latter is needed because a same-object window can be ordered front without becoming key in the native regression. The visible check prevents an update sent during close from remounting content. The existing tests still cover hidden windows retaining state, unrelated or duplicate close notifications, and release of models after close.

Runtime recheck used a separate ad-hoc signed Debug QA bundle `org.gewill.OpenCCman.ReusedWindowQA20260925`, built with Xcode 27.0 on macOS 27.0 from base `b3409ee` plus this patch. `codesign --verify --deep --strict` passed. At actual 300×412 pt, Computer Use performed Convert → ⌘W → reopened window → Convert; the workspace and result accessibility values were present after reopening. This is a Debug QA check, not a signed Xcode Cloud or TestFlight acceptance.

| Pre-fix blank window | Repaired app after reopening |
| --- | --- |
| ![Pre-fix 300×412 pt window](https://github.com/user-attachments/assets/10f1689e-701f-4b2a-bb1c-f278770d8e64) | ![Repaired 300×412 pt window](https://github.com/user-attachments/assets/b064374f-aaf3-46e1-bfac-83f151e5bdc2) |

[22.33-second window-close/reopen video](https://github.com/user-attachments/assets/e16eb8bb-e2c4-4499-ba57-c20eaf65bd8b) records only this QA application's windows with ScreenCaptureKit; black frames are the interval with no QA window. The video has no audio, microphone, or cursor. Cropped H.264 SHA-256: `4344561f0978682f8b6945d360f06cef4b3a749ed83a2ef1b3d022ae169d2cec`.

`bash scripts/check-window-sizing.sh` passed native geometry, restoration, lifetime, and same-window remount checks. The full macOS Debug app build passed. Final signed distribution, macOS 12, and the remaining #191 text-size / keyboard / VoiceOver acceptance remain open.

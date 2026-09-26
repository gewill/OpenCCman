# Physical display run — 2026-09-25

This records the actual #57 hardware run and the window-reopen defect found in its final stage. The three display screenshots and source-window recording are attached in the [#57 evidence comment](https://github.com/gewill/OpenCCman/issues/57#issuecomment-5827751143); the recording ends when macOS reconfigures the displays, so the screenshots and frame measurements are the evidence for the disconnect and reconnect stages.

## Environment and source

- Mac: macOS 27.0 (26A428), Xcode 27.0 (27A266a).
- Screens were separate logical displays, with mirroring off: MAG321UX OLED, 3840×2160 pixels / 1920×1080 points, and the built-in screen, 1496×967 points.
- Original QA app: ad-hoc signed Debug bundle `org.gewill.OpenCCman.TextSizeKeyboardQA20260925`, built from `fc5a901d`. The application source at `develop` `0babaa6` is identical to that build; no production bundle or production preferences were used.
- Reopen-fix QA app: ad-hoc signed Debug bundle `org.gewill.OpenCCman.WindowReopenQA20260925`, built from this branch. `codesign --verify --deep --strict` passed.
- Benign source text: `测试外接显示器断开与重连。鼠标里的硅二极管。`; result: `測試外接顯示器斷開與重連。鼠標裏的硅二極管。`.

| Stage | Available screen visible frame (pt) | Main window frame from CGWindow (pt) | Observed |
|---|---:|---:|---|
| Before removal, external | `(0, 60, 1920, 990)` | `(0, 30, 961, 990)` in Quartz top-left coordinates | Source, result, horizontal layout, and Convert visible |
| External physically removed, built-in only | `(0, 57, 1496, 882)` | `(0, 28, 748, 882)` in Quartz top-left coordinates | Same window identifier; source, result, layout, and Convert retained inside built-in visible area |
| External physically reconnected | `(0, 60, 1920, 990)` | `(0, 30, 960, 990)` in Quartz top-left coordinates | Same window identifier returned to the external display; source, result, layout, and Convert retained |

The window was initially 1024×768 pt, then moved/resized to the left half of the external visible area before removal. The different `NSScreen.visibleFrame` and Quartz coordinate origins above are intentional; the containment conclusion was checked against the actual visible region, not by comparing the raw Y numbers directly.

After reconnection, **File → Close** on the original QA build produced a new, visible 1024×768 pt window shell with no business content. Creating another window with Command-N rendered normally. The defect was in `WindowContentLifetime`: it correctly removes its business subtree when its NSWindow closes, but `closed` stayed true if SwiftUI attached the retained host to a different NSWindow.

The branch resets `closed` only when `MainWindowReader` reports a *different* NSWindow identity. A synthetic native regression first failed against `develop` with `A host attached to a new window must remount content`, then passed with the fix. The fixed QA build rendered source, layout, and Convert after closing and reopening a window. A normal Quit and relaunch rendered a 1024×768 pt window on the connected external screen and left the core controls reachable. This separate QA bundle had no saved non-default frame, so it does not by itself revalidate restoration of the original bundle's saved size. The original bundle's non-default frame survived the physical remove/reconnect cycle as measured above.

## Verification and limits

- `bash scripts/check-window-sizing.sh`: pass, including the new retained-host test.
- Mac Debug `xcodebuild` for the fixed QA bundle: pass; ad-hoc signature verifies.
- Physical display sequence: passed for geometry, text, result, and layout on the original QA build. The close/reopen stage exposed a bug and passed on the fixed build; it is not yet a signed distribution-build acceptance.
- The 33.66-second window-only recording was interrupted by display reconfiguration and captures only the pre-removal window. It must not be described as a continuous disconnect/reconnect video.
- Mac 100%/125%/150% complete language/theme/keyboard/VoiceOver matrix remains in #191. macOS 12 and final signed release validation remain in the release issues.

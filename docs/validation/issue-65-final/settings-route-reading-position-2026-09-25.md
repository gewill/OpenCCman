# Mac editor reading position across Settings — 2026-09-25

This is a new #65 regression found while running the current 2.0 candidate. It does not change the historical 2026-09-14 TextKit measurements in this directory.

On `develop` `0babaa6`, scrolling a 180-paragraph source to paragraph 155, opening **More → Settings**, and returning retains the source text but returns its viewport to paragraph 1. `RootView` owns the per-window `HomeViewModel`, while the route change dismantles `NativeWorkspaceTextEditor` and its coordinator-owned `WorkspaceScrollKeeper`. The model therefore kept the text without a reading anchor for the new native editor.

The fix stores a logical character/line-offset reading position for each source and result editor in the window-owned model. Native teardown snapshots the current position; a new native editor restores it after text and layout have been installed. A changed source or conversion result invalidates the corresponding position. The state contains no duplicate document, and an existing selection/navigation still takes precedence over queued restoration.

## Actual app comparison

- macOS 27.0 (26A428), Xcode 27.0 (27A266a), English UI, light appearance, application text size 100%, 1024×768 pt window, horizontal layout.
- Same 180-paragraph mixed Chinese/English/Emoji benign text; source viewport was at paragraph 155 in both isolated Debug apps before entering Settings.
- Before: ad-hoc Debug `org.gewill.OpenCCman.TextSizeKeyboardQA20260925`, built from `fc5a901d`, whose application source is identical to `develop` `0babaa6`; after: ad-hoc Debug `org.gewill.OpenCCman.ScrollQA20260925` from this branch. The baseline QA app's prior 150% setting was recorded, temporarily set to 100% for this comparison, then restored to 150%.
- Baseline returned to paragraph 1. Fixed app returned to paragraph 155. A subsequent conversion produced a long result; its source and result viewports independently stayed at paragraphs 155 and 148 after another Settings round trip. Replacing the source with a short new document cleared the old result and did not inherit either old reading position.
- Real before/after screenshots and window-only interaction video are attached to the related PR. The short videos are visual interaction evidence, not latency measurements.

## Checks and limits

- `bash scripts/check-workspace-editor.sh`: pass, including source and result teardown/recreate, stale-position invalidation, 1/5/10 MiB TextKit checks, selection, marked-text echo, and undo behavior.
- Mac Debug `xcodebuild` with a separate ad-hoc QA bundle: pass; `git diff --check`: pass.
- The native regression tests the real representable and `NSTextView`, but does not run a real input method. The app QA above checks the route transition and visible first paragraph. Complete VoiceOver, pure-keyboard, real IME, minimum macOS 12, and signed distribution acceptance remain tracked by #20/#16.

# Narrow inspector label layout

Tracks [#49](https://github.com/gewill/OpenCCman/issues/49). This is a focused
follow-up to the existing iPad workspace, not completion of its device matrix.

## Problem and implementation

At 1180 × 820 pt on iPad Air 11-inch (M2), English labels in the 248 pt inspector
split words such as “HongKong” across several lines. The preset heading also
competes with the selected preset in one horizontal row.

- Place the preset heading above its menu without changing the menu action.
- Measure localized, unbroken words with the same semantic body font as the
  selected segment, including the shared horizontal content inset. Keep normal
  word wrapping, but stack the existing segments when words cannot fit.
- Measure semibold labels for all choices so changing selection cannot cause an
  axis change. Width, locale and text size changes can restore the horizontal row.
- Keep measurement views invisible, inaccessible and noninteractive. They do not
  add another hit region or alter the visual control envelope.
- Keep accessibility-size vertical groups, current bindings, business models,
  editor identity, window thresholds, deployment floors and pinned dependencies.

The measurement uses SwiftUI's
[ideal-size behavior](https://developer.apple.com/documentation/swiftui/view/fixedsize(horizontal:vertical:)).
No iOS 16+ layout API is required.

## Validation status

- Project/Swift syntax, localization resolution and whitespace checks passed.
- Native control-size and live segment-layout regression passed with Xcode 27:
  two/three choices, narrow/wide recovery, live English/Traditional Chinese,
  selection stability and accessibility type. The same test against the baseline
  `59cad17` SegmentView fails the narrow-English assertion; the repaired source
  passes. The test flushes the host's rendering transactions before inspecting
  preference geometry; initial attempts without flushing produced no geometry
  and were test-host failures, not product measurements.
- Workspace resolution/recovery regression passed. Existing Mac 28 pt control
  envelopes, 32 pt primary controls and multiline growth remain unchanged.
- Full Mac application build and regression passed in
  [run 34941520884](https://github.com/gewill/OpenCCman/actions/runs/34941520884).
  The arm64 iOS Simulator build passed in
  [run 34941528578](https://github.com/gewill/OpenCCman/actions/runs/34941528578).
  Both use source `47ee5213f17678ef9cbd80c82e1333f453fab7ae` and Xcode 26.3.
- Actual Mac/iPad screenshots and iPad interaction video have been captured.
  The PR remains draft pending iPhone and maximum accessibility-size runtime
  validation; no real-device or release gate is closed by these captures.
- Existing Stage Manager, hardware keyboard, real IME and iOS 14/macOS 11 gates
  remain in #49/#16. No Xcode Cloud release or `build*` push is part of this change.

## Baseline evidence

Source `6af5ded56b70c2fca46793ccfac9cdbce6e5ae9e`, iOS 18.6, iPad Air 11-inch
(M2), 1180 × 820 pt, English, light appearance, default text size. The preceding
language fix is correct; this follow-up addresses layout separately.

![Before: narrow English inspector](https://github.com/user-attachments/assets/bccf79cc-2483-4553-a954-a0ec60c4ca61)

## Runtime results — 2026-09-15

[Actual before/after tables and interaction video](https://github.com/gewill/OpenCCman/pull/78#issuecomment-5676591710), uploaded using `gh`.
Media SHA-256 values are recorded in `media-checksums.json`.

Before: `6af5ded56b70c2fca46793ccfac9cdbce6e5ae9e`; after:
`47ee5213f17678ef9cbd80c82e1333f453fab7ae`. Both are CI Xcode 26.3 builds.
The Mac copies have an isolated bundle identifier and temporary ad-hoc signatures.

| Platform and scope | Observed result |
| --- | --- |
| macOS 27.0, 1920 × 990 pt window, 264 pt inspector, English/light/default size | Preset heading no longer competes with its menu; variant labels form complete rows. Other groups remain horizontal. Before/after captures use the same source text and empty result; the after capture has an inactive titlebar. |
| Mac selection, conversion and keyboard layout switches | Taiwan selection and converted result persist through Cmd-Option-1/2. Simplified target disables advanced choices; switching back retains Taiwan. AX exposes the real buttons without hidden measurement text. |
| iPad Air 11-inch (M2), iOS 18.6, 1180 × 820 pt, 248 pt inspector, English/light/default size | Words no longer split into fragments. Selection, conversion, stacked layout and portrait rotation retain the source/result/configuration. The system rating prompt was dismissed without rating. |
| iPad portrait sheet, 820 × 1180 pt | Wider groups return to horizontal rows with the current selection. The Done button closes the sheet. |
| iPad extra-extra-extra-large | Bottom choices remain reachable by a touch drag. This is the largest standard size offered by the mirror, not the maximum accessibility size. The initial wheel-scroll attempt did not move the content and is not counted. |
| iPad dark, English/Simplified/Traditional Chinese | Labels remain legible and selected state visible. Chinese captures use new-process locale arguments; they do not prove same-process draft retention during a language change. |

### iPhone validation is incomplete

On the existing iPhone 15 Pro Max iOS 18.6 simulator, the baseline application
starts and its main thread waits in `CFRunLoopRun`. The mirror logs normalized
touches on the settings and More buttons, but neither opens. The separate Home
action does return to SpringBoard, and reopening returns the same app PID.
This is not evidence of a new layout regression or successful touch delivery.
The input-path cause remains undiagnosed; no iPhone settings screenshot/pass is
claimed for this candidate. Do not substitute the home-screen capture.

### Cleanup

iPad appearance restored to light, content size to `large`, orientation to portrait.
VoiceOver was never enabled in this run. The isolated Mac process exited before
its preferences were restored. Only the test bundle was removed from each
simulator, both simulators were shut down, and both scoped mirror helpers exited.
The separate #19 closed-window baseline was not queried/reopened during this run.

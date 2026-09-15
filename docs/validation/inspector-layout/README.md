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
- Full Mac and iOS application builds: pending CI.
- Actual before/after screenshots and interaction checks: pending; the PR remains
  draft until the affected Mac/iPad/phone layouts have runtime evidence.
- Existing Stage Manager, hardware keyboard, real IME and iOS 14/macOS 11 gates
  remain in #49/#16. No Xcode Cloud release or `build*` push is part of this change.

## Baseline evidence

Source `6af5ded56b70c2fca46793ccfac9cdbce6e5ae9e`, iOS 18.6, iPad Air 11-inch
(M2), 1180 × 820 pt, English, light appearance, default text size. The preceding
language fix is correct; this follow-up addresses layout separately.

![Before: narrow English inspector](https://github.com/user-attachments/assets/bccf79cc-2483-4553-a954-a0ec60c4ca61)

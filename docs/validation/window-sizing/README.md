# Mac window sizing — issue #57

Latest runtime: [2026-09-25 current-source sidebar and layout matrix](#2026-09-25-current-source-layout-follow-up); [2026-09-24 actual edge dragging, minimum result access, new window and restart](2026-09-24-live-resize/README.md). On `develop` `9b335ac`, the isolated QA app was dragged from system Zoom through 1101 pt to 300 pt width, then to 300×412 pt; content stayed intact, a new window remained independent, and native size restoration passed. The current-source follow-up verifies sidebar and axis behavior without repeating that drag. These checks do **not** close the physical display-removal, Mac user-adjustable large-text decision, or final signed-package gates.

Implementation: [PR #74](https://github.com/gewill/OpenCCman/pull/74), merged into `develop` at `e6994c8`. Base `714f6bf`; first implementation checkpoint `48ad349`; CI app-build checkpoint `eb92b7e`. Runtime acceptance is in progress; this record is not a release approval.

Earlier: [2026-09-23 macOS reading-size follow-up](#2026-09-23-macos-reading-size-follow-up). The [2026-09-16 runtime matrix](2026-09-16-runtime/README.md) uses product source `4372fa4`; historical rows below keep their original source scope.

## Contract

- Recommended initial size: 1024 × 768 pt, passed to `NSWindow.setContentSize` only when no valid native history exists. `contentRect(forFrameRect:)` defines this measurement; with SwiftUI full-size content windows the titlebar can occupy part of that rectangle, so it is not a promise of 768 pt of editor space.
- Minimum SwiftUI root size: 300 × 360 pt. `contentMinSize` is initially seeded with this value, then SwiftUI accounts for system chrome. On macOS 27 the measured final `contentMinSize` and frame minimum are 300 × 412 pt, with a 52 pt titlebar and a 300 × 360 pt `contentLayoutRect`. The titlebar height is not hardcoded. The 300 pt narrow-workspace requirement is retained.
- Existing valid native frame history wins over the recommendation. History is captured before SwiftUI creates windows, because AppKit may save a provisional frame during creation. Closing a window updates the in-process history for its existing autosave name.
- Additional new windows retain SwiftUI's cascading placement; only the first fresh window is centered. Window sizing does not replace the native window delegate, autosave name, scene identity, layout preference or business model.
- Screen constraints operate on the entire window frame and the screen's visible frame (excluding menu bar/Dock). Choose the display with greatest overlap; if the previous display is absent, use the current/main screen. Clamp oversized/offscreen frames. Fullscreen/live resize are excluded from screen correction.
- Sheet dismissal is followed by a deferred screen correction. The first What's New sheet can capture the provisional parent's origin before recommended sizing; without this correction, its dismissal restores that old origin and leaves the bottom of the enlarged window behind the Dock. The correction retains the current size and only fits it to the available screen.

## Verified so far

| Evidence | Result / scope |
| --- | --- |
| Geometry checks | Valid/corrupt history, negative-origin screens, disconnected monitor, oversized frame, idempotence: PASS |
| Native AppKit checks | Fresh and restored windows despite provisional autosave, minimum size, repeated attachment and one-time NSView.window callback: PASS |
| Workspace resolution checks | PASS; existing layout thresholds unchanged |
| Project/source syntax | PASS |
| CI candidate `7fc833c`, macOS 27 / arm64 | Universal unsigned Debug artifact from [run 34933596160](https://github.com/gewill/OpenCCman/actions/runs/34933596160), ad-hoc signed locally in isolated bundle `org.gewill.OpenCCman.PRValidation`; App Regression and full Mac build PASS |
| Fresh window without automatic sheet | Frame 1024×768, root content 1024×716; centered within display |
| Restore a 300×100 historical test frame | Clamped by native minimum to 300×412, root 300×360; conversion succeeds and outer scroll reaches result/copy/export |
| Actual resize, same process/model | System Zoom to 1920×990, right-edge drag to 838×990, bottom-edge drag to 838×412; source/result retained |
| Additional window | New window 1024×768 at cascaded position (29,59 in Quartz coordinates), original 838×412 window remains unchanged |
| Restart | Native last-window frame 1024×768 restored. This does not prove restoration of all simultaneously open windows; system session settings remain unchanged |
| First What's New sheet | Reproduced twice on `7fc833c`: final frame origin moves to (510,300) Quartz, bottom 1068 versus available bottom 1020. Fix `7be4b3d` passed [App Regression](https://github.com/gewill/OpenCCman/actions/runs/34934533312) and real app recheck: origin (510,252), bottom 1020, frame still 1024×768 |
| Sheet regression | Pre-fix observer code fails the notification regression, fixed code passes. The displaced frame stays on the same display so a screen-change notification cannot accidentally satisfy this test. This native test complements the actual launch-sheet reproduction |
| Final minimum / reopening | `7be4b3d`: 300×412 frame and 300×360 root; conversion and source/result scrolling PASS. Closing then tool reactivation creates a new native window in the same process at 300×412; quit/relaunch also restores 300×412. This is not the external-entry acceptance in #19 |
| Display movement | `7fc833c`: system Window menu moves between 1920×1080 external and 1496×967 built-in screens, preserving 1024×768 within their visible areas. Physical hot unplug remains untested |
| Language and theme | `7fc833c`: English/light, Simplified/light and Traditional/dark minimum window controls and conversion/result reachability observed. The conversion settings sheet incorrectly uses English with Traditional app language: [#75](https://github.com/gewill/OpenCCman/issues/75) tracks the real defect |
| Large text | See the 2026-09-23 follow-up below: the macOS system preferred reading-size control does not scale this SwiftUI app. A real large-text product path and its window matrix remain unresolved |

[Real before/after screenshots and minimum-window video, uploaded with gh](https://github.com/gewill/OpenCCman/pull/74#issuecomment-5675535351). The baseline is `714f6bf` (local Xcode 26.6 build), the final pictured candidate is `7be4b3d` (CI Xcode 26.3 build); both ran on macOS 27, English/light/default text. The compiler difference follows the local toolchain transition and is recorded rather than hidden.

Raw measured geometry: [first candidate](runtime-7fc833c.json), [sheet fix and final minimum/restart](runtime-7be4b3d.json). [Pre-fix regression failure](sheet-regression-before.log), [fixed geometry/native checks](geometry-native-checks.log). Native `contentMinSize` values are sampled at constraint notifications and may be recomputed by SwiftUI afterward; the root size and actual window frame are the acceptance measurements.

After the run, the validation app was quit and its isolated preference domain was restored exactly to the captured baseline. Production preferences and system language/theme were untouched. VoiceOver was not enabled in this run.

## Toolchain transition during validation

The first local app builds passed with Xcode 26.6. The machine changed to macOS 27 / Xcode 27 during this work. The existing window introspection allowlist stopped at macOS 26, so root window binding is now a narrow NSViewRepresentable using NSView.window.

Xcode 27 rejects the unchanged macOS 11 deployment target. A local-only experiment with `MACOSX_DEPLOYMENT_TARGET=12.0` then failed inside the unchanged RevenueCat 5.64.0 (duplicate `init(stringRepresentation:)`). That experiment did not change repository deployment targets, package pins or caches. A compatible toolchain is pending; GitHub macOS CI now builds the normal application and retains an unsigned Debug validation artifact so runtime acceptance can continue independently. No build* branch or Xcode Cloud release is involved.

## Remaining gates

The `4372fa4` runtime matrix covers both axes with the sidebar shown/hidden, recommended-width fallback and three minimum-window language/theme combinations. The [2026-09-24 current-source run](2026-09-24-live-resize/README.md) adds actual live edge dragging, result access, new-window isolation and restart restoration. [#75](https://github.com/gewill/OpenCCman/issues/75) finished the language fix and closed after #76 merged. Before closing #57, resolve the Mac large-text product path and screen-removal/restoration coverage. Physical monitor unplug has not been replaced by the synthetic disconnected-screen geometry check. Minimum-OS real-device verification remains #16. Window creation from external entries after all windows close belongs to #19; native WindowGroup model release belongs to #18. PR #74 has since merged; the issue remains open for these acceptance items.

[Apple NSWindow frame restoration](https://developer.apple.com/documentation/appkit/nswindow/setframeusingname(_:)), [NSView.window](https://developer.apple.com/documentation/appkit/nsview/window).

## 2026-09-16 develop integration

Integrated develop `51bceda` into the existing #74 candidate (`d009913` before integration). The only textual conflict was RootView's window lookup: retain MainWindowReader and size constraints, while retaining develop's macOS 27 **editor** introspection and scroll configuration. The now-unused window Introspect predicate is removed; the combined editor/window regression now mounts the actual MainWindowReader in its SwiftUI hierarchy, so it does not claim to validate a window lookup no longer used by the app.

Local Xcode 27/macOS 27 checks passed: geometry/native restoration/sheet dismissal, workspace resolution, 60 application source syntax checks and 3 languages, and actual source/result/window adapter callbacks. The adapter check compiled a private copy of the clean pinned Introspect checkout; no dependency cache or deployment target was edited. [Commands and results](2026-09-16-integration/results.json), [native window checks](2026-09-16-integration/window-sizing.log), [workspace checks](2026-09-16-integration/workspace.log), and [adapter result excerpt](2026-09-16-integration/introspection-result.log).

These are integration regressions, not a replacement for the final app's pending inspector/two-axis/large-text matrix or physical monitor disconnect acceptance. Historical screenshots/videos above retain their original source SHA. The full app build and new validation artifact came from this PR's CI. At the time of this integration it remained Draft; its later merge does not complete the issue's runtime acceptance.

## 2026-09-16 current-candidate UI follow-up

The [runtime record](2026-09-16-runtime/README.md) adds same-toolchain real before/after captures and closes the pending ordinary-text sidebar/both-axis matrix for product `4372fa4`. It explicitly separates native history restoration from continuous edge dragging and captured pixels from native points. Full larger-text, physical display removal, final-candidate continuous-resize/video and #75 remain open; the subsequent PR merge did not change release gates.

## 2026-09-23 macOS reading-size follow-up

On macOS 27.0 / Xcode 27.0, the ad-hoc-signed isolated app `org.gewill.OpenCCman.WindowEntryValidation` built from application source `8619bec` was captured in the same 1024×768 pt window, English/light, once with Accessibility → Display → Text size at its original `Default` (slider value 4) and again at maximum `42 pt` (value 14). The 2048×1536 PNG captures were byte-identical (SHA-256 `937b7062558ddc165fef9b6ff4af65033bdc38a9865d8277f1447a36f60f9301`). [Both real screenshots and exact test conditions were uploaded to #57 with `gh`](https://github.com/gewill/OpenCCman/issues/57#issuecomment-5792430054). Only the isolated app window was captured; no production app or customer text was used. The system setting was restored to `Default` and read back afterward; VoiceOver remained off.

This is expected for the current SwiftUI macOS text behavior: [Apple documents that `dynamicTypeSize` cannot be changed by users on macOS and does not affect text size](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize). Thus changing the system preferred reading size is **not** a valid substitute for testing a Mac large-text layout. The app has no in-app Mac text-scale setting in this source. A separate product decision and implementation would be needed for user-adjustable Mac text enlargement; iPhone/iPad Dynamic Type acceptance remains in #20. No enlargement or regression is inferred from the unchanged screenshots.

CUA successfully clicked the layout control in this app, but that run's attempted right/bottom-edge drags did not resize the window; a point outside the right edge returned `windowNotFoundAtPosition`. This was a test-tool limitation, not an established app defect. The [2026-09-24 run](2026-09-24-live-resize/README.md) used the actual outermost window-edge coordinates and successfully resized the current source. Physical display removal/restoration remains untested.

## 2026-09-25 current-source layout follow-up

From `develop` `2fefef4`, an isolated ad-hoc Debug bundle ran on Xcode 27.0 / macOS 27.0, English/light/default text. Native window measurements: 1024×768 pt recommended; 1496×885 pt after system Zoom on the sole detected built-in display. At the wider size, the settings sidebar could be shown and hidden with both side-by-side and stacked editors. At 1024×768 pt, showing the sidebar while side-by-side remained selected temporarily stacked the editors and displayed the space warning; hiding the sidebar restored side-by-side without changing the selection. Conversion after the switches retained the sample source and produced the expected result, with copy/export enabled. `bash scripts/check-window-sizing.sh` also passed.

[Issue #57 current-source screenshots and 19.31-second interaction video](https://github.com/gewill/OpenCCman/issues/57#issuecomment-5818268545) record the exact source, bundle, dimensions and capture methods. The screenshots compare states of the **same** build, not code versions. This run did not repeat the previous 300×412 pt drag: its CUA edge attempts produced no resize, while #149 already has successful real drag evidence. Physical display removal remains untested because only the built-in display is currently detected. Mac user-adjustable large text still needs a product path; neither the synthetic disconnected-screen check nor system reading-size control substitutes for those remaining cases.

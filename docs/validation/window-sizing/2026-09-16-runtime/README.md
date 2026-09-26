# Current candidate runtime matrix — 2026-09-16

Product source `4372fa4237777c704ea6529e68c1b34af1d187ec`, PR #74 / issue #57. This supplements the historical `7fc833c` and `7be4b3d` captures; it does not relabel them as current evidence.

Status note: references below to #74 being Draft describe this 2026-09-16 test checkpoint. The PR later merged at `e6994c8`; #57 remains open for the outstanding runtime gates recorded in the [current overview](../README.md).

## Provenance and scope

Both baseline and candidate are CI Xcode 26.3 Debug artifacts, run on the same macOS 27.0 (26A428) arm64 host. The baseline comes from `ec214df`, whose application and Xcode project match develop `51bceda` exactly. The candidate's [App Regression](https://github.com/gewill/OpenCCman/actions/runs/35035270954) passed. [Source/archive/executable hashes and isolation changes](source.json) identify the binaries, including the separate bundle IDs, display names, removed Services registration and ad-hoc signatures. These are not release signatures or Xcode Cloud builds. The final ad-hoc signing changes full executable hashes; [payload comparison](payload-comparison.json) checks the actual runtime main executable, Debug dylib and preview dylib against their archived CI counterparts using temporary copies with canonical signing and only the LC_CODE_SIGNATURE data ranges excluded. The application code payloads match. Earlier preparation hashes are not reused as final runtime hashes.

[Real before/after screenshots and the state matrix](https://github.com/gewill/OpenCCman/pull/74#issuecomment-5689764790) are uploaded through `gh pr comment --attach`; the [media manifest](media.json) records original bytes, capture pixel dimensions, language, theme and source SHA. CUA returned JPEG bytes despite our initial local `.png` names; upload files use `.jpg` without re-encoding. Some large captures are downsampled. Native pt measurements and screenshot pixel sizes remain separate.

## Observations

| Condition | Evidence and result |
| --- | --- |
| Fresh baseline / candidate, English/light/default text | Native saved frames 900×450pt / 1024×768pt; same sample conversion successful |
| System Zoom, sidebar shown, horizontal / stacked | Same process, source and result preserved; both controls visible |
| System Zoom, sidebar hidden, horizontal / stacked | Same process, source and result preserved |
| Recommended 1024×768pt, sidebar explicitly shown | Side-by-side preference retained; actual stacked layout plus temporary-fallback explanation |
| Settings sheet open / Escape | English sheet opens and closes; source and result preserved |
| Native history restore to 300×412pt | App stopped before writing isolated native autosave fixture; normal launch restores the minimum window |
| Minimum English/light, Simplified/light, Traditional/dark | Conversion succeeds; scrolling reaches result, copy and export; these three combinations do not cover all six language/theme combinations |
| Minimum English export | Save panel opens with `OpenCCman-converted` stem; Cancel returns to retained source/result; no file saved |
| Quota | Wide sequence ends at 1; three subsequent minimum-language conversions end at 2, 3, 4; `isPro=false`, no layout/export-cancel extra consumption |
| Cleanup | Both isolated apps exit; preference dictionaries restored and compared exactly; no system language, theme, input source or VoiceOver changes |

[Curated native/runtime observations](runtime.json), [capture times](captures.json), application-only [AX observations](ax), and [cleanup readback](cleanup.json). Filesystem listings from the export panel and raw preferences/process samples remain private.

## Tool limits and remaining acceptance

- Edge-drag attempts did not resize this candidate through CUA. This is not established evidence of a product defect and is not counted as a passed continuous-resize test. The minimum fixture checks restoration, not dragging.
- The Zoomed native frame was not measured independently; the 1302×768px screenshots only describe captured pixels. Saved 1024×768pt and 300×412pt frames are separately observed after quitting those phases.
- An initial custom executable launcher requested a geometry report. Its process was live with a normal idle AppKit main loop, but AX inspection timed out twice. The owned process was stopped, the launcher removed and the normal executable restored/re-signed before this UI matrix. Its separate geometry report is not used as a measurement of the normal-launch screenshots.
- No new continuous interaction video was recorded. These images present static states; historical video retains its original candidate SHA.
- Full larger-text behavior, final-candidate live resize/interaction recording and physical monitor unplug remain unverified. The settings-sheet language defect stays in #75; this matrix does not accept that sheet in Chinese. Minimum-OS devices stay in #16. System entry and model lifetime acceptance remain #19/#18/#93.
- PR #74 remains Draft. No build branch, production release, purchase, backend edit or final acceptance gate was changed.

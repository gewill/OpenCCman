# Native document-window observations — 2026-09-15

Four real import → convert → export workflows passed full-byte validation. Closing their native windows did **not** release the observed models within the fixed observation intervals, and two 10 MiB documents produced a large process footprint. This is a correctness result and an unresolved performance finding, not an optimization or production release acceptance.

## Conditions and scope

- App source `aec0368fac73646fb3168204c0b150881bd7e55d`, Release / Xcode 26.3, CI [34964935263](https://github.com/gewill/OpenCCman/actions/runs/34964935263). The later documentation commits do not identify the running binary.
- Apple M4 Pro, Mac16,7, 48 GiB RAM; macOS 27.0 (26A428), English, Light, default text size, 900×450pt windows. Local ad-hoc signature; macOS 11 remains the deployment target, not a tested runtime.
- The same isolated diagnostic bundle and weak logger as the [parent protocol](../README.md). Archive SHA256 `c9e90f27988501fe52809a220a407764303086f6b05f7b96b5921bda425b2855`; harness SHA256 `2cdb02ce7eb4b5ec61ff3d648b8d31af52c817ef0a849e2162779283d0be82b8`.
- New process, one anchor, then one cycle of two 1 MiB windows and one cycle of two 10 MiB windows. These are cumulative cycles in one process, **not independent size benchmarks**. Earlier empty-window cycles used a different process.
- Purchases initialization/status refresh, Services registration and global shortcuts are excluded. No normal application code, dependency or editor behavior was changed for this run. Recording and per-second logging add overhead. AX queries of long editor values may themselves affect timing/resource behavior; there is no no-AX or no-recording control.

## Protocol and correctness

CUA operated normal Cmd-N, Import TXT, Convert, system Export and Cmd-W. Anchor model 1 retained source `锚点窗口：保留原文 é 👩🏽‍💻。` and result `錨點窗口：保留原文 é 👩🏽‍💻。`. Models 2/3 handled 1 MiB; models 4/5 handled 10 MiB. Every exported file was read in full and compared to the fixed oracle, rather than sampling displayed characters.

| Input size, each of two windows | Export bytes | U+0000 count | CRLF count | Exact bytes / BOM |
|---|---:|---:|---:|---|
| 1,048,576 bytes | 1,048,573 | 13,980 | 41,940 | Both pass; output has no BOM |
| 10,485,760 bytes | 10,485,757 | 139,810 | 419,430 | Both pass; output has no BOM |

[preparation.json](preparation.json) records hashes and the exact source/oracle unit. The fixture includes Chinese, emoji with modifiers/ZWJ, decomposed `é`, CRLF, blank lines and embedded NUL. The fixed mapping uses Simplified → OpenCC Traditional with no regional vocabulary conversion. It does not represent all configurations or general language correctness.

To regenerate each fixture from that manifest:

```python
unit = manifest["fixture_source"].encode("utf-8")
gold = manifest["fixture_expected"].encode("utf-8")
assert len(unit) == len(gold)
for fixture in manifest["fixtures"]:
    count, padding = divmod(fixture["input_bytes"] - 3, len(unit))
    source = b"\xef\xbb\xbf" + unit * count + b"x" * padding
    expected = gold * count + b"x" * padding
    # Compare SHA256 to the manifest before writing new files.
```

The four `*-verification.json` files record exported-byte hashes and comparison results. Local exports/large fixtures are not committed. [Quota evidence](quota-before-final-close.json) reports free access and exactly five successful conversions on the start day: anchor + four files. Imports, exports, window creation and closing did not add conversions in this run. Concurrent reservations, failure/cancellation, cross-day and Pro behavior were not exercised here.

**Setup deviation retained:** in the second 1 MiB window, a file-list row double-click selected a local diagnostic note instead of the intended fixture. The displayed filename/text revealed it before conversion. The exact fixture path and selected-filename guard corrected the import, then one conversion was performed. Both full-byte exports passed. This is not a clean interaction-timing sample; the deviation remains in the video. Subsequent imports used the exact-path guard.

## Fixed observations

The origin is the first 1 Hz sample showing one remaining window after the pre-close marker, or zero windows for the final case. Each reported delay uses the **first sample at or after** origin + 5/20 seconds. It is not an exact UI-close timestamp; logger scheduling and the floating-point threshold can select a sample around 6/21 seconds. Exact timestamps, statuses and bytes are in the three `*-observation.json` files and unabridged [runtime.jsonl](runtime.jsonl).

| Stage after closing windows | Visible windows | Live model IDs at ~5s and ~20s | RSS at ~5s / ~20s | Physical footprint at ~5s / ~20s |
|---|---:|---|---:|---:|
| Two 1 MiB documents | 1 | 1, 2, 3 | 428.77 / 362.64 MiB | 708.94 / 719.17 MiB |
| Two 10 MiB documents, same process | 1 | 1, 2, 3, 4, 5 | 2318.30 / 2316.45 MiB | 8747.74 / 8747.73 MiB |
| Final anchor closed | 0 | 1, 2, 3, 4, 5 | 1890.58 / 1431.83 MiB | 8790.62 / 8816.84 MiB |

All selected memory API statuses succeeded. No model deinit event was recorded during this process. RSS and physical footprint are different metrics; declining RSS is not evidence that all memory was released. The 10 MiB pre-close footprint was 9,176,145,960 bytes; ~20 seconds after closing its two windows it was 9,172,656,168 bytes (8.54 GiB). This observation warrants investigation under [#93](https://github.com/gewill/OpenCCman/issues/93), but does not isolate conversion, text layout, AX overhead, framework retention or other allocations. Do not extrapolate an unbounded leak or an engine-specific defect from it.

After the final Cmd-W, **no CUA state/screenshot/activation call** occurred during the zero-window observation. Zero windows persisted through the fixed interval. Cmd-Q then exited the owned process without creating another model. Reopen behavior was not tested in this run; earlier observations live in [PR #94](https://github.com/gewill/OpenCCman/pull/94).

The log caught model 4 converting and model 5 importing in isolated samples. Their windows were closed only after successful exports, when task flags were false. **Close while actually active is still untested**. Given the large retained footprint, another big-document cycle was not added to this process; no artificial engine delay or favorable retry was introduced.

## Visual evidence and cleanup

The 1 MiB post-close screenshot initially appeared to have a blank result while AX retained the expected text. The outer scrollbar was at `0.5311111111111111`. Scrolling the outer container to the top showed the unchanged result: the taller Source header had left its first line visible after the Result first line had scrolled out. There is no pre-close screenshot establishing that close changed the scroll position, so this is **not a proven close-induced rendering regression**. The 10 MiB cycle has same-binary before/after screenshots with the anchor at the top; both source and result remain visible.

The `one-mib-cycle-safe.mp4` video is 300.070 seconds; `ten-mib-cycle.mp4` is 193.812 seconds. Both are real 1920×1080 H.264 captures filtered to this diagnostic app, no audio/microphone, with representative frames inspected. They show the synthetic fixture folder and real system import/export panels. The 1 MiB safe recording starts with the fixture selected, not initial launch. The 10 MiB recording ends after the two windows close and fixed observations; the final zero-window/quit phase is recorded in the log, not the video. [Screenshots and both interaction videos](https://github.com/gewill/OpenCCman/pull/90#issuecomment-5682016914) were uploaded through `gh`; [media.json](media.json) preserves local hashes and codec metadata. These compare operations in one binary, not a code fix before/after.

An earlier recording showed an unrelated default folder listing. It was stopped, marked private, and **not uploaded or committed**. No unrelated file was opened. This exclusion does not remove any numeric runtime samples; the setup deviation above remains public.

[cleanup.json](cleanup.json) records UI quit/PID exit, exact comparison of preferences to the pre-run backup, removal of introduced keys, unregistration and renaming the local app inactive. `defaults import` alone is additive and insufficient; introduced keys were removed before the final dictionary comparison. This run also corrected six keys left by the earlier empty-window restore. VoiceOver was off before and after and was never enabled during this run. Other diagnostic apps, simulator handoffs and developer workspaces were preserved.

Remaining gates: root-cause isolation and older macOS control, measured fix comparison, active-task close, reopen/entry behavior, final signed Cloud and minimum-system acceptance. #18 and #93 stay open; #90 remains Draft while its outstanding protocol cases are explicit.

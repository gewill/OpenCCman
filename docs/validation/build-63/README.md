# OpenCCman 2.2(63) signed smoke acceptance

Status: **Approved and manually released on both App Store platforms on 2026-11-01.** The acceptance below was recorded on 2026-10-31, before submission. See the [2.2 release record](../../release/launch-2.2-20261101.md).

| Item | Verified state |
| --- | --- |
| Source | `15390dde4b7f70a97c174259ebd945c5a81647bf` (`release/v2.2`, PR #311) |
| Xcode Cloud run | `0e88e351-77b5-4b99-a998-c2d91630bc58`, Default workflow, Xcode 27.1 (27A9275) on macOS 27.0.1, `COMPLETE` / `SUCCEEDED` |
| iOS build | `c9539366-903d-4d40-90b1-d6b1a588aa52`, 2.2(63), `VALID` |
| Mac build | `b96b3e97-a9ae-4d33-b4b7-e79ab265e257`, 2.2(63), `VALID` |

[`report.json`](report.json) lists every check that passed and every check that was not run.

## Mac (TestFlight 2.2(63))

- The app installed through TestFlight. codesign reports Authority `TestFlight Beta Distribution`.
- Example conversion passed with the zh-Hant UI ([screenshot](mac/converted.jpg)).
- Settings and Pro opened from the app menu, and the document was kept after returning ([Settings](mac/settings-2.2-63.jpg), [Pro](mac/pro.jpg)).
- Settings shows version 2.2(63).
- The menu bar icon option is on, and the status item is present.
- The new layered icon appears.

Not run on 63: ⌘, and ⌘P in a narrow window with More in the overflow menu, and Mac large-file conversion.

## iPhone 16 Pro (iOS 27.2, TestFlight 62 → 63)

- System navigation bar layout and example conversion with Taiwan Standard + Idioms ([screenshot](iphone/01-example-conversion.jpg)).
- A 100 MiB input arrived by AirDrop: `100MiB-phrases.txt`, sha256 `68d3da48…`, see [fixture manifest](fixture-manifest.json).
  - Flow: confirmation page ([screenshot](iphone/02-convert-large-file-100mib.jpg)) → Converting → Ready to save in about 10 s → system save to iCloud Drive.
- The output is 112,173,244 bytes, sha256 `9d7363c7c35ca9c0dd2181f7b64a3329a2b28ebb10c0495ba6e5b73adb6859ac`. It equals the independent whole-text Taiwan-idiom reference in [`oracle.json`](oracle.json).

Not run on 63:
- Cancel, background abort, restart recovery, and the +1 byte rejection. These were covered on Build 61 in [#260](https://github.com/gewill/OpenCCman/issues/260).
- Memory footprint.
- iPad.
- The purchase and restore matrix ([#14](https://github.com/gewill/OpenCCman/issues/14), [#71](https://github.com/gewill/OpenCCman/issues/71)).

#260 stays open in milestone v2.3. The save-panel screenshot, full-size PNGs and the `devicectl` readback stay outside the repository because they show personal folders and device identifiers. Their hashes are in [external-evidence.json](../../release/store-assets-2.2-20261031/external-evidence.json).

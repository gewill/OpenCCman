# #18: v2.1 candidate application diagnostic baseline (2026-09-28)

This run measures the `develop` candidate at
`abad58c3252329068e6c42c0765eff8059680c94`. It records absolute values
for future same-protocol checks; it does not claim a performance gain over
2.0 or replace signed-app and device acceptance.

## Method and integrity

- Apple M4 Pro (`Mac16,7`), 48 GiB, macOS 27.0 (26A428), Xcode 27.0
  (27A266a), arm64. The host also had VirtualBuddy and two iPhone simulators
  running, so later measurements must account for background load.
- Five fresh processes from one isolated Release `-O` build; English, Light,
  1200×800 pt diagnostic window, fixed input and seven conversion
  configurations. The driver used an ad-hoc-signed diagnostic bundle,
  synthetic Pro state, no sandbox, and suppressed some SDK/UI behavior.
- Reproduce from the stated commit with a privately copied pinned
  `SourcePackages` directory:

  ```bash
  python3 scripts/benchmark-app.py \
    --output /tmp/openccman-18-v21-candidate \
    --packages /path/to/verified/SourcePackages \
    --samples 5 --timeout 240
  ```

- [`metadata.json`](metadata.json) records the clean source status, source
  hashes, dependency revisions and conditions;
  [`build-complete.json`](build-complete.json) binds the build to that
  metadata and executable hashes. The driver verified both after building.
  All five [`run-01.json`](run-01.json)–[`run-05.json`](run-05.json) have
  `complete` status, 36 ordered stages, matching metadata hash and identical
  input/output digests for each conversion stage. Exact editor and export
  checks passed; the two hosted-window close cycles ended with zero extra
  models alive. Raw files and [`summary.json`](summary.json) are preserved,
  with SHA-256 values in [`manifest.json`](manifest.json).

Times below are median (minimum–maximum). MiB means 2²⁰ bytes. The first
sample is included in every range.

| Stage | Time, ms | Process peak RSS, MiB |
| --- | ---: | ---: |
| New process to root layout | 641.61 (609.35–1790.82) | 107.16 (105.66–107.59) |
| First 256 KiB model conversion | 53.02 (44.40–65.93) | 163.28 (163.11–165.09) |
| First hot conversion | 16.56 (16.43–27.19) | 165.47 (164.70–167.03) |
| Fifth hot conversion | 26.08 (20.24–29.16) | 173.73 (173.08–175.16) |
| Seven configurations resident | — | 180.84 (180.09–181.22) |
| 1 MiB model conversion | 27.68 (23.42–31.80) | 188.00 (186.81–188.33) |
| 5 MiB model conversion | 92.96 (92.63–99.35) | 232.52 (232.25–233.33) |
| 10 MiB model conversion | 180.42 (179.50–181.37) | 312.39 (312.08–316.75) |
| Second hosted-window cycle closed | — | 333.22 (331.27–336.84) |

## Harness repair and interpretation

The first attempt built but crashed after `large_text_cleared` when the
diagnostic harness created an additional `RootView`. The macOS crash report
showed `EnvironmentObject.error()` → `RootView.launchReveal`: the harness
had not supplied the `LaunchTransitionCoordinator` introduced with the
launch transition. The fix injects a coordinator with its animation disabled
into each synthetic extra window, matching the app's later-window behavior.
It changes only the benchmark file, which is absent from the shipping target.
The five clean-source runs above completed after this repair. A second local
five-run set from the same file contents also completed, but was not archived
as the baseline because its working tree was uncommitted.

The launch number includes a LaunchServices reopen handshake and does not
purge OS/file caches; it is not a cold-disk launch or first interactive
frame. Conversion timing stops at model completion; the later editor flush
is a diagnostic acknowledgement, not measured user-visible presentation.
Peak RSS accumulates prior fixtures and work. Synthetic hosted windows are
not the production `WindowGroup` lifecycle. No FPS, energy, or signed-app
memory measurement was made.

The [2026-09-24 baseline](../2026-09-24-current-source-baseline/README.md)
used a different source and an older condition set; the comparison driver
rejects a direct before/after calculation. Keep #18 open for same-condition
paired comparison after an optimization, final signed-app and minimum-system
measurement, and user-visible launch/presentation timing.

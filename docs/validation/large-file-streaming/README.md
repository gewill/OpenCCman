# Mac large-file conversion candidate

Issue: [#52](https://github.com/gewill/OpenCCman/issues/52). Wrapper: [SwiftyOpenCC #8](https://github.com/gewill/SwiftyOpenCC/pull/8) with follow-ups [#9](https://github.com/gewill/SwiftyOpenCC/pull/9), [#10](https://github.com/gewill/SwiftyOpenCC/pull/10) and [#11](https://github.com/gewill/SwiftyOpenCC/pull/11).

## Scope and release gate

The candidate converts one UTF-8 TXT directly to a user-selected output, without
loading its body into the editor. The target is >10 MiB through 1 GiB. Existing
draft/result text, the ≤10 MiB editor workflow and iOS behavior remain separate.
No batch processing, preview, resumability or claim of unlimited capacity.

`MacLargeFileCoordinator.productionEnabled` stays false until #52's capacity,
sandbox, entitlement and minimum-system gates are satisfied. The exact Debug
bundle `org.gewill.OpenCCman.WhatsNewUITests` additionally requires
`-qa-enable-large-file-conversion` to enable the candidate. The optional
`-qa-large-file-pro` affects only in-memory QA eligibility; it does not validate
purchase/restore or write a Pro entitlement. Production copy continues to
describe the existing 10 MiB capability.

## Implementation

- SwiftyOpenCC's wrapper-owned stream consumes complete stable matching units,
  retaining dictionary/IDS lookahead independently at each stage. Normalization,
  segmentation and chain order match the complete-string API. Unsupported future
  converter structures throw rather than falling back to whole-file memory.
- The file service serially reads 256 KiB, converts and writes on a dedicated
  queue. A leading UTF-8 BOM is stripped; other bytes retain the conversion
  semantics, including NUL and mixed newlines. Invalid encoding fails.
- Import/provider URLs are opened while access is valid. Regular-file identity,
  size and timestamps are checked; source/target aliases are rejected. This
  protects against ordinary concurrent edits, not a hostile writer that spoofs
  metadata while modifying an open file.
- Output is created privately on the destination volume. Synchronization and
  close precede an NSFileCoordinator replacement accessor and atomic rename.
  Existing-target identity is rechecked; a new target uses exclusive rename.
  Uncoordinated external writes still obey normal filesystem race limitations.
- Cancellation waits for worker cleanup before releasing the single app-wide
  task slot. Window closure and normal app termination cancel and wait. Failed
  removal of partial output produces a recovery error; failure to remove an empty
  directory after successful commit does not turn saved output into a failure.
- SwiftUI receives throttled numeric progress only, capped below 100% until
  commit. Save panels, active jobs and cancellation cleanup defer What’s New.

## Validation protocol

Measured source `3a03f18e9bf25de5a7232db340417a886cc4eed8`; wrapper merge
`570c0a52402bdba9488a3e9ecfb2879f0b37526e`; OpenCC
`025f371dc76b598d77384fbdab90c937471844d8`. Both source worktrees were clean
when the main capacity run started. [Raw capacity evidence](capacity.json)
includes individual samples, complete hashes, source hashes and measurement
scope. Each wrapper PR passed required OpenCC Compatibility before merge, and the
wrapper merge commit passed it again after merging.

On Apple M4 Pro / 48 GiB, macOS 27.0 (26A428), Xcode 27.0 (27A266a), Release
service with preloaded `s2t` converter and 256 KiB I/O, three fresh processes per
cell produced complete matching output hashes:

| Input | No-newline median | Multiline median | Conversion sampled peak RSS range (both corpora) |
| --- | ---: | ---: | ---: |
| 10 MiB | 92 ms | 100 ms | 46.1–49.6 MiB |
| 20 MiB | 179 ms | 192 ms | 47.6–56.3 MiB |
| 50 MiB | 448 ms | 475 ms | 49.4–56.9 MiB |
| 100 MiB | 893 ms | 962 ms | 51.0–57.5 MiB |
| 1 GiB | 9,007 ms | 9,839 ms | 57.3–60.5 MiB |

The 30 independent cancellation probes requested cancellation after the first
successfully written 256 KiB block and returned after cleanup in 0.18–0.39 ms;
each preserved an existing destination and removed temporary output. These are
block-boundary service timings, not worst-case UI cancellation latency. Runtime
and OS page accounting vary; these results show bounded behavior for this fixed
configuration/corpus, not a universal capacity or speed guarantee. No other
task-owned build ran during the measurement matrix.

An additional three 1 GiB runs consisting entirely of unmatched ASCII completed
in 1.87–1.90 seconds at 55.3–56.0 MiB sampled peak RSS, with matching full hashes
and successful cancellation cleanup. [Raw unmatched-run evidence](unmatched.json)
specifically exercises the path that must not accumulate a whole unmatched
logical segment.

The previous record measured wrapper `13c3692` at App `a5f49ca` on the same Mac,
system and Xcode, with byte-identical measured sources: 1 GiB medians of
14,607 ms and 15,946 ms at 57.8–61.2 MiB, and unmatched runs of 2.50–2.52 s.
The newer wrapper matches each streamed byte once instead of twice and keeps
stage buffers reserved, so conversion is faster with the same peak memory.
At `3a03f18`, `scripts/check-core.py`, dependency resolution and the macOS and
iOS Simulator builds passed; only the SwiftyOpenCC pin changed.

Run `scripts/check-core.py` against the pinned wrapper. It includes all seven App
configurations, real NSItemProvider temporary-file lifetime, invalid UTF-8,
aliases/FIFO, source/target changes, injected I/O errors, cancellation/cleanup,
ownership, concurrent starts, frozen configuration/qualification and termination.
Fault injection validates handling of EIO/ENOSPC/EACCES; it is not a physical
full-disk test.

For capacity, `scripts/benchmark-streaming-files.py` builds the actual file service
in a Release executable and launches fresh processes. Its bounded oracle uses
the pre-existing complete-string converter, checks tile boundaries, hashes the
entire expected/output data and records RSS/physical footprint. This harness is
unsandboxed and does not replace the native application save-panel test.

```sh
python3 scripts/benchmark-streaming-files.py \
  --opencc-path /path/to/clean/pinned/SwiftyOpenCC \
  --output /tmp/openccman-streaming-capacity
```

## Native sandbox application evidence

[Native UI records and RSS samples](ui-runtime.json) cover the signed Debug QA
application on the same Mac and system. The general UI run used App source
`7079f2823776b440bc4b2c19453dca306181e72f`; the three conversion/file-service source
hashes still exactly match measured source `3a03f18`. Together, the Release
capacity and unmatched records contain **33 full-output hash passes and 33
successful cancellation/cleanup probes**. UI memory is a separate measurement.
The native runs below used wrapper `13c3692`. They were not repeated after the
wrapper update, which changes only internal matching and buffer reservation;
the service outputs above remain byte-identical.

| Native operation | Observed result |
| --- | --- |
| Import and export approximately 16 MiB | 16,806,400 input bytes (16.03 MiB); complete output SHA256 matched the recorded expected hash. |
| Import, save and replace a 1 GiB destination | 1,073,741,824 input bytes; native save/overwrite flow completed inside the sandbox; complete output SHA256 matched the bounded CLI oracle. |
| Cancel the save panel | Returned without starting conversion or replacing the editor draft/result. |
| Cancel an active conversion | Observed at least 5% / 63.7 MB before Cancel; the existing 42-byte destination and editor draft/result remained intact. The target size is a native operator observation, not a field in the original cancellation JSON. |
| Show the saved file | Finder revealed the completed output. |
| Another window starts a task | Busy rejection prevented a second task; closing an unrelated window did not cancel the owning window's task. |
| Pro eligibility without the QA entitlement flag | Importing the approximately 16 MiB file displayed the Pro prompt; canceling retained the default source text. This checks the locked-feature prompt only. |
| Normal Command-Q during conversion | At a displayed 4% / 49.5 MB, quit canceled and waited: the process exited, the observed 27,787,227-byte partial file and temporary directory were removed, and the prior 1 GiB destination retained its expected SHA256. |
| Standard OpenCCman > Quit menu | At a displayed 31%, the process exited after cleanup; the observed partial output and directory were removed, and the existing destination retained its expected SHA256. |

The normal-quit check includes a follow-up confined to
`MacLargeFileTaskView.swift`: on macOS 15.4+, the sheet permits application
termination so AppDelegate can cancel and await cleanup. It was exercised on
**macOS 27**, not on macOS 15.4 or macOS 12. The evidence records the exact modified
file SHA256 and final source commit
`f8306fa5ca21a1e922f320bbeda0d328be580eff`. Both final macOS and iOS Simulator builds
and the core regression passed; their exact log hashes and conclusions are in
the JSON. The native quit checks complement the coordinator regression and do
not cover forced process termination or power loss.

Command-W did **not** close the owning window while its modal task sheet was
visible. It therefore does not count as native owner-close acceptance; that
lifecycle remains covered by the core coordinator regression only. A bare QA
auto-import argument also did not grant sandbox access and failed with
`Operation not permitted`. The successful file-flow evidence used native file
panels to obtain access; no automatic-import success is claimed.

The UI RSS monitor recorded **2,512 samples over 279.289 seconds**, ranging from
**165.05 to 197.64 MiB** (173,064,192–207,241,216 bytes). It sampled the Debug QA
process through the native save/cancel/complete flow, including idle periods.
The nominal interval was a 100 ms sleep; `ps` overhead made the median actual
interval 110.618 ms. These numbers are neither Release service RSS nor isolated
conversion latency. All original sample timestamps and byte counts are retained
in `ui-runtime.json`; no editor contents or unrelated application data were
collected. Screenshot/video attachments belong in the candidate PR; they are not stored
in the Git source tree.

The sandbox evidence includes `com.apple.security.app-sandbox` and
`com.apple.security.files.user-selected.read-write` entitlements, plus actual
native save/cancel/replace outcomes. Enabling the Debug QA entitlement override
for these file-flow tests does not validate StoreKit or RevenueCat purchases.

## Remaining acceptance

- macOS 12 runtime remains unverified (#16). A macOS 12 deployment target build
  on macOS 27 does not satisfy this gate.
- Real purchase/restore/offline entitlement acceptance remains with #14/#71.
  The unchanged isolated StoreKit test target fails refund propagation and
  injected user cancellation locally on Xcode 27/macOS 27. Both failures also
  reproduce from clean `develop` baseline `c7f8b373`; do not weaken assertions or
  treat this as candidate success. The candidate ran seven tests with two
  failures; the baseline reran those two selected tests and both failed.
  [Baseline comparison](storekit-baseline.json) records identical StoreKit source
  hashes and exact underlying log hashes. CI uses Xcode 26.3 separately; its
  status is not inferred from these local failures.
- Forced process termination, power loss, file-provider eviction and removable
  volumes need separate recovery acceptance; normal cancellation/quit guarantees
  do not cover an externally killed process.

Runtime measurements, source hashes and UI evidence accompany the candidate PR.
This document is an implementation/acceptance record, not a public capacity claim.

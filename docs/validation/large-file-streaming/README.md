# Mac large-file conversion candidate

Issue: [#52](https://github.com/gewill/OpenCCman/issues/52). Wrapper: [SwiftyOpenCC #8](https://github.com/gewill/SwiftyOpenCC/pull/8).

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

## Remaining acceptance

- macOS 12 runtime remains unverified (#16). A macOS 12 deployment target build
  on macOS 27 does not satisfy this gate.
- Real purchase/restore/offline entitlement acceptance remains with #14/#71.
  The unchanged isolated StoreKit test target fails refund propagation and
  injected user cancellation locally on Xcode 27/macOS 27. Both failures also
  reproduce from clean `develop` baseline `c7f8b373`; do not weaken assertions or
  treat this as candidate success. CI uses Xcode 26.3 separately.
- Forced process termination, power loss, file-provider eviction and removable
  volumes need separate recovery acceptance; normal cancellation/quit guarantees
  do not cover an externally killed process.

Runtime measurements, source hashes and UI evidence accompany the candidate PR.
This document is an implementation/acceptance record, not a public capacity claim.

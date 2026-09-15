# Editor scroll test synchronization

Refs #20 / #65. [PR #91 failure](https://github.com/gewill/OpenCCman/actions/runs/34966485807) narrowed from `[6640,153]` to `[6701,63]`; selection stayed `{7115,12}`. A fixed 80ms RunLoop spin did not establish completion of the keeper's two queued restoration passes. The test could measure the widened top line and start narrowing while the original pre-widen anchor `6705` was still pending.

## Evidence and scope

| Experiment | Result | Meaning |
|---|---|---|
| Local original / traced prefix, 5 each | 10 passed | Negative reproduction result, not proof of correctness |
| macOS 15.7.9 / Xcode 16.4 original / traced prefix, 20 each | [40 passed](macos15-original-report.json) | Same OS as failing CI; no natural failure reproduced in this bounded run |
| Private keeper: delay first widen restoration 120ms before queuing the second | 3/3 failed with **the exact reported ranges and clip bounds** | [Trace](local-delayed-failure.jsonl) shows pending `6705` survives the first test measurement and is reused during narrowing |
| Same controlled delay with state-based test synchronization, 3 original / 3 traced | [6 passed](local-synchronized-delayed-report.json) | No assertion tolerance or product restoration strategy changed |
| Private negative fixture reports restoration pending forever | Failed at the bounded deadline | The helper does not silently accept incomplete work or wait indefinitely |
| Local complete editor regression | [Passed](local-full-regression.log) | Includes 1/5/10 MiB reflow, tail navigation, selection, composition and document replacement |

The first failing CI did not log pending state; its historical cause is inferred from an exact controlled reproduction, not directly traced there. [result.json](result.json) preserves this distinction. Success of 40 original runs does not erase the original CI failure.

## Fix

The test helper retains the existing 80ms native layout RunLoop slice but checks whether restoration is still pending before asserting or starting the next sequential resize. It pumps the run loop until both queued passes finish, with a two-second deadline that fails explicitly. Line/character thresholds, selection, marked-text and content assertions are unchanged. Coalesced resizes and navigation before queued restoration remain intentionally exercised.

The read-only pending property exists only under `WORKSPACE_SCROLL_CHECKS`, defined by the test compilation scripts. Application builds do not define it. After stripping that conditional, the keeper is byte-identical to `b7a27c3`; there is no change to user-facing scroll behavior, performance strategy or UI. Actual app/VoiceOver/IME/minimum-OS and signed-release gates stay open in #20/#65.

## Reproducible diagnostic

```sh
python3 scripts/diagnose-editor-anchor.py --output /tmp/openccman-anchor-normal --repetitions 20
python3 scripts/diagnose-editor-anchor.py --output /tmp/openccman-anchor-slow --repetitions 3 --first-pass-delay-ms 120
bash scripts/check-editor-scroll.sh
```

Each output must be new; overwrite is refused. The tool privately copies the current first widen/narrow assertions and keeper. Original and traced variants alternate independent processes a fixed number of times; the optional delay applies only to those copies. Trace events read already-stored character/lineOffset/pending values and clip bounds without extra layout queries. Synchronous tracing may affect timing, so the original variant is retained. All failed processes remain failures and return a nonzero diagnostic status; no retry is used. The tool records source SHA/dirty status, source and generated hashes, OS/compiler and every raw log, and verifies production sources did not change.

The manual `diagnose_editor_anchor=true` input uses the existing App Regression workflow on macOS 15. Normal PR App Regression always runs. The optional job runs both ordinary and controlled-delay experiments and preserves artifacts even on failure. It does not touch build branches, Xcode Cloud or dependency versions. The initial standalone prefix has no host window and is not real application UI acceptance. Candidate macOS 15 results are appended after its actual run finishes.

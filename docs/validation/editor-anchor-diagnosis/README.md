# Editor anchor timing diagnosis

Refs #20 / #65. [PR #91 failure](https://github.com/gewill/OpenCCman/actions/runs/34966485807) produced a 61-character change on narrowing: before `[6640,153]`, after `[6701,63]`. Selection stayed `{7115,12}`; the after line still contained the first, pre-widen anchor `6705`. This is evidence of the observed mismatch, not yet a diagnosis of a product bug or a bad assertion.

## Probe

`python3 scripts/diagnose-editor-anchor.py --output <new-directory> --repetitions 20` copies the original first widen/narrow assertions, with their exact thresholds and 80ms settle, into an isolated output. It compiles both the original keeper and a private traced copy, alternating independent processes a fixed number of times. Trace events record already-stored character/lineOffset/pending values and clip bounds; they do not issue extra layout queries. The production keeper and test files are hash-checked unchanged. No retry is used; all failed processes remain in the report and make the diagnostic exit nonzero. Generated sources, source SHA, OS/compiler and all logs are preserved.

The workflow is manual-only on macOS 15. It does not replace, skip or weaken required App Regression, and does not touch build branches or dependencies. Tracing is synchronous and may affect timing; uninstrumented samples are necessary. This is the initial standalone NSTextView test, without a host window, not a substitute for real application scroll/IME acceptance.

## Current evidence and hypotheses

Local macOS 27: five original and five traced prefix processes passed. The first restoration's subsequent capture saw changed native layout estimates; the second restoration returned the intended character. Full logs remain in the diagnostic worktree's `.build/anchor-diagnosis/`. This does not prove macOS 15 behavior.

The macOS 15 trace should distinguish: (1) stale pending character from the earlier resize, (2) correct character with changed line offset/geometry, or (3) native geometry changes after restoration finishes. Do not change the 50-character threshold, add repeated restore attempts, or extend sleeps without evidence. No production fix or CI-failure resolution is claimed yet.

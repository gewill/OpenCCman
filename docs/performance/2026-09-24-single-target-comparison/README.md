# #68: archived single-target TextKit 2 candidate against TextKit 1

The #169 single-target scroll keeper restores the tested midpoint selection after every 1 MiB layout switch, but this private app candidate is not ready to replace TextKit 1. On the same 1 MiB unbroken paragraph, its final RSS is about 301 MiB higher and its measured layout action is slower. This is evidence about these two app builds and this fixture, not a general TextKit 2 comparison or a leak diagnosis.

## Builds and protocol

- Source commit: `c9599dd9ebbf488fb759341d2a6ea045ceeab70c`. The two private Release builds have identical dependency revisions, environment and benchmark conditions. Their snapshot hashes differ only in `WorkspaceTextEditor.swift`, `WorkspaceScrollKeeper.swift`, and the diagnostic `ModernWorkspaceScrollKeeper.swift` fixture; only the first two are app source files.
- Machine: Apple M4 Pro / 48 GiB, macOS 27.0 (26A428), Xcode 27.0 (27A266a). Apps use an ad-hoc diagnostic identity and disabled sandbox, with synthetic Pro access. This is not a signed distribution build.
- Input: one unbroken 1 MiB paragraph with Chinese, Emoji and combining characters. Navigation targets the complete midpoint composed character. A 1200 × 800 pt English, light window is used. Each sample starts a separate foreground process with the same reopen handshake; OS/file caches were not purged.
- The private build records a 10 MiB maximum, while `scripts/run-private-reflow-subset.py` runs the **same verified binaries** with a 1 MiB maximum for three independent samples per engine. The driver refuses a run maximum above the recorded build maximum and verifies the built app, source snapshot, dependency checkouts and environment before launch.
- Both engines produce the same input SHA-256 `3589430ad438ead1803658c8c0d77d32d30f5694b0b1787ffc512d4e32f8b239` and output SHA-256 `ce5d34522786fd54a3736ffd550f239c57b7799515540632eeeef7dde53c8501` in all six complete runs. The final layout rows confirm actual TextKit 1 or TextKit 2 identity.

| 1 MiB, three independent processes | TextKit 1 | TextKit 2 + #169 keeper |
| --- | ---: | ---: |
| Final RSS, median (range) | 343.7 MiB (340.9–346.2) | 645.2 MiB (641.5–645.7) |
| Process peak RSS, range | 340.9–346.2 MiB | 641.6–645.8 MiB |
| Median of per-run six-action medians (run range) | 1702.3 ms (1698.4–1712.7) | 1916.9 ms (1907.2–1954.2) |
| Selection visible after layout switch | 18/18 | 18/18 |

The TextKit 2 candidate's final RSS is 1.88× the TextKit 1 value for this workload. The action measurement includes the harness's layout acknowledgement, main-thread scheduling and flush; it is neither frame latency nor screen presentation time. This single enormous paragraph is deliberately adverse and does not represent ordinary TXT documents. The three processes provide a small range, not a broad performance distribution.

## 5 MiB boundary and exclusions

One foreground TextKit 2 candidate process reached the 300-second limit during the second remote vertical layout of a 5 MiB unbroken paragraph. Its first two 5 MiB layout actions took 79.7 and 80.5 seconds, with 2221.6 MiB RSS after the first horizontal layout. The run is a **partial timeout**, not a crash or successful 5 MiB completion.

Two TextKit 1 attempts also failed to produce a valid 5 MiB comparison: the first lost foreground focus after conversion; the retry lost focus before its first 5 MiB layout completed and was terminated as an owned, invalid private process. Their partial rows are archived to make the exclusion checkable. The 5 MiB observation therefore does **not** establish a TextKit 1 versus TextKit 2 time difference. A future paired 5/10 MiB run needs stable foreground control and the same completion boundary for both variants.

## Evidence and reproduction

`raw/` contains both build metadata and build markers, six complete run files, the candidate timeout and the two excluded TextKit 1 partial runs. `raw/checksums.json` fixes all archived file bytes. `analyze.py` checks checksums, same-source conditions and pins, the exact three snapshot differences, six complete foreground runs, text hashes, actual editor identity and selection visibility, and the 5 MiB exclusion reasons:

```bash
python3 docs/performance/2026-09-24-single-target-comparison/analyze.py
```

To repeat the test, start at the source commit above and use a fresh output directory for each build. The original runs used a private clone of already resolved SourcePackages; provide the same `--packages /path/to/SourcePackages` input when available. Run `benchmark-app.py` with `--reflow --single-paragraph --middle-composed --reflow-max-mib 10 --build-only`, adding `--textkit2-single-target` for the candidate. Then use `run-private-reflow-subset.py --build <build-directory> --output <fresh-run-directory> --max-mib 1 --samples 3 --timeout 120` for each verified build. The original 5 MiB candidate partial run used the same candidate build command without `--build-only`, with `--samples 1 --timeout 300`; its recorded stages are archived here. Replace the example paths with fresh local output directories.

The private generated builds and full local manifests remain under `/private/tmp/openccman-68-single-target-reflow`, `/private/tmp/openccman-68-tk1-matched-build`, and the corresponding repeat-run directories. They are not required to recheck the archived data. The prior gated Allocations/VM trace in [the paired-memory report](../2026-09-24-paired-paragraph-memory/README.md) belongs to the **older** modern-anchor candidate and must not be attributed to this #169 version.

## Decision and remaining work

Keep shipping the optimized TextKit 1 editor. The #169 keeper resolves the measured selection-visibility regression, but the current candidate has no verified memory or layout-performance advantage on this adverse fixture. #68 remains open for object-lifetime and memory-recovery analysis of the current candidate, repeated ordinary TXT corpora and 5/10 MiB cases, editing/IME/undo/VoiceOver, iOS 15/macOS 12 paths, and signed-build acceptance. A framework migration would need a separate reviewed PR and evidence across those cases.

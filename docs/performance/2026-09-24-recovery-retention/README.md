# #68: TextKit editor memory after replacing a document with empty text

The current private TextKit 2 + #169 candidate sometimes keeps a substantial layout object graph after both editors become empty. In six independent 1 MiB foreground processes, four still had about 381–383 MiB physical footprint 30 seconds after clear; two fell below 206 MiB. TextKit 1 fell to 197–226 MiB in all three paired processes. A live heap reference tree in a high-footprint TextKit 2 process reaches old `CTRun` objects through each visible editor's `NSTextLayoutManager` fragment table. These are **reachable objects while the window remains open**, not proof of an unreachable-memory leak.

## Paired builds and bounded protocol

- Both diagnostic Release apps were built from `9e7c35443373abc1dbfba4cf38c9f539c88779bb` on Apple M4 Pro / 48 GiB, macOS 27.0 (26A428), Xcode 27.0 (27A266a), with identical pinned dependencies and conditions. The private snapshots differ only in two app editor/keeper files and the archived keeper fixture. The shipping target remains TextKit 1.
- One unbroken 1 MiB Chinese/Emoji/combining-character paragraph is converted and navigated at three positions. The app then calls its existing `replaceSource("")`, waits until both native editors report zero UTF-16 units, verifies exact empty content, unchanged editor identities, no export snapshot and no source undo action, then records memory immediately, at 5 seconds and at 30 seconds. Each run is a fresh foreground process in a 1200 × 800 pt English/light window.
- `task_vm_info.resident_size` and `phys_footprint` are recorded separately. They answer different questions: the former counts resident pages in the process address space, while the latter reflects memory charged to the process, including compressed or swapped dirty pages as discussed in [Apple's memory profiling guide](https://developer.apple.com/documentation/xcode/analyzing-the-memory-usage-of-your-metal-app). Neither alone identifies an object owner or establishes a leak. The six TextKit 2 samples include a second bounded repeat because the initial three showed two different recovery states.

| 1 MiB recovery, independent processes | TextKit 1 (n=3) | TextKit 2 + #169 (n=6) |
| --- | ---: | ---: |
| Physical footprint before clear, median | 353.1 MiB | 522.8 MiB |
| Physical footprint 30 s after clear, median (range) | 212.2 MiB (197.3–226.3) | 381.7 MiB (189.2–383.4) |
| Runs below 250 MiB after 30 s | 3/3 | 2/6 |
| RSS after 30 s, range | 318.8–345.3 MiB | 610.7–644.6 MiB |

All nine processes completed in the foreground. Both native editors reported empty text at each post-clear stage; every run used its intended text engine and retained the selected range during the preceding layout checks. Input/output hashes match across both variants. The RSS range remains high even in a low-footprint TextKit 2 run, so RSS alone would have hidden the recovery split.

## Object evidence at the 30-second hold

The apps were held alive after recovery for read-only `heap -s -H -q` and `vmmap -summary` snapshots. The table shows one TextKit 1 hold and one high and one low TextKit 2 hold; it is not a distribution of object counts.

| Held private process | Physical footprint | Live `CTRun` | Live `CTLine` | Live `NSTextLineFragment` |
| --- | ---: | ---: | ---: | ---: |
| TextKit 1 | 214.3 MiB | 38 / 17 KiB | 38 / 10 KiB | 0 |
| TextKit 2, high state | 384.4 MiB | 96,807 / 41.4 MiB | 13,649 / 3.4 MiB | 13,613 / 4.2 MiB |
| TextKit 2, low state | 188.8 MiB | 48,422 / 20.7 MiB | 6,843 / 1.7 MiB | 6,807 / 2.1 MiB |

A separate high-state process was used for two `leaks --noContent --traceTree` paths, each ending at a different live `NSTextView`. The observed ownership chain is `NSTextView → NSTextLayoutManager._textLayoutFragmentTable → NSTextLayoutFragment → NSTextLineFragment → CTLine → CTRun`. The two trees identify distinct editor and layout-manager instances; they do not distinguish Source from Result because this run did not record their addresses. Apple documents `NSTextLayoutManager` and its [fragment enumeration](https://developer.apple.com/documentation/appkit/nstextlayoutmanager/enumeratetextlayoutfragments(from:options:using:)); the underscored table name in the trace is a private implementation detail, not an API to call. Apple also documents that requesting the legacy `layoutManager` on a TextKit 2 `NSTextView` can switch it into compatibility mode; this benchmark verified `textLayoutManager` instead of calling that accessor. [Apple TextKit guidance](https://developer.apple.com/videos/play/wwdc2022/10090/)

The high snapshot's `vmmap` malloc zone reports about 197.6 MiB allocated and 290.1 MiB dirty-plus-swap fragmentation; the low snapshot reports 154.4 MiB allocated and 52.8 MiB fragmentation. Those are tool classifications, not a sum that explains the full physical-footprint difference. The retained `CTRun` bytes alone account for only part of it. A `leaks` scan of the high process reported about 20 KiB in XPC cycles; it did not classify the traced `CTRun` graph as leaked. Reachability does not prove that retaining old layout after clear is desirable.

## Reproduction and limits

`raw/` contains the paired build metadata and markers, all nine completed run files, four held-process reports, three compressed heap summaries, three compressed VM summaries, two compressed reference trees, the compressed leak-scan output and checksums. `analyze.py` checks the same-source conditions, input/output identity, foreground completion, empty editors, sample statistics, live object counts and two distinct reference paths:

```bash
python3 docs/performance/2026-09-24-recovery-retention/analyze.py
```

The private application source is generated with `scripts/benchmark-app.py --reflow --single-paragraph --middle-composed --reflow-max-mib 1 --build-only`; add `--textkit2-single-target` for the candidate. Use separate fresh output directories and the same resolved `--packages` input. Run `scripts/run-private-reflow-subset.py --build <directory> --output <fresh-directory> --max-mib 1 --samples 3 --timeout 120 --recovery` on each build. `scripts/profile-recovery-snapshot.py` captures a held private process and terminates only the owned app. The full local binary/intermediate directories and unsanitized investigative outputs were not added to the repository; the archived outputs are sufficient to recheck every number and the two ownership paths in this report.

The initial TextKit 2 result varied between high and low states; this report does not establish why a particular process releases one or both fragment graphs. The reported snapshots do not identify which editor is Source or Result, nor whether a public TextKit operation can reclaim the fragments without disturbing editor identity, selection, marked text or undo. Real TXT samples, 5/10 MiB completion, repeated editing/IME, iOS 15/macOS 12 paths, VoiceOver and signed-build acceptance remain open under #68. Keep the optimized TextKit 1 editor in the shipping app while those conditions are unresolved.

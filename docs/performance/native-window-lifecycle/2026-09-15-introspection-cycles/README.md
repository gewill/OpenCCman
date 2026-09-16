# Native window cycles after macOS 27 introspection correction

Issue #93 remains reproducible after the #98 / #99 editor/window predicate correction. This is not a claim that the correction fixes model retention.

Actual diagnostic source `1c6114efc94d769bceb63a4d637b7c828dff1874`, with product source identical to `9c8ab60205483f6d80c60108e6ab9c252de992f4`. This is the separate validated diagnostic branch, not an app rebuilt from this documentation commit. Release / Xcode 26.3, local ad-hoc signature, private bundle; purchase setup, Services and global shortcuts excluded. Same Mac16,7 / M4 Pro / 48 GiB and macOS 27.0 (26A428), English / Light / default font. Anchor window is 900×450pt at (298,245); windows cascade through native File → New Window. VoiceOver stayed off.

The protocol was saved before launch. The first-run sheet was dismissed before cycling. Each of three cycles creates two windows, clears both new sources via native select-all/delete, and closes both through Cmd-W while keeping the anchor. **Unlike the earlier all-empty anchor protocol, this run retains the anchor's short default source** to check that it survives other windows closing. This is an explicitly recorded condition difference; do not treat small memory differences as a controlled optimization result. There are no imports, conversions or quota charges.

| Cycle | Models before close | Models at +5 s | Models at +20 s | Footprint at +20 s | RSS at +20 s |
|---|---:|---:|---:|---:|---:|
| 1 | 3 | 3 | 3 | 67,503,184 bytes | 142,098,432 bytes |
| 2 | 5 | 5 | 5 | 80,430,184 bytes | 155,631,616 bytes |
| 3 | 7 | 7 | 7 | 91,030,632 bytes | 165,249,024 bytes |

Each delay is measured from the first sampled return to one visible window after that cycle's three-window state; the first sample at or after 5/20 s is used, with actual timestamps preserved. No deinit event occurred. The baseline source remained unchanged through all three closes; result stayed empty and no active task was observed. Thus this only tests idle windows, not active-task close.

After the final anchor closes, no explicit UI query/activation occurred during the independent 20-second observation. The +20 s sample has zero visible windows but all seven models, footprint 94,585,960 bytes and RSS 171,786,240 bytes. The process was then quit through Cmd-Q and its PID disappearance verified. It did not reproduce the one-document run's deinit; that single-window result must not be generalized to multiple windows. This still does not identify the retaining owner or prove an unbounded production leak.

Recording contains only the owned app, H.264 1496×968, no audio, 300.252 s. The five-minute guard stops after the three cycles, before final-anchor close, so the video does not prove the later zero-window observation; raw diagnostic logs do. Recording/AX/per-second sampling affect absolute resource figures. Final screenshot shows the preserved anchor, not a visual count of hidden models. All media are inspected before gh upload; private preferences are not published.

Cleanup restored the exact prior private preference dictionary, unregistered and renamed the diagnostic bundle inactive, and verified VoiceOver false. No other app, device or protected handoff was touched. Checksums cover all retained raw state and sampling script.

Still open: root holding-chain attribution, corrected-path 1/10 MiB multiwindow document cycles, actually active close, reopen/system-entry behavior, older-system and signed-product acceptance. #90 remains a diagnostic PR; #93 and #18 remain open.

[Real three-cycle video and final anchor screenshot](https://github.com/gewill/OpenCCman/pull/90#issuecomment-5683085660), uploaded via gh.

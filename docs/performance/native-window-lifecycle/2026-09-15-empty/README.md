# Native empty-window observations — 2026-09-15

Source `aec0368fac73646fb3168204c0b150881bd7e55d`, Release/Xcode 26.3 diagnostic, locally ad-hoc signed; macOS 27.0 (26A428), English, Light, 900×450pt windows. Video is 1920×1080/15fps, muted and filtered to this application only. VoiceOver was off before and after; own preferences restored after UI quit and PID exit verification.

The native File → New Window / Cmd-N and Cmd-W paths were used, with an anchor window kept open. Built-in sample text was cleared through the UI in every window before closing. No imports, conversions, clipboard operations or purchase calls were performed.

| Cycle | Visible windows after close | Models at ~5s | Models at ~20s | RSS at ~20s | Physical footprint at ~20s |
|---|---:|---:|---:|---:|---:|
| 1 | 1 | 3 | 3 | 132.28 MiB | 71.49 MiB |
| 2 | 1 | 5 | 5 | 144.95 MiB | 83.53 MiB |
| 3 | 1 | 7 | 7 | 155.23 MiB | 96.06 MiB |

The exact sample times and bytes are in [result.json](result.json); sampling is approximately 1 Hz and the table uses the first sample at or after each target delay. [raw.jsonl](raw.jsonl) preserves every event, including the later reopened model 8. No model-deinitialization event occurred before process exit.

This establishes model-count accumulation over three native cycles, beyond the old manually hosted NSWindow harness. It does not identify the retaining owner or prove an unbounded production leak. RSS/footprint include native UI work and active recording/diagnostic sampling; there is no before/after optimization claim.

After closing the final anchor, the subsequent CUA UI observation found a reopened window/model 8. CUA activation and the application reopen handler were not isolated; an independent 20-second no-window interval was not obtained. This case is **not passed** and the owned process was then quit.

Still pending: retaining-chain diagnosis; 1 MiB/10 MiB import-convert-export cycles and full-byte verification; actually active import/conversion close; independent no-window reopen; minimum OS and signed Cloud acceptance. The purchase/Services/global shortcut exclusions documented in the parent protocol apply.

[RecordOwnedApp.swift](RecordOwnedApp.swift) is the local ScreenCaptureKit recording helper used for evidence, not an app target or app dependency. It requires macOS 15+, checks existing recording permission without requesting new permission, records only the fixed diagnostic bundle, excludes audio/microphone/other apps, refuses existing output files and stops after a marker or five minutes. It does not send input to applications. All UI actions used CUA.

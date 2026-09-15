# Native WindowGroup lifecycle diagnostic — protocol 1

Tracks [#18](https://github.com/gewill/OpenCCman/issues/18). The previous benchmark created `NSWindow` / `NSHostingView` itself and retained four models after two cycles; that result cannot establish whether the real SwiftUI WindowGroup leaks. This diagnostic keeps the production WindowGroup, Router, RootView and editor ownership structure and observes model creation/deinitialization with weak references. It never opens or closes windows programmatically.

## Source isolation

`python3 scripts/prepare-window-lifecycle.py --output <new-directory>` copies tracked source into a new directory, then injects `NativeWindowLifecycleAudit.swift` into that private Xcode target. The real application target has no reference to this file. The tool refuses to overwrite a destination, checks injection anchors, records exact hashes/dirty-source status, and verifies unchanged RootView and dependency lockfile bytes.

The private copy adds a numeric diagnostic identity to HomeViewModel, logs init/deinit, and writes one JSONL sample per second. Registration owns only a weak model reference; an identity generation prevents a delayed deinit event from removing a new allocation that reused the same address. It does not retain models or windows between samples, force layout, scan text, clear editors, change cache eviction or alter close behavior.

For isolation, this variant resets only its own `org.gewill.OpenCCman.NativeWindowLifecycleAudit` preferences to free access, skips purchase SDK setup/status refresh, removes Services registration and disables global shortcut registration (including lazy initialization from activation/menu callbacks). This avoids competing with another running OpenCCman or pending cross-app acceptance. Normal File/New Window and close controls remain. Do not invoke the diagnostic app's Test/status-bar conversion entries, purchase support or Pro purchase screens: those services are intentionally unavailable in this variant. The first What's New sheet may need normal dismissal.

This is not an unmodified production binary, an entitlement/purchase test, or a Services validation. These exclusions must accompany results. The initial application source is `b7a27c3fb213cd86558276b28faf35d886b623a5`; each actual build must record its own source/harness hashes from `preparation.json` and CI head.

## Build and evidence

The optional `build_window_lifecycle=true` dispatch input builds a Release universal macOS diagnostic app using Xcode 26.3. Regular PR App Regression remains unchanged in scope and always runs; a dedicated lifecycle dispatch runs only the diagnostic build rather than repeating that suite. It uploads preparation metadata, source SHA, pins, Xcode version, build log and app archive, retaining failures. It does not target a build-prefixed branch or invoke Xcode Cloud.

The local Xcode 27 build of the same locked RevenueCat 5.64.0 already failed in a previous window-sizing run with duplicate `init(stringRepresentation:)` synthesis. Do not patch its checkout or upgrade dependencies merely to build this diagnostic. The new CI build, not Swift syntax parsing alone, must prove type checking and linking.

After downloading and verifying source SHA/pins, locally ad-hoc sign the private app copy as required for launch. Use CUA for application launch and every UI action. Do not launch or close the separate app awaiting #19 manual status-bar acceptance. The diagnostic is not a signed Cloud release acceptance build.

Logs are created at the per-app cache directory under the diagnostic bundle ID, with a unique PID/UUID name on every launch. They contain numeric model identities, converting/importing flags, visible main-capable window count, elapsed time, RSS, physical footprint and process peak RSS, plus API statuses. No input/output text, clipboard contents, product/customer IDs or window titles are recorded. A missing/failed sample is not a zero reading. Per-second RSS/footprint samples can miss transient peaks; process peak RSS is a separate OS cumulative metric. Sampling/file I/O adds overhead, so this is not a new throughput benchmark.

## Fixed runtime protocol (pending)

1. Record OS/build, machine, Release source/harness hashes, baseline VoiceOver/theme/text settings and app process. Dismiss What's New through the UI if present. Keep an anchor window open.
2. Empty windows: repeat three cycles of File → New Window twice, then close those two native windows. Keep the anchor. For each cycle preserve observations at approximately 5 and 20 seconds after close; do not wait until a favorable count appears or retry failures away.
3. Text windows: repeat with fixed 1 MiB and 10 MiB UTF-8 fixtures, recording input and expected output hashes. Use the real import/convert/export UI and verify full exported bytes. Close secondary windows and retain the same fixed observation schedule. Restore test preferences only within this diagnostic identity.
4. Exercise close while import/conversion is actually active when feasible; accept this case only if runtime evidence establishes the active state. A fast operation that completed before the close does not count. Preserve missing cases as unresolved rather than adding artificial engine delays.
5. Close the anchor, observe the process with no document windows, then reopen through normal File/New Window if available. Record whether model counts remain bounded over cycles and whether old identities are actually deinitialized. An alive object alone is not proof of a production leak: distinguish bounded SwiftUI reuse, pending tasks and growth across cycles.
6. Quit through the app UI, verify that the owned process exited, archive all raw logs and interactions, and restore/remove only this test app's settings/installation. Preserve other test apps and user settings; VoiceOver stays at its prior value.

Attach real interaction video via `gh` and record platform, window dimensions, appearance, language and exact source. Log evidence must correlate to UI actions. Do not substitute programmatically hosted windows or a design image. A local diagnostic result does not close final signed Cloud, iOS 14/macOS 11, UI/accessibility or purchase gates.

## Current status

- Preparation, overwrite refusal, production-file invariants, Swift syntax and project/plist checks are locally verified.
- Full Xcode 26.3 Release typecheck/link passed in [run 34964935263](https://github.com/gewill/OpenCCman/actions/runs/34964935263), source `aec0368fac73646fb3168204c0b150881bd7e55d`. Downloaded artifact source/pins, diagnostic identity, Services exclusion and macOS 11 minimum verified; see [ci-build-check.json](ci-build-check.json).
- Narrow local typecheck also passed when the real Bundle extension was included; the first fixture had omitted it. No production fix was required for that fixture error.
- [Three native empty-window cycles](2026-09-15-empty/README.md) are recorded: after closing secondary windows, live model counts remained 3, 5 and 7 at ~20 seconds, with one visible window. This is an observed accumulation pattern, not a retaining-chain diagnosis or performance improvement.
- 1/10 MiB document cycles, close-during-task and independent zero-window/reopen remain pending. #18 stays open.

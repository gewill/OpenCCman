# macOS 27 editor/window opt-in — Issue #98

The app's Introspect 26.0.0 predicates explicitly list macOS 11–15 and 26. On macOS 27, the locked library evaluates `.v26` as `.past`, and a normal version list matches only `.current`. The editor style/read-only callback, `WorkspaceScrollKeeper.attach` and native window registration therefore do not run on that system. Source containing a TextKit 1 optimization did **not** prove the native SwiftUI editor used it on macOS 27.

This explains a missing application configuration path; it does not yet prove the cause of all retained-window models under [#93](https://github.com/gewill/OpenCCman/issues/93), or establish a measured optimization benefit. Issue [#98](https://github.com/gewill/OpenCCman/issues/98) tracks this correction separately.

## Baseline: one imported document, before/after one AX query

The original Release diagnostic binary is `aec0368fac73646fb3168204c0b150881bd7e55d`, built with Xcode 26.3. Mac16,7 / M4 Pro / 48 GiB, macOS 27.0 (26A428), English / Light / default font, one 900×450pt window, no recording. It is the same isolated variant used in [#90](https://github.com/gewill/OpenCCman/pull/90): purchase setup, Services and global shortcut registration are excluded. No conversion occurred and quota charges were zero.

The predeclared [protocol](baseline/protocol.json) imports the previously hashed 10 MiB fixture via the real system picker. After clicking Open, no explicit editor AX tree request occurs until a 20-second observation and `vmmap -summary` / `heap -s --noContent` capture. Then one full AX tree is requested, followed by another 20-second observation and the same tools. The AX result was 3,286 characters (displayed text was limited in tool output); this is not a manually implemented raw AX traversal.

| Observation | Physical footprint | RSS |
|---|---:|---:|
| Before import, picker open | 51,725,392 bytes | 126,107,648 bytes |
| Import complete, before explicit large-editor AX tree | 2,160,298,816 bytes | 2,325,184,512 bytes |
| Immediately before AX, after first memory tools | 2,160,282,432 bytes | See raw sample |
| After one AX tree request and 20-second observation | 2,160,560,960 bytes | 2,325,463,040 bytes |

The large allocation precedes this AX tree request. This single sequential observation does not support attributing approximately 2 GiB to that request. It does not prove all AX APIs are cheap, isolate any implicit input-tool behavior, or eliminate time/order and memory-tool overhead. It is an import-only, one-window case; do not compare its size directly to the earlier cumulative four-document run as a before/after fix.

Before the explicit AX query, heap summary includes:

| Class | Count | Allocated bytes |
|---|---:|---:|
| CTRun | 1,677,807 | 751,657,536 |
| NSTextLayoutFragment | 419,432 | 214,749,184 |
| NSCTFont | 279,677 | 178,993,280 |
| NSTextLineFragment | 419,432 | 134,218,240 |
| NSTextParagraph | 419,432 | 53,687,296 |

The layout-fragment counts are consistent with a TextKit 2 editor path, unlike the configured TextKit 1 path in the app source. This is allocation-category evidence, not a complete retaining-chain diagnosis. The baseline's 10 MiB fixture contains 419,430 CRLF pairs; this is a paragraph-heavy corpus, not a universal 10 MiB cost claim.

All samples and full no-content heap/VM summaries are under [baseline](baseline/), with SHA256 in [checksums.json](baseline/checksums.json). Tools were from Xcode 27.0 (27A266a), while the app was built with Xcode 26.3. Heap/VM tools completed successfully; the memory tools can pause/touch the target. No raw object contents or memgraph were uploaded. The private diagnostic process exited via Cmd-Q; exact preferences were restored, the app unregistered and renamed inactive, and VoiceOver read back false.

## Candidate

`AppIntrospection` centralizes the two Mac selectors. It uses the already-pinned library's Advanced range predicate only on **macOS 27.x**, reusing the known NSTextView/NSWindow selectors. macOS 28+ is deliberately not opted in. The existing explicit platform list remains for earlier systems; the iOS path is unchanged. Both editor modifiers and RootView's window callback use this policy.

No dependencies or deployment targets change. Upstream Introspect 27.0.0 requires macOS 12, so a direct upgrade would violate this app's macOS 11 requirement. The Advanced SPI is a library API, not an Apple private API; it remains tied to the exact current dependency and must be reviewed on upgrade.

`python3 scripts/check-introspection.py` builds the actual app `ViewExtensions.swift` and `WorkspaceScrollKeeper.swift` with the pinned Introspect dependency, then hosts native SwiftUI editors/window. It verifies callbacks resolve the intended controls, distinct source/result views, actual read-only state, content, inset/background settings, and that TextKit 1 is already selected **before** the test reads `layoutManager`. Its negative control uses the old exact list: zero callbacks on macOS 27, callbacks expected on supported older runtimes. A local clean pinned checkout can be supplied with `--introspect-path`; it is copied before building.

The first test harness accidentally used Swift 6 language mode and rejected an existing unrelated preference-key mutable static. The harness was corrected to the application's Swift 5 language mode; no application source was changed to hide that fixture error. Native macOS 27 checks then passed. A CI step exercises the older macOS runner as well. This hosted test proves the narrow adapters, not the complete product entry/UI matrix.

## Pending acceptance

- Full application typecheck/link and real app callbacks, then the same 10 MiB import-only heap/footprint comparison in fresh processes.
- Complete import → convert → export byte check, native scrolling/axis switching, result read-only behavior, same-condition screenshots and interaction video through `gh`.
- Re-evaluate macOS 27 window/entry results for #19/#57; this change does not by itself close them or #93.
- Existing older-runtime regression, iOS build and no dependency drift.
- Signed Cloud, minimum-system, physical keyboard/input method and VoiceOver gates remain explicit. No build branch or formal release is triggered.

## Sources

- [Pinned version conditions](https://github.com/siteline/swiftui-introspect/blob/a08b87f96b41055577721a6e397562b21ad52454/Sources/PlatformVersion.swift) and [predicate matching](https://github.com/siteline/swiftui-introspect/blob/a08b87f96b41055577721a6e397562b21ad52454/Sources/PlatformViewVersion.swift).
- [Upstream future-version/range design](https://github.com/siteline/swiftui-introspect/tree/a08b87f96b41055577721a6e397562b21ad52454#introspect-on-future-platform-versions) and [27.0.0 deployment requirements](https://github.com/siteline/swiftui-introspect/releases/tag/27.0.0).
- [Apple: Analyze heap memory](https://developer.apple.com/videos/play/wwdc2024/10173/) explains allocation tools; [Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use) separates memory reporting from allocations analysis.

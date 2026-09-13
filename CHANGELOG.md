# Changelog

All notable changes to OpenCCman are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow the app's marketing version, independently of the embedded
OpenCC version and Xcode Cloud build number.

Unreleased changes target the application's `develop` branch. Historical entries
below are reconstructed from repository snapshots; unverified App Store release
dates are intentionally omitted. Intermediate 1.0.x changes without release tags
are grouped with the later 1.1 source snapshot rather than assigned release dates.

## [Unreleased]

Planned for 1.3: common conversion presets, a single-file text workflow, and
conversion reliability improvements. iOS 14 and macOS 11 remain supported;
pricing and the daily limit of 12 homepage conversions are unchanged.

Xcode Cloud build **1.3 (44)** was verified in internal TestFlight on both
platforms on 2026-09-13 ([#33]). That build predates the What’s New cards below.
TestFlight availability is not a public App Store release; remaining acceptance
work is tracked in the [release validation record](docs/v1.3-release-validation-2026-09-13.md)
and [What’s New validation record](docs/WHATS_NEW.md).

### Added

- Adaptive conversion workspace: independent per-window layout choices, macOS
  and iPad horizontal/vertical panes, an inspector or settings sheet, pane-size
  controls and keyboard alternatives. Narrow windows temporarily stack the panes
  without overwriting the chosen layout ([#45](https://github.com/gewill/OpenCCman/issues/45)).
- iPhone stacked workspace with a conversion settings sheet and a single action
  area that remains reachable above the software keyboard. Recommendations hide
  while typing; source and result use the same window model.

- Four common presets: Simplified Chinese, OpenCC Traditional, Taiwan Standard
  with idioms, and Hong Kong Traditional. Advanced options remain available and
  other combinations display as Custom ([#2]).
- Import or drop one UTF-8 TXT file, including files with a BOM, up to 10 MiB.
  Export the latest successful result as UTF-8 without a BOM to a system-selected
  location, using the source filename when available ([#2]).
- Cancel controls for homepage conversion and file import. Cancellation prevents
  late results from replacing the current text; it does not forcibly interrupt
  an already executing native conversion ([#2]).
- Native What’s New cards in English, Simplified Chinese and Traditional Chinese.
  A supported marketing version is shown automatically once, can be reopened in
  Settings, and is recorded only when actually presented. Shared window ownership
  and presentation guards defer the cards during conversion, import and other
  app presentations ([#35]).
- Internal: isolated checks for conversion, file handling, quota reservations,
  pasteboard ownership, What’s New state and localization, integrated into the
  app's GitHub Actions regression workflow ([#1], [#2], [#35]).
- Internal: a weekly upstream coordinator on the repository's default `main`
  branch prepares separately reviewed SwiftyOpenCC and application dependency
  PRs. It records sources and validation evidence and supports ignored rollback
  candidates; see the [upstream sync guide].

### Changed

- Size complete custom controls by platform: Mac icon/text buttons and segments
  default to 28pt, primary actions to 32pt, and iPhone/iPad controls to 44pt.
  Shadows and padding stay inside that envelope; larger text can grow naturally.
  Segment seams remain clickable, and the Mac pane divider uses a 16pt drag band.
  See the [measurements and before/after captures](docs/validation/control-sizing/README.md).

- Keep the reading position anchored to text characters when macOS workspace
  panes reflow, instead of reusing a pixel offset that can jump to later paragraphs.

- Recommendations now participate in scrolling content instead of covering the
  editor. Dynamic Type layouts and settings/action touch targets have been
  improved; settings dismissal continues blocking What’s New until completion.
  See the [adaptive workspace validation record](docs/validation/adaptive-workspace/README.md)
  for completed checks and remaining device/accessibility acceptance.

- Remove unused button styles and their dedicated preview, plus the unused
  VisualEffects package, project references and in-app license entry. The other
  14 dependency pins remain unchanged ([#38](https://github.com/gewill/OpenCCman/issues/38)).
- Pin Neumorphic to the stable 2.4.1 release. Use iPerfman-style joined conversion
  segments with inset tracks, dividers and accent-filled selections; adopt the
  library's switch, circular loading and card APIs. Picker labels follow the
  app language and use a vertical layout at accessibility text sizes.
  See the [control adoption audit](docs/NEUMORPHIC_CONTROLS.md) for retained system
  controls and validation boundaries.
- Upgrade the embedded OpenCC core from 1.2.0 to 1.4.2 through the compatible
  SwiftyOpenCC fork. Existing option meanings remain available; updated
  dictionaries can change conversion output ([#5]).
- Pin SwiftyOpenCC to the exact validated revision
  `6eded293f5c84c064f332cbc2832391165c82dda` in both the project and
  `Package.resolved`, keeping the other dependencies locked ([#32]).
- Read imported files in the background with a bounded size check. macOS uses
  the user-selected file read/write entitlement, and security-scoped access is
  released after use ([#2]).
- Reserve the daily homepage allowance across windows before starting work.
  Success consumes the reservation; failure or cancellation releases it. Work
  finishing after midnight belongs to its start day, and Pro conversions remain
  exempt ([#2]).
- Internal: require same-version official CLI evidence for engine candidates
  and exercise the sync promotion and rollback flow with isolated Git fixtures
  ([#9]).

### Fixed

- Preserve phrase boundaries, leading/trailing blank lines and earlier text
  when converting large inputs. Reuse converters and publish a completed result
  once instead of repeatedly rebuilding the visible result ([#1]).
- Release conversion models, reject repeated starts and stale task results,
  and deliver macOS conversion requests to the intended window. Requests received
  without a ready window are retained for a later window ([#1]).
- Preserve all representations of saved pasteboard items and avoid restoring
  over a newer user copy during the macOS shortcut workflow ([#1]).
- Purchase the package associated with the selected product card, keep cached
  Pro status when entitlement lookup fails, and restore purchases only after an
  explicit user action ([#1]).
- Keep the current draft after a failed or oversized import. Preserve line
  endings, blank lines, Emoji, combining characters and embedded U+0000 through
  the file and compatible engine paths ([#2], [#5]).
- Include the fork's native handle cleanup and byte-length bridge, preventing
  handle leaks and U+0000 truncation ([#5], [engine migration]).
- Correct the engine resource bundle layout used by iOS signing, resolving the
  Xcode Cloud archive blocker. Both platform archives and internal TestFlight
  actions subsequently passed in build 44 ([#32], [#33]).
- Keep reopened What’s New cards in the app's current language, and prevent
  delayed review requests from competing with an already presented system sheet
  ([#35]).

## [1.2]

Source baseline: `cc8c7e8`, the last application commit before the 1.3 work.
The marketing version was set to 1.2 in [the version update][version 1.2].

### Changed

- Update Swift Package dependencies, including SwiftUI Introspect 26.

### Fixed

- Split large input into chunks and add conversion progress reporting to address
  UI stalls ([large-text baseline]). This implementation was subsequently replaced
  by the 1.3 correction above because chunk boundaries could change phrases and
  lose text or blank lines.

## [1.1]

Source snapshot: `v1.1-macOS`. This is the next repository release tag after
`v1.0-macOS`; it also contains the untagged 1.0.x maintenance described below.

### Added

- macOS Services for converting selected Chinese text or opening it in the app.
- Configurable global shortcuts for converting or opening selected text, an
  optional menu bar icon, and an in-app Convert menu command with Command-T.
- Help and localized service names for the macOS selection workflows.

### Changed

- Earlier 1.0.x maintenance included remembered conversion options and migration
  from Glassfy to RevenueCat for purchases ([saved options], [purchase migration]).

### Fixed

- Restore the shortcut recorder's delete control and remove conflicting shortcuts
  from menu bar buttons ([shortcut recorder], [shortcut conflicts]).

## [1.0]

Source snapshot: `v1.0-macOS`.

### Added

- SwiftUI text conversion interface for iOS, iPadOS and macOS using OpenCC.
- Simplified/traditional targets, regional character variants and Taiwan idiom
  options, with source and result text views.
- Settings, language selection, help, open-source information and a lifetime Pro
  purchase option.

[Unreleased]: https://github.com/gewill/OpenCCman/compare/cc8c7e83215261d94b272e354bf2b03c522e4c8c...build
[1.2]: https://github.com/gewill/OpenCCman/compare/v1.1-macOS...cc8c7e83215261d94b272e354bf2b03c522e4c8c
[1.1]: https://github.com/gewill/OpenCCman/compare/v1.0-macOS...v1.1-macOS
[1.0]: https://github.com/gewill/OpenCCman/tree/v1.0-macOS
[#1]: https://github.com/gewill/OpenCCman/pull/1
[#2]: https://github.com/gewill/OpenCCman/pull/2
[#5]: https://github.com/gewill/OpenCCman/pull/5
[#9]: https://github.com/gewill/OpenCCman/pull/9
[#32]: https://github.com/gewill/OpenCCman/pull/32
[#33]: https://github.com/gewill/OpenCCman/pull/33
[#35]: https://github.com/gewill/OpenCCman/pull/35
[engine migration]: https://github.com/gewill/SwiftyOpenCC/pull/1
[upstream sync guide]: https://github.com/gewill/OpenCCman/blob/main/docs/upstream-sync.md
[version 1.2]: https://github.com/gewill/OpenCCman/commit/de925d1
[large-text baseline]: https://github.com/gewill/OpenCCman/commit/cc8c7e83215261d94b272e354bf2b03c522e4c8c
[saved options]: https://github.com/gewill/OpenCCman/commit/61b0401
[purchase migration]: https://github.com/gewill/OpenCCman/commit/4061dac
[shortcut recorder]: https://github.com/gewill/OpenCCman/commit/a05ca05
[shortcut conflicts]: https://github.com/gewill/OpenCCman/commit/7c76a12

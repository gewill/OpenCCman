# OpenCCman

Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)

An OpenCC UI for iOS、iPadOS、macOS by SwiftUI with ❤️

See the [Changelog](CHANGELOG.md) for notable changes and the current unreleased work.

[![Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917](./assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## 1.3

- Four presets: Simplified, OpenCC Traditional, Taiwan Standard + Idioms, and Hong Kong Traditional. Existing advanced preferences remain available.
- Import one UTF-8 `.txt` file (with or without BOM), up to 10 MiB. Drop a file or plain text onto the indicated drop area.
- Export the latest successful conversion as a new UTF-8 file without BOM. Line endings, blank lines and Unicode are preserved.
- Cancel conversion or import without accepting late results. Failed imports leave the current draft intact.
- Daily homepage quota reservations are shared across windows; only successful conversions consume a use.
- Localized What’s New cards appear once per supported marketing version and can be reopened in Settings. See the [presentation rules and validation record](docs/WHATS_NEW.md).

iOS 14 / macOS 11 remain supported. Batch conversion, Shortcuts, history and custom dictionaries are not part of 1.3.

## Development

See the [branching policy](docs/BRANCHING.md) for PR targets and Xcode Cloud packaging branches. The [CI guide](docs/CI.md) describes checks, runner selection and migration status.

## Adaptive workspace design

The selected sidebar direction now has [detailed iPhone, iPad and Mac UI mockups](docs/design/adaptive-workspace/README.md), including side-by-side/stacked layouts, keyboard and task states. The [implementation plan](docs/design/adaptive-workspace/PLAN.md) tracks delivery and acceptance; these are design proposals, not implemented features.

## Development checks

Run on macOS with Xcode command-line tools and Python 3; no simulator is required:

```sh
bash scripts/check-project.sh
python3 scripts/check-core.py
bash scripts/check-quota.sh
bash scripts/check-whats-new.sh
bash scripts/check-control-labels.sh
bash scripts/check-pasteboard.sh
```

Core checks compile the actual app model/services with the dependencies pinned in `Package.resolved`. All preferences and pasteboards used by these checks are isolated from the running app. See [1.3 validation](docs/version-1.3-validation.md) for coverage and remaining release checks.

## Project status

Neumorphic is pinned to the stable **2.4.1** release. Unused button styles and the obsolete VisualEffects dependency/credit have been removed; the remaining 14 dependency pins are unchanged. See the [platform sizing fix and runtime before/after captures](docs/validation/control-sizing/README.md), and the [control adoption audit](docs/NEUMORPHIC_CONTROLS.md) for segmented selectors, switches, loading indicators, cards, and the controls that retain system behavior.

The [application performance baseline](docs/performance/README.md) documents isolated Release measurements, raw samples, engine comparisons and the limits of each metric.

See the [complete project status and follow-up report (2026-09-13)](docs/project-status-and-follow-up-2026-09-13.md) for delivered work, validation evidence, remaining release gates and concrete improvement recommendations.

The [1.3 follow-up validation record](docs/v1.3-release-validation-2026-09-13.md) tracks the latest tooling checks and the Xcode Cloud resource-signing blocker.

The [release metadata and privacy audit (2026-09-15)](docs/release/metadata-2026-09-15/README.md) includes three-language candidate copy, current ASC version discrepancies and remaining privacy/release gates. These drafts have not been applied to App Store Connect.

## Xcode Cloud release builds

Production builds use Xcode Cloud. Push a temporary branch whose name starts with `build` only when a cloud package is needed; it triggers the existing iOS and macOS workflow. Everyday application PRs target `develop`. The legacy `build` branch must be retired before creating `build/*` branches. See [Xcode Cloud configuration and release checks](docs/XCODE_CLOUD.md) for the verified App/workflow IDs, diagnostics and acceptance steps. Local archives and exports are diagnostic evidence; release acceptance uses the cloud build and its exact source commit.

## Upstream sync

The coordinator lives on [`main`](https://github.com/gewill/OpenCCman/tree/main), while application updates target `develop`. The default-branch coordinator migration was merged in [PR #44](https://github.com/gewill/OpenCCman/pull/44); see the [current CI and migration status](docs/CI.md). It proposes a SwiftyOpenCC PR first, then pins the merged, validated fork revision in an app PR. Maintainers review and merge each PR; all other dependencies remain locked.

See the shared [upstream sync guide](https://github.com/gewill/OpenCCman/blob/main/docs/upstream-sync.md) for the Monday 09:17 (UTC+8) schedule, manual commands, CI setup and rollback. Engine-specific work is covered by the [SwiftyOpenCC maintenance guide](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md).

## Thanks

1. [BYVoid](https://github.com/BYVoid)‘s original SDK [OpenCC](https://github.com/BYVoid/OpenCC) 
2. [ddddxxx](https://github.com/ddddxxx)‘s Swift SDK [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC)

## License

MIT License

### Adaptive workspace

macOS and iPad support horizontal or vertical source/result panes, a settings
inspector or sheet, and independent window layout preferences. iPhone uses a
stacked workspace with a keyboard-aware conversion action. Narrow windows fall
back without overwriting the chosen layout. See the [UI specification and designs](docs/design/adaptive-workspace/README.md)
and [runtime screenshots, checks and remaining acceptance](docs/validation/adaptive-workspace/README.md).

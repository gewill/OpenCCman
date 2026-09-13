# OpenCCman

Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)

An OpenCC UI for iOS、iPadOS、macOS by SwiftUI with ❤️

[![Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917](./assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## 1.3

- Four presets: Simplified, OpenCC Traditional, Taiwan Standard + Idioms, and Hong Kong Traditional. Existing advanced preferences remain available.
- Import one UTF-8 `.txt` file (with or without BOM), up to 10 MiB. Drop a file or plain text onto the indicated drop area.
- Export the latest successful conversion as a new UTF-8 file without BOM. Line endings, blank lines and Unicode are preserved.
- Cancel conversion or import without accepting late results. Failed imports leave the current draft intact.
- Daily homepage quota reservations are shared across windows; only successful conversions consume a use.

iOS 14 / macOS 11 remain supported. Batch conversion, Shortcuts, history and custom dictionaries are not part of 1.3.

## Development checks

Run on macOS with Xcode command-line tools and Python 3; no simulator is required:

```sh
bash scripts/check-project.sh
python3 scripts/check-core.py
bash scripts/check-quota.sh
bash scripts/check-pasteboard.sh
```

Core checks compile the actual app model/services with the dependencies pinned in `Package.resolved`. All preferences and pasteboards used by these checks are isolated from the running app. See [1.3 validation](docs/version-1.3-validation.md) for coverage and remaining release checks.

## Project status

See the [complete project status and follow-up report (2026-09-13)](docs/project-status-and-follow-up-2026-09-13.md) for delivered work, validation evidence, remaining release gates and concrete improvement recommendations.

The [1.3 follow-up validation record](docs/v1.3-release-validation-2026-09-13.md) tracks the latest tooling checks and the Xcode Cloud resource-signing blocker.

## Xcode Cloud release builds

Production builds use Xcode Cloud. Pushing a branch whose name starts with `build`, including merging an application PR into `build`, triggers the existing iOS and macOS workflow. See [Xcode Cloud configuration and release checks](docs/XCODE_CLOUD.md) for the verified App/workflow IDs, diagnostics and acceptance steps. Local archives and exports are diagnostic evidence; release acceptance uses the cloud build and its exact source commit.

## Upstream sync

The coordinator lives on [`main`](https://github.com/gewill/OpenCCman/tree/main), while application updates target `build`. It proposes a SwiftyOpenCC PR first, then pins the merged, validated fork revision in an app PR. Maintainers review and merge each PR; all other dependencies remain locked.

See the shared [upstream sync guide](https://github.com/gewill/OpenCCman/blob/main/docs/upstream-sync.md) for the Monday 09:17 (UTC+8) schedule, manual commands, CI setup and rollback. Engine-specific work is covered by the [SwiftyOpenCC maintenance guide](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md).

## Thanks

1. [BYVoid](https://github.com/BYVoid)‘s original SDK [OpenCC](https://github.com/BYVoid/OpenCC) 
2. [ddddxxx](https://github.com/ddddxxx)‘s Swift SDK [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC)

## License

MIT License

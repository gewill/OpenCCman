# OpenCCman

A native Chinese text conversion app for iPhone, iPad and Mac, powered by [OpenCC](https://github.com/BYVoid/OpenCC). Convert between Simplified and Traditional Chinese and adapt regional wording on your device.

[Website](https://openccman.gewill.org/) · [App Store](https://apps.apple.com/app/id6474449401) · [Privacy policy](https://openccman.gewill.org/en/privacy.html) · [Support](https://openccman.gewill.org/en/support.html)

[![Download on the App Store](assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## OpenCCman 2.1

- Choose from four common presets: Simplified Chinese, OpenCC Traditional, Taiwan Standard with Taiwan idioms, and Hong Kong Traditional. Advanced character and regional wording options remain available. Simplified output is not a complete reverse conversion of Taiwan-specific vocabulary.
- Read source and result side by side or stacked on Mac and iPad. Each window keeps its layout preference, while narrow windows temporarily stack the panes. The iPhone workspace uses a compact Convert action to leave more room for text.
- On Mac, use customizable global shortcuts to convert selected text in another app and replace it in an editable field, or open the selection in OpenCCman. Compatible apps can also use macOS Services. Replacement requires Accessibility permission and support from the source app.
- Import or drop one UTF-8 TXT file up to 10 MiB, including files with a BOM; export the latest successful result as UTF-8 without a BOM. Line endings, blank lines and Unicode text are preserved. On Mac, Pro can convert one UTF-8 TXT over 10 MiB and up to 1 GiB directly to a file, with progress and cancellation while preserving the editor draft. iPhone/iPad remain limited to 10 MiB. Batch conversion and Big5/GBK decoding are not supported.
- Automate text conversion with the free Shortcuts action on iOS/iPadOS 16+ and macOS 13+: four presets, up to 10 MiB of UTF-8 text, without consuming homepage conversions.
- Start with an empty workspace or insert an example. Clear Source asks for confirmation before clearing the source and result.
- Cancel a conversion or import without letting a late result replace the current text. Cancellation does not forcibly interrupt native conversion already in progress.
- Use OpenCCman free for 12 successful homepage conversions per day. Lifetime Pro removes that limit and in-app recommendations; existing lifetime purchases remain valid. Importing, exporting and changing presets do not use the daily allowance.

OpenCCman 2.1 requires **iOS/iPadOS 15 or macOS 12**. Optional Launch at Login is available on macOS 13 or later. See the [2.1 release notes](https://github.com/gewill/OpenCCman/releases/tag/v2.1), [changelog](CHANGELOG.md#21---2026-10-01) and [release record](docs/release/launch-2.1-20261001.md) for technical changes and validation limits.

## Development

Daily application work targets `develop`; `main` carries published releases and the weekly upstream coordinator. Only temporary `build`-prefixed branches trigger Xcode Cloud packaging. Read the [branching policy](docs/BRANCHING.md), [CI guide](docs/CI.md) and [Xcode Cloud guide](docs/XCODE_CLOUD.md) before changing release or build configuration.

On macOS with Xcode command-line tools and Python 3, run the relevant isolated checks:

```sh
bash scripts/check-project.sh
python3 scripts/check-core.py
bash scripts/check-quota.sh
bash scripts/check-whats-new.sh
bash scripts/check-control-labels.sh
bash scripts/check-pasteboard.sh
```

These checks do not replace a signed Xcode Cloud build or device acceptance. The [adaptive workspace validation](docs/validation/adaptive-workspace/README.md), [performance evidence](docs/performance/README.md) and [Build 56 record](docs/validation/build-56/README.md) describe what was tested and what remains open.

The [2.1 Shortcuts action examples](docs/SHORTCUTS.md) describe the text-only automation and its supported systems.

The [upstream sync guide](docs/upstream-sync.md) explains the weekly, reviewed SwiftyOpenCC and OpenCC update flow. Engine-specific maintenance is documented in the [SwiftyOpenCC repository](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md).

Earlier [1.3 validation](docs/version-1.3-validation.md), [project audit](docs/project-status-and-follow-up-2026-09-13.md) and [handoff](docs/handoff/2026-09-16/README.md) are dated historical records, not the current release status.

## Credits and license

OpenCCman builds on [OpenCC](https://github.com/BYVoid/OpenCC) by BYVoid and [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC) by ddddxxx. Licensed under [MIT](LICENSE).

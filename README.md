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

## Thanks

1. [BYVoid](https://github.com/BYVoid)‘s original SDK [OpenCC](https://github.com/BYVoid/OpenCC) 
2. [ddddxxx](https://github.com/ddddxxx)‘s Swift SDK [SwiftyOpenCC](https://github.com/ddddxxx/SwiftyOpenCC)

## License

MIT License

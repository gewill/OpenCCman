# OpenCCman

Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)

An OpenCC UI for iOS、iPadOS、macOS by SwiftUI with ❤️

[![Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917](./assets/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg)](https://apps.apple.com/app/id6474449401)

## Upstream sync

Application development lives on [`build`](https://github.com/gewill/OpenCCman/tree/build); `main` hosts the upstream coordinator. It checks wrapper commits and stable OpenCC releases every Monday at 09:17 (UTC+8), opens a SwiftyOpenCC PR first, then an app revision-update PR after the fork is merged and validated. Maintainers review and merge each PR.

See the [upstream sync guide](docs/upstream-sync.md) for repository responsibilities, local commands, CI credentials, failure recovery and rollback. The [Sync OpenCC workflow](https://github.com/gewill/OpenCCman/actions/workflows/sync-opencc.yml) also supports manual runs.

## License

MIT License

# OpenCCman 2.3 release — 2026-11-19

The maintainer authorized App Store publication, GitHub Release publication and the website update on 2026-11-19 (Asia/Taipei), and explicitly accepted the unverified Build 65 acceptance items before publication. No Issue closure was requested.

## Build and source

- Version/build: 2.3 (65), iOS/iPadOS and native macOS.
- Source and annotated `v2.3` tag: `0fca3a2893161fc08c17e9fe3a0fb142090d5a4a`, the `main` squash of PR #346. This commit is already an ancestor of `develop`.
- Xcode Cloud run: `4123e410-9ff8-4576-b338-3dce4ca5a453`, SUCCEEDED. Both platforms use this same source and run.
- Xcode 27.1 (27A9275), iPhoneOS 27.1 SDK / MacOSX 27.0 SDK. Minimum systems remain iOS/iPadOS 15 and macOS 12.
- Exact artifact hashes, UUIDs, dependency pins and historical validation are preserved in the [2.3 GitHub Release](https://github.com/gewill/OpenCCman/releases/tag/v2.3).

## App Store publication

| Platform | Version ID | Build ID | Readback |
| --- | --- | --- | --- |
| iOS/iPadOS | `36f89171-fec0-425d-9b46-c09319e1cfc5` | `99d13bb1-02fa-4dcb-ae77-27d27bc8915b` | READY_FOR_DISTRIBUTION, downloadable=true |
| macOS | `7d6ee717-0a85-4f41-b3ef-11dc8a372ba5` | `e7aa0989-54e1-46b7-a850-5763b1f159af` | READY_FOR_DISTRIBUTION, downloadable=true |

Both versions were read as PENDING_DEVELOPER_RELEASE with release type MANUAL and Build 65 VALID before `asc versions release --version-id … --confirm`. Both release requests succeeded and were independently read back. Approval was confirmed before release; the exact approval timestamps were not retrieved. Storefront propagation is separate from ASC state.

## Validation and accepted limits

- Existing evidence: Release archives succeeded; source `0fca3a2` passed App Regression and App icon. Build 65's macOS TestFlight shortcut replacement was verified on 2026-11-18 in TextEdit, with output compared to OpenCC, clipboard restoration and source focus checked.
- Not verified on Build 65: purchase/restore, share extension, batch TXT, differences, the full core-flow/UI acceptance, minimum operating systems and other hosts including WeChat. These are not counted as passed. The maintainer explicitly accepted these risks for this release.
- This follow-up changes documentation only; no App rebuild, simulator or new UI automation was run.
- Website: three-language home, changelog, support email and affected guides updated. Static generation, local links, CSP markup, specimen outputs and font coverage checked with `scripts/check.py`. Local browser review covered the changelog language links and English home. Website evidence does not establish App feature acceptance.

Public links: [App Store](https://apps.apple.com/app/id6474449401), [GitHub Release](https://github.com/gewill/OpenCCman/releases/tag/v2.3), [website release notes](https://openccman.gewill.org/en/changelog).

The published tag continues to identify the binary source; subsequent README, changelog and release-record commits do not change the shipped binary.

## Website deployment

Website `main` commit `8efcd6b3aa3af357905bfde99e963c583b9babac` was pushed, read back equal to `origin/main`, rebuilt without tracked changes, and deployed to Cloudflare Pages Production (`526ecea2.openccman-website.pages.dev`). Production verification compares eighteen affected pages across three languages. The three home pages and nine guides match the committed output byte-for-byte. Cloudflare rewrites email addresses on the three changelogs and three support pages; their content is compared after decoding that documented transformation, including the mailto destination. Initial Python HTTP requests received 403; ordinary curl requests and browser navigation succeed. The production Chinese changelog was also viewed in the browser.

Initial public US/TW Apple Lookup responses still returned 2.2 immediately after release; this propagation observation does not override the independently verified ASC publication state.

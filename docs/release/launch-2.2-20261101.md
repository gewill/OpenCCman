# OpenCCman 2.2 release — 2026-11-01

The maintainer authorized these publication steps on 2026-11-01 (UTC+8): App Store release, Squash merge to `main`, `v2.2` Tag, GitHub Release, sync to `develop`, website changelog, blog app page, and closing milestones.

Both platforms use Xcode Cloud Build 63, built from source `15390dde4b7f70a97c174259ebd945c5a81647bf` (`release/v2.2`, PR #311). Cloud run `0e88e351-77b5-4b99-a998-c2d91630bc58` succeeded.

| Platform | Version ID | Build ID | Review submission | Release readback |
| --- | --- | --- | --- | --- |
| iOS/iPadOS | `a45ea7c1-95f5-48d6-93a1-b514da32bdb9` | `c9539366-903d-4d40-90b1-d6b1a588aa52` | `92603338-60da-4965-a91e-9fb6e22bc742` | READY_FOR_SALE / READY_FOR_DISTRIBUTION |
| macOS | `1fda2f5f-7edd-4458-a560-1765e58d5682` | `b96b3e97-a9ae-4d33-b4b7-e79ab265e257` | `72a7af72-cc49-438f-a10f-43a65a75a5f8` | READY_FOR_SALE / READY_FOR_DISTRIBUTION |

## App Store release

- **Before mutation:** both versions read `PENDING_DEVELOPER_RELEASE` with release type MANUAL, Build 63 `VALID`, and no phased release configured. Both review submissions read `COMPLETE`; they were submitted on 2026-10-31.
- **Release calls:** `asc versions release --version-id … --confirm` ran at 23:24:58Z (iOS) and 23:25:11Z (macOS) on 2026-10-31 UTC.
- **After release:** an immediate readback and a recheck about 30 minutes later both returned `READY_FOR_DISTRIBUTION`, `downloadable: true` and build 63.
- **Storefronts:** the Apple Lookup API reports `currentVersionReleaseDate` 2026-10-31T23:25:01Z. During the first half hour, US, Taiwan, Hong Kong, Japan, Singapore and UK reads alternated between 2.1 and 2.2 as CDN caches propagated. The app is not sold in mainland China.
  - From this network, apps.apple.com redirects to the China Today page, so the storefront web page was not used as evidence.

Details are in [metadata-2026-10-31/release-readback.json](metadata-2026-10-31/release-readback.json).

## Source, Tag and branches

| Step | Result |
| --- | --- |
| Publication PR | [#313](https://github.com/gewill/OpenCCman/pull/313) `codex/release-2.2-publication` → `main`. One docs commit on `15390dd` marks the CHANGELOG entry released and updates the README. A tree-preserving merge of `main` resolves history conflicts left by the 2.1 squash. Against `15390dd`, the tree diff is limited to `CHANGELOG.md` and `README.md`. |
| Checks | App Regression passed on PR HEAD `f3ada52`. It also passed on the push to `main` at the squash commit (run 41253457954). |
| Squash merge | `main` = `92847e35ff2b86dcd4bb54995a59d7291e3adba0`, same tree as the PR HEAD |
| Tag | Annotated `v2.2` (`26725f9`) → `92847e3` |
| GitHub Release | [OpenCCman 2.2](https://github.com/gewill/OpenCCman/releases/tag/v2.2), marked latest |
| Sync to develop | [#314](https://github.com/gewill/OpenCCman/pull/314), merged with a merge commit (`fbcf154`) so the `main` squash becomes an ancestor of `develop`. The tree equals `main`. This brings the 776accc release changes into develop: `productionEnabled`, `MARKETING_VERSION = 2.2`, and the TestFlight notes. |

Merging #314 with a merge commit, rather than a squash, is deliberate. The 2.1 sync (#266) was squashed, so `main`'s history never reached `develop`, and #313 needed an extra merge to resolve conflicts. With `main` now an ancestor of `develop`, the next release PR should merge cleanly.

## Product scope

- **iPhone/iPad Pro file conversion:** one UTF-8 TXT larger than 10 MiB and up to 100 MiB converts directly to a file chosen in the system save panel.
  - Runs only while the app is open, and stops safely in the background or when the device locks.
  - A finished result survives a cancelled save or a restart. The editor and drag and drop stay at 10 MiB.
  - Enabled by `MobileFileRuntime.productionEnabled = true`.
- **iPhone layout:** the workspace follows the window size and uses the system navigation bar.
- **Pro prompt:** a system alert on iPhone and iPad; a pending file error is shown after it closes.
- **Mac:** the menu bar icon is on by default, an explicit choice is kept, and ⌘, / ⌘P work with More in the overflow menu.
- **Not enabled:** the experimental capacities above 100 MiB on iPhone/iPad and above 1 GiB on Mac ([#268](https://github.com/gewill/OpenCCman/issues/268), [#269](https://github.com/gewill/OpenCCman/issues/269)).
- **Minimums:** the app still requires iOS/iPadOS 15 and macOS 12. Publication does not close issue-based acceptance limits.

## Evidence

- [Metadata, validation and submission](metadata-2026-10-31/README.md): snapshot, approved proposal, readback, `asc validate` with 0 errors, submission and release readbacks.
- [iPhone store assets](store-assets-2.2-20261031/README.md): manifest with ASC checksum readback, capture and encoding inputs, and a compressed contact sheet. Large originals stay outside the repository; their sha256 hashes are listed in that folder.
- [Build 63 signed smoke acceptance](../validation/build-63/README.md):
  - Mac TestFlight checks.
  - iPhone 16 Pro 100 MiB conversion, whose output sha256 `9d7363c7…` equals the independent reference.
  - Checks not run on 63: cancel, background, restart and +1 byte (covered on Build 61); memory; iPad; purchases.

## Toolchain note

The Xcode Cloud Default workflow is pinned to **Xcode 27.1 (27A9275) on macOS 27.0.1**; the ASC API read this back on 2026-11-01. GitHub App Regression still uses **Xcode 26.3**. Under Xcode 27/macOS 27, two local StoreKit regression tests fail, tracked in [#218](https://github.com/gewill/OpenCCman/issues/218) (v2.3): refund revocation takes about 15 s, and the simulated purchase error becomes `unknown`. Moving CI to Xcode 27 must resolve #218 first. A local 27.1 build is not evidence that CI covers 27.1.

## Website, blog and milestones

- **Website:** [OpenCCman-website #19](https://github.com/gewill/OpenCCman-website/pull/19) was squash merged as `45fcb22`. It was deployed from a clean, fast-forwarded `main` to the Cloudflare Pages Production environment at source `45fcb22`. On 2026-11-01, `https://openccman.gewill.org/{zh-Hans,zh-Hant,en}/changelog` returned 200, byte-identical to the local `main` build. Each page shows 2.2 above 2.1 with the v2.2 release link.
- **Blog:** [blog #17](https://github.com/gewill/blog/pull/17) updates the OpenCCman app-page intros from 2.0 to 2.2. It was squash merged as `ef93de6` and deployed from `main` to Cloudflare Pages Production. `https://gewill.org/apps/openccman/` and `/zh/apps/openccman/` both show the new text.
- **Website follow-up:** the homepage and guide file-limit wording was not updated for 2.1 or 2.2.
- **Milestones:** v2.1 and v2.2 had 0 open issues and were closed on 2026-11-01. Unfinished work, including #218, #260, #14, #71 and #16, is in milestone v2.3.

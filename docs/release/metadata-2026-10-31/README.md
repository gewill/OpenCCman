# 2.2 App Store metadata, submission and release readback

Recorded 2026-10-31 to 2026-11-01. App `6474449401`.

| Folder / file | Content |
| --- | --- |
| `snapshot/` | ASC version and app-info localizations before editing (iOS, macOS; en-US, zh-Hans, zh-Hant) |
| `proposed/` | Approved 2.2 description and What's New per platform and locale |
| `review/` | Field-level change plan and approval: iOS changed description and What's New, macOS What's New |
| `readback/` | ASC API readback after upload, matching `proposed/` |
| `submission/` | `asc validate` output for each version (each 0 errors, 0 blocking, 2 non-blocking warnings) and the review submission readback |
| `release-readback.json` | State before release, both `asc versions release` calls, ASC readback after release, storefront Lookup observations, and the Build 63 Xcode Cloud run and toolchain |

App-info fields (name, subtitle, privacy URL) did not change in 2.2. iPhone screenshots and previews are recorded in [store-assets-2.2-20261031](../store-assets-2.2-20261031/README.md).

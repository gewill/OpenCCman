# OpenCCman 1.3 implementation and validation

> Status update (2026-09-13): this document preserves the feature-stage validation record. OpenCC 1.4.2 and the app dependency PR have since merged; the app now pins `eacb73dcb28c26e7cc5d8d9cb405e88fa2d59b13`. Earlier Debug builds and development-signed file tests are not final-distribution acceptance for that engine revision. See the [complete status and follow-up report](project-status-and-follow-up-2026-09-13.md) for current evidence and remaining gates.

Date: 2026-09-12. Baseline: PR #1, merged into `build` at `59fcad781045182bc7f032910a23be656dbe514b`.

## Implemented behavior

The four presets and all existing controls share `ConversionConfiguration`, also used by macOS Services and global shortcuts. The original defaults keys and enum raw values remain compatible. Switching to simplified output preserves inactive advanced choices.

The file workflow accepts a single UTF-8 TXT file, including a leading BOM, up to 10 MiB. Reads use a dedicated queue, bounded chunks and balanced security-scoped access. Dropped providers are opened while their temporary URL is valid. Cancellation completes even when a provider never invokes its callback. Import failure/cancellation preserves the current draft; successful import or an input edit invalidates older work. Export uses an immutable successful-result snapshot and writes UTF-8 without BOM.

Quota reservations include unfinished conversions across windows. Reservation, limit checking and success accounting use one lock. Success commits once; cancellation, failure and deallocation release idempotently. Work belongs to its starting date, so a late completion cannot consume or overwrite the new day's quota. Pro uses and existing macOS service/shortcut pricing remain unchanged.

## Automated verification

- Project/plist/localization validation and all production Swift source parsing.
- Actual HomeViewModel, conversion service, file service, configuration, document and quota code compiled against the exact locked OpenCC and SwiftyUserDefaults revisions.
- Seven conversion combinations × eight text fixtures; phrase boundary, newline, empty paragraph, Unicode, U+0000 and converter reuse checks.
- Model release, repeated taps, one result publication, cancellation/replacement, empty input, quota guard and export snapshot preservation.
- All presets, custom recognition, UTF-8/BOM/CRLF/emoji/combining characters/NUL, exact size boundary, oversized and invalid files, import cancellation, draft/result preservation and stale conversion rejection.
- Real NSURL and NSString providers, escaped filenames and a provider that never calls back after cancellation.
- Quota cap, two windows claiming the last slot, 100 concurrent attempts, idempotent commit/release, abandoned reservations, midnight rollover and Pro exemption.
- Isolated NSPasteboard tests preserve complete multi-item/type data and do not overwrite a newer copy.

Commands are listed in the README and run in the `App Regression` GitHub Actions job. These do not launch simulators or modify the user's clipboard/preferences.

## Build and signed sandbox verification

- Complete generic macOS and iOS Debug builds passed with pinned dependencies; no simulator was launched.
- A separate validation bundle identifier was signed with the local Apple Development identity. Its actual entitlements include App Sandbox and user-selected read/write access.
- In that signed app, selected the Taiwan preset, imported a BOM-prefixed TXT outside the container, converted it and exported through the system save panel. Export filename matched the source-derived default.
- Read the saved file and compared exact bytes: BOM removed, CRLF/blank line/emoji/combining mark preserved, expected `鼠标 → 滑鼠` and `汉字 → 漢字` output.
- Imported invalid UTF-8 through the real file panel: an error appeared and the previous input/result remained intact.
- Closed/reopened the app window: preferences persisted and a fresh window model loaded without a crash.

Build warnings observed were existing generated color-symbol collisions and the absence of AppIntents metadata; they were not changed as part of this feature work.

## Release gates and dependency separation

At the feature-stage validation recorded above, the app still pinned the prior engine while the OpenCC 1.4.2 migration was reviewed separately. That dependency separation is now complete: [app PR #5](https://github.com/gewill/OpenCCman/pull/5) adopted `eacb73dcb28c26e7cc5d8d9cb405e88fa2d59b13` after the merged fork SHA passed `OpenCC Compatibility`. Future promotions retain the same gate. Final-distribution acceptance remains outstanding; engine benchmark results are not app-wide performance claims.

Before App Store release, verify purchase/cancellation/restore with a StoreKit sandbox account or TestFlight and verify the signed distribution build's Services/global-shortcut permissions and cross-app behavior. No real purchase was made. TestFlight/distribution signing and older physical devices are not covered by local Debug builds.

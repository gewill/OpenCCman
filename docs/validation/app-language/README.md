# App language mechanism — `AppleLanguages`

The app now stores its language choice in `AppleLanguages`, so `Bundle.main`
itself resolves localized resources. This candidate is **not yet accepted**:
every result below is a source-level or storage-level check. No running app was
observed, and no before/after captures exist.

Base: `develop` `d81c2ca`. No dependency pins change.

## Why the previous mechanism kept regressing

The selected language reached the UI only through `.environment(\.locale,)` on
the `WindowGroup`. A SwiftUI sheet is presented outside that branch, so each
presentation had to re-inject the value by hand. [#75](https://github.com/gewill/OpenCCman/issues/75)
fixed three call sites through [#76](https://github.com/gewill/OpenCCman/pull/76)
— What's New, `PhoneWorkspace`, `WorkspaceSurface` — and the rule then had to be
remembered for every new sheet. `ProAlertView`'s `ProScene` sheet did not carry
it, and nothing outside SwiftUI's `Text` followed the choice at all, which is
what `String.localized(in:)` was written to work around.

Storing the choice in `AppleLanguages` moves resolution into the bundle. Sheets,
AppKit and system-provided UI follow the selected language without
per-presentation plumbing. The mechanism follows the one already shipping in
SecretDiary, including its restart prompt and its legacy-key migration.

## Cost, stated plainly

`Bundle.main` caches its localization at launch, so a new choice applies in full
only on the next one. Choosing a language therefore offers a restart (Later /
Restart) instead of forcing it; `Restart` calls `exit(0)`, which on macOS quits
without relaunching. The existing root `.environment(\.locale,)` injection is
kept so SwiftUI text still updates in place before that restart, and the missing
injection on `ProAlertView`'s sheet was added.

This is a deliberate change of the behavior accepted in #75/#76, where language
switching completed within one process. It was chosen by the maintainer after
the trade-off was raised, including the risk that `exit(0)` discards editor text.

## The `AppleLanguages` domain trap

`UserDefaults.standard` also serves `NSGlobalDomain`, so
`array(forKey: "AppleLanguages")` returns the **system** languages even when the
app has stored nothing. Reading it that way makes every launch look already
migrated, and an existing install's saved choice is silently discarded. The app
reads its own persistent domain instead. Both regression checks below caught
this, in the app code and then in the check's own assertion.

## Reproducible local checks

| Check | Command | Result on 2026-09-20 |
| --- | --- | --- |
| Stored language representation | `python3 scripts/check-app-language.py` | PASS: BCP-47 tags, `AppleLanguages` writes and removal, legacy selection fallback, tag matching |
| SDK language bridge | `python3 scripts/check-iap-locale.py` | PASS: six saved-language cases, proxy ordering, configure idempotence, unchanged preferences |
| Control labels in the selected language | `bash scripts/check-control-labels.sh` | PASS: English, Simplified/Traditional, underscore locales, live changes, missing-key fallback |
| Project and source syntax | `bash scripts/check-project.sh` | PASS: 62 Swift sources and three localization files |
| macOS build | `xcodebuild … -destination 'platform=macOS'` | BUILD SUCCEEDED, Xcode 27.0 (27A266a) |
| iOS Simulator build | `xcodebuild … -destination 'generic/platform=iOS Simulator'` | BUILD SUCCEEDED, Xcode 27.0 (27A266a) |

`scripts/check-app-language.py` compiles the actual `LocaleConstants` and
preference keys against an isolated temporary defaults suite. It covers the
stored representation only.

## Not covered

- Any running app. Whether each surface redraws in the selected language, in
  place or after a relaunch, is unverified — including the `ProScene` sheet this
  change fixes, which was never reproduced as a failure.
- Three-language and dark-appearance captures of the settings rows, including
  the `Launch at login` row that prompted this work.
- The restart prompt in a signed build, and what `exit(0)` does to unsaved
  editor text on macOS.
- The migration on a real install that already stores the legacy key.
- `macOS 12`, minimum-system and RevenueCatUI behavior, which stay with
  [#16](https://github.com/gewill/OpenCCman/issues/16) and
  [#71](https://github.com/gewill/OpenCCman/issues/71).

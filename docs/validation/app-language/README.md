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
Restart) instead of forcing it. On macOS `Restart` reopens the app's own bundle
through `NSWorkspace.openApplication` — the same public call
`AppDelegate.activateMainWindow` already uses inside the sandbox — and leaves
only once the replacement is running; iOS keeps SecretDiary's `exit(0)`. The
existing root `.environment(\.locale,)` injection is kept so SwiftUI text still
updates in place before that restart, and the missing injection on
`ProAlertView`'s sheet was added.

This is a deliberate change of the behavior accepted in #75/#76, where language
switching completed within one process. It was chosen by the maintainer after
the trade-off was raised, including the risk that `exit(0)` discards editor text.

## The `AppleLanguages` domain trap

`UserDefaults.standard` also serves `NSGlobalDomain`, so
`array(forKey: "AppleLanguages")` returns the **system** languages even when the
app has stored nothing. Reading it that way makes every launch look already
migrated, and an existing install's saved choice is silently discarded. Both
regression checks below caught this, in the app code and then in the check's own
assertion.

The first fix read only the app's persistent domain, which was too narrow.
`-AppleLanguages` is Apple's way to set the language for one run, and UI tests
inject it there, in the argument domain. A persistent-domain read cannot see it,
so the app treated such a run as following the system and removed the stored key
at launch. OpenCCman has no UI suite to show this; iPerfman's did, where the full
freemium UI suite went from 40 passed to 25 passed and 10 failed. The app now
reads the argument domain first, then its persistent domain, never
`NSGlobalDomain`. `scripts/check-app-language.py` runs its check a second time
with `-AppleLanguages "(zh-Hans)"`, so the argument domain is real in that
process; with the argument-domain read removed, that run fails.

## Reproducible local checks

| Check | Command | Result on 2026-09-20 |
| --- | --- | --- |
| Stored language representation | `python3 scripts/check-app-language.py` | PASS: BCP-47 tags, `AppleLanguages` writes and removal, legacy selection fallback, tag matching, and a launch-argument language outranking stored choices |
| SDK language bridge | `python3 scripts/check-iap-locale.py` | PASS: six saved-language cases, proxy ordering, configure idempotence, unchanged preferences |
| Control labels in the selected language | `bash scripts/check-control-labels.sh` | PASS: English, Simplified/Traditional, underscore locales, live changes, missing-key fallback |
| Project and source syntax | `bash scripts/check-project.sh` | PASS: 62 Swift sources and three localization files |
| macOS build | `xcodebuild … -destination 'platform=macOS'` | BUILD SUCCEEDED, Xcode 27.0 (27A266a) |
| iOS Simulator build | `xcodebuild … -destination 'generic/platform=iOS Simulator'` | BUILD SUCCEEDED, Xcode 27.0 (27A266a) |

## Runtime observations

An ad-hoc signed, sandboxed macOS build of this branch, bundle
`org.gewill.OpenCCman.LanguageValidation` on its own preferences domain,
macOS 27.0, 1024×768 window. Its domain was removed afterwards; the installed
app's own preferences were not read or written.

| Observation | Result |
| --- | --- |
| Settings in English, Simplified and Traditional, including the `Launch at login` row | Each switch applied in place, without a relaunch |
| Settings in dark appearance | Rows and the restart alert stay legible |
| Restart prompt in all three languages | Title, message and both buttons localized |
| `Restart` on macOS | Process replaced, pid 95202 → 97481; the new instance opened in the chosen language |
| Legacy install migration | Seeded `selectedLocale = zh_Hant` with no `AppleLanguages`; after one launch the domain held `AppleLanguages = ("zh-Hant")`, the legacy key was gone and the app opened in Traditional Chinese |
| AppKit menu bar after migration | The app's standard menus render in Traditional Chinese while the system stays English — resolution the environment-only mechanism could not reach |


`scripts/check-app-language.py` compiles the actual `LocaleConstants` and
preference keys against an isolated temporary defaults suite. It covers the
stored representation only.

## Not covered

- The `ProScene` sheet this change also fixes. Its missing injection is a source
  reading; the wrong language was never reproduced as a running failure.
- iOS. Both builds pass, but no iOS device or simulator was driven, and the
  `exit(0)` path there is untried. Apple's interface guidelines advise against an
  app quitting itself, so whether iOS keeps that path is still open.
- A distribution-signed build. The observations above come from an ad-hoc signed
  local build, not from TestFlight.
- The migration on an actual user install. The legacy state above was seeded in
  an isolated domain; it is a real launch, not a real install.
- What a restart does to unsaved editor text, and the restart prompt while a
  conversion is running.
- `macOS 12`, minimum-system and RevenueCatUI behavior, which stay with
  [#16](https://github.com/gewill/OpenCCman/issues/16) and
  [#71](https://github.com/gewill/OpenCCman/issues/71).

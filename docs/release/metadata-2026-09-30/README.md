# 2.1 App Store descriptions and What’s New (2026-09-30)

Updated both 2.1 drafts for app `6474449401` after the user requested ASC descriptions and What’s New. The source baseline is Xcode Cloud Build 60, commit `da526f03f5f9d49df3edfbc4ef9c5c37c49d36fe`, from successful run `2c0c4cb8-45da-4aa8-bfcd-c866c8a78471`. Both drafts still report `PREPARE_FOR_SUBMISSION` and Build 60 / `VALID`. This is a metadata record, not a public release or signed-device acceptance.

| Platform | Version ID | Scope |
| --- | --- | --- |
| iOS / iPadOS | `02cd9cf1-769a-43a9-a48e-09991ac63a6b` | en-US, zh-Hans, zh-Hant: description and What’s New |
| Mac | `2b464434-d44b-43c3-bd8b-3b4104a42966` | en-US, zh-Hans, zh-Hant: description and What’s New |

## Copy and factual basis

The descriptions lead with native workflows: Mac global shortcuts and Services, Shortcuts text handoff, native Files/TXT handling, source/result layouts and one-tap document controls. The update notes summarize user-visible 2.1 changes following the shared [changelog/release-note guide](https://github.com/gewill/dev-standards/blob/main/changelog_release_notes_guide.md). `CHANGELOG.md` now records these candidate changes instead of the obsolete disabled-large-file statement.

The previous Mac descriptions still said Pro could not process files over 10 MiB. They now distinguish the 10 MiB editor limit from the Mac-only Pro direct-to-file path for one UTF-8 TXT larger than 10 MiB and up to 1 GiB. iPhone/iPad retain the 10 MiB limit, including with Pro. No batch, unlimited-capacity, conversion-speed or full Taiwan-vocabulary reversal claim is added.

Shortcuts is free, does not consume the homepage quota or change an open draft, accepts at most 10 MiB of UTF-8 text, and requires iOS/iPadOS 16 or macOS 13. The app remains iOS/iPadOS 15 / macOS 12 compatible. Mac cross-app replacement still states its Accessibility permission and source-app requirements. Lifetime Pro is a one-time purchase; no price is quoted or changed.

The Build 60 source contains the implementation commits for enabled large-file conversion (`671699f`), Shortcuts (`fbd48cd`), blank workspaces (`8d08715`), confirmed clearing (`63d9eaa`), guarded shortcut replacement (`2c6e631`) and the new icon/launch mark (`bd4c2de`). These ancestor checks establish candidate inclusion, not a new device/purchase regression run. The existing launch transition is described as updated visuals, not advertised as a newly introduced feature.

## Files and validation

- `snapshot/`: canonical metadata pulled immediately before editing, including untouched app-info fields.
- `proposed/`: exactly two version fields per locale; omitted fields are unmanaged.
- `readback/`: fresh canonical remote metadata after the write.
- [verification.json](verification.json): exact content SHA-256, character counts and checks that all other version/app-info fields stayed unchanged.
- `validation-ios.json` / `validation-mac.json`: three files each, zero errors and warnings.

Each dry-run plan had six field updates, zero additions/deletions and no app-info writes. The validated plans were applied sequentially, then all 12 description/What’s New values were compared exactly against fresh remote reads. Keywords, URLs, names, subtitles and privacy-policy fields remained unchanged. The operation did not change builds, pricing, privacy labels or review state.

| Platform | Locale | Description characters | What’s New characters | Exact candidate |
| --- | --- | ---: | ---: | --- |
| ios | en-US | 1880 | 573 | [Copy](proposed/ios/version/2.1/en-US.json) |
| ios | zh-Hans | 748 | 185 | [Copy](proposed/ios/version/2.1/zh-Hans.json) |
| ios | zh-Hant | 753 | 185 | [Copy](proposed/ios/version/2.1/zh-Hant.json) |
| mac | en-US | 2382 | 819 | [Copy](proposed/mac/version/2.1/en-US.json) |
| mac | zh-Hans | 845 | 288 | [Copy](proposed/mac/version/2.1/zh-Hans.json) |
| mac | zh-Hant | 854 | 289 | [Copy](proposed/mac/version/2.1/zh-Hant.json) |

The three-language previews were uploaded and read back separately in [PR #254’s staging record](https://github.com/gewill/OpenCCman/pull/254#issuecomment-5905778746). Metadata/media completion does not close purchase, signing or minimum-system gates. Public website release notes should be finalized from the same changelog when the 2.1 release is authorized; current downloadable 2.0 claims remain separate.

# 2.0 App Store metadata alignment (2026-09-24)

Tracks [#17](https://github.com/gewill/OpenCCman/issues/17). This is the
current **draft metadata** for App Store Connect, not a release or final-build
acceptance record. The source baseline is `develop` at
`c3c81b30db6b5d3b8bc4e2337f80af67ba976476`; app ID is `6474449401`.

| Platform | 2.0 version ID | State when read |
| --- | --- | --- |
| iOS / iPadOS | `17a9e553-7399-4e0c-97be-e1695f06b7d0` | `PREPARE_FOR_SUBMISSION` |
| macOS | `ca370499-5c15-4510-8a7e-36ef7ebff15d` | `PREPARE_FOR_SUBMISSION` |

The live App Store version remained 1.2 on both platforms. The 2.0 drafts had
no What's New text; descriptions primarily described the upstream OpenCC
engine, including Japanese conversion that the app does not expose. The Mac
description also promised conversion from “any application,” while actual
Services and shortcut behavior depends on the source app and Accessibility
permission. The Chinese Mac keywords included pinyin generation, which the app
does not provide. Support and marketing URLs still pointed to 2023 blog posts.

The `snapshot/` files are the API read immediately before this change. The
`proposed/` files are the exact values written to the two 2.0 drafts. They
adapt the previously reviewed [1.3 candidate](../metadata-2026-09-15/README.md)
to the confirmed 2.0 target, with the product URL and support URL moved to the
three-language official website. Both targets were HTTP 200 on 2026-09-24.
The draft distinguishes four presets from the engine's wider capabilities,
states the single UTF-8 TXT and 10 MiB limit (also for Pro), and avoids
promising a complete reverse conversion of Taiwan-specific vocabulary. Mac
cross-app wording states its permission and source-app boundaries.

## Validation and readback

- `asc metadata validate` scanned six files per platform: zero errors and
  warnings.
- Separate ASC plans for iOS and macOS each had three additions (What's New),
  twelve field updates (description, keywords and two URLs in three languages),
  and zero deletions. Plan hashes were
  `eca3f0db2d732eff19a213c0d1464741766a73be0954d91ba3da886ed69f08f5`
  and `8ec9ff4d082c56242484ffd14dd14c3bd7b4178775577460957cf8cb7449fee8`.
- The approved plans were applied to the **2.0 drafts only**. The API readback
  in [readback.json](readback.json) confirms all five candidate version fields
  across both platforms and all three languages, plus the existing three
  official-site privacy-policy URLs.

No app binary was submitted, attached or released. This operation did not
change prices, the privacy questionnaire, TestFlight What to Test, or app
source. The privacy questionnaire requires a separate ASC web session and was
not re-read on this date; its last published readback is in
[the 2026-09-19 privacy record](../privacy-review-2026-09-19/evidence.json).

Before closing #17, compare the final signed 2.0 binary and its aggregated
privacy report against the questionnaire, confirm the official privacy URL is
effective for the released version, and recheck these draft descriptions and
What's New against the exact build. The price-doubling plan and actual
purchase/restore acceptance have their own release gates; neither is proved
by a metadata readback. Publish the corresponding website 2.0 release notes
from the final changelog before release, following the shared
`dev-standards/changelog_release_notes_guide.md` copy hierarchy.

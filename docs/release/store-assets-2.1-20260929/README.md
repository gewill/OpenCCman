# OpenCCman 2.1 App Store media

This candidate follows the [App Store screenshot prompt guide](https://github.com/gewill/dev-standards/blob/main/app_store_screenshot_prompt_guide.md). Titles and subtitles are outside the unaltered app captures. The sample sentence is demonstration text converted by OpenCCman; it is not a customer document or a measured productivity claim. Localized copy lives in [raw/marketing-copy.json](raw/marketing-copy.json).

| Order | Screen or preview | What it shows |
| --- | --- | --- |
| iPhone 1–4 | Converted text, empty workspace, presets, clear confirmation | The iPhone assets prepared for the original 2.1 candidate remain unchanged. |
| iPad 1–4 | Side-by-side, stacked, empty workspace, clear confirmation | Two layouts and the 2.1 blank-start and clear controls, captured separately in English, Simplified Chinese and Traditional Chinese. |
| Mac 1–2 | Workspace, clear confirmation | Native Mac window from the 2.1 source, captured separately in the three app languages. |
| iPhone preview | Launch, convert, presets and clear | English 22.1 s, Simplified Chinese 22.7 s, Traditional Chinese 22.2 s; all use the 2.1 heavier launch mark. |
| iPad preview | Convert, switch layouts and clear | English 25 s, Simplified Chinese about 22 s, Traditional Chinese 25.5 s. |
| Mac preview | Convert, open settings and switch layout | English, Simplified Chinese and Traditional Chinese, about 24.5 s each. |

The conversion and layout footage shows actual app interaction; it does not claim that switching layouts consumes a conversion. The clear screenshots show the confirmation dialog, not a completed deletion. The new Mac Pro direct-to-file workflow is not pictured because its signed-purchase and file-handling acceptance remains open.

## Capture and provenance

The iPhone and iPad screenshots were captured from source commit `20d4ff7257e1e79483c7abb51296d10f117479dd`, the source of successful Xcode Cloud Build 59. A local unsigned Debug QA build with bundle ID `org.gewill.OpenCCman.WhatsNewUITests` was used for capture; it did not replace the installed TestFlight app. Xcode 27.0, an iPhone 18 Pro Max simulator on iOS 27.0 and an iPad Pro 13-inch (M5) simulator on iPadOS 26.5 were used in light appearance. Each language (`en`, `zh-Hans`, `zh-Hant`) was launched and captured separately. The archived XCUITest capture sources are [capture-tests.swift](capture-tests.swift) and [capture-ipad-addendum.swift](capture-ipad-addendum.swift); the new iPad video test and three locale screenshot tests passed.

Unlike the initial 2.1 candidate, the Mac screenshots and video now come from a locally built QA app at the same source commit `20d4ff7`, running on macOS 27 with a 1024×768 pt window. The Mac window was captured through `screencapture` after UI actions, then rendered into the App Store's 2560×1600 screenshot canvas. This validates the pictured UI, not signed Build 59 behavior on the macOS 12 deployment floor.

The iPhone preview opens on the system launch screen, so it was re-recorded when 2.1 took the layered app icon and its heavier launch mark ([#251](https://github.com/gewill/OpenCCman/issues/251), [#252](https://github.com/gewill/OpenCCman/pull/252)). The new recording comes from source commit `bd4c2de95ef85c8d27dcb0a7555bf81696a18eb0`, whose app sources differ from `20d4ff7` only in the icon and launch mark. It used the same QA bundle and `testCaptureHans` pacing on a newly created iPhone 18 Pro Max simulator (iOS 27.0, light, status time 9:41) that had never run an older build; a reused simulator keeps showing the old launch snapshot. The final is trimmed from 7.6 s for 22.7 s and is otherwise encoded as before. Compared with the earlier preview only the launch mark changes; the app screens and timing match. `manifest.json` lists these two files under `sourceOverrides`.

`raw/` retains original captures, including untrimmed recordings. `marketing/` contains 30 titled screenshots and nine final App Previews (three platforms × three languages). The final previews are trimmed from recordings of the real app, encoded as H.264 at 30 fps with silent stereo AAC, and contain no fabricated UI or touch overlays. The iPad video is 1200×1600 and the Mac video is 1920×1080. Upload only the final MP4s under `marketing/preview/`.

The image renderer is `scripts/store-assets/render-marketing-screenshots.swift`. After rendering, run `python3 flatten-marketing.py` to remove alpha from the new iPad/Mac screenshots; the previously staged iPhone files stay byte-for-byte unchanged. Run `python3 refresh-manifest.py` to record file hashes and media properties, then `python3 verify.py`. [manifest.json](manifest.json) records dimensions, bytes, SHA-256, source commit, renderer hash and video streams. The checks follow Apple's [screenshot](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [App Preview](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) specifications.

## English and Traditional Chinese preview addendum (2026-09-30)

The six added previews contain the app’s actual English (`en`, store locale `en-US`) or Traditional Chinese (`zh-Hant`) interface. The Chinese demonstration sentence stays Chinese because it demonstrates script conversion. No translated labels were composited onto the recordings, and no narration or music was added.

| Platform | English | Traditional Chinese | Source / capture environment |
| --- | --- | --- | --- |
| iPhone | [Convert and clear](marketing/preview/en-US/01-convert-and-clear.mp4) | [Convert and clear](marketing/preview/zh-Hant/01-convert-and-clear.mp4) | `bd4c2de95ef85c8d27dcb0a7555bf81696a18eb0`; iPhone 18 Pro Max, iOS 27.0 |
| iPad | [Workspace](marketing/preview/en-US/02-ipad-workspace.mp4) | [Workspace](marketing/preview/zh-Hant/02-ipad-workspace.mp4) | `20d4ff7257e1e79483c7abb51296d10f117479dd`; iPad Pro 13-inch (M5), iPadOS 26.5 |
| Mac | [Workspace](marketing/preview/en-US/03-mac-workspace.mp4) | [Workspace](marketing/preview/zh-Hant/03-mac-workspace.mp4) | `20d4ff7257e1e79483c7abb51296d10f117479dd`; macOS 27, 1024×768 pt native window |

All used the dedicated QA bundle and light appearance described above; they did not change the installed production/TestFlight app. iPhone and iPad recordings used `simctl io recordVideo` and the archived [localized capture test](capture-localized-previews.swift). The four selected XCUITests passed with zero failures: `testCaptureEnglish` (24.998 s), `testCaptureHant` (24.859 s), `testIpadPreviewEnglish` (29.143 s) and `testIpadPreviewHant` (29.058 s). They assert successful conversion, open the real confirmation dialog and cancel it. Test execution durations are automation timing, not conversion benchmarks. The final videos show the clear confirmation without committing a deletion.

Mac actions used native accessibility UI automation, with `screencapture -v -l` for the selected QA window. Each language was observed converting the example, opening localized settings and selecting stacked layout without losing source or result. The principal recording and a supplementary layout recording are retained for each locale; the final cuts between settings and the workspace, then shows the actual layout transition. These recordings are not signed-package or minimum-system acceptance.

[localized-preview-edits.json](localized-preview-edits.json) records exact input ranges and crop coordinates. Reproduce the six finals with `python3 encode-localized-previews.py` (requires FFmpeg), then refresh the manifest and verify it. The Mac crop removes the capture’s outer shadow margin, preserves the whole 1024×768 pt window, and fits it into a 1920×1080 canvas. All clips retain normal playback speed; idle automation waits are cut rather than accelerated. Final start/end frames and sequence contact sheets were inspected for the right locale, intact controls, conversion result, settings/confirmation and layout transitions, with no Home Screen or unrelated app in the final footage.

The three existing Simplified Chinese final videos and all 30 marketing screenshots are unchanged. The six new final MP4s and eight raw recordings are included in the checksum manifest; the two new iPhone recording/final pairs explicitly override the original source SHA.

## App Store Connect staging

The last verified staging snapshot (2026-09-29) showed the iOS and Mac 2.1 versions as drafts in `PREPARE_FOR_SUBMISSION`, with Build 59 attached. Version IDs are `02cd9cf1-769a-43a9-a48e-09991ac63a6b` (iOS) and `2b464434-d44b-43c3-bd8b-3b4104a42966` (Mac). Per language, the iOS draft has four iPhone and four iPad screenshots; the Mac draft has two Mac screenshots. The earlier inherited iPad/Mac screenshots were removed after the replacements reached `COMPLETE`. The existing iPhone screenshot and preview sets remain unchanged. At that snapshot, Simplified Chinese had an iPhone, iPad and Mac preview; English and Traditional Chinese used screenshots without previews. This addendum prepares their missing previews locally; it does not upload them or submit for review. Before submission, upload all six new English/Traditional Chinese final MP4s and verify processing and poster frames by locale and platform.

As of 2026-09-29 the Simplified Chinese iPhone preview in App Store Connect is still the earlier recording with the old launch mark, and Build 59 still carries the old icon. Before submission, attach a build that contains #252 to both drafts and replace that preview with `marketing/preview/zh-Hans/01-convert-and-clear.mp4`.

App Store Connect processing and readback should be checked again before submission. Asset upload is not App Review submission, signed-device visual parity, human-language copy review or minimum-system acceptance.

# OpenCCman 2.1 App Store media

This candidate follows the [App Store screenshot prompt guide](https://github.com/gewill/dev-standards/blob/main/app_store_screenshot_prompt_guide.md). Titles and subtitles are outside the unaltered app captures. The sample sentence is demonstration text converted by OpenCCman; it is not a customer document or a measured productivity claim. Localized copy lives in [raw/marketing-copy.json](raw/marketing-copy.json).

| Order | Screen or preview | What it shows |
| --- | --- | --- |
| iPhone 1–4 | Converted text, empty workspace, presets, clear confirmation | The iPhone assets prepared for the original 2.1 candidate remain unchanged. |
| iPad 1–4 | Side-by-side, stacked, empty workspace, clear confirmation | Two layouts and the 2.1 blank-start and clear controls, captured separately in English, Simplified Chinese and Traditional Chinese. |
| Mac 1–2 | Workspace, clear confirmation | Native Mac window from the 2.1 source, captured separately in the three app languages. |
| iPhone preview | Convert, presets and clear | Simplified Chinese, 22.7 seconds. |
| iPad preview | Convert, switch layouts and clear | Simplified Chinese, about 22 seconds. |
| Mac preview | Convert, open settings and switch layout | Simplified Chinese, about 24.5 seconds. |

The conversion and layout footage shows actual app interaction; it does not claim that switching layouts consumes a conversion. The clear screenshots show the confirmation dialog, not a completed deletion. The new Mac Pro direct-to-file workflow is not pictured because its signed-purchase and file-handling acceptance remains open.

## Capture and provenance

The iPhone and iPad screenshots were captured from source commit `20d4ff7257e1e79483c7abb51296d10f117479dd`, the source of successful Xcode Cloud Build 59. A local unsigned Debug QA build with bundle ID `org.gewill.OpenCCman.WhatsNewUITests` was used for capture; it did not replace the installed TestFlight app. Xcode 27.0, an iPhone 18 Pro Max simulator on iOS 27.0 and an iPad Pro 13-inch (M5) simulator on iPadOS 26.5 were used in light appearance. Each language (`en`, `zh-Hans`, `zh-Hant`) was launched and captured separately. The archived XCUITest capture sources are [capture-tests.swift](capture-tests.swift) and [capture-ipad-addendum.swift](capture-ipad-addendum.swift); the new iPad video test and three locale screenshot tests passed.

Unlike the initial 2.1 candidate, the Mac screenshots and video now come from a locally built QA app at the same source commit `20d4ff7`, running on macOS 27 with a 1024×768 pt window. The Mac window was captured through `screencapture` after UI actions, then rendered into the App Store's 2560×1600 screenshot canvas. This validates the pictured UI, not signed Build 59 behavior on the macOS 12 deployment floor.

`raw/` retains original captures, including untrimmed recordings. `marketing/` contains 30 titled screenshots and three final App Previews. The final previews are trimmed from recordings of the real app, encoded as H.264 at 30 fps with silent stereo AAC, and contain no fabricated UI or touch overlays. The iPad video is 1200×1600 and the Mac video is 1920×1080. Upload only the final MP4s under `marketing/preview/`.

The image renderer is `scripts/store-assets/render-marketing-screenshots.swift`. After rendering, run `python3 flatten-marketing.py` to remove alpha from the new iPad/Mac screenshots; the previously staged iPhone files stay byte-for-byte unchanged. Run `python3 refresh-manifest.py` to record file hashes and media properties, then `python3 verify.py`. [manifest.json](manifest.json) records dimensions, bytes, SHA-256, source commit, renderer hash and video streams. The checks follow Apple's [screenshot](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [App Preview](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) specifications.

## App Store Connect staging

The iOS and Mac 2.1 versions are drafts in `PREPARE_FOR_SUBMISSION`, with Build 59 attached. Version IDs are `02cd9cf1-769a-43a9-a48e-09991ac63a6b` (iOS) and `2b464434-d44b-43c3-bd8b-3b4104a42966` (Mac). Per language, the iOS draft has four iPhone and four iPad screenshots; the Mac draft has two Mac screenshots. The earlier inherited iPad/Mac screenshots were removed after the replacements reached `COMPLETE`. The existing iPhone screenshot and preview sets remain unchanged. Simplified Chinese has an iPhone, iPad and Mac preview; English and Traditional Chinese use screenshots without previews.

App Store Connect processing and readback should be checked again before submission. Asset upload is not App Review submission, signed-device visual parity, human-language copy review or minimum-system acceptance.

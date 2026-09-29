# OpenCCman 2.1 App Store media candidate

This candidate follows the [App Store screenshot prompt guide](https://github.com/gewill/dev-standards/blob/main/app_store_screenshot_prompt_guide.md). Marketing titles and subtitles are outside unaltered application captures. The sample sentence is demonstration text, converted by the app with OpenCC Traditional; it is not a customer document or a measured productivity result.

The storyboard starts with the purpose and visible result, then shows the new blank start, conversion choices and the clear confirmation. Each image has one claim; the localized copy is in [`raw/marketing-copy.json`](raw/marketing-copy.json).

| Position | User action and evidence | Boundary |
| --- | --- | --- |
| iPhone 1: converted | Enter or use a sample, convert, compare source and result. | Free homepage conversions remain limited to 12 per day. |
| iPhone 2: empty | Start a new workspace and optionally fill the sample. | This is the 2.1 default; it does not promise text recovery. |
| iPhone 3: presets | Open conversion settings and inspect four presets and advanced controls. | A preset is a configuration choice, not a claim of complete reverse Taiwan vocabulary conversion. |
| iPhone 4: clear | Open the confirmation dialog for clearing the current window. | The screenshot shows the confirmation, not a completed deletion. |
| iPad 1–2: layouts | Convert the same sample, then switch from side by side to stacked. | Layout changes do not imply a new conversion or quota use. |
| Mac 1: workspace | Compare and export text in the native Mac workspace. | The unchanged workspace capture is reused from the 2.0 source; it does not show the new Pro direct-to-file flow. |

## Capture and provenance

The iPhone and iPad images came from the app source at `20d4ff7257e1e79483c7abb51296d10f117479dd`, the exact source of successful Xcode Cloud Build 59. A local unsigned Debug QA build (`org.gewill.OpenCCman.WhatsNewUITests`, internal build 30) was used only for capture, leaving the installed TestFlight app untouched. Xcode 27.0, iPhone 18 Pro Max simulator/iOS 27.0 and iPad Pro 13-inch (M5) simulator/iPadOS 26.5 were used in light appearance with status time 9:41. Each app language (`en`, `zh-Hans`, `zh-Hant`) was launched and captured separately. [`capture-tests.swift`](capture-tests.swift) records the XCUITest sequence used in a temporary copy of `Tests/UI/WhatsNewPresentation/`; all three iPhone locale tests and all three iPad layout tests passed. The capture test source is archival and is not added to the app test target.

The three Mac raw images are reused from the 2.0 media at source `2f782714103d68b4972bee93e47bda8cafee1959` (Xcode Cloud Build 56). Their pictured workspace, preset and text result remain accurate at the 2.1 candidate. They do **not** demonstrate the new Mac Pro file workflow or signed Build 59 runtime.

`raw/` keeps every original screenshot and the untrimmed simulator recording. `marketing/` contains the 21 titled PNGs and **one final App Preview**, `marketing/preview/zh-Hans/01-convert-and-clear.mp4`. The final video shows a real app launch, optional example, conversion, presets and clear confirmation. It was trimmed from the simulator recording, scaled to 886×1920, encoded as H.264 at 30 fps with silent stereo AAC, and lasts 22.7 seconds. It contains no simulated touches or fabricated UI. Its source recording includes simulator home-screen lead-in; upload only the final video.

The screenshots were rendered with `swift scripts/store-assets/render-marketing-screenshots.swift <this directory>/raw <this directory>/marketing`. The video was encoded with:

```sh
ffmpeg -ss 11.9 -i raw/preview/zh-Hans/01-convert-and-clear-recording.mp4 \
  -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -t 22.7 \
  -vf 'scale=886:1920:force_original_aspect_ratio=decrease,pad=886:1920:(ow-iw)/2:(oh-ih)/2,fps=30' \
  -c:v libx264 -crf 19 -preset medium -pix_fmt yuv420p \
  -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart -shortest \
  marketing/preview/zh-Hans/01-convert-and-clear.mp4
```

[`manifest.json`](manifest.json) records dimensions, bytes, SHA-256, app source per image, renderer hash and video streams. Run `python3 verify.py` here before using the assets. The iPhone screenshots are 1320×2868, iPad 2064×2752 and Mac 2560×1600. The video is 886×1920, 30 fps and 15–30 seconds, following [Apple screenshot](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [App Preview](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) specifications checked for this candidate.

## Review and upload boundary

Full-size and thumbnail visual reviews covered the Simplified Chinese iPhone sequence and iPad/Mac representative frames; automated dimension, hash and video checks cover every file. The other localized layouts were captured by passing UI tests but still need a final human-language review. No user-comprehension or conversion experiment was performed. The new Mac Pro file workflow is not pictured because signed-build purchase and file handling acceptance is still open. Build 59 success is a packaging result, not public release or signed-device visual acceptance.

## App Store Connect staging (2026-09-29)

The iOS and Mac 2.1 versions are **drafts** in `PREPARE_FOR_SUBMISSION`, with Build 59 attached. Their version IDs are `02cd9cf1-769a-43a9-a48e-09991ac63a6b` (iOS) and `2b464434-d44b-43c3-bd8b-3b4104a42966` (Mac). All 21 titled PNGs were uploaded to their matching language and device sets: four iPhone, two iPad and one Mac per locale. An App Store Connect readback found every screenshot in `COMPLETE`, with its MD5 matching the corresponding local file. Inherited 2.0 screenshots were removed from the 2.1 drafts; a before/after ID and checksum comparison found the live 2.0 screenshot sets unchanged.

The Simplified Chinese App Preview was uploaded to the iOS 2.1 draft and reads back as `COMPLETE`, with matching MD5. The old inherited iPhone previews were removed from the 2.1 drafts; English and Traditional Chinese have screenshots but no 2.1 preview video. The API initially returned an empty preview-image size even after marking the new video `COMPLETE`, so its processed thumbnail and App Store presentation still need a visual check before submission.

This staging is not App Review submission. Human-language review, signed-device visual parity and remaining release acceptance are separate gates.

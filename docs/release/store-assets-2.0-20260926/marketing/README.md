# OpenCCman 2.0 marketing screenshots and preview

This is the replacement creative for the 2.0(56) App Store review. It uses the same application source as Xcode Cloud Build 56: `2f782714103d68b4972bee93e47bda8cafee1959`. The artwork adds a title, subtitle, gradient and frame **outside** each genuine application capture; it does not redraw application controls or fabricate a converted result. The captions are in [`marketing-copy.json`](../marketing-copy.json), and [`render-marketing-screenshots.swift`](../../../../scripts/store-assets/render-marketing-screenshots.swift) renders all 15 images from the [raw capture set](../README.md).

| Surface | Per locale | Size | Story |
| --- | ---: | --- | --- |
| iPhone 6.9-inch | 2 screenshots | 1320×2868 | Original and real converted result, then preset selection |
| iPad 13-inch | 2 screenshots | 2064×2752 | Side-by-side reading, then stacked layout |
| Mac desktop | 1 screenshot | 2560×1600 | TXT workspace with actual converted result |
| iPhone App Preview | 1 video | 886×1920 | Select Taiwan preset, convert, inspect changed result |

The three preview files use actual iPhone 18 Pro Max simulator screen recordings on iOS 27.0, one each in English, Simplified Chinese and Traditional Chinese. A locally built QA app from the Build 56 source was used; its internal build number is 30 and it is **not** the signed TestFlight artifact. The recording shows the real settings and conversion interaction. The H.264/AAC files are 30 fps and 18–21 seconds, within [Apple's App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications). Silent AAC audio is present; there is no narration or invented system UI. The sample sentence is demonstration text, not customer data.

The initial English Mac raw capture had a macOS window-sharing indicator. The final English artwork instead uses [`01-workspace-clean.png`](../mac/en-US/01-workspace-clean.png), a recapture from the same source code in a separate QA app with no sharing indicator. That recapture has the sidebar closed; the other locale Mac images show the sidebar. This distinction is visible and intentional.

Rebuild the screenshots with `swift scripts/store-assets/render-marketing-screenshots.swift docs/release/store-assets-2.0-20260926 docs/release/store-assets-2.0-20260926/marketing`. [`manifest.json`](manifest.json) records each local asset's SHA-256 and MD5, rendering source and ASC state. `asc screenshots validate` reported no issues for all nine screenshot sets. The videos were checked with `ffprobe` and sampled before upload. The local and App Store metadata copy were read back independently; matching source does not replace a signed-build device acceptance test.

On 2026-09-26, App Store Connect readback found all 15 replacement screenshots and all three iPhone previews `COMPLETE`; each remote source checksum matched the file in this directory. The iOS review submission is `dbf4cccf-83e4-4bb5-b833-8a600a2e62d0` and the Mac submission is `2ca043a7-0d5f-4c00-870e-5791294e2c05`. Both read back `WAITING_FOR_REVIEW` with Build 56 attached. Review submission does not mean approval or public release. The historical empty screenshot-slot warnings described in the [raw asset record](../README.md) remain in the CLI validator; the actual review submissions were accepted.

These screenshots make claims about the shown workspace and conversion. The Mac description separately explains global shortcuts and macOS Services because the single Mac screenshot does not demonstrate their interaction. Actual cross-App replacement still depends on Accessibility permission and source-app behavior, as described in the [release gates](../../metadata-2026-09-26/README.md).

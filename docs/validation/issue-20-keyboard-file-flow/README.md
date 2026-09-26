# #20 Mac keyboard file-flow runtime subset (2026-09-24)

This records one current-source keyboard and system-panel path. It is a **subset**, not complete keyboard, VoiceOver, minimum-OS, or distribution-build acceptance. The [Issue observation and actual media](https://github.com/gewill/OpenCCman/issues/20#issuecomment-5804412592) were uploaded with `gh` and read back.

## Identity

| Item | Actual value |
| --- | --- |
| Source | `develop` `4e0ee5d30cb6ea64b771ff781a08266e5ac84e05` |
| Host | macOS 27.0, Xcode 27.0 (`27A266a`), 1024 × 768 pt app window, English, light, default text size, non-Pro |
| Build | Complete macOS Debug `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` succeeded; build-log SHA-256 `3f38c5b101868af2da09b8273279abb45125f2f65340a01c9303eb2a0cc18f42` |
| Runtime copy | Unique bundle `org.gewill.OpenCCman.Issue20KeyboardQA20260924`; copied `NSServices` removed to avoid a duplicate Services provider; original sandbox entitlement retained and app signed ad hoc; `codesign --verify --deep --strict` passed |
| Executable SHA-256 | `02966de67e64382348eeb655c05347dc7a0638d2c6183e4256574c58fff7ab8c` |
| Input fixture | UTF-8 BOM + `鼠标\r\nA😀\n`; a second synthetic file contained `bad\xffutf8` |
| Output | No BOM; exact UTF-8 bytes `e9bca0e6a8990d0a41f09f98800a`, 14 bytes; SHA-256 `f0f58e2956f3bd2d5ef910dd1e6beaac69707ba377a64c1500d9bf6adbff57b1` |

The test used Codex computer use for UI input and AX state, the system file panels, and ScreenCaptureKit for an actual app-window recording. No production app window, purchase, authorization prompt, or user document was operated.

## Observed sequence

1. System Keyboard Navigation was off before the test. It was temporarily enabled in System Settings. Starting at the QA app's main window, seven Tab presses focused `Import TXT`; Space opened the system Open panel.
2. `⌘⇧G` opened the path sheet. The synthetic path was entered with CUA AX `setValue`, then Return selected the file and Return confirmed it. This **does not establish physical-keyboard path entry**. The BOM was removed from the displayed source; its `\r\n` and Emoji remained.
3. `⌘T` produced `鼠標\r\nA😀\n`. From Source, `⌃Tab` moved focus to Copy Result; Tab moved to Export TXT. Space opened the system save panel, which suggested `openccman-20-source-converted`; Return exported to a new file in `/tmp`. File bytes matched the expected 14-byte result exactly.
4. Reverse navigation from Source required `⌃⇧Tab` to return to Import. The second Open panel selected the invalid UTF-8 fixture via the same AX path setter. An explicit invalid-encoding alert appeared; Return dismissed it. The first file name, source, result and enabled Copy/Export controls remained unchanged. The isolated defaults showed exactly one daily conversion, so the failed import did not add a charge.
5. The QA app was quit. Keyboard Navigation was read back off in System Settings and `AppleKeyboardUIMode=0`; System Settings returned to its original AirDrop & Continuity page. VoiceOver stayed off and the input source was unchanged.

The [90-second video excerpt](https://github.com/user-attachments/assets/bf3c12fd-59b4-499c-b307-92295fc74ed1) captures the imported text, conversion, export controls and invalid-file alert at 1024 × 768 pixels, H.264, without audio, microphone or cursor. It was cut from the 122-second uninterrupted capture to exclude an initial system picker view that exposed unrelated user filenames; **it is an excerpt**, not claimed as continuous full-flow video. [Error screenshot](https://github.com/user-attachments/assets/50a189c1-20f3-4270-adc5-f89c216f4c60) and [retained result screenshot](https://github.com/user-attachments/assets/ea882b6d-1fec-4f26-9382-822070b1e3fb) show two states of the same source, not a code change before/after comparison.

## Remaining acceptance

This does not validate genuine hardware-keyboard typing into the system path sheet, complete keyboard cancel and long-document navigation, spoken VoiceOver order and activation, Chinese IME composition, iPhone/iPad accessibility, macOS 12 runtime, or the final Xcode Cloud signed artifact. Keep #20 open; minimum-system and distribution evidence remain in #16 and #15.

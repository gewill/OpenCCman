# Issue #20: custom preset state in the shared settings sheet

Date: 2026-09-24. Scope: the non-preset advanced combination in the shared iPhone/iPad conversion settings sheet. This is a partial accessibility and UI check, not full closure of #20.

## Problem and change

Starting from `Traditional · OpenCC`, selecting `Taiwan Standard` while `Region Idiom` remains `Not convert` creates a valid custom configuration. Before this change, the four preset buttons were all unselected, but the sheet showed no current preset name. VoiceOver moved directly from “Conversion Preset” to “Simplified Chinese”, without announcing “Custom”.

The preset list now displays the existing localized `preset_custom` string only while `selectedPreset == nil`. Selecting any matching preset removes it. The Mac inspector menu already showed `Custom` and is unchanged. No conversion configuration, persistence key, quota, or engine behavior changed.

## Reproduction and evidence

- Baseline source: product code built from `c2d8106a394720fd3c1c5a845aa162974f5d1ccb`. `git diff c2d8106..fe1fc14 -- OpenCCman OpenCCman.xcodeproj` was empty at test time; the target base was `origin/develop` `fe1fc14c67ef9d2df0df37d608cc1ffa3bd3c466`. Baseline executable SHA-256: `9e8ae9ec6165b3f558b345aeceddf02ae5b4676071bb9bed63d629503e171ce5`.
- Candidate: the conditional status addition on `codex/20-custom-preset-status`, built by Xcode 27.0 (27A266a) in Debug for iOS 27.0. Candidate executable SHA-256: `26868ea019284ffd315309907ff382aebcdec003d6e0682dd49db63c1a1e6c5f`.
- iPad Air 11-inch (M4), iPadOS 27.0 simulator, English, light appearance, default text size: a temporary XCTest UI harness used `XCUIDevice.shared.voiceOverService.currentSpeech()` and `moveForward()` to record actual utterances. Baseline: `Custom` absent from the view and utterances; candidate: `Custom` visible and spoken immediately after “Conversion Preset”. Selecting `Taiwan · Standard + Idioms` then removed the status.
- iPhone 17 Pro, iOS 27.0 simulator, same language/appearance/size: candidate `Custom` visible and spoken in the same order; selecting a preset removed it. The iPhone settings entry exposes a composite button label, so the test located it by label containing “Conversion settings”.
- Earlier settings sweep on the baseline iPad confirmed four preset buttons, selected target/variant/idiom traits, and `dimmed` variant/idiom buttons for Simplified Chinese. It did not establish every #20 interaction path.

Both simulator UI tests passed with zero failures. The candidate iOS simulator and macOS Debug builds, `scripts/check-project.sh`, `scripts/check-control-labels.sh`, `scripts/check-workspace.sh`, and `git diff --check` passed. Real device, minimum iOS 15/macOS 12, signed distribution build, Mac sheet runtime, other languages at runtime, keyboard/IME, cancellation and error paths remain outside this check and stay on #20/#16.

The PR contains same-condition baseline/candidate iPad screenshots, an additional iPhone screenshot and a 41.7-second iPad interaction recording. Screenshots show visual state; the XCTest utterance log is the evidence for spoken output. The recording has no audio and is not speech evidence.

VoiceOver was disabled before testing and read back as disabled after testing. The dedicated simulators are removed after the check; no formal app preferences or release branches were changed.

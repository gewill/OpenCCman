# Toggle rendering aligned with iPerfman — 2026-10-02

Follow-up to #274 / #275. Base `374035f2862d7d6392896b2dd24211a3480abae2`.

## Reference and cause

iPerfman SettingsScene.swift at `0360d9c74da45e9b815ddb3b4ff3c42b56bcec68` uses `neumorphicThemedSwitchStyle(tint: .accentColor)`. Both apps pin Neumorphic 2.4.1, revision `1f5745173dedddf0227fffc47cbdaa3100e5569a`.

The pinned SwitchToggleStyle.swift draws an outer shell, inset track, and a smaller raised thumb. While on, both inner-shadow colors use the accent; while off, the fill is mainColor. OpenCCman previously put gray/white inner shadows on the accent track, tinted the off track gray, and omitted the shell/thumb outer shadows.

The local adapter now follows those layers and proportions, while preserving the complete Mac 44×28 pt envelope, rectangle hit area, existing disabled state, accessibility labels/value/selected trait and Reduce Motion handling. Outer shadow radius/offset are kept within the existing 2 pt inset. The pinned upstream style's unconditional 44 pt minimum height is not imported. Dependencies are unchanged. This matches the reference structure, not its exact pixels: iPerfman uses Catalyst and a different theme palette.

## Evidence

- macOS 27.0.1, Xcode 27.0; isolated QA bundle org.gewill.OpenCCman.WhatsNewUITests.
- Before: product code from 01c07b1, identical to merged base 374035f; after: this PR's AppControlStyle.swift. Both screenshots show 2.1(30).
- Settings screenshots: English, 100% app text, 1024×768 pt window, 2048×1536 PNG, light and dark. Menu-bar toggle on and login toggle off for each comparison.
- Actual CUA interactions: menu-bar toggle off→on→off; accessibility values updated and the independent AXExtrasMenuBar probe returned 1 while on / 0 while off. Login startup was never activated.
- ScreenCaptureKit recording: isolated titled main window only, 2048×1536, 66.97 seconds, no audio/microphone. The PR includes the raw continuous recording; idle time is retained. Early recorder setup attempts that selected a status-item/hidden window are excluded.
- QA theme overrides were launch arguments, not system preferences. QA menu preference ended off; QA app quit. No VoiceOver/system appearance/login setting changed.

## Checks and boundary

- Mac universal Debug and iOS Simulator arm64 builds: BUILD SUCCEEDED.
- Mounted native control sizing and segment checks: PASS (switch remains 28 pt high).
- Project/Swift/localization parsing and released control labels: PASS.
- git diff --check: PASS; dependency lock unchanged.
- Independent source review: no blocking findings.

This is a Mac settings visual change; iOS uses its existing system toggles. No new minimum-system, spoken VoiceOver or real login-startup acceptance is claimed. Full lifecycle matrices remain tracked separately by #16 / #19 / #274. No release or TestFlight build was triggered.

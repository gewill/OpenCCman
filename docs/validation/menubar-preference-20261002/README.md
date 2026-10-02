# macOS menu-bar preference — 2026-10-02

Issue #274. Base develop `a6158a7ef89278381a72302772feb9ab179c1817`.

The existing Settings switch already created/removed NSStatusItem immediately. This change makes an absent preference default to true in both AppStorage and SwiftyUserDefaults, preserves explicit false/true without migration writes, hides the redundant built-in Toggle label, and identifies both the switch and status item for acceptance.

## Actual run

macOS 27.0.1 (26A434), Xcode 27.0, isolated unsigned Debug app `org.gewill.OpenCCman.WhatsNewUITests`. English, light theme, 100% app text, 1024×768 pt window (2048×1536 screenshot). CUA performed actions; a read-only AXExtrasMenuBar probe counted only this QA application's items. ScreenCaptureKit recorded only this QA app, without audio/microphone or other apps.

| Case | Observed |
| --- | --- |
| Before / after default | Existing control off → on; runtime after contains one status item with ID openccman-status-item |
| Switch off | Toggle off; AX status item count 0 |
| Switch on again | Toggle on; AX status item count 1, no duplicate |
| Save off, quit, reopen | Settings still off; status item count 0 |
| Save on, quit, reopen | Settings still on; status item count 1 |
| Login startup independence | Remained off throughout; no login item setting changed |
| Icon off, close window, reopen through Launch Services | App stayed running, item count 0; original window removed and a new main window appeared |

Actual before/after screenshots and 28.13-second on/off/on interaction recording are attached to the implementation PR. Baseline screenshot is the prior candidate c41b3cb (version label 2.2); after is this develop-based change (version label 2.1). Product marketing version is unchanged by this PR. All other capture conditions match. Video shows the Settings interaction; status-item presence is established separately by the AX probe, not inferred from the switch appearance.

## Validation

- Mac universal arm64/x86_64 Debug build: BUILD SUCCEEDED.
- iOS Simulator arm64 Debug build: BUILD SUCCEEDED.
- check-project.sh, check-app-language.py, check-control-labels.sh: PASS.
- git diff --check: PASS; Package.resolved unchanged.
- Existing creation guard, observer, shortcut service and Services registration remain unchanged.

## Boundaries

#19 retains the complete cross-app shortcuts/Services acceptance matrix: a production copy was running concurrently, so global hotkey ownership was not tested here. #16 retains real macOS 12 acceptance; this machine is macOS 27.0.1. No VoiceOver setting was changed; AX labels are observed but spoken reading order was not tested. No login item, production preference, release/build branch, purchase or App Store action was performed. The isolated QA preference is left off and the app quit after acceptance.

Issue #274 stays open until merged and its remaining runtime criteria are explicitly resolved or transferred with evidence.

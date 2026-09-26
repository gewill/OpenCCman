# What’s New presentation UI tests

This standalone XCUITest project checks the actual iOS file picker, conversion
state, alert, and What’s New sheet in a Simulator. It runs against an isolated
Debug bundle, `org.gewill.OpenCCman.WhatsNewUITests`; it does not install or
reset the store app. The project is generated from `project.yml`, with the
generated `.xcodeproj` committed so running tests does not require XcodeGen.

Boot a **dedicated** iOS Simulator and run:

```bash
bash scripts/check-whats-new-ui.sh <simulator-UDID>
```

The script builds the current app source with the resolved package versions,
reinstalls only the QA bundle, runs all UI cases, and prints the result directory
containing build logs and an `.xcresult`. Keep that directory when attaching
evidence to #34. The task-deferral tests start by marking the current card read
in the QA bundle, then make it unread while the file picker or conversion is
active. The launch/relaunch case instead marks the release unread before the
home scene appears, confirms the automatic sheet, relaunches without the unread
argument to verify that the read state persisted, and opens it manually from
Settings. Headless XCUITest leaves the Simulator scene phase `inactive`, so
this one case uses a Debug-only, exact-QA-bundle argument to make the home scene
eligible. It checks the on-screen presentation and persistence logic, not a
real foreground transition, signed first install, or TestFlight launch.
For import-success and invalid-UTF-8 cases, the script enables file sharing
only in the unsigned QA app, places a valid UTF-8 TXT and an invalid byte
sequence in its Documents directory, and selects them through the native Files
picker. A Debug-only, exact-QA-bundle delay keeps the real import task visible
long enough to assert that cards do not appear over it. The successful case
checks the replacement source and cleared result; the failure case checks the
error alert, preserved source and appearance only after dismissing the alert.
The two-second delay tests presentation ordering, not large-file throughput.
These two file-selection cases run on iPhone and iPad. The dedicated iPad Air
11-inch (M4) / iPadOS 26.5 Simulator completed both selections and the full
presentation suite from a fresh test build; see the [iPad follow-up](../../../docs/validation/issue-34-import-outcomes/ipad-followup-2026-09-25.md).
An earlier iPad run left the native Files picker open after taps. That result
was not reproduced in the follow-up, but its cause is not established; do not
claim this run proves every iPadOS Files configuration or physical device.
The UI verifies deferral, appearance after success/failure/cancellation, one-time
dismissal, and the absence of a late result after cancellation. It also checks
that the first conversion does not produce a StoreKit review prompt immediately
after What’s New, while a later conversion can still request a review.
Additional cases cover the native export panel while open, an exhausted real
quota leading through the Pro alert and Pro sheet, landscape dismissal, and a
downward system-sheet swipe. The QA launch hook resets the isolated daily quota
before each case so the Pro case cannot affect later conversions. On a portrait
iPhone, the exporter case returns to the Files browser root and cancels; on a
portrait iPad, it uses the Files browser's top-left close control. Both paths
verify that the picker disappears and the pending cards appear once. The
system extension's controls are absent from app-scoped accessibility queries,
so the test uses each device's observed top-left navigation position. This
coordinate step is limited to full-screen portrait iPhone/iPad and needs
revalidation if the system file browser layout changes.

For the maximum Dynamic Type matrix, set the dedicated Simulator's content size
with `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`,
run the landscape case, then restore its prior size. `simctl io <UDID> screenshot`
captures a stable landscape image; XCUITest's `app.screenshot()` can capture a
rotated transition frame even when the control is hittable and the test passes.

The iOS 27-only `testVoiceOverCardReadingOrder` enables VoiceOver on a dedicated
Simulator, navigates forward through the heading, version, four cards and Done,
then backwards to the heading. It checks spoken titles, focus order and that
`currentSpeech()` agrees with each reverse move. It also checks that the
accessibility tree contains the ending of all four card details. On the current
iOS 27 Simulator, each combined-card `utterance` returned exactly 64 characters,
so this does not prove that VoiceOver spoke each full paragraph.
The script records and restores the Simulator's initial VoiceOver state even
when XCTest fails; the test also restores that state during teardown. On the
current 2.0 source, the 14-case suite passed on iPhone 18 Pro / iOS 27.0 with
the iPad-only case skipped; see the [bidirectional follow-up](../../../docs/validation/issue-34-voiceover/bidirectional-2026-09-25.md).
The full-detail accessibility check on the same dedicated Simulator is recorded
in the [later follow-up](../../../docs/validation/issue-34-voiceover/full-detail-2026-09-25.md).

The two-second conversion delay and synthetic failure are available only in a
Debug build with the exact QA bundle ID and test launch arguments. They expose
the presentation state long enough to inspect; they do not measure OpenCC speed,
prove C++ work can be interrupted, or replace a real 10 MiB import. The tests
do not establish VoiceOver narration outside the tested iOS 27 forward path,
iOS 15, physical-device, or signed TestFlight behavior. The QA bundle has a
different bundle ID from the store
app, so its RevenueCat Pro sheet can show unavailable products; only sheet
presentation and dismissal are validated here, not purchase configuration.

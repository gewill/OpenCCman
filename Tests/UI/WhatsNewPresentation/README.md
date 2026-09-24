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
evidence to #34. Each test starts by marking the current card read in the QA
bundle, then makes it unread while the file picker or conversion is active.
The UI verifies deferral, appearance after success/failure/cancellation, one-time
dismissal, and the absence of a late result after cancellation. It also checks
that the first conversion does not produce a StoreKit review prompt immediately
after What’s New, while a later conversion can still request a review.

The two-second conversion delay and synthetic failure are available only in a
Debug build with the exact QA bundle ID and test launch arguments. They expose
the presentation state long enough to inspect; they do not measure OpenCC speed,
prove C++ work can be interrupted, or replace a real 10 MiB import. The tests
do not establish VoiceOver narration, iOS 15, physical-device, or signed
TestFlight behavior.

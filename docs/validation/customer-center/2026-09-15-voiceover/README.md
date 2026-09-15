# Mac VoiceOver bounded attempt — #71 / #20

**Reading order, speech and activation are still unverified.** This report records
an actual, bounded attempt and its cleanup; it does not certify VoiceOver support
or identify an application defect.

## Source and environment

- Candidate product source: `4da64c9b6f5dfc909eb15c29b1b67b71323e6954` from PR #96;
  [successful Mac CI build](https://github.com/gewill/OpenCCman/actions/runs/34975740015).
- Host: macOS 27.0, build 26A428. Binary: Xcode 26.3 / macOS SDK 26.2, Debug,
  local ad-hoc signing. Not a production sandbox or minimum-system test.
- Separate bundle/defaults: `org.gewill.OpenCCman.CustomerCenterVoiceOverAudit`.
  Removed NSServices, disabled both global shortcuts with the pinned package's
  false sentinel, and hid the menu bar icon before launch.
- English, light appearance, default font; initial window 900×450pt. The recording
  is 1920×1080 and shows framing changes; do not use it for fixed-size comparisons.
- See [metadata and cleanup](results.json), including the downloaded binary's hash.

## Observations

1. The isolated app opened Settings and the native Mac Customer Center. Its AX tree
   exposed Back, Customer Center, the combined basic-access/lifetime explanation,
   Restore, Refresh Status and Feedback. These labels alone are not VoiceOver QA.
2. Command-F5 did not turn VoiceOver on in this session. The existing System
   Settings switch did; both its displayed value and
   `NSWorkspace.shared.isVoiceOverEnabled` confirmed the transition.
3. VoiceOver Utility showed Control-Option or Caps Lock as the modifier, with
   caption panel and cursor already enabled. These preferences were read only.
   No AppleScript control or other security permission was enabled.
4. The real app showed a focus border around Back. A captured VoiceOver caption
   instructed how to activate a button. Direction and activation requests through
   UI automation did not establish a reliable transition to another element or
   back to Settings. Some input attempts were interrupted by a reported UI-state
   change; the same app state was re-read, rather than restarting the app.
5. After disabling VoiceOver, ordinary UI navigation returned to the workspace.
   The synthetic multiline Chinese/Emoji/combining-character draft was intact.
   A transient AX failure during Back was followed by a successful read of the
   same running instance; the navigation action was not replayed.

The official [Apple VoiceOver command reference](https://support.apple.com/guide/voiceover/general-commands-cpvokys01/10/mac/26)
was consulted. Key submission is not evidence that VoiceOver executed the command.
There was no native-control/physical-keyboard comparison, so the cause remains
undetermined. Do not label this as an application accessibility regression.

## Media and remaining acceptance

The issue comment linked in [media.md](media.md) contains a real video frame and
the complete 120.198-second H.264 recording, uploaded through `gh`. It captures only
the isolated app and VoiceOver's caption window, without audio or microphone.
The screenshot is a same-version observation, not a before/after product comparison.
Frames at 30 and 85 seconds were inspected before publication; full reading-order
or activation success is not inferred from those frames.

The next meaningful check is physical-keyboard navigation and activation against
this candidate, plus a native system control if it also fails. Only after that
comparison can an app fix or automation/environment fix be justified. #71 and #20
remain open. Chinese/dark-mode VoiceOver, iOS official-component VoiceOver,
accessibility sizes, actual purchase/restore and minimum systems remain separate
unchecked gates. No purchase, restore or feedback-send action occurred here.

## Cleanup and correction to the earlier visual report

VoiceOver was switched off and read back as false. VoiceOver Utility and the
isolated app exited. System Settings returned to its original App Management page;
no security switches were changed. The local app was unregistered and renamed
inactive. The original phone/Services/closed-window handoffs were not modified.

`defaults import` merges values: importing an empty backup did not remove new
test keys. Cleanup therefore removed only keys introduced into this isolated
domain, then exported and compared the complete property-list dictionaries.
The final dictionary equals the startup backup. Quota was not consumed and Pro
remained false during the test.

The same check of the previous #95 visual-test domain found 11 added keys remaining
after its earlier import. That app was not running; those added keys were removed
and the domain compared equal to its empty original backup. The earlier statement
that preferences were restored was too broad: it proved only a successful import.
The linked earlier report is corrected accordingly. No production app preferences
were involved, and no full preference exports or customer payloads are published.

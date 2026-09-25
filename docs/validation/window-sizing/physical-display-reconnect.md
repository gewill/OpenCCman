# Physical display disconnect/reconnect acceptance for #57

The 2026-09-25 hardware run, measurements, recording limitation, and
window-reopen fix are recorded in [physical-run-2026-09-25.md](physical-run-2026-09-25.md).

This is the remaining hardware-only window-sizing check. Geometry tests already
cover a disconnected screen rectangle, and prior UI runs moved the window
between two connected displays. Neither reproduces physically removing a
display while a window is on it. Do not mark #57 complete from a mirrored
display or a synthetic `NSScreen` frame.

## Preconditions

1. Record the application source SHA, macOS/Xcode versions, display models,
   resolutions, scaling, and arrangement. `system_profiler SPDisplaysDataType`
   must show a built-in and an external display as **separate logical screens**;
   turn off mirroring for this test only if that change is authorized, and
   restore the original setting afterward.
2. Use an isolated Debug bundle containing the current `develop` source and
   benign sample text. Record its bundle ID and signing state. Leave the store
   app, production preferences, and customer documents untouched.
3. Capture the initial main-window frame and the active screen's `visibleFrame`
   in points. The standard Debug `-window-sizing-report <absolute JSON path>`
   argument records the frame after a window constraint event; keep a copy of
   each report before the next event overwrites it.

## Run

1. Move the main window onto the external display. Use a 1024×768 pt window,
   then resize it once to a non-default size. Confirm source text, result, and
   Convert/Cancel remain reachable. Capture a screenshot and the window/screen
   frames.
2. Start a continuous screen recording. Physically disconnect the external
   display without closing the app. Wait for the system to settle. The window
   must become visible within the built-in display's `visibleFrame`, retain its
   text and current layout preference, and allow conversion and result access.
   Capture the new frames and screenshot.
3. Reconnect the external display. Confirm the window remains on a connected
   screen, without clipping or a jump outside both visible frames. Move it
   back to the external display, close and reopen the window, then quit and
   relaunch the app. Record the restored frame and confirm the core controls
   still work. Automatic movement *back* to the external screen is not required;
   the app only promises a usable frame on a connected screen.
4. Stop recording. Restore any changed display arrangement or mirroring setting
   and confirm the isolated test app has exited.

## Record and decision

Attach the same-run screenshots and interaction video to #57 with
`gh issue comment 57 --attach`.
Record expected and actual frames in points, the source SHA, build/bundle,
display configuration and macOS version. A pass requires all three physical
stages, visible controls, preserved text, and a valid restored frame. If the
external monitor is unavailable, report “not run”; rerunning the geometry
script or moving between displays is not a substitute.

The Mac large-text product path is tracked separately in #191. Its partial
300×412 pt runtime evidence is recorded in the [large-text follow-up](../mac-text-size/followup-2026-09-25.md),
but the complete matrix remains an unchecked #57 acceptance item.

Apple documents [`NSApplication.didChangeScreenParametersNotification`](https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification)
for attached-display configuration changes and notes that [`NSWindow.screen`](https://developer.apple.com/documentation/appkit/nswindow/screen)
can be `nil` when a window is offscreen. The app responds to those events by
fitting the window frame to a connected screen's visible area; the physical run
above is needed to verify that behavior end to end.

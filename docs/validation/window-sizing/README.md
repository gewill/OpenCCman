# Mac window sizing — issue #57

Implementation: [PR #74](https://github.com/gewill/OpenCCman/pull/74). Base `714f6bf`; first implementation checkpoint `48ad349`; CI app-build checkpoint `eb92b7e`. Runtime acceptance is in progress; this record is not a release approval.

## Contract

- Recommended initial size: 1024 × 768 pt, passed to `NSWindow.setContentSize` only when no valid native history exists. `contentRect(forFrameRect:)` defines this measurement; with SwiftUI full-size content windows the titlebar can occupy part of that rectangle, so it is not a promise of 768 pt of editor space.
- Minimum SwiftUI root size and `NSWindow.contentMinSize`: 300 × 360 pt. The window including toolbar can require more height. The 300 pt narrow-workspace requirement is retained.
- Existing valid native frame history wins over the recommendation. History is captured before SwiftUI creates windows, because AppKit may save a provisional frame during creation. Closing a window updates the in-process history for its existing autosave name.
- Additional new windows retain SwiftUI's cascading placement; only the first fresh window is centered. Window sizing does not replace the native window delegate, autosave name, scene identity, layout preference or business model.
- Screen constraints operate on the entire window frame and the screen's visible frame (excluding menu bar/Dock). Choose the display with greatest overlap; if the previous display is absent, use the current/main screen. Clamp oversized/offscreen frames. Fullscreen/live resize are excluded from screen correction.

## Verified so far

| Evidence | Result / scope |
| --- | --- |
| Geometry checks | Valid/corrupt history, negative-origin screens, disconnected monitor, oversized frame, idempotence: PASS |
| Native AppKit checks | Fresh and restored windows despite provisional autosave, minimum size, repeated attachment and one-time NSView.window callback: PASS |
| Workspace resolution checks | PASS; existing layout thresholds unchanged |
| Project/source syntax | PASS |
| macOS 27 runtime, earlier candidate | First launch 1024×768 frame, conversion and horizontal narrowing to 302 pt with vertical layout: observed |
| Minimum-height drag, final restoration and multiple screens | Still being verified; do not infer from the geometry unit checks |

## Toolchain transition during validation

The first local app builds passed with Xcode 26.6. The machine changed to macOS 27 / Xcode 27 during this work. The existing window introspection allowlist stopped at macOS 26, so root window binding is now a narrow NSViewRepresentable using NSView.window.

Xcode 27 rejects the unchanged macOS 11 deployment target. A local-only experiment with `MACOSX_DEPLOYMENT_TARGET=12.0` then failed inside the unchanged RevenueCat 5.64.0 (duplicate `init(stringRepresentation:)`). That experiment did not change repository deployment targets, package pins or caches. A compatible toolchain is pending; GitHub macOS CI now builds the normal application and retains an unsigned Debug validation artifact so runtime acceptance can continue independently. No build* branch or Xcode Cloud release is involved.

## Remaining gates

Final candidate runtime screenshots/video, min-height behavior, resize/restart/new-window restoration, inspector and both axes, Chinese/English and larger text, screen movement and removal must be recorded before closing #57. Minimum-OS real-device verification remains #16. Window creation after all windows close belongs to #19; native WindowGroup model release belongs to #18.

[Apple NSWindow frame restoration](https://developer.apple.com/documentation/appkit/nswindow/setframeusingname(_:)), [NSView.window](https://developer.apple.com/documentation/appkit/nsview/window).

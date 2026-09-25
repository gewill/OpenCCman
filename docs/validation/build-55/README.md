# OpenCCman 2.0(55) signed-build validation

Status: **candidate, not released**. Recorded on 2026-09-25 (Asia/Taipei).
Build 55 supersedes Build 54 after the app privacy manifest fix in
[PR #211](https://github.com/gewill/OpenCCman/pull/211). The earlier
[Build 54 record](../build-54/README.md) remains as evidence of the defect and
its signed-app runtime checks; the focused Build 55 checks below are recorded
separately and do not inherit the untested Build 54 cases.

| Item | Exact source or result |
| --- | --- |
| Application source | `dd6cc9c2f9decb6465313e2610eb8fda23101521` on `build/v2.0-privacy-20260925` |
| Xcode Cloud run | `e5d72562-1e11-44a3-9ca9-c95d6e66e0fc`; iOS/Mac Archive and internal TestFlight actions all `SUCCEEDED` |
| ASC iOS build | `c45c7010-9af1-4e03-99f6-bf6c07af5094`, 2.0(55), `VALID` |
| ASC Mac build | `5bce88ce-ab2f-461f-8ba4-3a18b45b9c66`, 2.0(55), `VALID` |
| Store drafts | Both 2.0 drafts now attach Build 55; `PREPARE_FOR_SUBMISSION`; manual release remains selected |
| Source lineage | [PR #211](https://github.com/gewill/OpenCCman/pull/211) passed required `App Regression` and merged to `develop` as `da4f3a4212a4dddfae5c723da4a5a5a3550840e3`; the release branch merges it. No application, project, package, or workflow files differ from Cloud source `dd6cc9c` at this record's creation. |

## Signed privacy reports

Xcode 27 Organizer generated the [iOS PDF](OpenCCman-2.0-55-iOS-PrivacyReport.pdf)
and [Mac PDF](OpenCCman-2.0-55-macOS-PrivacyReport.pdf) from the two downloaded
Cloud Archives. Both report RevenueCat's Purchase History for App Functionality,
not linked, not tracked. Neither has the Build 54 `Missing an expected key:
'NSPrivacyCollectedDataTypes'` error. Both app manifests explicitly contain an
empty `NSPrivacyCollectedDataTypes` array and the existing UserDefaults `CA92.1`
reason. An empty array does not assert app data collection. RevenueCat's separate
manifest is unchanged.

The app manifest SHA-256 is
`80e38881dbfb3b165f9ef35cfa43b28eac00d5b18058a127588c294193841c9f`
in both Archives, the exported iOS App Store IPA, and the exported Mac App Store
PKG. The corresponding RevenueCat manifest SHA-256 is
`76c876c73bf37d63b2944d0491e4d9a43d420de78b66512fcca27a484ae92e79`
in both exports. The Mac exported app identifies itself as 2.0(55). The Cloud
Archives have internal version 2.0(30); ASC's distributed versions are 2.0(55).

## Focused signed-app runtime checks

On macOS 27.0, `/Applications/OpenCCman.app` was installed from TestFlight
as 2.0(55). Code signing reports TestFlight Beta Distribution, Team
`RLK76T8Y89`, app sandbox, and the user-selected file read/write entitlement.
The app converted `鼠标里面的硅二极管坏了，导致光标分辨率降低。` to
`滑鼠裡面的矽二極體壞了，導致游標解析度降低。` and exported the visible result through
the system save panel.

The signed app imported a 44-byte UTF-8 TXT with BOM and
`汉字\r\n\r\nEmoji 😀 é\r\n前文\0末尾\r\n`, converted `汉字` to `漢字`, and
suggested `openccman-build55-input-converted.txt` in the system save panel.
The saved file is 41 bytes, decodes as UTF-8 without BOM, and preserves both
CRLF pairs, the blank line, Emoji, the decomposed accent, U+0000 and text
after it. Importing invalid UTF-8 showed an encoding error; after dismissal,
the earlier source filename, original text, and successful result remained.
Importing a 10 MiB + 1 byte TXT showed the capacity error and likewise
preserved all three. Canceling the system save panel retained both editor
contents and left the previously saved file's SHA-256 unchanged
(`48317fe6af692be8e07717941cfbbaeb0441ae880a74aa5e41317094c71c2e9d`).
An exact 10 MiB ASCII TXT imported and converted; its exported result is
10,485,760 bytes of ASCII `a`, matching the source byte for byte. The separate
QA window was closed afterward; the original app window remained open.
These checks used the native app UI and byte-level inspection of the exported
file. They do not cover drag-and-drop, TCC denial/revocation, or cross-app
shortcut behavior on Build 55.

For the system Services check, Launch Services still had 166 registered
OpenCCman QA app records (95 existing temporary app bundles and 71 missing
paths) alongside the installed TestFlight app and its system-managed
placeholder. Only the QA records were unregistered; no app bundle was deleted.
Afterward TextEdit's Services menu had one `Convert Chinese Text with
OpenCCman` entry. Invoking it on selected
`鼠标里面的硅二极管坏了，导致光标分辨率降低。` replaced the selection with
`滑鼠裡面的矽二極體壞了，導致游標解析度降低。`. The temporary TextEdit document was saved
under `/tmp`, leaving no new document in iCloud. This establishes the selected
text Services path in this cleaned local environment. In the signed app's
shortcut settings, global shortcuts were enabled and Accessibility permission
was granted, but the "Convert selected text" binding was empty; "Open selected
text" was bound to Option-Command-R. No conversion shortcut was invoked or
counted as passing. The no-selection, clipboard-race, target-switch, TCC, and
global-shortcut matrix remains open.

On a wired iPhone 17 Pro Max running iOS 27.0, `devicectl device info apps`
identified TestFlight 2.0(55). The existing purchase identity showed lifetime
Pro after restore and after an app restart. RevenueCatUI Customer Center also
reported a successful restore of that prior purchase. This does not establish
a first purchase or cancellation. After the maintainer created a new Sandbox
account and reinstalled the app, the Pro screen briefly displayed `Buy Now` at
`$2.99` and then automatically changed to lifetime Pro without any purchase or
cancellation action. The phone's production Media & Purchases account was still
signed in. Per
[Apple's TestFlight sandbox instructions](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox),
that setting can make IAP attribution use the production account. The precise
transaction behind the
automatic entitlement was not independently identified. A clean test requires
installation followed by production Media & Purchases sign-out, Sandbox sign-in,
and first launch in that state. The maintainer then followed that sequence:
before a transaction, `Buy Now` remained available; tapping it opened an
Apple Sandbox sheet labeled as a no-charge test. Canceling with the sheet's
close button returned to `Buy Now` without granting Pro. After app restart,
the unpaid state remained. The maintainer then confirmed the Sandbox purchase
on the device. The Pro page changed to lifetime Pro, retained it after another
app restart, and retained it after explicitly tapping Restore. Device screenshots
were captured with `devicectl`; the Apple purchase sheet contains the test
account identifier and is kept local, not uploaded to GitHub. This covers the
new-purchase/cancel/restore/restart path, but not refund or offline behavior.

One unresolved [price-display discrepancy](https://github.com/gewill/OpenCCman/issues/212)
was observed before the purchase:
OpenCCman's price card showed `$2.99`, while the Apple Sandbox confirmation
sheet showed `£2.99`. The app renders RevenueCat's
`package.localizedPriceString`, rather than a hard-coded currency. A restart
still showed `$2.99`. The source of the mismatch is not established; this
candidate must not be called fully price-verified based on the successful
Sandbox transaction. The ASC Sandbox list identifies the tester's storefront
as United Kingdom. Read-only `asc iap pricing summary` reports this product
at `2.99 GBP` in the United Kingdom and `2.99 USD` in the United States, with
no scheduled price changes. The Apple sheet matches the UK storefront while
the app card matches the US listing. The public price has not changed.

## Remaining launch gates

- [#14](https://github.com/gewill/OpenCCman/issues/14): iPhone TestFlight
  cancellation, first purchase, explicit restore, app restart, and entitlement
  checks passed on the clean Sandbox identity; older-purchase restore passed
  separately. [Price currency mismatch](https://github.com/gewill/OpenCCman/issues/212),
  refund/revocation, offline and failure
  paths remain. The maintainer performed transaction prompts.
- [#15](https://github.com/gewill/OpenCCman/issues/15): focused Mac
  shortcut/TCC and remaining Services/file workflow acceptance on the signed
  55 package. The UTF-8, BOM, CRLF, Unicode, NUL, export-name, invalid
  decoding, and 10 MiB / 10 MiB + 1 byte boundary checks above passed.
  TextEdit selected-text Services conversion passed after QA registrations
  were removed. Other scenarios remain; Build 54's global shortcut was not
  confirmed and is not counted as Build 55 evidence.
- [#16](https://github.com/gewill/OpenCCman/issues/16): no iOS 15 or macOS 12
  runtime is available. Keep as a pre-release gate unless explicit release-risk
  acceptance is given; static minimum-version settings alone are not runtime
  evidence.
- [#17](https://github.com/gewill/OpenCCman/issues/17): privacy report defect
  is fixed on the signed candidate. Published ASC answers were read back before
  this build. The three edited privacy-policy URLs take effect with the next
  version; check them again after public release.
- [#18](https://github.com/gewill/OpenCCman/issues/18),
  [#19](https://github.com/gewill/OpenCCman/issues/19), and
  [#20](https://github.com/gewill/OpenCCman/issues/20): the maintainer approved
  tracking these P1 remainders after launch; none is counted as passed.
- [#122](https://github.com/gewill/OpenCCman/issues/122): release PR, App Review,
  public release, tag, and synchronized US lifetime price change from $2.99 to
  $5.99 are not yet complete. Preserve existing Pro entitlements.

No App Review submission or public release is implied by Cloud/TestFlight
success, ASC `VALID`, or the clean privacy reports.

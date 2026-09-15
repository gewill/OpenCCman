# Customer Center preferred language — #71

This candidate connects the app's selected language to RevenueCat 5.64.0. It is
**not yet accepted for merge**: official iOS before/after captures and runtime
checks remain outstanding. The Mac compatibility-screen evidence in
[2026-09-15](../2026-09-15/README.md) does not exercise RevenueCatUI.

## Evidence and change

Baseline app source: `68350cb487f6006b42d0c329354cbfbe553b4b53` (the subsequent
`f4777140c85cbbd34f98f830f03446d4c29dd10b` merge adds documentation only).
Locked RevenueCat source: `155ea739f45f54189ca83ee9088b373c1415d98b`; no pins change.

The app previously supplied SwiftUI's locale but did not supply the SDK's
preferred UI locale. This is a source-level mismatch, not a claimed observation
of the affected iOS screen:

- [HTTPClient](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/Sources/Networking/HTTPClient/HTTPClient.swift)
  derives `X-Preferred-Locales` from SDK system information.
- [CustomerCenterView](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/RevenueCatUI/CustomerCenter/Views/CustomerCenterView.swift)
  owns a view model, loads information once and uses the returned configuration's
  localization. Updating only the app's environment does not reload that model.
- The [configuration builder](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/Sources/Purchasing/Configuration.swift)
  and [Purchases locale override](https://github.com/RevenueCat/purchases-ios-spm/blob/155ea739f45f54189ca83ee9088b373c1415d98b/Sources/Purchasing/Purchases/Purchases.swift)
  provide public initialization and runtime language APIs.
- Dashboard text remains separately configurable; see
  [RevenueCat's configuration documentation](https://www.revenuecat.com/docs/tools/customer-center/customer-center-configuration).

Initialization now passes the saved effective app language to the SDK. Choosing
a language updates the SDK before publishing the AppStorage selection. Following
the system uses the app's existing effective fallback, rather than giving the SDK
an independent language policy. Invalid saved selections also use this fallback.
The proxy is still assigned before SDK configuration.

Only the official CustomerCenterView has locale-dependent identity. A language
change can reset that component's navigation, form and loading state, including
when another iPad window changes the app language. HomeViewModel remains outside
this boundary. Existing `onDisappear` access refresh also runs when this component
is replaced. The SDK locale override may refetch offerings; this change is **not**
a promise of zero network activity. Runtime behavior while restoring, loading or
editing a support form must be checked before acceptance.

## Reproducible local checks

Run `python3 scripts/check-iap-locale.py`. It compiles the actual IAPManager,
LocaleConstants, preference keys and ProAccessUpdate against a recording SDK
boundary, with an isolated temporary defaults suite. The double does not model
HTTP, server translations, SDK caching or official UI behavior.

| Check | Result on 2026-09-15 |
| --- | --- |
| Unchanged baseline, bootstrap-only negative control | Expected failure: SDK initial locale `<none>`, app effective locale `en` |
| Current initialization | PASS: unset, system, English, Simplified, Traditional and invalid persisted selections |
| Runtime bridge | PASS: four choices reach the SDK; unconfigured preview path avoids the singleton |
| Initialization invariants | PASS: proxy precedes configure; repeat configure preserves the SDK session and delegate |
| Preferences | PASS: bridge preserves all preferences, including Pro and the quota fixture; no explicit access refresh from the bridge |
| Project/source checks | PASS: 58 Swift sources and three localization files |
| Existing Pro/real quota integration checks | PASS: restore/revocation, missing/failed/cancelled snapshots |
| Real SDK macOS/iOS builds | Pending CI; the double is not API compatibility evidence |

[Sanitized local output](checks.log) contains the baseline observation and complete
PASS observations. The expected baseline assertion's crash dump is excluded.
Deprecation warnings from unchanged Locale.current language/script access under
Xcode 27 are not changed in this focused fix; deployment remains iOS 14/macOS 11.

## Merge gate

- [ ] Real SDK macOS and iOS Simulator builds with existing exact pins.
- [ ] Same-condition official iOS before/after screenshots: OS language differs
  from selected app language; English, Simplified and Traditional; light/dark.
  Upload through `gh`, attach to the PR as a comparison table with source SHA,
  device/window size and font size. Existing Mac screenshots are not substitutes.
- [ ] Record language switching/close/reopen and iPad second-window switching;
  check original text, result, quota and selected language after restart.
- [ ] Check loading, restore and support-form behavior across locale changes;
  retain #14 for genuine Sandbox/TestFlight purchase/restore verification.
- [ ] Maximum accessibility size/VoiceOver checks; restore test settings afterward.

Current iOS UI automation cannot access DeviceHub. The prepared simulator handoff
remains pending; no device was restarted or user-owned app state changed for this
fix. Minimum-system execution stays a pre-release gate under #16 as agreed.
No RevenueCat dashboard, ASC metadata, products, prices or production build branch
is changed by this candidate.

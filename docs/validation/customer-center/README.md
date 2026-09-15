# Customer Center / Pro access validation — 2026-09-14

Update: [2026-09-15 Mac three-language/light-dark and independent-window validation](2026-09-15/README.md) adds six real screenshots and navigation video. The original results and remaining mobile/transaction gates below retain their historical scope.

Tracking: [#71](https://github.com/gewill/OpenCCman/issues/71), local StoreKit [#70](https://github.com/gewill/OpenCCman/issues/70), server-side purchase acceptance [#14](https://github.com/gewill/OpenCCman/issues/14).

## Implementation and compatibility

Settings opens official RevenueCatUI CustomerCenterView on iOS 15+. Native macOS and iOS 14 use an application-owned status / explicit restore / refresh / support view. The existing RevenueCat 5.64.0 dependency and all package pins are unchanged. The official component does not support native macOS; see [RevenueCat platform requirements](https://www.revenuecat.com/docs/tools/customer-center/customer-center-installation) and [iOS integration](https://www.revenuecat.com/docs/tools/customer-center/customer-center-integration-ios).

CustomerInfo updates from the existing Pro scene, SDK delegate and Customer Center restoration share ProAccessUpdate. Successful snapshots can grant or revoke Pro; missing, failed or cancelled responses preserve cached access. Opening a screen only queries status. Restoring requires an explicit button. Close pops route history so Settings Back returns home. The fallback invalidates obsolete view callbacks and resets loading when leaving.

## Source and evidence

- Base: `30eef4d`; screenshot baseline binary: `5d527bd`. `git diff 5d527bd 30eef4d -- OpenCCman OpenCCman.xcodeproj` is empty.
- Initial UI implementation: `416a065`; final app code and both successful Debug builds: `14b1a63`; subsequent `aaf9574` only validates scheme configuration.
- UI binaries use isolated bundle ID `org.gewill.OpenCCman.CustomerCenterValidation`, adhoc/local signing; not TestFlight, App Store or sandboxed release validation.
- Mac: macOS 26.6.2, 900×450pt. iPhone 15 Pro Max: iOS 18.6, 430×932pt. iPad Air 11: iOS 18.6, 820×1180pt. English, light, default font, no-purchase test identities.
- Mac screenshots/video show `416a065`; iPhone/iPad final evidence shows `14b1a63`. Mac final build verifies the loading reset; UI appearance is unchanged. Mac live navigation was checked before that reset, so do not treat it as a runtime test of the reset.
- [Before/after screenshots and interaction videos](https://github.com/gewill/OpenCCman/issues/71#issuecomment-5665836684), uploaded via gh. Screenshots are real app renders, not mockups. Anonymous IDs shown belong to isolated test installations.

## Verified

| Check | Result |
| --- | --- |
| Final macOS + iOS Simulator Debug builds | PASS; locked dependencies, no automatic resolution |
| ProAccessUpdate + actual daily quota manager | PASS: grant, revocation, offline/missing/error/cancelled response; restored Pro bypasses quota; revoked Pro returns to daily cap |
| Local StoreKit host | 7/7 PASS, 0 failures; product, purchase, cancellation, error, sync, repeat, refund |
| What’s New, quota, project/source syntax | PASS |
| English / Simplified / Traditional keys | PASS completeness; visual evidence only English/light/default size |
| Mac compatibility screen | Status, refresh, support and back; Chinese/emoji/combining-character/multiline draft preserved |
| iPhone official component | Loaded empty state; close → Settings → Back → home; original draft preserved |
| iPad official component | Loaded empty state; close → Settings → Back → home; original draft preserved |
| Fixture isolation | Standard OpenCCman scheme has no StoreKit config and archives Release; separate OpenCCman-StoreKit Debug scheme cannot archive |

## Findings fixed during validation

1. RevenueCat cancellation convenience is internal in this SDK. Use public ErrorCode domain/code matching; final builds pass.
2. Opening an explicit local StoreKit scheme suppresses Xcode’s auto-generated app scheme in a fresh checkout. Added a checked-in ordinary OpenCCman scheme and a regression check that archives contain no local StoreKit reference. No archive or Cloud build was triggered.
3. Navigating to Settings on Customer Center close appended history and could return to Customer Center from Settings. Replaced with goBack; retested on iPhone and iPad and recorded final video.
4. Reset fallback loading when leaving, allowing a fresh request if SwiftUI reuses the view. Stale callbacks cannot update obsolete view messages; completed transactions still update shared access.

## Remaining release checks

- #14: actual Sandbox/TestFlight lifetime purchase, explicit restore, restart/offline, revocation/refund and UI/quota propagation through RevenueCat/Apple. Local StoreKit and reducer tests are separate layers, not proof of this chain.
- #71: official purchased lifetime state and network/error/retry screens, dark appearance, Chinese visual layouts, accessibility sizes/VoiceOver and simultaneous windows are not fully exercised here. The SDK currently displays “No subscriptions found” for the empty lifetime-product account; verify Customer Center dashboard text/configuration before shipping. No subscription product or price was added.
- #16: iOS 14/macOS 11 runtime, signed production behavior. No suitable minimum-OS device is available; existing release gate remains open.
- ASC read-only catalog confirmed approved non-consumable `ios_openccman_pro_lifetime_3`. Local fixture display price 0.99 is synthetic and is not a verified current store price.

See [sanitized validation log](results.log) and [StoreKit setup/limitations](../storekit/README.md). No credentials, receipts or customer payloads are saved in this report.

Language synchronization candidate: [source evidence, checks and pending iOS merge gate](locale-sync/README.md).

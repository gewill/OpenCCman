# Issue #212: distinguish storefront, StoreKit and RevenueCat prices

The UK Sandbox observation is still unresolved: on TestFlight 2.0(55), the
OpenCCman card showed `$2.99` while Apple's confirmation sheet showed
`£2.99`. The two prices are from different moments and sources. This
diagnostic adds an **opt-in, read-only comparison** for a future 2.1 candidate;
it does not change the displayed price, invalidate a cache, select a product,
start a purchase or claim that the mismatch has been fixed.

Launch the candidate with `-qa-price-source-diagnostics`, then open its Pro
page. When RevenueCat returns its offering, the app writes one
`PRICE_SOURCE` line to the process console and unified log category
`OpenCCman/PriceSource`. The line contains only:

- the current StoreKit storefront's three-letter country and currency;
- the known lifetime product ID;
- a fresh native `Product.products(for:)` price and currency;
- the RevenueCat package's price string and currency, which are the values
  used by the card.

The field names distinguish the RevenueCat snapshot taken when the offering
arrived from the subsequent native product fetch. On iOS 15/16 and macOS
12/13, the storefront-currency API is unavailable; that field reports
`unavailable` rather than guessing from the device locale. The target
reproduction is iOS 27.

It does not log an Apple account, RevenueCat user ID, receipt, transaction,
entitlement or device identifier. The diagnostic performs an extra StoreKit
product lookup only when the launch argument is present. Normal startup and
the purchase path are unchanged.

## Controlled iPhone reproduction

Use an **unowned** UK Sandbox test identity on a physical iPhone with the
candidate TestFlight build. Install the build while the normal media account
is signed in, then sign out of **Media & Purchases** before the app's first
launch. Confirm the UK Sandbox account is selected in Developer settings,
without recording its email. Apple says a changed Sandbox region may require
signing out and back in to activate the storefront. This procedure concerns
the test identity, not the device's display language.

First check the local Xcode and `devicectl device process launch --help`.
After the app is closed, launch it with the diagnostic argument. For example,
substituting the actual device identifier:

```sh
xcrun devicectl device process launch --console --device DEVICE_ID \
  org.gewill.OpenCCman -qa-price-source-diagnostics
```

Open the Pro page once, capture only the `PRICE_SOURCE` line and a redacted
card screenshot, then compare the Apple purchase sheet without confirming
payment. The confirmation sheet may show account information; redact it
before sharing and let the maintainer operate any system purchase controls.
Repeat with an independent, unowned US Sandbox identity. Record the exact
build/source SHA, iOS version, storefront, product metadata, card display and
sheet currency for each run. Never publish the full process console, account
names or a receipt.

## Reading the comparison

| Storefront | Native product | RevenueCat package | Next investigation |
| --- | --- | --- | --- |
| GBR / GBP | GBP | USD | RevenueCat offering cache or acquisition timing |
| GBR / GBP | USD | USD | StoreKit/TestFlight product metadata or storefront transition |
| USA / USD | USD | USD | Sandbox/media account activation before comparing prices |
| GBR / GBP | GBP | GBP, but card USD | App UI snapshot/update ordering |

These are triage directions, not root-cause declarations. A product lookup
failure or `nil` storefront must be recorded as such and the test repeated
only after checking the account state. A matching card and sheet in one run
does not prove the earlier Build 55 mismatch was repaired. Do not replace a
StoreKit-provided price by a manually formatted currency.

Apple documents that `Product.displayPrice` is localized by the connected
storefront, that storefront data can change, and that an app should refresh
available products on a storefront update:
[Storefront](https://developer.apple.com/documentation/storekit/storefront),
[displayPrice](https://developer.apple.com/documentation/storekit/product/displayprice),
[storefront updates](https://developer.apple.com/documentation/storekit/storefront/updates).
The current app's `Package.localizedPriceString` delegates to RevenueCat's
`StoreProduct.localizedPriceString`; for its StoreKit 2 product this is the
underlying `Product.displayPrice` at the time RevenueCat obtained it.

This PR only prepares the comparison. Issue #212 remains open until the
signed-device comparison and US control run establish the cause, and any
necessary fix is separately verified.

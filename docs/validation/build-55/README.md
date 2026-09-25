# OpenCCman 2.0(55) signed-build validation

Status: **candidate, not released**. Recorded on 2026-09-25 (Asia/Taipei).
Build 55 supersedes Build 54 after the app privacy manifest fix in
[PR #211](https://github.com/gewill/OpenCCman/pull/211). The earlier
[Build 54 record](../build-54/README.md) remains as evidence of the defect and
its signed-app runtime checks; those checks have not yet been repeated on 55.

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

## Remaining launch gates

- [#14](https://github.com/gewill/OpenCCman/issues/14): iPhone TestFlight
  purchase, cancellation, restore, app restart, and entitlement checks on 55.
  The maintainer performs transaction prompts.
- [#15](https://github.com/gewill/OpenCCman/issues/15): focused Mac
  Services/shortcut/TCC and file workflow acceptance on the signed 55 package.
  Build 54 file tests passed, but duplicate QA Services registrations prevented
  firm handler attribution and its global shortcut was not confirmed.
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

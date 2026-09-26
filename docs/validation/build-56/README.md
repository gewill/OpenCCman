# OpenCCman 2.0(56) Xcode Cloud release candidate

Status: **Submitted to App Review, not publicly released**. Recorded 2026-09-26.

| Item | Verified state |
| --- | --- |
| Source | `2f782714103d68b4972bee93e47bda8cafee1959`, including the compact iPhone Convert action from #213 |
| Xcode Cloud run | `bc22950f-31fb-441f-af0f-6a1992eaac86`, `COMPLETE` / `SUCCEEDED` |
| iOS build | `45c49cca-4d86-4ad5-b448-dd1958abacef`, 2.0(56), `VALID`, attached to iOS 2.0 draft |
| Mac build | `274f2192-1439-4d02-aad3-b0b526c67bd3`, 2.0(56), `VALID`, attached to Mac 2.0 draft |
| App Store metadata | Three locales on each platform read back after upload; see [copy record](../../release/metadata-2026-09-26/README.md) |
| Screenshots | 15 real UI captures uploaded and MD5-matched to ASC, all `COMPLETE`; see [asset record](../../release/store-assets-2.0-20260926/README.md) |
| App Review | iOS submission `20e0c302-8472-47a4-ab86-c59fa04f134d` and Mac `cc43b50a-d2f5-4837-8fac-69a27009290b`, both API-read back as `WAITING_FOR_REVIEW` |

A local unsigned QA build from the same source ran conversion and visual checks on iPhone 18 Pro Max / iOS 27.0, iPad Pro 13-inch M5 / iPadOS 27.0, and Mac / macOS 27.0. Its bundle ID is separate from the distributed app and its internal build number is 30. It does **not** replace signed Build 56 purchase, file-panel, TCC, minimum-system, or cross-app runtime testing.

The focused signed Build 55 checks remain in [the prior record](../build-55/README.md). Do not automatically carry them over as Build 56 results. The unresolved release checks are [#14](https://github.com/gewill/OpenCCman/issues/14), [#15](https://github.com/gewill/OpenCCman/issues/15), [#16](https://github.com/gewill/OpenCCman/issues/16), and [#212](https://github.com/gewill/OpenCCman/issues/212). User-approved P1 follow-ups #18, #19, and #20 may continue after launch; they are not declared complete.

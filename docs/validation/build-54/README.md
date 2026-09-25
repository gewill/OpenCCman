# OpenCCman 2.0(54) release-candidate validation

Status: **candidate, not released**. Recorded on 2026-09-25 (Asia/Taipei).
This record distinguishes Xcode Cloud completion, App Store Connect processing,
and actual signed-app checks. It does not count unperformed tests as passing.

| Item | Exact source or result |
| --- | --- |
| Application source | `43cb43068e0afaa44af7c6656c1c4f15ae40541c` on `build/v2.0-20260925` |
| Xcode Cloud run | `fc5a0daa-2a5f-4f81-b2d0-97d1dedcc49d`, triggered by `GIT_REF_CHANGE` |
| Cloud actions | iOS Archive, macOS Archive, iOS TestFlight Internal Testing, macOS TestFlight Internal Testing: all `SUCCEEDED` |
| ASC iOS build | `dc274d67-37e8-4f31-992f-c63f51daaa08`, 2.0(54), `VALID`, iOS 15.0 minimum |
| ASC Mac build | `9693281f-6e46-4233-8f2e-747c809f32ed`, 2.0(54), `VALID`, macOS 12.0 minimum |
| Store drafts | Both 2.0 drafts attached to their respective Build 54, `PREPARE_FOR_SUBMISSION`, `MANUAL` release |
| Store validation | iOS and Mac: zero errors/blocking; nonblocking copyright and keyword warnings. IAP validation: zero errors/warnings/blocking. |
| Release PR | [#210](https://github.com/gewill/OpenCCman/pull/210), release head `30f102d43f5c85d8038aa62cb15cf116b4a88342` |
| Main CI protection | `App Regression` required, GitHub Actions app ID 15368; PR head check passed. Existing PR/admin/force-push/deletion settings retained. |

The release head merges `main` into the candidate. Compared with the Cloud
source, only README content changes; app sources, project, dependencies, and
workflow match. The branch remains a draft until acceptance and main integration.

## Signed Mac checks completed

Device: this Mac on macOS 27.0. App: `/Applications/OpenCCman.app` installed
through TestFlight, 2.0(54), signature authority `TestFlight Beta Distribution`,
Team `RLK76T8Y89`. Its entitlements include app sandbox and user-selected file
read/write access.

- Taiwan preset converted `汉字转换测试` to `漢字轉換測試`. Switching horizontal to
  vertical layout retained the source and result.
- Imported a BOM-prefixed UTF-8 TXT through the system open panel, converted it,
  then exported through the system save panel with default filename
  `openccman-v2-release-qa-converted.txt`. A byte comparison confirmed UTF-8
  without BOM, preserved CRLF, empty line, final LF, Emoji, and combining mark.
- An invalid UTF-8 file showed a decoding error. A `10 MiB + 1 byte` file showed
  the size error. Both failures retained the previous source, result, and source
  filename.
- A TextEdit selection changed from simplified to traditional through a
  visible OpenCCman Services menu item. This Mac lists several same-named
  services from old QA copies; the test does **not** establish that Build 54
  handled this invocation. The attempted global shortcut produced no
  confirmable change and is **not** counted as passing.

## Remaining release gates

| Gate | Current state | Owner or action |
| --- | --- | --- |
| [#14](https://github.com/gewill/OpenCCman/issues/14) Sandbox/TestFlight purchase, cancellation, restore, restart, and entitlement | Pending on Build 54 | Maintainer performs transaction prompts on iPhone; assistant records outcomes without account or receipt data. |
| [#15](https://github.com/gewill/OpenCCman/issues/15) full file/Services/shortcut/TCC matrix | Partial Mac result above | Complete focused remaining cases; do not infer provenance from duplicate Services names. |
| [#16](https://github.com/gewill/OpenCCman/issues/16) minimum-system runtime | No iOS 15/macOS 12 environment available | Maintainer supplies environment or explicitly accepts release risk; keep issue open unless actual evidence is obtained. |
| [#17](https://github.com/gewill/OpenCCman/issues/17) ASC privacy questionnaire | CLI cannot read published label | Log in to ASC web, compare final label with policy and SDK audit. |
| [#18–#20](https://github.com/gewill/OpenCCman/issues/18) performance, all-windows-closed entry points, accessibility/IME | Prior candidate evidence exists; Build 54 scope not fully repeated | Review actual evidence and decide which runtime checks must precede publication. |
| Main merge, tag, App Review, public release | Not started | Complete release acceptance, merge PR, submit both versions for review; they release manually after approval. |
| IAP price | US lifetime price still $2.99 | Change to agreed $5.99 at coordinated public 2.0 launch, preserving existing entitlements; do not increase while 1.2 remains public. |

The privacy-policy URLs for English, Simplified Chinese, and Traditional Chinese
returned HTTP 200, and both version metadata validation reports are nonblocking.
The published ASC privacy answer itself still requires a web readback. Public
App Store version remains 1.2 at the time of this record.

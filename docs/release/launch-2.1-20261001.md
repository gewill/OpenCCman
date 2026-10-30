# OpenCCman 2.1 release — 2026-10-01

The user authorized App Store publication, GitHub Tag/Release and website changelog updates. Both approved platforms use Xcode Cloud Build 60, source `da526f03f5f9d49df3edfbc4ef9c5c37c49d36fe`, successful Cloud run `2c0c4cb8-45da-4aa8-bfcd-c866c8a78471`.

| Platform | Version ID | Build ID | Release readback |
| --- | --- | --- | --- |
| iOS/iPadOS | `02cd9cf1-769a-43a9-a48e-09991ac63a6b` | `7c615224-68b8-4395-8c78-6f53898d4d5d` | READY_FOR_DISTRIBUTION |
| macOS | `2b464434-d44b-43c3-bd8b-3b4104a42966` | `b80885d5-02da-46e2-a13e-a7e6d8a48a41` | READY_FOR_DISTRIBUTION |

Before mutation, both states were PENDING_DEVELOPER_RELEASE and review submissions COMPLETE. Sequential `asc versions release --version-id … --confirm` calls succeeded; fresh review status reads returned the states above. The first US public Lookup read still returned 2.0, so release acceptance must not be mistaken for all storefronts having propagated.

The publication branch starts at develop `9daa9c77eea9d9fb6b0952b63772d4f68baf3bfd`. Its application, project and ci_scripts trees are identical to Build 60 source; later commits contain store media and documentation only. Under the user’s updated publication rule, the release PR targets main with Squash and merge; v2.1 must identify the resulting main squash commit, never the feature-branch HEAD. Release documentation is synchronized back to develop through a PR. No new build branch, Cloud run, dependency or price change is part of this publication.

## Product scope

- Mac Pro: one UTF-8 TXT over 10 MiB through 1 GiB, direct file conversion, progress/cancel, preserving the editor draft.
- iPhone/iPad and ordinary editor imports remain limited to 10 MiB. The gated v2.2 mobile 100 MiB work is excluded.
- Free Shortcuts text action: iOS/iPadOS 16+, macOS 13+, four presets and 10 MiB UTF-8 limit; no homepage quota charge.
- Empty new workspaces, optional example, confirmed Clear Source, refreshed icon/launch mark, safer cross-app replacement.
- App minimum remains iOS/iPadOS 15 and macOS 12. Existing issue-based acceptance limitations are not closed by publication.

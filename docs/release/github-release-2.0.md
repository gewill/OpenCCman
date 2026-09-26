# OpenCCman 2.0

OpenCCman 2.0 brings a more flexible reading and conversion workspace to
iPhone, iPad, and Mac.

- Choose from four common conversion presets or keep using the advanced
  character and regional vocabulary options.
- Import or drop one UTF-8 TXT file up to 10 MiB, then export the latest
  successful result. UTF-8 files with a BOM are accepted; exported files use
  UTF-8 without a BOM.
- Arrange the source and result side by side or vertically on Mac and iPad.
  On iPhone, the compact Convert action leaves more room to read the result.
- Cancel a conversion without letting an older result overwrite the current
  text. The embedded OpenCC core is updated to 1.4.2, so some dictionary
  results may differ from earlier versions.

The minimum systems are **iOS 15 and macOS 12**. The homepage allowance
remains 12 conversions per day; existing lifetime Pro access is retained.

This GitHub Release records the source for the App Store version. The signed
app is distributed through the [App Store](https://apps.apple.com/app/id6474449401),
not as a GitHub binary. Xcode Cloud Build **2.0 (56)** used application source
`2f782714103d68b4972bee93e47bda8cafee1959`; the annotated `v2.0` tag
marks the corresponding `main` integration commit, which also includes release
documentation and store screenshots. See the
[full changelog](https://github.com/gewill/OpenCCman/blob/v2.0/CHANGELOG.md)
and [Build 56 record](https://github.com/gewill/OpenCCman/blob/v2.0/docs/validation/build-56/README.md).

Extended acceptance and investigations deferred from 2.0 remain open in the
[v2.1 milestone](https://github.com/gewill/OpenCCman/milestone/1). This does
not mean those checks have passed.

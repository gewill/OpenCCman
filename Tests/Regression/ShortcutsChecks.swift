import Foundation

@available(macOS 13.0, *)
enum ShortcutsChecks {
  static func run() async throws {
    let homepageUsesBefore = coreQuotaCount
    precondition(homepageUsesBefore == FreeFeature.maxTestNumber,
                 "Exercise Shortcuts with the free homepage quota already exhausted")
    let fixtures = [
      "",
      "鼠标\r\n\r\n台湾",
      "👨‍👩‍👧‍👦 e\u{301} \0头发\0干杯\n",
    ]
    for preset in ShortcutConversionPreset.allCases {
      for text in fixtures {
        let intent = ConvertChineseTextIntent()
        intent.text = text
        intent.preset = preset
        let result = try await intent.perform()
        let expected = try await ChineseConversionService.shared.convert(
          text, options: preset.configuration.options)
        precondition(result.value == expected,
                     "Shortcuts must return the same complete text as the matching app preset")
      }
    }

    let oversized = ConvertChineseTextIntent()
    oversized.text = String(repeating: "a", count: TextFileService.maximumBytes + 1)
    oversized.preset = .traditional
    do {
      _ = try await oversized.perform()
      preconditionFailure("Shortcuts must reject text beyond the declared capacity")
    } catch ShortcutConversionError.textTooLarge {
      // The action returns a specific, localized error to Shortcuts.
    }
    precondition(coreQuotaCount == homepageUsesBefore,
                 "Shortcuts must remain free without charging the homepage quota")
    print("PASS: free Shortcuts action runs at the exhausted homepage quota, matches four presets, preserves Unicode/NUL/newlines and rejects over-limit text")
  }
}

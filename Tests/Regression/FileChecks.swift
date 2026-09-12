import Combine
import Foundation
import OpenCC

@MainActor func checkPresetsAndFiles() async throws {
  let presets: [(ConversionConfiguration.Preset, ChineseConverter.Options)] = [
    (.simplified, .simplify), (.traditional, .traditionalize),
    (.taiwan, [.traditionalize, .twStandard, .twIdiom]),
    (.hongKong, [.traditionalize, .hkStandard])
  ]
  for (preset, expected) in presets {
    precondition(preset.configuration.options == expected)
    precondition(preset.configuration.preset == preset)
  }
  precondition(ConversionConfiguration(target: .traditional, variant: .hongKong, region: .taiwan).preset == nil)
  precondition(ConversionConfiguration(target: .simplified, variant: .hongKong, region: .taiwan).preset == .simplified)

  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("文稿.txt")
  let fixtures = ["", "\r\n汉字\r\n\r\n", "👨‍👩‍👧‍👦🇹🇼e\u{301}\0鼠标\0\0\n"]
  for text in fixtures {
    for bom in [Data(), Data([0xEF, 0xBB, 0xBF])] {
      try (bom + Data(text.utf8)).write(to: file)
      let imported = try await TextFileService.read(file)
      precondition(imported.text == text, "UTF-8 import preserves exact text, removing only the BOM")
      precondition(imported.exportFilename == "文稿-converted.txt")
    }
  }
  precondition(TextFileService.ImportedText(text: "", sourceFilename: nil).exportFilename == "OpenCCman-converted.txt")
  let exactLimit = Data(repeating: 0x61, count: TextFileService.maximumBytes)
  let exactDecoded = try TextFileService.decode(exactLimit)
  precondition(exactDecoded.utf8.count == TextFileService.maximumBytes)

  let invalid = directory.appendingPathComponent("invalid.txt")
  try Data([0xFF, 0xFE, 0x80]).write(to: invalid)
  do {
    _ = try await TextFileService.read(invalid)
    preconditionFailure("Invalid UTF-8 must be rejected")
  } catch TextFileService.FileError.invalidUTF8 {}

  let large = directory.appendingPathComponent("large.txt")
  FileManager.default.createFile(atPath: large.path, contents: nil)
  let handle = try FileHandle(forWritingTo: large)
  try handle.truncate(atOffset: UInt64(TextFileService.maximumBytes + 1))
  try handle.close()
  do {
    _ = try await TextFileService.read(large)
    preconditionFailure("Oversized files must be rejected before unbounded allocation")
  } catch TextFileService.FileError.tooLarge {}
  do {
    _ = try await TextFileService.read(directory)
    preconditionFailure("Directories are not text files")
  } catch TextFileService.FileError.unsupportedFile {}

  let cancelledRead = Task { try await TextFileService.read(file) }
  cancelledRead.cancel()
  do {
    _ = try await cancelledRead.value
    preconditionFailure("Cancelled reads must not return a replacement draft")
  } catch is CancellationError {}

  UserDefaults.standard.set(true, forKey: UserDefaultsKeys.isPro.rawValue)
  defer { UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.isPro.rawValue) }
  let model = HomeViewModel()
  model.replaceSource("保留原稿", sourceFilename: "原稿.txt")
  model.resultText = "保留结果"
  let quotaBefore = coreQuotaCount
  model.importFile(invalid)
  await waitForImport(model)
  precondition(model.inputText == "保留原稿" && model.resultText == "保留结果")
  precondition(model.error != nil && !model.isImporting)
  model.importFile(file)
  model.cancelImport()
  precondition(model.inputText == "保留原稿" && model.resultText == "保留结果")
  model.importFile(file)
  await waitForImport(model)
  precondition(model.inputText == fixtures.last! && model.resultText.isEmpty)
  precondition(model.exportSnapshot == nil, "A new imported draft cannot export an unrelated prior result")
  precondition(model.error == nil && coreQuotaCount == quotaBefore)

  model.applyPreset(.taiwan)
  precondition(model.selectedPreset == .taiwan && model.options == presets[2].1)
  model.applyPreset(.simplified)
  precondition(model.variantOptions == .taiwan && model.regionOptions == .taiwan, "Inactive advanced preferences survive simplified output")
  precondition(coreQuotaCount == quotaBefore, "Imports and presets never consume quota")

  model.inputText = String(repeating: "汉字鼠标\n", count: 100_000)
  model.translate()
  model.importFile(file)
  await waitForImport(model)
  // Drain the serial conversion actor: an earlier result must not overwrite the import.
  _ = try await ChineseConversionService.shared.convert("", options: .simplify)
  await Task.yield()
  precondition(model.inputText == fixtures.last! && model.resultText.isEmpty && !model.isLoading)
  print("PASS: presets, UTF-8/BOM/Unicode/NUL files, size limit, invalid input, cancellation and import replacement")
}

@MainActor private func waitForImport(_ model: HomeViewModel) async {
  guard model.isImporting else { return }
  await withCheckedContinuation { continuation in
    var observation: AnyCancellable?
    observation = model.$isImporting.filter { !$0 }.first().sink { _ in
      continuation.resume()
      observation?.cancel()
      observation = nil
    }
  }
}

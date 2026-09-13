import Combine
import Foundation
import OpenCC
import SwiftUI
import SwiftyUserDefaults

#if os(macOS)
  extension Notification.Name {
    static let textConversionServiceDidReceiveText = Notification.Name("TextConversionServiceDidReceiveText")
    static let textServiceDidReceiveText = Notification.Name("TextServiceDidReceiveText")
    static let convertTextFromMenu = Notification.Name("ConvertTextFromMenu")
  }
#endif

@MainActor
class HomeViewModel: ObservableObject {
  @Published var inputText: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。" {
    didSet {
      guard inputText != oldValue else { return }
      cancelImport()
      cancelConversion()
      resultText = ""
      exportSnapshot = nil
    }
  }
  @Published var resultText: String = ""

  @Published var options: ChineseConverter.Options = []
  @Published var targetOptions: Language = appDefaults[\.targetOptions]
  @Published var variantOptions: Variant = appDefaults[\.variantOptions]
  @Published var regionOptions: Region = appDefaults[\.regionOptions]

  @AppStorage(UserDefaultsKeys.lastVersionPromptedForReview.rawValue) var lastVersionPromptedForReview: String = ""

  @Published var showingProAlert: Bool = false
  @Published var error: Error?
  @Published var isLoading: Bool = false
  @Published private(set) var isImporting = false
  @Published private(set) var sourceFilename: String?
  struct ExportSnapshot: Equatable, Sendable {
    let text: String
    let filename: String
  }
  @Published private(set) var exportSnapshot: ExportSnapshot?
  var resultFilename: String { exportSnapshot?.filename ?? "OpenCCman-converted.txt" }
  @Published var localProgress: Double = 0.0 // 0.0 ~ 1.0

  var localProgressPercent: Int {
    max(0, min(100, Int((localProgress * 100).rounded())))
  }

  private var cancellables = Set<AnyCancellable>()
  private var conversionTask: Task<Void, Never>?
  private var reservation: TestNumbersPerDayManager.Reservation?
  private var conversionID: UUID?
  private var importTask: Task<Void, Never>?
  private var importID: UUID?
  #if os(macOS)
    weak var window: NSWindow?

    private func accepts(_ notification: Notification) -> Bool {
      guard let window else { return false }
      return window === ((notification.object as? NSWindow) ?? NSApp.keyWindow)
    }
  #endif

  // MARK: - life cycle

  init() {
    Publishers.CombineLatest3($targetOptions, $variantOptions, $regionOptions)
      .map { targetOptions, variantOptions, regionOptions in
        ConversionConfiguration(target: targetOptions, variant: variantOptions, region: regionOptions).options
      }
      .removeDuplicates()
      .assign(to: &$options)

    $targetOptions.dropFirst()
      .sink { targetOptions in
        appDefaults[\.targetOptions] = targetOptions
      }.store(in: &cancellables)
    $variantOptions.dropFirst()
      .sink { variantOptions in
        appDefaults[\.variantOptions] = variantOptions
      }.store(in: &cancellables)
    $regionOptions.dropFirst()
      .sink { regionOptions in
        appDefaults[\.regionOptions] = regionOptions
      }.store(in: &cancellables)

    // Listen for text conversion service notifications
    #if os(macOS)
      NotificationCenter.default.publisher(for: .textConversionServiceDidReceiveText)
        .sink { [weak self] notification in
          guard let self = self,
                let userInfo = notification.userInfo,
                let originalText = userInfo["originalText"] as? String,
                let convertedText = userInfo["convertedText"] as? String else {
            return
          }

          DispatchQueue.main.async {
            guard self.accepts(notification) else { return }
            self.cancelConversion()
            self.replaceSource(originalText)
            self.resultText = convertedText
            self.exportSnapshot = ExportSnapshot(text: convertedText, filename: "OpenCCman-converted.txt")
            self.localProgress = 1.0
          }
        }
        .store(in: &cancellables)

      // Listen for global shortcut notifications
      NotificationCenter.default.publisher(for: .globalShortcutDidConvertText)
        .sink { [weak self] notification in
          guard let self = self,
                let userInfo = notification.userInfo,
                let originalText = userInfo["originalText"] as? String,
                let convertedText = userInfo["convertedText"] as? String else {
            return
          }

          DispatchQueue.main.async {
            guard self.accepts(notification) else { return }
            self.cancelConversion()
            self.replaceSource(originalText)
            self.resultText = convertedText
            self.exportSnapshot = ExportSnapshot(text: convertedText, filename: "OpenCCman-converted.txt")
            self.localProgress = 1.0
          }
        }
        .store(in: &cancellables)

      // Listen for text service notifications (just open text without conversion)
      NotificationCenter.default.publisher(for: .textServiceDidReceiveText)
        .sink { [weak self] notification in
          guard let self = self,
                let userInfo = notification.userInfo,
                let originalText = userInfo["originalText"] as? String else {
            return
          }

          DispatchQueue.main.async {
            guard self.accepts(notification) else { return }
            self.cancelConversion()
            self.replaceSource(originalText)
          }
        }
        .store(in: &cancellables)

      // Listen for menu convert notifications
      NotificationCenter.default.publisher(for: .convertTextFromMenu)
        .sink { [weak self] notification in
          guard let self = self else { return }

          DispatchQueue.main.async {
            guard self.accepts(notification) else { return }
            self.translate()
          }
        }
        .store(in: &cancellables)
    #endif
  }

  // MARK: - response methods

  var configuration: ConversionConfiguration {
    ConversionConfiguration(target: targetOptions, variant: variantOptions, region: regionOptions)
  }

  var selectedPreset: ConversionConfiguration.Preset? { configuration.preset }

  func applyPreset(_ preset: ConversionConfiguration.Preset) {
    let configuration = preset.configuration
    targetOptions = configuration.target
    // Keep inactive advanced choices when switching to simplified output.
    guard configuration.target == .traditional else { return }
    variantOptions = configuration.variant
    regionOptions = configuration.region
  }

  func translate() {
    guard !isLoading, !isImporting, !inputText.isEmpty else { return }
    guard let reservation = TestNumbersPerDayManager.reserve() else {
      showingProAlert = true
      return
    }

    isLoading = true
    resultText = ""
    localProgress = 0.0
    error = nil

    let currentInput = inputText
    let currentOptions = options
    let filename = TextFileService.ImportedText(text: "", sourceFilename: sourceFilename).exportFilename
    let identifier = UUID()
    conversionID = identifier
    self.reservation = reservation

    conversionTask = Task(priority: .userInitiated) { [weak self] in
      do {
        let result = try await ChineseConversionService.shared.convert(currentInput, options: currentOptions)
        try Task.checkCancellation()
        guard let self, self.conversionID == identifier else {
          reservation.release()
          return
        }
        self.resultText = result
        self.exportSnapshot = ExportSnapshot(text: result, filename: filename)
        reservation.commit()
        self.reservation = nil
        self.showReview()
        self.localProgress = 1.0
        self.isLoading = false
        self.conversionTask = nil
        self.conversionID = nil
      } catch {
        reservation.release()
        guard !Task.isCancelled, let self, self.conversionID == identifier else { return }
        self.error = error
        self.reservation = nil
        self.isLoading = false
        self.localProgress = 0.0
        self.conversionTask = nil
        self.conversionID = nil
      }
    }
  }

  func cancelConversion() {
    conversionTask?.cancel()
    conversionTask = nil
    conversionID = nil
    reservation?.release()
    reservation = nil
    isLoading = false
    localProgress = 0.0
    error = nil
  }

  func replaceSource(_ text: String, sourceFilename: String? = nil) {
    cancelImport()
    cancelConversion()
    inputText = text
    self.sourceFilename = sourceFilename
    resultText = ""
    exportSnapshot = nil
  }

  func handleFileFailure(_ error: Error) {
    let cocoaError = error as NSError
    guard !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) else { return }
    self.error = error
  }

  func importFile(_ url: URL) {
    startImport { try await TextFileService.read(url) }
  }

  func importDroppedItems(_ providers: [NSItemProvider]) -> Bool {
    guard providers.count == 1, let provider = providers.first else {
      error = TextFileService.FileError.multipleItems
      return false
    }
    startImport { try await TextFileService.read(provider) }
    return true
  }

  private func startImport(_ read: @escaping () async throws -> TextFileService.ImportedText) {
    cancelImport()
    error = nil
    isImporting = true
    let identifier = UUID()
    importID = identifier
    importTask = Task { [weak self] in
      do {
        let imported = try await read()
        try Task.checkCancellation()
        guard let self, self.importID == identifier else { return }
        self.replaceSource(imported.text, sourceFilename: imported.sourceFilename)
      } catch {
        guard !Task.isCancelled, let self, self.importID == identifier else { return }
        self.error = error
        self.isImporting = false
        self.importTask = nil
        self.importID = nil
      }
    }
  }

  func cancelImport() {
    importTask?.cancel()
    importTask = nil
    importID = nil
    isImporting = false
  }

  deinit {
    conversionTask?.cancel()
    reservation?.release()
    importTask?.cancel()
  }

  // MARK: - Review

  func showReview() {
    guard lastVersionPromptedForReview != Bundle.main.appVersion else { return }

    ReviewHandler.requestReview()
    lastVersionPromptedForReview = Bundle.main.appVersion
  }

  // MARK: - Options

  typealias Language = ConversionConfiguration.Language
  typealias Variant = ConversionConfiguration.Variant
  typealias Region = ConversionConfiguration.Region
}

extension ConversionConfiguration.Language: Segmentable, DefaultsSerializable {}
extension ConversionConfiguration.Variant: Segmentable, DefaultsSerializable {}
extension ConversionConfiguration.Region: Segmentable, DefaultsSerializable {}

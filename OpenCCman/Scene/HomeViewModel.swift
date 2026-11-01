import Combine
import Foundation
import OpenCC
import SwiftUI
import SwiftyUserDefaults
import UniformTypeIdentifiers

#if os(macOS)
  extension Notification.Name {
    static let textConversionServiceDidReceiveText = Notification.Name("TextConversionServiceDidReceiveText")
    static let textServiceDidReceiveText = Notification.Name("TextServiceDidReceiveText")
    static let convertTextFromMenu = Notification.Name("ConvertTextFromMenu")
  }
#endif

@MainActor
class HomeViewModel: ObservableObject {
  static let exampleSourceText = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"

  #if os(macOS)
    let sourceReadingState = WorkspaceEditorReadingState()
    let resultReadingState = WorkspaceEditorReadingState()
  #endif

  @Published var inputText: String = "" {
    didSet {
      guard !inputText.utf8.elementsEqual(oldValue.utf8) else { return }
      #if os(macOS)
        sourceReadingState.invalidate()
      #endif
      cancelImport()
      cancelConversion()
      resultText = ""
      exportSnapshot = nil
    }
  }
  @Published var resultText: String = "" {
    didSet {
      if !resultText.utf8.elementsEqual(oldValue.utf8) { invalidateDiff() }
      #if os(macOS)
        if resultText != oldValue { resultReadingState.invalidate() }
      #endif
    }
  }

  @Published var options: ChineseConverter.Options = []
  @Published var targetOptions: Language = appDefaults[\.targetOptions] { didSet { if targetOptions != oldValue { cancelConversion() } } }
  @Published var variantOptions: Variant = appDefaults[\.variantOptions] { didSet { if variantOptions != oldValue { cancelConversion() } } }
  @Published var regionOptions: Region = appDefaults[\.regionOptions] { didSet { if regionOptions != oldValue { cancelConversion() } } }

  @AppStorage(UserDefaultsKeys.lastVersionPromptedForReview.rawValue) var lastVersionPromptedForReview: String = ""

  @Published var showingProAlert: Bool = false
  @Published var proAlertDetailKey = "Unlimited calculations"
  @Published var error: Error?
  @Published var isLoading: Bool = false
  @Published private(set) var isImporting = false
  @Published private(set) var sourceFilename: String?
  struct ExportSnapshot: Equatable, Sendable {
    let text: String
    let filename: String
  }
  @Published private(set) var resultConfiguration: ConversionConfiguration?
  var resultConfigurationChanged: Bool {
    guard !resultText.isEmpty, let resultConfiguration else { return false }
    return resultConfiguration.options != configuration.options
  }
  @Published private(set) var diffSnapshot: ConversionDiffSnapshot<ConversionConfiguration>?
  @Published var showsDifferences = false {
    didSet {
      guard showsDifferences != oldValue else { return }
      cancelDiffCalculation()
      if showsDifferences { calculateDiff() }
    }
  }
  @Published private(set) var diffDisplay: ConversionDiffDisplay?
  @Published private(set) var diffComputing = false
  @Published private(set) var diffTooLarge = false
  @Published private(set) var currentDiffIndex: Int?
  @Published private(set) var diffNavigationID: UUID?
  private var diffGeneration = ConversionDiffGeneration()
  private var diffWorker: Task<ConversionDiffDisplay?, Never>?
  private var diffPublication: Task<Void, Never>?
  #if DEBUG
    private var diffMetricsTask: Task<Void, Never>?
  #endif

  func diffDecoration(source: Bool) -> WorkspaceDiffDecoration? {
    guard showsDifferences, let display = diffDisplay, let snapshot = diffSnapshot,
          display.id == snapshot.id else { return nil }
    return WorkspaceDiffDecoration(id: display.id, text: source ? snapshot.source : snapshot.result,
                                   ranges: source ? display.sourceRanges : display.resultRanges,
                                   currentIndex: currentDiffIndex, navigationID: diffNavigationID)
  }

  func navigateDiff(by step: Int) {
    guard showsDifferences, let display = diffDisplay, !display.sourceRanges.isEmpty else { return }
    let count = display.sourceRanges.count
    currentDiffIndex = currentDiffIndex.map { ($0 + step + count) % count } ?? (step > 0 ? 0 : count - 1)
    diffNavigationID = UUID()
  }

  private func cancelDiffCalculation() {
    #if DEBUG
      diffMetricsTask?.cancel()
      diffMetricsTask = nil
    #endif
    diffGeneration.invalidate()
    diffWorker?.cancel()
    diffPublication?.cancel()
    diffWorker = nil
    diffPublication = nil
    diffDisplay = nil
    currentDiffIndex = nil
    diffNavigationID = nil
    diffComputing = false
    diffTooLarge = false
  }

  private func invalidateDiff() {
    cancelDiffCalculation()
    diffSnapshot = nil
  }

  private func calculateDiff() {
    guard showsDifferences, let snapshot = diffSnapshot else { return }
    let generation = diffGeneration.id
    diffComputing = true
    #if DEBUG
      if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
         ProcessInfo.processInfo.arguments.contains("-qa-diff-metrics") {
        diffMetricsTask = Self.measureDiffResponsiveness(snapshotID: snapshot.id)
      }
    #endif
    let worker = Task.detached(priority: .userInitiated) { () -> ConversionDiffDisplay? in
      let outcome = ConversionDiff.compute(source: snapshot.source, result: snapshot.result,
                                          limits: .workspace, cancelled: { Task.isCancelled })
      guard case let .computed(hunks) = outcome, !Task.isCancelled else { return nil }
      return ConversionDiffDisplay(id: snapshot.id, source: snapshot.source, result: snapshot.result, hunks: hunks)
    }
    diffWorker = worker
    diffPublication = Task { [weak self] in
      let display = await worker.value
      guard !Task.isCancelled, let self, self.diffGeneration.accepts(generation),
            self.diffSnapshot?.id == snapshot.id, self.showsDifferences else { return }
      self.diffDisplay = display
      self.diffTooLarge = display == nil
      self.diffComputing = false
      self.diffWorker = nil
      self.diffPublication = nil
    }
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
  #if DEBUG
    private var didInjectQAUnreadCards = false
  #endif
  let windowOwnerID = UUID()
  #if os(macOS)
    weak var window: NSWindow?
    #if DEBUG
      private var didImportLargeFileForQA = false
    #endif

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
            self.resultConfiguration = nil // External Services do not supply configuration provenance.
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
            self.resultConfiguration = nil // External Services do not supply configuration provenance.
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

      NotificationCenter.default.publisher(for: Notification.Name("WorkspaceDiffCommand"))
        .sink { [weak self] notification in
          DispatchQueue.main.async {
            guard let self, self.accepts(notification) else { return }
            switch notification.userInfo?["action"] as? String {
            case "toggle": self.showsDifferences.toggle()
            case "previous": self.navigateDiff(by: -1)
            case "next": self.navigateDiff(by: 1)
            default: break
            }
          }
        }.store(in: &cancellables)

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

  var canFillExample: Bool {
    inputText.isEmpty && resultText.isEmpty && exportSnapshot == nil && !isImporting && !isLoading
  }

  var canClearSource: Bool { !inputText.isEmpty }

  func fillExampleIfEmpty() {
    guard canFillExample else { return }
    replaceSource(Self.exampleSourceText)
  }

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
      #if DEBUG
        if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
           ProcessInfo.processInfo.arguments.contains("-qa-unread-whats-new-on-pro-alert") {
          UserDefaults.standard.removeObject(forKey: WhatsNewCoordinator.lastPresentedVersionKey)
        }
      #endif
      proAlertDetailKey = "Unlimited calculations"
      showingProAlert = true
      #if DEBUG
        if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
           ProcessInfo.processInfo.arguments.contains("-qa-error-with-pro-alert") {
          error = NSError(domain: "OpenCCmanQA", code: 284,
                          userInfo: [NSLocalizedDescriptionKey: "QA pending file error"])
        }
      #endif
      return
    }

    invalidateDiff()
    isLoading = true
    resultText = ""
    localProgress = 0.0
    error = nil
    #if DEBUG
      if !didInjectQAUnreadCards,
         Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
         ProcessInfo.processInfo.arguments.contains("-qa-unread-whats-new-on-convert") {
        UserDefaults.standard.removeObject(forKey: "lastPresentedWhatsNewVersion")
        didInjectQAUnreadCards = true
      }
    #endif

    let currentInput = inputText
    let currentConfiguration = configuration
    let currentOptions = options
    let filename = TextFileService.ImportedText(text: "", sourceFilename: sourceFilename).exportFilename
    let identifier = UUID()
    conversionID = identifier
    self.reservation = reservation

    conversionTask = Task(priority: .userInitiated) { [weak self] in
      do {
        #if DEBUG
          if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests" {
            if ProcessInfo.processInfo.arguments.contains("-qa-delay-conversion") {
              try await Task.sleep(nanoseconds: 2_000_000_000)
            }
            if ProcessInfo.processInfo.arguments.contains("-qa-fail-conversion") {
              throw NSError(domain: "OpenCCman.WhatsNewUITests", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "QA conversion failure"])
            }
          }
        #endif
        let result = try await ChineseConversionService.shared.convert(currentInput, options: currentOptions)
        try Task.checkCancellation()
        guard let self, self.conversionID == identifier else {
          reservation.release()
          return
        }
        self.resultConfiguration = currentConfiguration
        self.resultText = result
        self.exportSnapshot = ExportSnapshot(text: result, filename: filename)
        self.diffSnapshot = ConversionDiffSnapshot(source: currentInput, result: result, configuration: currentConfiguration)
        self.calculateDiff()
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
    invalidateDiff()
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

  func clearSource() {
    guard canClearSource else { return }
    // Invalidate both task IDs before replacing the document so a late worker
    // cannot publish a result or imported draft after confirmation.
    cancelImport()
    cancelConversion()
    inputText = ""
    sourceFilename = nil
    resultText = ""
    resultConfiguration = nil
    exportSnapshot = nil
  }

  func handleFileFailure(_ error: Error) {
    let cocoaError = error as NSError
    guard !(cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSUserCancelledError) else { return }
    self.error = error
  }

  func importFile(_ url: URL) {
    #if os(iOS)
    startImport { try await TextFileService.prepare(url, allowLargeFile: MobileFileRuntime.isEnabled) }
    #else
    startImport { try await TextFileService.prepare(url) }
    #endif
  }

  func importDroppedItems(_ providers: [NSItemProvider]) -> Bool {
    #if os(macOS)
      // Several dropped files open the Pro batch list instead of the editor.
      if providers.count > 1 {
        guard MacBatchConversionCoordinator.isQualified else {
          showBatchProAlert()
          return true
        }
        Task { [weak self] in
          guard let urls = await Self.fileURLs(from: providers) else {
            self?.error = MacBatchConversionCoordinator.StartError.dropUnavailable
            return
          }
          self?.offerBatch(urls)
        }
        return true
      }
    #endif
    guard providers.count == 1, let provider = providers.first else {
      error = TextFileService.FileError.multipleItems
      return false
    }
    startImport { try await TextFileService.prepare(provider) }
    return true
  }

  private func startImport(_ read: @escaping () async throws -> TextFileService.PreparedImport) {
    cancelConversion()
    cancelImport()
    error = nil
    isImporting = true
    let identifier = UUID()
    importID = identifier
    importTask = Task { [weak self] in
      do {
        #if DEBUG
          if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
             ProcessInfo.processInfo.arguments.contains("-qa-delay-import") {
            try await Task.sleep(nanoseconds: 2_000_000_000)
          }
        #endif
        let imported = try await read()
        try Task.checkCancellation()
        guard let self, self.importID == identifier else { return }
        switch imported {
        case let .text(text):
          self.replaceSource(text.text, sourceFilename: text.sourceFilename)
        case let .largeFile(source):
          #if os(macOS)
            var retainedByCoordinator = false
            defer { if !retainedByCoordinator { try? source.close() } }
            guard MacLargeFileCoordinator.isEnabled else { throw TextFileService.FileError.tooLarge }
            try MacLargeFileCoordinator.validateSize(source.byteCount)
            if MacLargeFileCoordinator.isQualified {
              try MacLargeFileCoordinator.shared.offer(
                source, configuration: self.configuration, qualified: true,
                owner: self.windowOwnerID, window: self.window)
              retainedByCoordinator = true
            } else {
              self.proAlertDetailKey = source.byteCount > FileConversionPolicy.macMaximumBytes
                ? "mac_file_experimental_pro" : "pro_large_file_conversion"
              self.showingProAlert = true
            }
          #else
            var retainedByCoordinator = false
            defer { if !retainedByCoordinator { try? source.close() } }
            guard MobileFileRuntime.isEnabled else { throw TextFileService.FileError.tooLarge }
            let runtime = MobileFileRuntime.shared
            try runtime.coordinator.validateSize(source.byteCount)
            if runtime.isQualified {
              try runtime.coordinator.offer(source, configuration: self.configuration, owner: self.windowOwnerID)
              retainedByCoordinator = true
            } else {
              self.proAlertDetailKey = source.byteCount > FileConversionPolicy.mobileMaximumBytes
                ? "mobile_file_experimental_pro" : "mobile_file_pro"
              self.showingProAlert = true
            }
          #endif
          self.isImporting = false
          self.importTask = nil
          self.importID = nil
        }
      } catch {
        guard !Task.isCancelled, let self, self.importID == identifier else { return }
        self.error = error
        self.isImporting = false
        self.importTask = nil
        self.importID = nil
      }
    }
  }

  #if os(macOS)
    /// Menu entry: Pro chooses files; free users see the Pro prompt and nothing starts.
    func chooseBatchFiles() {
      guard MacBatchConversionCoordinator.isQualified else {
        showBatchProAlert()
        return
      }
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = true
      panel.canChooseDirectories = false
      panel.allowedContentTypes = [.plainText]
      panel.title = NSLocalizedString("batch_title", comment: "")
      let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
        guard response == .OK else { return }
        self?.offerBatch(panel.urls)
      }
      if let window { panel.beginSheetModal(for: window.attachedSheet ?? window, completionHandler: completion) }
      else { panel.begin(completionHandler: completion) }
    }

    func offerBatch(_ urls: [URL]) {
      do {
        try MacBatchConversionCoordinator.shared.offer(
          urls, configuration: configuration, qualified: MacBatchConversionCoordinator.isQualified,
          owner: windowOwnerID, window: window)
      } catch MacBatchConversionCoordinator.StartError.requiresPro {
        showBatchProAlert()
      } catch {
        self.error = error
      }
    }

    private func showBatchProAlert() {
      proAlertDetailKey = "pro_batch_conversion"
      showingProAlert = true
    }

    /// Finder drops may arrive as plain text only, without a file URL or name.
    /// The in-place file representation still identifies the original file;
    /// a copied or non-file item makes the whole drop unavailable, never a
    /// silently shorter batch.
    private static func fileURLs(from providers: [NSItemProvider]) async -> [URL]? {
      var urls: [URL] = []
      for provider in providers {
        let url: URL? = await withCheckedContinuation { continuation in
          if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
              continuation.resume(returning: data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) })
            }
          } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            _ = provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.plainText.identifier) { url, inPlace, _ in
              continuation.resume(returning: inPlace ? url : nil)
            }
          } else {
            continuation.resume(returning: nil)
          }
        }
        guard let url else { return nil }
        urls.append(url)
      }
      return urls
    }
  #endif

  func cancelImport() {
    importTask?.cancel()
    importTask = nil
    importID = nil
    isImporting = false
  }

  #if os(macOS) && DEBUG
    /// Exact isolated QA bundle only; no production preferences or entitlement writes.
    func importLargeFileForQAIfRequested() {
      guard !didImportLargeFileForQA, MacLargeFileCoordinator.isQABundle else { return }
      let arguments = ProcessInfo.processInfo.arguments
      guard let index = arguments.firstIndex(of: "-qa-import-large-file"),
            arguments.indices.contains(index + 1) else { return }
      didImportLargeFileForQA = true
      if arguments.contains("-qa-large-file-existing-result") {
        resultText = "鼠標裡面的矽二極體壞了，導致游標解析度降低。"
        resultConfiguration = configuration
        exportSnapshot = ExportSnapshot(text: resultText, filename: "draft-converted.txt")
      }
      importFile(URL(fileURLWithPath: arguments[index + 1]))
    }
  #endif

  deinit {
    #if DEBUG
      diffMetricsTask?.cancel()
    #endif
    diffWorker?.cancel()
    diffPublication?.cancel()
    conversionTask?.cancel()
    reservation?.release()
    importTask?.cancel()
  }

  #if DEBUG
    /// QA-only two-second main-actor probe, including first render after the
    /// worker publishes. It records no document text and is cancelled on edits.
    private static func measureDiffResponsiveness(snapshotID: UUID) -> Task<Void, Never> {
      let start = DispatchTime.now().uptimeNanoseconds
      return Task { @MainActor in
        var last = start
        var maximum: Double = 0
        var samples = 0
        while !Task.isCancelled, DispatchTime.now().uptimeNanoseconds - start < 2_000_000_000 {
          do { try await Task.sleep(nanoseconds: 8_000_000) } catch { break }
          let now = DispatchTime.now().uptimeNanoseconds
          maximum = max(maximum, Double(now - last) / 1e6)
          samples += 1
          last = now
        }
        print("DIFF_QA snapshot=\(snapshotID) main_actor_samples=\(samples) max_gap_ms=\(maximum) cancelled=\(Task.isCancelled)")
      }
    }
  #endif

  // MARK: - Review

  func showReview() {
    guard lastVersionPromptedForReview != Bundle.main.appVersion else { return }

    if ReviewHandler.requestReview() {
      lastVersionPromptedForReview = Bundle.main.appVersion
    }
  }

  // MARK: - Options

  typealias Language = ConversionConfiguration.Language
  typealias Variant = ConversionConfiguration.Variant
  typealias Region = ConversionConfiguration.Region
}

extension ConversionConfiguration.Language: Segmentable, DefaultsSerializable {}
extension ConversionConfiguration.Variant: Segmentable, DefaultsSerializable {}
extension ConversionConfiguration.Region: Segmentable, DefaultsSerializable {}

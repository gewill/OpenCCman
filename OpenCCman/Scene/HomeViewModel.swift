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
  @Published var inputText: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
  @Published var resultText: String = ""

  @Published var options: ChineseConverter.Options = []
  @Published var targetOptions: Language = appDefaults[\.targetOptions]
  @Published var variantOptions: Variant = appDefaults[\.variantOptions]
  @Published var regionOptions: Region = appDefaults[\.regionOptions]

  @AppStorage(UserDefaultsKeys.lastVersionPromptedForReview.rawValue) var lastVersionPromptedForReview: String = ""

  @Published var showingProAlert: Bool = false
  @Published var error: Error?
  @Published var isLoading: Bool = false
  @Published var localProgress: Double = 0.0 // 0.0 ~ 1.0

  var localProgressPercent: Int {
    max(0, min(100, Int((localProgress * 100).rounded())))
  }

  private var cancellables = Set<AnyCancellable>()
  private var conversionTask: Task<Void, Never>?
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
        var options: ChineseConverter.Options = []
        if targetOptions == .traditional {
          options.formUnion(.traditionalize)
          switch variantOptions {
          case .openCC:
            break
          case .taiwan:
            options.formUnion(.twStandard)
          case .hongKong:
            options.formUnion(.hkStandard)
          }
          if regionOptions == .taiwan {
            options.formUnion(.twIdiom)
          }
        } else {
          options.formUnion(.simplify)
        }
        return options
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
            self.inputText = originalText
            self.resultText = convertedText
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
            self.inputText = originalText
            self.resultText = convertedText
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
            self.inputText = originalText
            self.resultText = "" // Clear result text since we're not converting
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

  func translate() {
    guard !isLoading, !inputText.isEmpty else { return }
    guard TestNumbersPerDayManager.isToMax == false else {
      showingProAlert = true
      return
    }

    // Prepare UI state
    isLoading = true
    resultText = ""
    localProgress = 0.0
    error = nil

    let currentInput = inputText
    let currentOptions = options

    conversionTask = Task(priority: .userInitiated) { [weak self] in
      do {
        let result = try await ChineseConversionService.shared.convert(currentInput, options: currentOptions)
        try Task.checkCancellation()
        guard let self else { return }
        self.resultText = result
        TestNumbersPerDayManager.add()
        self.showReview()
        self.localProgress = 1.0
        self.isLoading = false
        self.conversionTask = nil
      } catch {
        guard !Task.isCancelled, let self else { return }
        self.error = error
        self.isLoading = false
        self.localProgress = 0.0
        self.conversionTask = nil
      }
    }
  }

  func cancelConversion() {
    conversionTask?.cancel()
    conversionTask = nil
    isLoading = false
    localProgress = 0.0
    error = nil
  }

  deinit {
    conversionTask?.cancel()
  }

  // MARK: - Review

  func showReview() {
    guard lastVersionPromptedForReview != Bundle.main.appVersion else { return }

    ReviewHandler.requestReview()
    lastVersionPromptedForReview = Bundle.main.appVersion
  }

  // MARK: - Options

  enum Language: String, CaseIterable, Identifiable, Segmentable, DefaultsSerializable {
    case simplified = "Simplified Chinese"
    case traditional = "Traditional Chinese"

    var id: Language { self }
    var title: String { rawValue }
  }

  enum Variant: String, CaseIterable, Identifiable, Segmentable, DefaultsSerializable {
    case openCC = "OpenCC Standard"
    case taiwan = "Taiwan Standard"
    case hongKong = "HongKong Standard"

    var id: Variant { self }
    var title: String { rawValue }
  }

  enum Region: String, CaseIterable, Identifiable, Segmentable, DefaultsSerializable {
    case notConvert = "Not convert"
    case taiwan = "Taiwan Idiom"

    var id: Region { self }
    var title: String { rawValue }
  }

}

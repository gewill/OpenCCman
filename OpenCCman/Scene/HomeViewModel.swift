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
  private var cancellables = Set<AnyCancellable>()

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
      .assign(to: \.options, on: self)
      .store(in: &cancellables)

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
          self.inputText = originalText
          self.resultText = convertedText
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
          self.inputText = originalText
          self.resultText = convertedText
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
          self.inputText = originalText
          self.resultText = "" // Clear result text since we're not converting
        }
      }
      .store(in: &cancellables)

    // Listen for menu convert notifications
    NotificationCenter.default.publisher(for: .convertTextFromMenu)
      .sink { [weak self] _ in
        guard let self = self else { return }

        DispatchQueue.main.async {
          self.translate()
        }
      }
      .store(in: &cancellables)
    #endif
  }

  // MARK: - response methods

  func translate() {
    guard TestNumbersPerDayManager.isToMax == false else {
      showingProAlert.toggle()
      return
    }

    do {
      let converter = try ChineseConverter(options: options)
      resultText = converter.convert(inputText)
      TestNumbersPerDayManager.add()
      showReview()
    } catch {
      self.error = error
      print(error.localizedDescription)
    }
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

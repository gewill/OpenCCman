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
  @Published var localProgress: Double = 0.0 // 0.0 ~ 1.0

  var localProgressPercent: Int {
    max(0, min(100, Int((localProgress * 100).rounded())))
  }

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
        print("options:", options)
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

    // Prepare UI state
    isLoading = true
    resultText = ""
    localProgress = 0.0

    let currentInput = inputText
    let currentOptions = options

    // Pre-create converter on background thread once to amortize cost
    Task(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      do {
        let converter: ChineseConverter = try await withCheckedThrowingContinuation { continuation in
          DispatchQueue.global(qos: .userInitiated).async {
            do {
              let conv = try ChineseConverter(options: currentOptions)
              continuation.resume(returning: conv)
            } catch {
              continuation.resume(throwing: error)
            }
          }
        }

        let chunks = self.chunked(text: currentInput)
        let total = max(chunks.count, 1)

        // Convert each chunk sequentially on a background queue and append on main
        for (index, chunk) in chunks.enumerated() {
          let convertedChunk: String = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
              let out = converter.convert(chunk)
              continuation.resume(returning: out)
            }
          }

          await MainActor.run {
            if self.resultText.isEmpty {
              self.resultText = convertedChunk
            } else {
              self.resultText += "\n" + convertedChunk
            }
            self.localProgress = Double(index + 1) / Double(total)
          }
        }

        await MainActor.run {
          TestNumbersPerDayManager.add()
          self.showReview()
          self.localProgress = 1.0
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.error = error
          self.isLoading = false
          self.localProgress = 0.0
          print(error.localizedDescription)
        }
      }
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

  // Chunking helper: split large text by paragraphs first, then by size
  private func chunked(text: String, maxChunkLength: Int = 4000) -> [String] {
    guard !text.isEmpty else { return [] }

    // Prefer splitting by double newlines (paragraphs)
    let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }

    var chunks: [String] = []
    var current = ""

    func flushCurrent() {
      if !current.isEmpty { chunks.append(current); current.removeAll(keepingCapacity: true) }
    }

    if paragraphs.count > 1 {
      for para in paragraphs {
        if current.count + para.count + 2 <= maxChunkLength {
          if current.isEmpty { current = para } else { current += "\n\n" + para }
        } else if para.count <= maxChunkLength {
          flushCurrent()
          current = para
        } else {
          // Paragraph itself is too big, hard-split by size
          var start = para.startIndex
          while start < para.endIndex {
            let end = para.index(start, offsetBy: maxChunkLength, limitedBy: para.endIndex) ?? para.endIndex
            chunks.append(String(para[start ..< end]))
            start = end
          }
          current.removeAll(keepingCapacity: true)
        }
      }
      flushCurrent()
    } else {
      // No clear paragraph boundaries, split by size
      var start = text.startIndex
      while start < text.endIndex {
        let end = text.index(start, offsetBy: maxChunkLength, limitedBy: text.endIndex) ?? text.endIndex
        chunks.append(String(text[start ..< end]))
        start = end
      }
    }

    return chunks
  }
}

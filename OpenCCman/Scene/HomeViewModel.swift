import Combine
import Foundation
import OpenCC
import SwiftUI

class HomeViewModel: ObservableObject {
  @Published var inputText: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
  @Published var resultText: String = ""

  @Published var options: ChineseConverter.Options = []
  @Published var targetOptions: Language = .simplified
  @Published var variantOptions: Variant = .openCC
  @Published var regionOptions: Region = .notConvert

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
    } catch {
      self.error = error
      print(error.localizedDescription)
    }
  }

  // MARK: - Options

  enum Language: String, CaseIterable, Identifiable, Segmentable {
    case simplified = "Simplified Chinese"
    case traditional = "Traditional Chinese"

    var id: Language { self }
    var title: String { rawValue }
  }

  enum Variant: String, CaseIterable, Identifiable, Segmentable {
    case openCC = "OpenCC Standard"
    case taiwan = "Taiwan Standard"
    case hongKong = "HongKong Standard"

    var id: Variant { self }
    var title: String { rawValue }
  }

  enum Region: String, CaseIterable, Identifiable, Segmentable {
    case notConvert = "Not convert"
    case taiwan = "Taiwan Idiom"

    var id: Region { self }
    var title: String { rawValue }
  }
}

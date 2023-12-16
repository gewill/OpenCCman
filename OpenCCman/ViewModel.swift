//
//  ViewModel.swift
//  OpenCCman
//
//  Created by will on 2023/12/16.
//

import Combine
import Foundation
import OpenCC
import SwiftUI

class ViewModel: ObservableObject {
  @Published var inputText: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
  @Published var resultText: String = ""

  @Published var options: ChineseConverter.Options = []
  @Published var targetOptions: Language = .simplified
  @Published var variantOptions: Variant = .openCC
  @Published var regionOptions: Region = .notConverted

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
          case .taiWan:
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
    do {
      let converter = try ChineseConverter(options: options)
      resultText = converter.convert(inputText)
    } catch {
      self.error = error
      print(error.localizedDescription)
    }
  }

  // MARK: - Options

  enum Language: String, CaseIterable, Identifiable, Segmentable {
    case simplified
    case traditional

    var id: Language { self }
    var title: String { rawValue }
  }

  enum Variant: String, CaseIterable, Identifiable, Segmentable {
    case openCC
    case taiWan
    case hongKong

    var id: Variant { self }
    var title: String { rawValue }
  }

  enum Region: String, CaseIterable, Identifiable, Segmentable {
    case notConverted
    case taiwan

    var id: Region { self }
    var title: String { rawValue }
  }
}

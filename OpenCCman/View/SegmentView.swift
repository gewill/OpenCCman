import Neumorphic
import SwiftUI

protocol Segmentable: Identifiable, Hashable {
  var title: String { get }
}

struct SegmentView<T: Segmentable>: View {
  @Environment(\.locale) private var locale
  @Environment(\.sizeCategory) private var sizeCategory
  @State private var availableWidth: CGFloat = 0
  @State private var widestWord: CGFloat = 0
  let title: String
  let options: [T]
  @Binding var selected: T

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.localizedStringKey)
        .appFont(.headline)
      picker
        .frame(maxWidth: .infinity)
        .appSegmentTrack()
        .background(
          GeometryReader { geometry in
            Color.clear.preference(key: SegmentAvailableWidthKey.self, value: geometry.size.width)
          }
        )
        .background(labelMeasurements)
        .onPreferenceChange(SegmentAvailableWidthKey.self) { availableWidth = $0 }
        .onPreferenceChange(SegmentWordWidthKey.self) { widestWord = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title.localizedStringKey))
        .accessibilityIdentifier("conversion-segment-\(title)")
    }
  }

  private var usesVerticalLayout: Bool {
    sizeCategory.isAccessibilityCategory ||
      (availableWidth > 0 && widestWord > 0 &&
       availableWidth < CGFloat(options.count) * max(AppControlMetrics.height,
         widestWord + 2 * AppSegmentButtonStyle.horizontalInset))
  }

  // Measure unbroken words in the same semantic font as a selected segment.
  // This permits normal two-line labels, but avoids splitting English words into
  // fragments. Measuring the heavier weight keeps selection from changing axes.
  private var labelMeasurements: some View {
    ZStack {
      ForEach(options) { option in
        let words = Self.unbrokenWords(in: option.title.localized(in: locale))
        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
          Text(word)
            .appFont(.body, weight: .semibold)
            .fixedSize()
            .background(
              GeometryReader { geometry in
                Color.clear.preference(key: SegmentWordWidthKey.self, value: geometry.size.width)
              }
            )
        }
      }
    }
    .hidden()
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }

  // Chinese labels have no spaces, so a whitespace split would measure the whole
  // label as one word. Runs containing ideographs are split into dictionary words
  // instead: "OpenCC標準" measures "OpenCC" and "標準". Other runs, including all
  // English words, stay whole.
  static func unbrokenWords(in label: String) -> [String] {
    label.split(whereSeparator: { $0.isWhitespace }).flatMap { run -> [String] in
      let run = String(run)
      guard run.unicodeScalars.contains(where: { $0.properties.isIdeographic }) else { return [run] }
      var words: [String] = []
      run.enumerateSubstrings(in: run.startIndex..., options: .byWords) { word, _, _, _ in
        if let word { words.append(word) }
      }
      return words.isEmpty ? [run] : words
    }
  }

  // Keep the selected value in the binding when width, language or type size changes.
  @ViewBuilder
  private var picker: some View {
    if usesVerticalLayout {
      VStack(spacing: 0) { segments }
    } else {
      HStack(spacing: 0) { segments }
    }
  }

  private var segments: some View {
    ForEach(options) { option in
      Button {
        selected = option
      } label: {
        Text(option.title.localized(in: locale))
      }
      .buttonStyle(AppSegmentButtonStyle(selected: option == selected))
      .overlay(
        SegmentGrooveDivider(isHorizontal: usesVerticalLayout)
          .opacity(option.id == options.first?.id ? 0 : 1),
        alignment: usesVerticalLayout ? .top : .leading
      )
      .accessibilityAddTraits(option == selected ? .isSelected : [])
    }
  }
}

private struct SegmentAvailableWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct SegmentWordWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct SegmentGrooveDivider: View {
  @Environment(\.colorScheme) private var colorScheme
  let isHorizontal: Bool

  var body: some View {
    Group {
      if isHorizontal {
        VStack(spacing: 0) {
          Color.Neumorphic.darkShadow.opacity(0.65).frame(height: 1)
          Color.white.opacity(colorScheme == .dark ? 0.32 : 0.9).frame(height: 1)
        }
        .padding(.horizontal, 8)
      } else {
        HStack(spacing: 0) {
          Color.Neumorphic.darkShadow.opacity(0.65).frame(width: 1)
          Color.white.opacity(colorScheme == .dark ? 0.32 : 0.9).frame(width: 1)
        }
        .frame(height: 20)
      }
    }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }
}

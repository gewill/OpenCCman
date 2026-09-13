import Neumorphic
import SwiftUI

protocol Segmentable: Identifiable, Hashable {
  var title: String { get }
}

struct SegmentView<T: Segmentable>: View {
  @Environment(\.locale) private var locale
  let title: String
  let options: [T]
  @Binding var selected: T

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.localizedStringKey)
        .font(.headline)
      NeumorphicPicker(selection: $selected, options: options) { option in
        option.title.localized(in: locale)
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text(title.localizedStringKey))
      .accessibilityIdentifier("conversion-segment-\(title)")
    }
  }
}

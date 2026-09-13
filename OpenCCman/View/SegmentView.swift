import Neumorphic
import SwiftUI

protocol Segmentable: Identifiable, Hashable {
  var title: String { get }
}

struct SegmentView<T: Segmentable>: View {
  @Environment(\.locale) private var locale
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.isEnabled) private var isEnabled
  let title: String
  let options: [T]
  @Binding var selected: T

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.localizedStringKey)
        .font(.headline)
      picker
        .padding(3)
        .background(
          RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.Neumorphic.main)
            .softInnerShadow(RoundedRectangle(cornerRadius: 11, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title.localizedStringKey))
        .accessibilityIdentifier("conversion-segment-\(title)")
    }
  }

  // Keep the selected value in the binding when Dynamic Type changes layout.
  @ViewBuilder
  private var picker: some View {
    if sizeCategory.isAccessibilityCategory {
      VStack(spacing: 0) { segments }
    } else {
      HStack(spacing: 0) { segments }
    }
  }

  private var segments: some View {
    ForEach(options) { option in
      if option.id != options.first?.id {
        SegmentGrooveDivider(isHorizontal: sizeCategory.isAccessibilityCategory)
      }
      Button {
        selected = option
      } label: {
        Text(option.title.localized(in: locale))
          .font(.body.weight(option == selected ? .semibold : .regular))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 8)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, minHeight: 44)
          .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(option == selected ? Color.accentColor : Color.clear)
          )
          .foregroundColor(option == selected ? .white : Color.Neumorphic.secondary)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(option == selected ? .isSelected : [])
    }
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

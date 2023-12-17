import Neumorphic
import SwiftUI
import VisualEffects

protocol Segmentable: Identifiable, Equatable {
  var title: String { get }
}

struct SegmentView<T: Segmentable>: View {
  @Environment(\.isEnabled) var isEnabled: Bool
  let title: String
  let options: [T]
  @Binding var seleted: T

  // MARK: - life cycle

  var body: some View {
    ZStack {
      Color.Neumorphic.main
        .ignoresSafeArea()
      ScrollView(.horizontal) {
        HStack(spacing: Constant.padding) {
          Text(title.localizedStringKey)
            .bold()
          HStack(spacing: Constant.padding) {
            ForEach(options) { option in
              let active = option == seleted
              ZStack {
                if active {
                  RoundedRectangle(cornerRadius: 20).fill(Color.accent.opacity(isEnabled ? 1 : 0.5))
                    .softInnerShadow(RoundedRectangle(cornerRadius: 20), spread: 0.1, radius: 10)
                } else {
                  RoundedRectangle(cornerRadius: 20).fill(Color.Neumorphic.main.opacity(isEnabled ? 1 : 0.5))
                    .softOuterShadow()
                }
                Text(option.title.localizedStringKey)
                  .font(active ? .headline : .body)
                  .foregroundColor(active ? Color.Neumorphic.main : Color.Neumorphic.secondary)
                  .padding(Constant.padding)
              }
              .frame(minWidth: 60)
              .onTapGesture {
                seleted = option
              }
            }
          }
          .padding(6)
          .modify {
            if #available(iOS 15, macOS 12,*) {
              $0.background(.ultraThinMaterial)
            } else {
              #if os(iOS)
                $0.background(VisualEffectBlur(blurStyle: .systemUltraThinMaterial))
              #endif
            }
          }
          .cornerRadius(Constant.cornerRadius)
        }
      }
    }
  }
}

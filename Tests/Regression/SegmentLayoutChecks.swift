import AppKit
import QuartzCore
import SwiftUI

@MainActor
enum SegmentLayoutChecks {
  static func run() {
    let state = Fixture()
    let host = NSHostingView(rootView: Sample(state: state))
    host.frame = NSRect(x: 0, y: 0, width: 600, height: 800)
    let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = host
    window.isReleasedWhenClosed = false
    window.orderFront(nil)
    defer { window.close(); window.contentView = nil }

    func settle() {
      for _ in 0..<12 {
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
      }
      precondition(state.height > 0, "Native SwiftUI layout did not produce geometry")
    }

    settle()
    let wide = state.height
    state.width = 160
    settle()
    let narrow = state.height
    precondition(narrow > wide + 15, "Narrow English labels must stack instead of splitting words")
    state.selected = state.options[1]
    settle()
    precondition(abs(state.height - narrow) < 1, "Selection must not change segment orientation")
    state.locale = Locale(identifier: "zh_Hant")
    settle()
    precondition(state.height < narrow - 15, "Shorter translated labels must recover horizontal layout")
    state.locale = Locale(identifier: "en")
    settle()
    precondition(abs(state.height - narrow) < 1, "Live language changes must remeasure labels")
    state.width = 400
    settle()
    precondition(abs(state.height - wide) < 1, "Widening must restore the horizontal group")
    state.sizeCategory = .accessibilityExtraExtraExtraLarge
    settle()
    precondition(state.height > wide + 15, "Accessibility type must keep the vertical fallback")
    state.sizeCategory = .large
    settle()
    precondition(abs(state.height - wide) < 1, "Restoring type size must restore compact layout")
    precondition(state.selected == state.options[1], "Layout changes must preserve the selection binding")
    state.options = [Option(title: "OpenCC Standard"), Option(title: "Taiwan Standard"),
                     Option(title: "HongKong Standard")]
    state.selected = state.options[0]
    settle()
    let wideVariants = state.height
    state.width = 200
    settle()
    precondition(state.height > wideVariants + 28, "Three narrow variant choices must form readable rows")
    state.width = 400
    settle()
    precondition(abs(state.height - wideVariants) < 1, "Three variants must also recover after widening")
    print("PASS: native segment narrow/wide, live English/Traditional Chinese, selection stability and accessibility layout")
  }

  private struct Option: Segmentable {
    let title: String
    var id: String { title }
  }

  private final class Fixture: ObservableObject {
    @Published var options = [Option(title: "Simplified Chinese"), Option(title: "Traditional Chinese")]
    @Published var selected = Option(title: "Simplified Chinese")
    @Published var width: CGFloat = 400
    @Published var locale = Locale(identifier: "en")
    @Published var sizeCategory = ContentSizeCategory.large
    var height: CGFloat = 0
  }

  private struct Sample: View {
    @ObservedObject var state: Fixture
    var body: some View {
      SegmentView(title: "Target Language", options: state.options, selected: $state.selected)
        .frame(width: state.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geometry in
          Color.clear.preference(key: HeightKey.self, value: geometry.size.height)
        })
        .onPreferenceChange(HeightKey.self) { state.height = $0 }
        .environment(\.locale, state.locale)
        .environment(\.sizeCategory, state.sizeCategory)
        .neumorphicTheme(.openCCman)
    }
  }

  private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
  }
}

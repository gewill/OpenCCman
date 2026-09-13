import AppKit
import Neumorphic
import SwiftUI

@main
enum ControlSizingChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    let icon = Button {} label: { Image(systemName: "doc.on.doc") }
    let legacy = size(icon.fixedSizeSoftButtonStyle(Circle(), size: CGSize(width: 30, height: 30)))
    precondition(legacy.width == 44 && legacy.height == 44, "Pinned upstream reproduction changed")
    let legacy28 = size(icon.fixedSizeSoftButtonStyle(Circle(), size: CGSize(width: 28, height: 28)))
    let dynamic = size(icon.softButtonStyle(Circle(), padding: 0))
    precondition(legacy28 == CGSize(width: 44, height: 44) && dynamic == legacy28)
    let compact = size(icon.appNeumorphicButtonStyle(Circle(), kind: .icon))
    precondition(compact.width == 28 && compact.height == 28, "Mac icon envelope must be 28×28")
    let text = size(Button("Import TXT") {}.appNeumorphicButtonStyle(Capsule()))
    precondition(text.height == 28)
    let primary = size(Button("Convert") {}.appNeumorphicButtonStyle(Capsule(), kind: .primary, role: .accent))
    precondition(primary.height == 32)
    let segment = size(HStack(spacing: 0) {
      Button("Left") {}.buttonStyle(AppSegmentButtonStyle(selected: true))
      Button("Right") {}.buttonStyle(AppSegmentButtonStyle(selected: false))
    }.appSegmentTrack())
    precondition(segment.height == 28, "Groove cannot add another outer inset")
    let multiline = size(Button("Two lines\nMust remain readable") {}.appNeumorphicButtonStyle(Capsule()))
    precondition(multiline.height > 28, "The default is not a clipping height")
    let toggle = size(Toggle("Test", isOn: .constant(false)).toggleStyle(AppNeumorphicSwitchStyle()))
    precondition(toggle.height == 28)
    print("PASS: upstream 30→44 reproduction; Mac icon 28, text 28, primary 32, segment 28, switch 28 and multiline growth")
  }

  @MainActor private static func size<V: View>(_ view: V) -> CGSize {
    NSHostingView(rootView: view.fixedSize().neumorphicTheme(.openCCman)).fittingSize
  }
}

#if DEBUG
import Neumorphic
import SwiftUI

/// Only available with -control-sizing-gallery in a Debug build. It never buys,
/// imports files or consumes conversion quota; counters expose actual hit testing.
struct ControlSizingGallery: View {
  @State private var taps = 0
  @State private var selected = 0
  @State private var switchOn = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("Control sizing · runtime measurements").appFont(.headline)
        Text("Activations: \(taps) · Segment: \(selected)")
          .accessibilityIdentifier("sizing-counter")
        ControlMeasurement(title: "Neumorphic 2.4.1 · requested 30×30") {
          Button { taps += 1 } label: { Image(systemName: "doc.on.doc") }
            .fixedSizeSoftButtonStyle(Circle(), size: CGSize(width: 30, height: 30))
            .accessibilityLabel("Legacy 30")
        }
        ControlMeasurement(title: "Complete icon bounds") {
          Button { taps += 1 } label: { Image(systemName: "doc.on.doc") }
            .appNeumorphicButtonStyle(Circle(), kind: .icon)
            .accessibilityLabel("Sized icon")
        }
        ControlMeasurement(title: "Complete text bounds") {
          HStack(spacing: 12) {
            Button { taps += 1 } label: { Text("Import TXT") }
              .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
              .accessibilityLabel("Sized text")
            Button { taps += 100 } label: { Text("Disabled") }
              .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
              .disabled(true)
          }
        }
        ControlMeasurement(title: "Complete primary bounds") {
          Button { taps += 1 } label: { Text("Convert").appFont(.headline) }
            .appNeumorphicButtonStyle(Capsule(), kind: .primary, role: .accent)
            .accessibilityLabel("Sized primary")
        }
        ControlMeasurement(title: "Segment · including groove") {
          HStack(spacing: 0) {
            ForEach(0..<2) { index in
              Button { selected = index; taps += 1 } label: { Text(index == 0 ? "Left" : "Right") }
                .buttonStyle(AppSegmentButtonStyle(selected: selected == index))
                .accessibilityLabel("Segment \(index)")
            }
          }.appSegmentTrack()
        }
        ControlMeasurement(title: "Complete switch bounds") {
          Toggle("Sized switch", isOn: $switchOn)
            .toggleStyle(AppNeumorphicSwitchStyle())
            .accessibilityLabel("Sized switch")
        }
        ControlMeasurement(title: "Multiline content grows naturally") {
          Button { taps += 1 } label: {
            Text("Import a UTF-8 document\nKeep Chinese, Emoji 😀 and line breaks")
          }
          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
        }
      }
      .padding(20)
    }
    .background(Color.Neumorphic.main)
    .neumorphicTheme(.openCCman)
    #if os(macOS)
      .frame(minWidth: 480, idealWidth: 600, minHeight: 650)
    #endif
  }
}

private struct ControlMeasurement<Content: View>: View {
  let title: String
  let content: Content
  @State private var size: CGSize = .zero

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("\(title) · \(Int(size.width.rounded()))×\(Int(size.height.rounded())) pt")
        .appFont(.caption)
      content
        .readSize { size = $0 }
        .overlay(Rectangle().strokeBorder(Color.orange, lineWidth: 0.5).allowsHitTesting(false))
    }
  }
}
#endif

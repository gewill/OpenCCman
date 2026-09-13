import SwiftUI

struct WhatsNewView: View {
  let release: WhatsNewRelease
  @Environment(\.presentationMode) private var presentationMode

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        Button("whats_new_done") { presentationMode.wrappedValue.dismiss() }
          .keyboardShortcut(.cancelAction)
          .padding(12)
          .accessibilityIdentifier("whats-new-done")
      }
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("whats_new_title")
              .font(.largeTitle.bold())
              .accessibilityAddTraits(.isHeader)
            Text("OpenCCman \(release.version)")
              .font(.title3)
              .foregroundColor(.secondary)
          }
          ForEach(release.cards) { card in
            VStack(alignment: .leading, spacing: 12) {
              Image(systemName: card.symbol)
                .font(.title)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
              Text(LocalizedStringKey(card.titleKey))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
              Text(LocalizedStringKey(card.detailKey))
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(16)
            .accessibilityElement(children: .combine)
          }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
      }
    }
    .foregroundColor(.primary)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("whats-new-sheet")
    #if os(macOS)
    .frame(minWidth: 360, idealWidth: 520, maxWidth: 640, minHeight: 360, idealHeight: 660, maxHeight: 760)
    #endif
  }
}

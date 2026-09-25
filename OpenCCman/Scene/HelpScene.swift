import SwiftUI

struct HelpScene: View {
  @Environment(\.selectedLocale) private var selectedLocale: Binding<LocaleConstants>

  // MARK: - life cycle

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      navi
      list
    }.background(Color.Neumorphic.main)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Help")
        .appFont(.title)
        .foregroundColor(Color.Neumorphic.secondary)
      HStack {
        BackButton()
          .padding(.horizontal, Constant.padding * 2)
        Spacer()
      }
    }
    .padding(.vertical, Constant.padding)
    .foregroundColor(Color.Neumorphic.secondary)
    .background(Color.Neumorphic.main)
  }

  var list: some View {
    ZStack(alignment: .top) {
      Color.Neumorphic.main
        .ignoresSafeArea()
      VStack(alignment: .center, spacing: 10.0) {
        Link("Online help", destination: URL(string: selectedLocale.wrappedValue.helpUrl)!)
          .padding(4)
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(Color("AccentColor"), lineWidth: 1)
          )
        Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")

        ScrollView {
          VStack(alignment: .leading, spacing: 15.0) {
            // Introduction
            Text("help_intro".localizedStringKey)
              .appFont(.body)

            // Features section
            VStack(alignment: .leading, spacing: 8) {
              Text("help_features_title".localizedStringKey)
                .appFont(.headline, weight: .semibold)
              Text("help_features_content".localizedStringKey)
                .appFont(.body)
            }

            // Global Service section (macOS only)
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
              Text("help_global_service_title".localizedStringKey)
                .appFont(.headline, weight: .semibold)
              Text("help_global_service_intro".localizedStringKey)
                .appFont(.body)

              // Method 1
              VStack(alignment: .leading, spacing: 4) {
                Text("help_method1_title".localizedStringKey)
                  .appFont(.subheadline, weight: .medium)
                Text("help_method1_content".localizedStringKey)
                  .appFont(.body)
              }
              .padding(.top, 8)

              // Method 2
              VStack(alignment: .leading, spacing: 4) {
                Text("help_method2_title".localizedStringKey)
                  .appFont(.subheadline, weight: .medium)
                Text("help_method2_content".localizedStringKey)
                  .appFont(.body)
              }
              .padding(.top, 8)

              // Service tip
              Text("help_service_tip".localizedStringKey)
                .appFont(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

              // Service Details section
              VStack(alignment: .leading, spacing: 4) {
                Text("help_service_details_title".localizedStringKey)
                  .appFont(.subheadline, weight: .medium)
                Text("help_service_details_content".localizedStringKey)
                  .appFont(.body)
              }
              .padding(.top, 8)

              // Conclusion
              Text("help_conclusion".localizedStringKey)
                .appFont(.body, weight: .medium)
                .padding(.top, 8)
            }
            #endif
          }
          .textSelectable()
        }
      }
      .padding(Constant.padding)
      .foregroundColor(Color.Neumorphic.secondary)
      .ignoresSafeArea(edges: .bottom)
    }
  }
}

struct HelpView_Previews: PreviewProvider {
  static var previews: some View {
    HelpScene()
  }
}

import SwiftUI

struct HelpScene: View {
  @AppStorage(UserDefaultsKeys.selectedLocale.rawValue) var selectedLocale: LocaleConstants = .system

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
        .font(.title)
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
        Link("Online help", destination: URL(string: selectedLocale.helpUrl)!)
          .padding(4)
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(Color.accent, lineWidth: 1)
          )
        Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")

        ScrollView {
          VStack(alignment: .leading, spacing: 15.0) {
            // Introduction
            Text("help_intro".localizedStringKey)
              .font(.body)

            // Features section
            VStack(alignment: .leading, spacing: 8) {
              Text("help_features_title".localizedStringKey)
                .font(.headline)
                .fontWeight(.semibold)
              Text("help_features_content".localizedStringKey)
                .font(.body)
            }

            // Global Service section (macOS only)
            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
              Text("help_global_service_title".localizedStringKey)
                .font(.headline)
                .fontWeight(.semibold)
              Text("help_global_service_intro".localizedStringKey)
                .font(.body)

              // Method 1
              VStack(alignment: .leading, spacing: 4) {
                Text("help_method1_title".localizedStringKey)
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("help_method1_content".localizedStringKey)
                  .font(.body)
              }
              .padding(.top, 8)

              // Method 2
              VStack(alignment: .leading, spacing: 4) {
                Text("help_method2_title".localizedStringKey)
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("help_method2_content".localizedStringKey)
                  .font(.body)
              }
              .padding(.top, 8)

              // Service tip
              Text("help_service_tip".localizedStringKey)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)

              // Service Details section
              VStack(alignment: .leading, spacing: 4) {
                Text("help_service_details_title".localizedStringKey)
                  .font(.subheadline)
                  .fontWeight(.medium)
                Text("help_service_details_content".localizedStringKey)
                  .font(.body)
              }
              .padding(.top, 8)

              // Conclusion
              Text("help_conclusion".localizedStringKey)
                .font(.body)
                .fontWeight(.medium)
                .padding(.top, 8)
            }
            #endif
          }
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

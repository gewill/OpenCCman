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
      Text("Relationship Calculator")
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
        HStack {
          Text("Thanks").bold()
          Link(destination: URL(string: "https://github.com/mumuy/relationship/")!, label: {
            Text("Open source algorithm")
              .padding(4)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.accent, lineWidth: 1)
              )
          })
        }

        ScrollView {
          VStack(alignment: .leading, spacing: 10.0) {
            Group {
              Text("help title")
            }
            .font(.title3)

            Text("help description")

            Text("All featrues")
              .font(.title3)
              .padding(.vertical)
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

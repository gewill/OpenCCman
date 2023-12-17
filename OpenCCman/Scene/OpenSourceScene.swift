import SwiftUI

struct OpenSourceScene: View {
  @Environment(\.openURL) var openURL

  var body: some View {
    VStack {
      navi
      list
    }.background(Color.Neumorphic.main)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Open Source")
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
    ScrollView {
      LazyVStack(pinnedViews: [.sectionHeaders]) {
        ForEach(allOpenSourceModels, id: \.name) { model in
          Section(header:
            HStack {
              Button {
                if let url = URL(string: model.link) {
                  openURL(url)
                }
              } label: {
                VStack(alignment: .leading) {
                  Text(model.name)
                    .font(.title3)
                  Divider()
                  Text(model.link)
                }.foregroundColor(.accentColor)
              }.softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 16)
            }
          ) {
            Text(model.licence)
              .softRectangleStyle()
          }
        }
      }
      .padding()
      .foregroundColor(Color.Neumorphic.secondary)
      .background(Color.Neumorphic.main)
    }
  }
}

struct OpenSourceScene_Previews: PreviewProvider {
  static var previews: some View {
    OpenSourceScene()
  }
}

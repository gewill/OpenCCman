import SwiftUI

struct FeedbackScene: View {
  let email = "support@gewill.org"
  var mailtoUrl: URL {
    let subject = "\(Bundle.main.appName) feedback".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    let body = "\n\n\(Bundle.main.appName) v\(Bundle.main.appVersionInfo)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    let urlString = "mailto:\(email)?subject=\(subject ?? "")&body=\(body ?? "")"
    return URL(string: urlString)!
  }

  var body: some View {
    VStack(alignment: .leading) {
      #if os(macOS)
      navi
      #endif
      list
    }
    .appFont(.body)
    .appNavigation("Feedback")
  }

  var navi: some View {
    SceneHeader("Feedback")
      .padding(.vertical, Constant.padding)
  }

  var list: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Constant.padding) {
        Text("""
        Thank you for using \(Bundle.main.appName). We are always looking for ways to improve the app and your feedback is an important part of that process. If you have any suggestions or ideas, please let us know.
        """)
        HStack {
          Link("Email: \(email)", destination: mailtoUrl)
          Button(action: {
            copyToClipboard(text: email)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
        }
      }
      .padding()
    }
  }
}

#Preview {
  FeedbackScene()
}

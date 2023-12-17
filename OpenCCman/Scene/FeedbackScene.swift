import SwiftUI

struct FeedbackScene: View {
  let email = "531sunlight@gmail.com"
  let twitter = "@BoJack_D"
  let redBook = "100260332"
  let mailtoUrl = {
    let subject = "\(Bundle.main.appName) feedback".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    let body = "\n\n\(Bundle.main.appName) v\(Bundle.main.appVersionInfo)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
    let urlString = "mailto:531sunlight@gmail.com?subject=\(subject ?? "")&body=\(body ?? "")"
    return URL(string: urlString)!
  }()

  var body: some View {
    VStack(alignment: .leading) {
      navi
      list
    }
    .font(.body)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Feedback").font(.title)
      HStack {
        BackButton()
          .padding(.horizontal, Constant.padding)
        Spacer()
      }
    }
    .padding(.vertical, Constant.padding)
  }

  var list: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Constant.padding) {
        Text("""
        Thank you for using \(Bundle.main.appName). We are always looking for ways to improve the app and your feedback is an important part of that process. If you have any suggestions or ideas, please let us know.
        """)
        Text("You can contact us via the following methods, email is prefered:")
        HStack {
          Link("Email: \(email)", destination: mailtoUrl)
          Button(action: {
            copyToClipboard(text: email)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
        }
        HStack {
          Link("Twitter：\(twitter)", destination: URL(string: "https://twitter.com/BoJack_D")!)
          Button(action: {
            copyToClipboard(text: twitter)
          }, label: {
            Image(systemName: "doc.on.doc")
          })
        }
        HStack {
          Link("小红书号：\(redBook)", destination: URL(string: "https://www.xiaohongshu.com/user/profile/56273698f53ee003a28363e7")!)
          Button(action: {
            copyToClipboard(text: redBook)
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

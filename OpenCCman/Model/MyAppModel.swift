import Foundation

struct MyAppModel: Codable, Identifiable {
  var name: String
  var des: String
  var link: String
  var iconName: String

  var id: String { name }

  static let campaigns = "?pt=117201810&ct=\(Bundle.main.appName.percentEncoding)&mt=8"

  init(name: String, des: String, appId: String, iconName: String) {
    self.name = name
    self.des = des
    link = "https://apps.apple.com/app/id\(appId)" + MyAppModel.campaigns
    self.iconName = iconName
  }
}

let allMyApps: [MyAppModel] = [
  MyAppModel(name: "iPerfman", des: "An iPerf3 tool", appId: "6447375831", iconName: "Icon-iPerfman"),
  MyAppModel(name: "Clickman", des: "Auto clicker for Mac", appId: "6449612559", iconName: "Icon-Clickman"),
  MyAppModel(name: "Secret Diary", des: "password notes", appId: "6445909382", iconName: "Icon-Secret Diary"),
]

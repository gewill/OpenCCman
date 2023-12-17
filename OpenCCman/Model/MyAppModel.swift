import Foundation

struct MyAppModel: Codable, Identifiable {
  var name: String
  var des: String
  var link: String
  var iconName: String

  var id: String { name }
}

let allMyApps: [MyAppModel] = [
  MyAppModel(name: "iPerfman", des: "An iPerf3 tool", link: "https://apps.apple.com/app/id6447375831", iconName: "Icon-iPerfman"),
  MyAppModel(name: "VoiceAI Chat", des: "chat to AI with voice", link: "https://apps.apple.com/app/id6445994863", iconName: "Icon-VoiceAI Chat"),
  MyAppModel(name: "Secret Diary", des: "password notes", link: "https://apps.apple.com/app/id6445909382", iconName: "Icon-Secret Diary"),
]

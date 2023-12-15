//
//  ContentView.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import OpenCC
import SwiftUI

struct ContentView: View {
  @State var text: String = ""
  @State var result: String = ""

  let converter = try! ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom])

  var body: some View {
    VStack {
      Text("OpenCCman").font(.title)
      TextEditor(text: $text)
        .frame(minHeight: 200)
      Divider()
      Text(result)
      Spacer()
      Button("Convert") {
        result = converter.convert(text)
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}

//
//  ContentView.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import OpenCC
import SwiftUI

struct ContentView: View {
  @State var text: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
  @State var result: String = ""

  let converter = try! ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom])

  var body: some View {
    VStack(alignment: .leading) {
      Group {
        Text("OpenCCman").font(.title)
        Text("Convert Chinese text with OpenCC")
      }
      .frame(maxWidth: .infinity)
      
      Text("Input").font(.headline)
      TextEditor(text: $text)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
        .padding(6)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.primary.opacity(0.3), lineWidth: 1)
        )
      Text("Result").font(.headline)
      Text(result)
        .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300, alignment: .topLeading)
        .padding(6)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.primary.opacity(0.3), lineWidth: 1)
        )
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

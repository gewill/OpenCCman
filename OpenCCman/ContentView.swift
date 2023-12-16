//
//  ContentView.swift
//  OpenCCman
//
//  Created by will on 2023/12/15.
//

import Neumorphic
import OpenCC
import SwiftUI

struct ContentView: View {
  @State var text: String = "鼠标里面的硅二极管坏了，导致光标分辨率降低。"
  @State var result: String = ""

  let converter = try! ChineseConverter(options: [.traditionalize, .twStandard, .twIdiom])

  var body: some View {
    ZStack(alignment: .top) {
      Color.main
        .ignoresSafeArea()
      VStack(alignment: .leading) {
        Group {
          Text("OpenCCman").font(.title)
          Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")
        }
        .frame(maxWidth: .infinity)

        Text("Input").font(.headline)
        TextEditor(text: $text)
          .clearTextEdtorStyle()
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
          .padding(6)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
        Button(action: {
          result = converter.convert(text)
        }, label: {
          Text("Convert")
        })
        .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 10, mainColor: Color.accentColor, textColor: Color.Neumorphic.main)
        Text("Result").font(.headline)
        Text(result)
          .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300, alignment: .topLeading)
          .padding(6)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.secondary, lineWidth: 1)
          )
      }
      .foregroundColor(Color.Neumorphic.secondary)
      .textSelectable()
      .padding()
    }
  }
}

#Preview {
  ContentView()
}

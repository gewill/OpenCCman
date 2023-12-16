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
  @ObservedObject var viewModel = ViewModel()

  var body: some View {
    ZStack(alignment: .top) {
      Color.main
        .ignoresSafeArea()
      VStack(alignment: .leading, spacing: Constant.padding) {
        Group {
          Text("OpenCCman").font(.title)
          Text("Convert Chinese text with [OpenCC](https://github.com/BYVoid/OpenCC)")
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading) {
          SegmentView(title: "Target Language", options: ViewModel.Language.allCases, seleted: $viewModel.targetOptions)
          Group {
            SegmentView(title: "Variant", options: ViewModel.Variant.allCases, seleted: $viewModel.variantOptions)
            SegmentView(title: "Region", options: ViewModel.Region.allCases, seleted: $viewModel.regionOptions)
          }
          .disabled(viewModel.targetOptions == .simplified)
        }
        .padding(Constant.padding)
        .background(
          RoundedRectangle(cornerRadius: Constant.cornerRadius)
            .fill(Color.Neumorphic.main)
            .softOuterShadow()
        )

        VStack(alignment: .leading, spacing: Constant.padding) {
          Text("Source").font(.headline)
          TextEditor(text: $viewModel.inputText)
            .clearTextEdtorStyle()
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
            .padding(Constant.padding)
            .background(
              RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary, lineWidth: 1)
            )
        }
        .padding(Constant.padding)
        .background(
          RoundedRectangle(cornerRadius: Constant.cornerRadius)
            .fill(Color.Neumorphic.main)
            .softOuterShadow()
        )

        VStack(alignment: .leading, spacing: Constant.padding) {
          HStack {
            Text("Result").font(.headline)
            Button(action: {
              copyToClipboard(text: viewModel.resultText)
            }, label: {
              Image(systemName: "doc.on.doc")
            })
            .softButtonStyle(Circle(), padding: 6)
            Spacer()
            Button(action: {
              viewModel.translate()
            }, label: {
              Text("Convert")
            })
            .softButtonStyle(RoundedRectangle(cornerRadius: 20), padding: 10, mainColor: Color.accentColor, textColor: Color.Neumorphic.main)
          }
          Text(viewModel.resultText)
            .textSelectable()
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300, alignment: .topLeading)
            .padding(Constant.padding)
            .background(
              RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary, lineWidth: 1)
            )
        }
        .padding(Constant.padding)
        .background(
          RoundedRectangle(cornerRadius: Constant.cornerRadius)
            .fill(Color.Neumorphic.main)
            .softOuterShadow()
        )
      }
      .foregroundColor(Color.Neumorphic.secondary)
      .padding(Constant.padding)
    }
    .frame(minWidth: 300)
  }
}

#Preview {
  ContentView()
}

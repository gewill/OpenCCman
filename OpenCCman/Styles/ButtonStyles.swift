//
//  ButtonStyles.swift
//  iperfman
//
//  Created by will on 04/12/2022.
//

import Neumorphic
import SwiftUI

public extension View {
  func smallSizeSoftButtonStyle<S: Shape>(_ content: S = Circle(), mainColor: Color = Color.Neumorphic.main, textColor: Color = Color.Neumorphic.secondary, darkShadowColor: Color = Color.Neumorphic.darkShadow, lightShadowColor: Color = Color.Neumorphic.lightShadow, pressedEffect: SoftButtonPressedEffect = .hard) -> some View {
    buttonStyle(FixedSizeSoftDynamicButtonStyle(content, mainColor: mainColor, textColor: textColor, darkShadowColor: darkShadowColor, lightShadowColor: lightShadowColor, pressedEffect: pressedEffect, padding: 0, size: Constant.smallButtonSize))
  }
}

struct ButtonStyles_Previews: PreviewProvider {
  static var previews: some View {
    Button {} label: {
      Image(systemName: "xmark")
    }
    .smallSizeSoftButtonStyle(mainColor: Color.accentColor, textColor: Color.main)
  }
}

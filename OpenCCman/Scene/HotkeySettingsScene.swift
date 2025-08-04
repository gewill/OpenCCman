//
//  ShortcutSettingsScene.swift
//  OpenCCman
//
//  Created by will on 2024/07/30.
//

import SwiftUI
import Neumorphic
#if os(macOS)
import KeyboardShortcuts
#endif

struct ShortcutSettingsScene: View {
    #if os(macOS)
    @ObservedObject private var shortcutService = GlobalShortcutService.shared
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            navi
            list
        }
        .background(Color.Neumorphic.main)
    }
    
    var navi: some View {
        ZStack(alignment: .center) {
            Text("Shortcut Settings".localizedStringKey)
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
        ZStack(alignment: .top) {
            Color.Neumorphic.main
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Constant.padding) {
                    #if os(macOS)
                    // Permission Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Permissions".localizedStringKey)
                            .font(.headline)

                        HStack {
                            Image(systemName: shortcutService.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(shortcutService.hasAccessibilityPermission ? .green : .orange)

                            Text(shortcutService.hasAccessibilityPermission ? "Accessibility permission granted".localizedStringKey : "Accessibility permission required".localizedStringKey)
                                .font(.body)

                            Spacer()

                            if !shortcutService.hasAccessibilityPermission {
                                Button("Grant Permission".localizedStringKey) {
                                    shortcutService.requestAccessibilityPermission()
                                }
                                .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 6)
                            }

                            Button("Refresh".localizedStringKey) {
                                shortcutService.checkAccessibilityPermission()
                            }
                            .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 6)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Enable/Disable Toggle
                    HStack {
                        Text("Enable Global Shortcut".localizedStringKey)
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $shortcutService.isEnabled)
                            .toggleStyle(SwitchToggleStyle())
                            .disabled(!shortcutService.hasAccessibilityPermission)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Convert Selected Text Shortcut
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Convert Selected Text Shortcut".localizedStringKey)
                            .font(.headline)

                        HStack {
                            KeyboardShortcuts.Recorder("", name: .convertSelectedText)
                                .frame(minWidth: 150)

                            Spacer()

                            Button("Test".localizedStringKey) {
                                shortcutService.convertSelectedText()
                            }
                            .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Open Selected Text Shortcut
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Open Selected Text Shortcut".localizedStringKey)
                            .font(.headline)

                        HStack {
                            KeyboardShortcuts.Recorder("", name: .openSelectedText)
                                .frame(minWidth: 150)

                            Spacer()

                            Button("Test".localizedStringKey) {
                                shortcutService.openSelectedText()
                            }
                            .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 8)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to Use".localizedStringKey)
                            .font(.headline)

                        Text(shortcutService.hasAccessibilityPermission ?
                            "shortcut_instructions_enabled".localizedStringKey :
                            "shortcut_instructions_disabled".localizedStringKey)
                        .font(.body)
                        .foregroundColor(Color.Neumorphic.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Additional Info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips".localizedStringKey)
                            .font(.headline)

                        Text("shortcut_tips".localizedStringKey)
                        .font(.body)
                        .foregroundColor(Color.Neumorphic.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    #else
                    // iOS placeholder
                    VStack(alignment: .center, spacing: 20) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 60))
                            .foregroundColor(Color.Neumorphic.secondary.opacity(0.5))

                        Text("Global Shortcut".localizedStringKey)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Global shortcut feature is only available on macOS".localizedStringKey)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.Neumorphic.secondary.opacity(0.7))
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )
                    #endif
                }
                .padding(Constant.padding)
            }
            .foregroundColor(Color.Neumorphic.secondary)
        }
    }


}

struct ShortcutSettingsScene_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutSettingsScene()
    }
}

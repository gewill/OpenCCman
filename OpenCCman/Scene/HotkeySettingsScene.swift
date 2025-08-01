//
//  HotkeySettingsScene.swift
//  OpenCCman
//
//  Created by will on 2024/07/30.
//

import SwiftUI
import Neumorphic
#if os(macOS)
import KeyboardShortcuts
#endif

struct HotkeySettingsScene: View {
    #if os(macOS)
    @ObservedObject private var hotkeyService = GlobalHotkeyService.shared
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
            Text("Hotkey Settings".localizedStringKey)
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

                        VStack(alignment: .leading, spacing: 8) {
                            // Accessibility Permission
                            HStack {
                                Image(systemName: hotkeyService.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(hotkeyService.hasAccessibilityPermission ? .green : .orange)

                                Text(hotkeyService.hasAccessibilityPermission ? "Accessibility permission granted".localizedStringKey : "Accessibility permission required".localizedStringKey)
                                    .font(.body)

                                Spacer()

                                if !hotkeyService.hasAccessibilityPermission {
                                    Button("Grant Permission".localizedStringKey) {
                                        hotkeyService.requestAccessibilityPermission()
                                    }
                                    .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 6)
                                }
                            }

                            // Apple Events Permission
                            HStack {
                                Image(systemName: hotkeyService.hasAppleEventsPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(hotkeyService.hasAppleEventsPermission ? .green : .orange)

                                Text(hotkeyService.hasAppleEventsPermission ? "Apple Events permission granted".localizedStringKey : "Apple Events permission required".localizedStringKey)
                                    .font(.body)

                                Spacer()

                                if !hotkeyService.hasAppleEventsPermission {
                                    Button("Grant Permission".localizedStringKey) {
                                        hotkeyService.requestAppleEventsPermission()
                                    }
                                    .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 6)
                                }
                            }

                            // Refresh Button
                            HStack {
                                Spacer()
                                Button("Refresh".localizedStringKey) {
                                    hotkeyService.checkAccessibilityPermission()
                                }
                                .softButtonStyle(RoundedRectangle(cornerRadius: 8), padding: 8)
                            }
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
                        Text("Enable Global Hotkey".localizedStringKey)
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $hotkeyService.isEnabled)
                            .toggleStyle(SwitchToggleStyle())
                            .disabled(!hotkeyService.hasAccessibilityPermission)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Keyboard Shortcut Recorder
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Keyboard Shortcut".localizedStringKey)
                            .font(.headline)

                        HStack {
                            KeyboardShortcuts.Recorder("", name: .convertSelectedText)
                                .frame(minWidth: 150)

                            Spacer()

                            Button("Test".localizedStringKey) {
                                hotkeyService.convertSelectedText()
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

                        Text(hotkeyService.hasAccessibilityPermission ?
                            "hotkey_instructions_enabled".localizedStringKey :
                            "hotkey_instructions_disabled".localizedStringKey)
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

                        Text("hotkey_tips".localizedStringKey)
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

                        Text("Global Hotkey".localizedStringKey)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Global hotkey feature is only available on macOS".localizedStringKey)
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

struct HotkeySettingsScene_Previews: PreviewProvider {
    static var previews: some View {
        HotkeySettingsScene()
    }
}

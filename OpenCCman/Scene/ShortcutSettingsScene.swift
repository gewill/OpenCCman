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
    @AppStorage(UserDefaultsKeys.shortcutFailureToast.rawValue) private var failureToast = true
    @AppStorage(UserDefaultsKeys.shortcutSuccessToast.rawValue) private var successToast = false
    @ObservedObject private var shortcutService = GlobalShortcutService.shared
    @Environment(\.locale) private var locale
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            navi
            list
        }
        .background(Color.Neumorphic.main)
        #if os(macOS)
        .onAppear {
            shortcutService.checkAccessibilityPermission()
        }
        #endif
    }
    
    var navi: some View {
        SceneHeader("Shortcut Settings".localizedStringKey, buttonInset: Constant.padding * 2)
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
                            .appFont(.headline)

                        // One row while it fits. Otherwise the buttons move under
                        // the status, side by side or stacked, so no word splits.
                        WidthFittingView {
                            HStack {
                                permissionIcon
                                permissionStatus
                                Spacer()
                                permissionButtons
                            }
                        } fallback: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    permissionIcon
                                    permissionStatus
                                }
                                WidthFittingView {
                                    HStack { permissionButtons }
                                } fallback: {
                                    VStack(alignment: .leading) { permissionButtons }
                                }
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
                        Text("Enable Global Shortcut".localizedStringKey)
                            .appFont(.headline)
                        Spacer()
                        Toggle("Enable Global Shortcut", isOn: $shortcutService.isEnabled)
                            .toggleStyle(AppNeumorphicSwitchStyle())
                            .accessibilityLabel(Text("Enable Global Shortcut"))
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
                            .appFont(.headline)

                        HStack {
                          KeyboardShortcuts.Recorder("", name: .convertSelectedText)
                              .frame(minWidth: 150)

                            Spacer()
                          Button("Test".localizedStringKey) {
                              shortcutService.convertSelectedText()
                          }
                          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
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
                            .appFont(.headline)

                        HStack {
                          KeyboardShortcuts.Recorder("", name: .openSelectedText)
                              .frame(minWidth: 150)

                            Spacer()

                          Button("Test".localizedStringKey) {
                              shortcutService.openSelectedText()
                          }
                          .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("shortcut_feedback_title".localizedStringKey).appFont(.headline)
                        feedbackToggle("shortcut_feedback_failure", isOn: $failureToast,
                            identifier: "shortcut-failure-toast-toggle")
                        feedbackToggle("shortcut_feedback_success", isOn: $successToast,
                            identifier: "shortcut-success-toast-toggle")
                        Text("shortcut_feedback_detail".localizedStringKey)
                            .appFont(.body)
                            .foregroundColor(Color.Neumorphic.secondary.opacity(0.8))
                    }
                    .appFont(.body)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: Constant.cornerRadius)
                        .fill(Color.Neumorphic.main).softOuterShadow())

                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to Use".localizedStringKey)
                            .appFont(.headline)

                        Text(verbatim: (shortcutService.hasAccessibilityPermission ?
                            "shortcut_instructions_enabled" : "shortcut_instructions_disabled")
                            .localizedNamingAccessibilityPermission(in: locale))
                        .appFont(.body)
                        .foregroundColor(Color.Neumorphic.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: Constant.cornerRadius)
                            .fill(Color.Neumorphic.main)
                            .softOuterShadow()
                    )

                    // Services remain an alternative without Accessibility permission.
                    VStack(alignment: .leading, spacing: 10) {
                        Text("shortcut_services_title".localizedStringKey)
                            .appFont(.headline)

                        Text(verbatim: "shortcut_services_content".localizedNamingAccessibilityPermission(in: locale))
                        .appFont(.body)
                        .foregroundColor(Color.Neumorphic.secondary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Open Keyboard Settings".localizedStringKey) {
                            shortcutService.openKeyboardShortcutSettings()
                        }
                        .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
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
                            .appFont(.headline)

                        Text("shortcut_tips".localizedStringKey)
                        .appFont(.body)
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
                            .appFont(.title2, weight: .semibold)

                        Text("Global shortcut feature is only available on macOS".localizedStringKey)
                            .appFont(.body)
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

    #if os(macOS)
    private func feedbackToggle(_ key: String, isOn: Binding<Bool>, identifier: String) -> some View {
        HStack(spacing: 12) {
            Text(key.localizedStringKey)
                .appFont(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Toggle(key, isOn: isOn)
                .toggleStyle(AppNeumorphicSwitchStyle())
                .accessibilityLabel(Text(key.localizedStringKey))
                .accessibilityIdentifier(identifier)
        }
    }

    private var permissionIcon: some View {
        Image(systemName: shortcutService.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundColor(shortcutService.hasAccessibilityPermission ? .green : .orange)
    }

    private var permissionStatus: some View {
        Text(verbatim: (shortcutService.hasAccessibilityPermission ? "Accessibility permission granted" : "Accessibility permission required")
            .localizedNamingAccessibilityPermission(in: locale))
            .appFont(.body)
    }

    @ViewBuilder private var permissionButtons: some View {
        if !shortcutService.hasAccessibilityPermission {
            Button("Grant Permission".localizedStringKey) {
                shortcutService.requestAccessibilityPermission()
            }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
        }

        Button("Refresh".localizedStringKey) {
            shortcutService.checkAccessibilityPermission()
        }
        .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
    }
    #endif
}

struct ShortcutSettingsScene_Previews: PreviewProvider {
    static var previews: some View {
        ShortcutSettingsScene()
    }
}

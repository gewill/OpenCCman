#if os(iOS)
  import BetterSafariView
#endif
import SwiftUI
import Neumorphic
import SwiftUIRouter

struct SettingsScene: View {
  @EnvironmentObject var navigator: Navigator
  @EnvironmentObject private var whatsNew: WhatsNewCoordinator
  @EnvironmentObject private var whatsNewWindow: WhatsNewWindowState
  @Environment(\.openURL) var openURL

  @Environment(\.selectedLocale) private var selectedLocale: Binding<LocaleConstants>
  @AppStorage(UserDefaultsKeys.hasHapticFeedback.rawValue) var hasHapticFeedback: Bool = true
  #if os(iOS)
    @State private var presentingSafariView: Bool = false
  #endif
  @AppStorage(UserDefaultsKeys.isPro.rawValue) var isPro: Bool = false
  #if os(macOS)
    @AppStorage(UserDefaultsKeys.showMenuBarIcon.rawValue) var showMenuBarIcon: Bool = false
  #endif

  var body: some View {
    VStack {
      navi
      list
    }
    .background(Color.Neumorphic.main)
  }

  var navi: some View {
    ZStack(alignment: .center) {
      Text("Settings")
        .font(.title)
        .foregroundColor(Color.Neumorphic.secondary)
      HStack {
        BackButton()
          .padding(.horizontal, Constant.padding)
        Spacer()
      }
    }
    .padding(.vertical, Constant.padding)
  }

  var list: some View {
    ScrollView {
      VStack(spacing: Padding.verLarge) {
        VStack(spacing: Constant.padding) {
          CellButton(title: "customer_center_title") {
            navigator.navigate("/settings/customerCenter")
          }
          .accessibilityIdentifier("customer-center-settings")
          Divider()
          HStack(alignment: .center, spacing: 6) {
            Text("App Version")
            Spacer()
            Text(Bundle.main.appVersionInfo)
          }
          Divider()
          if whatsNew.release != nil {
            CellButton(title: "whats_new_title") {
              whatsNewWindow.manualRequest = UUID()
            }
            .accessibilityIdentifier("whats-new-settings")
            Divider()
          }
          CellButton(title: "Review on App Store") {
            openURL(URL(string: "https://apps.apple.com/app/relationship/id6474449401?mt=12&action=write-review")!)
          }
          Divider()
          CellButton(title: "Open Source") {
            navigator.navigate("/settings/openSource")
          }
          Divider()
          #if os(macOS)
            CellButton(title: "Privacy Policy") {
              openURL(URL(string: selectedLocale.wrappedValue.privacyUrl)!)
            }
          #elseif os(iOS)
            CellButton(title: "Privacy Policy") {
              presentingSafariView = true
            }
            .safariView(isPresented: $presentingSafariView) {
              SafariView(
                url: URL(string: selectedLocale.wrappedValue.privacyUrl)!,
                configuration: SafariView.Configuration(
                  entersReaderIfAvailable: false,
                  barCollapsingEnabled: true
                )
              )
              .preferredBarAccentColor(Color.Neumorphic.main)
              .preferredControlAccentColor(Color.Neumorphic.secondary)
              .dismissButtonStyle(.done)
            }
          #endif
          Divider()
          CellButton(title: "Feedback") {
            navigator.navigate("/settings/feedback")
          }
        }.softRectangleStyle()

        #if os(macOS)
          VStack(spacing: Constant.padding) {
            HStack(alignment: .center, spacing: 6) {
              Text("Show Menu Bar Icon".localizedStringKey)
              Spacer()
              Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                .toggleStyle(AppNeumorphicSwitchStyle())
                .accessibilityLabel(Text("Show Menu Bar Icon"))
            }

            Divider()
            if #available(macOS 13.0, *) {
              HStack(alignment: .center, spacing: 6) {
                Text("Launch at login".localizedStringKey)
                Spacer()
                LaunchAtLogin.Toggle { Text("Launch at login".localizedStringKey) }
                  .labelsHidden()
                  .toggleStyle(AppNeumorphicSwitchStyle())
                  .accessibilityLabel(Text("Launch at login".localizedStringKey))
              }
              Divider()
            }
            CellButton(title: "Global Shortcut") {
              navigator.navigate("/settings/shortcut")
            }
          }.softRectangleStyle()
        #endif

        VStack(spacing: Constant.padding) {
          CellButton(title: "Language") {
            navigator.navigate("/settings/changeLanguage")
          }
          Divider()
          CellButton(title: "Appearance") {
            navigator.navigate("/settings/changeAppearance")
          }
        }
        .softRectangleStyle()

        if isPro == false {
          VStack(alignment: .leading) {
            Text("My more apps:")
              .font(.headline)
            ForEach(allMyApps) { model in

              HStack(alignment: .center, spacing: 6) {
                Image(model.iconName)
                  .resizable()
                  .frame(width: 60, height: 60)
                VStack(alignment: .leading) {
                  Text(model.name.localizedStringKey)
                    .font(.headline)
                  Text(model.des.localizedStringKey)
                    .font(.body)
                }
                Spacer()

                Button(action: {
                  openURL(URL(string: model.link)!)
                }) {
                  Text("Get")
                }
                .appNeumorphicButtonStyle(Capsule(), role: .accent)
              }
            }
          }
          .softRectangleStyle()
        }
      }
      .padding()
      .foregroundColor(Color.Neumorphic.secondary)
      .background(Color.Neumorphic.main)
    }
  }
}

struct SettingsScene_Previews: PreviewProvider {
  static var previews: some View {
    SettingsScene()
      .environmentObject(WhatsNewCoordinator(version: "1.3", skipAutomatic: true))
      .environmentObject(WhatsNewWindowState())
  }
}

// Adapted from sindresorhus/LaunchAtLogin-Modern, a04ec1c.
// MIT license: docs/licenses/LaunchAtLogin-Modern.txt
#if os(macOS)
import SwiftUI
import ServiceManagement
import os.log

@available(macOS 13.0, *)
public enum LaunchAtLogin {
	private static let logger = Logger(subsystem: "com.sindresorhus.LaunchAtLogin", category: "main")
	fileprivate static let observable = Observable()

	/**
	Toggle “launch at login” for your app or check whether it's enabled.
	*/
	public static var isEnabled: Bool {
		get { SMAppService.mainApp.status == .enabled }
		set {
			observable.objectWillChange.send()

			do {
				if newValue {
					if SMAppService.mainApp.status == .enabled {
						try? SMAppService.mainApp.unregister()
					}

					try SMAppService.mainApp.register()
				} else {
					try SMAppService.mainApp.unregister()
				}
			} catch {
				logger.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
			}
		}
	}

	/**
	Whether the app was launched at login.

	- Important: This property must only be checked in `NSApplicationDelegate#applicationDidFinishLaunching`.
	*/
	public static var wasLaunchedAtLogin: Bool {
		let event = NSAppleEventManager.shared().currentAppleEvent
		return event?.eventID == kAEOpenApplication
			&& event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
	}
}

@available(macOS 13.0, *)
extension LaunchAtLogin {
	final class Observable: ObservableObject {
		var isEnabled: Bool {
			get { LaunchAtLogin.isEnabled }
			set {
				LaunchAtLogin.isEnabled = newValue
			}
		}
	}
}

@available(macOS 13.0, *)
extension LaunchAtLogin {
	/**
	This package comes with a `LaunchAtLogin.Toggle` view which is like the built-in `Toggle` but with a predefined binding and label. Clicking the view toggles “launch at login” for your app.

	```
	struct ContentView: View {
		var body: some View {
			LaunchAtLogin.Toggle()
		}
	}
	```

	The default label is `"Launch at login"`, but it can be overridden for localization and other needs:

	```
	struct ContentView: View {
		var body: some View {
			LaunchAtLogin.Toggle {
				Text("Launch at login")
			}
		}
	}
	```
	*/
	public struct Toggle<Label: View>: View {
		@ObservedObject private var launchAtLogin = LaunchAtLogin.observable
		private let label: Label

		/**
		Creates a toggle that displays a custom label.

		- Parameters:
			- label: A view that describes the purpose of the toggle.
		*/
		public init(@ViewBuilder label: () -> Label) {
			self.label = label()
		}

		public var body: some View {
			SwiftUI.Toggle(isOn: $launchAtLogin.isEnabled) { label }
		}
	}
}

@available(macOS 13.0, *)
extension LaunchAtLogin.Toggle<Text> {
	/**
	Creates a toggle that generates its label from a localized string key.

	This initializer creates a ``Text`` view on your behalf with the provided `titleKey`.

	- Parameters:
		- titleKey: The key for the toggle's localized title, that describes the purpose of the toggle.
	*/
	public init(_ titleKey: LocalizedStringKey) {
		label = Text(titleKey)
	}

	/**
	Creates a toggle that generates its label from a string.

	This initializer creates a `Text` view on your behalf with the provided `title`.

	- Parameters:
		- title: A string that describes the purpose of the toggle.
	*/
	public init(_ title: some StringProtocol) {
		label = Text(title)
	}

	/**
	Creates a toggle with the default title of `Launch at login`.
	*/
	public init() {
		self.init("Launch at login")
	}
}
#endif

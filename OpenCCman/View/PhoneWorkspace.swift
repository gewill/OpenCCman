#if os(iOS)
  import Neumorphic
  import SwiftUI
  import SwiftUIRouter

  struct PhoneWorkspace: View {
    @EnvironmentObject private var navigator: Navigator
    @EnvironmentObject private var viewModel: HomeViewModel
    @EnvironmentObject private var windowState: WhatsNewWindowState
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.locale) private var locale
    @AppStorage(UserDefaultsKeys.isPro.rawValue) private var isPro = false
    @State private var keyboardVisible = false
    var export: () -> Void

    var body: some View {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          header.padding(.horizontal, 12).padding(.vertical, 8)
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              Button {
                UIApplication.shared.endEditing()
                windowState.showingConversionSettings = true
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  Label("workspace_settings", systemImage: "slider.horizontal.3").appFont(.headline)
                  Text((viewModel.selectedPreset?.title ?? "preset_custom").localizedStringKey)
                    .appFont(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 12))
              SourcePane(editorHeight: max(180, min(200, geometry.size.height * 0.25)),
                         showsConversionAction: !showsPinnedConversionAction)
              ResultPane(editorHeight: 200, export: export)
              if !isPro, !keyboardVisible {
                MyAppView()
              }
            }
            .padding(12)
          }
          if showsPinnedConversionAction {
            HStack(spacing: 16) {
              if keyboardVisible {
                Button { UIApplication.shared.endEditing() } label: {
                  Image(systemName: "keyboard.chevron.compact.down")
                }
                .appNeumorphicButtonStyle(Circle(), kind: .icon)
                .accessibilityLabel(Text("workspace_dismiss_keyboard"))
              }
              Spacer(minLength: 0)
              ConversionAction()
            }
            .padding(12)
            .background(Color.Neumorphic.main)
          }
        }
      }
      .background(WorkspaceKeyboardProbe(isVisible: $keyboardVisible).frame(width: 0, height: 0))
      .sheet(isPresented: $windowState.showingConversionSettings, onDismiss: {
        windowState.conversionSettingsIsActive = false
      }) {
        ConversionSettingsSheet()
          .environment(\.locale, locale)
          .environmentObject(viewModel)
          .environmentObject(windowState)
      }
    }

    // Keep the action reachable above the keyboard and while a long conversion
    // is running. Otherwise it shares the source header instead of reserving a
    // full-width footer that hides the result pane.
    private var showsPinnedConversionAction: Bool {
      keyboardVisible || viewModel.isLoading
    }

    private var header: some View {
      HStack(alignment: .center, spacing: 12) {
        Text("OpenCCman").appFont(.title2).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Menu {
          Button("Help") { navigator.navigate("/help") }
          Button("Pro") { navigator.navigate("/pro") }.keyboardShortcut("p")
          Button("Settings") { navigator.navigate("/settings") }.keyboardShortcut(",")
        } label: { Image(systemName: "ellipsis.circle").font(.system(size: AppControlMetrics.iconSize)).frame(width: AppControlMetrics.height, height: AppControlMetrics.height) }
          .accessibilityLabel(Text("workspace_more"))
      }
      .foregroundColor(Color.Neumorphic.secondary)
    }
  }

  /// Observe keyboard intersection in this view's own window. No global keyboard
  /// height or manual bottom inset competes with SwiftUI's safe-area adjustment.
  private struct WorkspaceKeyboardProbe: UIViewRepresentable {
    @Binding var isVisible: Bool
    func makeUIView(context _: Context) -> ProbeView {
      let view = ProbeView()
      view.changed = { isVisible = $0 }
      return view
    }

    func updateUIView(_ uiView: ProbeView, context _: Context) {
      uiView.changed = { isVisible = $0 }
    }

    final class ProbeView: UIView {
      var changed: ((Bool) -> Void)?
      private var tokens: [NSObjectProtocol] = []
      override init(frame: CGRect) {
        super.init(frame: frame)
        for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification] {
          tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            guard let self, let window else { return }
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            let local = window.convert(frame, from: window.screen.coordinateSpace)
            changed?(note.name != UIResponder.keyboardWillHideNotification
              && window.isKeyWindow && window.bounds.intersection(local).height > 0)
          })
        }
      }

      @available(*, unavailable)
      required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
    }
  }
#endif

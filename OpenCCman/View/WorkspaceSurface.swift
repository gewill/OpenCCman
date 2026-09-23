import Neumorphic
import SwiftUI
import SwiftUIRouter

/// Editors remain in one ZStack on every supported OS. Switching HStack/VStack
/// subtrees would destroy TextEditor's native selection, marked text and focus.
struct WorkspaceSurface: View {
  @EnvironmentObject private var viewModel: HomeViewModel
  @EnvironmentObject private var navigator: Navigator
  @EnvironmentObject private var windowState: WhatsNewWindowState
  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(\.locale) private var locale
  @AppStorage(UserDefaultsKeys.isPro.rawValue) private var isPro = false
  private var preferences = WorkspacePreferences()
  @State private var previousAxis: WorkspaceLayoutResolution.Axis?
  var platform: WorkspaceLayoutResolution.Platform = .mac
  var export: () -> Void

  init(platform: WorkspaceLayoutResolution.Platform = .mac, export: @escaping () -> Void) {
    self.platform = platform
    self.export = export
  }

  var body: some View {
    GeometryReader { geometry in
      let resolution = WorkspaceLayoutResolution.resolve(
        preference: preferences.value, width: Double(max(0, geometry.size.width - 24)),
        platform: platform, accessibility: sizeCategory.isAccessibilityCategory, previousAxis: previousAxis
      )
      VStack(spacing: 12) {
        controls(resolution: resolution)
        HStack(alignment: .top, spacing: 0) {
          if resolution.inspectorWidth > 0 {
            ScrollView { ConversionInspector().padding(4) }
              .frame(width: resolution.inspectorWidth)
          }
          ScrollView {
            VStack(spacing: 20) {
              WorkspacePanes(resolution: resolution, preference: Binding(
                get: { preferences.value }, set: { preferences.value = $0 }
              ),
              availableHeight: max(400, geometry.size.height - 110), export: export)
              if !isPro {
                MyAppView()
              }
            }
            .padding(4)
          }
          .padding(.leading, resolution.inspectorWidth > 0 ? 24 : 0)
        }
      }
      .padding(12)
      .onAppear { previousAxis = resolution.axis }
      .onChange(of: resolution.axis) { previousAxis = $0 }
    }
    .sheet(isPresented: $windowState.showingConversionSettings, onDismiss: {
      windowState.conversionSettingsIsActive = false
    }) {
      ConversionSettingsSheet()
        .environment(\.locale, locale)
        .environmentObject(viewModel)
        .environmentObject(windowState)
    }
    #if os(macOS)
    .onReceive(NotificationCenter.default.publisher(for: .workspaceCommand)) { notification in
      guard let target = notification.object as? NSWindow, target === viewModel.window,
            let command = notification.userInfo?["command"] as? String else { return }
      switch command {
      case "horizontal": preferences.value.axis = .horizontal
      case "vertical": preferences.value.axis = .vertical
      case "equal": resetRatio()
      case "inspector": windowState.showingConversionSettings = true
      default: break
      }
    }
    .toolbar {
      ToolbarItem {
        Menu {
          Button("Help") { navigator.navigate("/help") }
          Button("Pro") { navigator.navigate("/pro") }.keyboardShortcut("p")
          Button("Settings") { navigator.navigate("/settings") }.keyboardShortcut(",")
        } label: { Label("workspace_more", systemImage: "ellipsis.circle") }
      }
      ToolbarItem { Button { windowState.showingConversionSettings = true } label: {
        Label("Conversion Preset", systemImage: "slider.horizontal.3")
      } }
    }
    #endif
  }

  private func controls(resolution: WorkspaceLayoutResolution) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      #if os(iOS)
        HStack {
          Text("OpenCCman").font(.headline)
          Spacer()
          Menu {
            Button("Help") { navigator.navigate("/help") }
            Button("Pro") { navigator.navigate("/pro") }.keyboardShortcut("p")
            Button("Settings") { navigator.navigate("/settings") }.keyboardShortcut(",")
          } label: { Image(systemName: "ellipsis.circle").font(.system(size: AppControlMetrics.iconSize)).frame(width: AppControlMetrics.height, height: AppControlMetrics.height) }
            .accessibilityLabel(Text("workspace_more"))
        }
      #endif
      if sizeCategory.isAccessibilityCategory || resolution.editorWidth < 460 {
        VStack(alignment: .leading, spacing: 8) {
          Button("workspace_settings") { windowState.showingConversionSettings = true }
          Menu("workspace_layout") {
            Button("workspace_horizontal") { preferences.value.axis = .horizontal }
            Button("workspace_vertical") { preferences.value.axis = .vertical }
          }
          ConversionAction()
        }
      } else {
        HStack(spacing: 12) {
          Button {
            if resolution.inspectorWidth > 0 {
              preferences.value.inspector = .hidden
            } else if resolution.editorWidth >= 1100 {
              preferences.value.inspector = .shown
            } else {
              windowState.showingConversionSettings = true
            }
          } label: { Image(systemName: "sidebar.left") }
            .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8), kind: .icon)
            .accessibilityLabel(Text("workspace_settings"))
          WorkspaceLayoutPicker(selection: Binding(get: { preferences.value.axis }, set: { preferences.value.axis = $0 }),
                                effectiveAxis: resolution.axis)
          Spacer(minLength: 0)
          ConversionAction()
        }
      }
      if resolution.isTemporaryVertical {
        Text("workspace_temporary_vertical").font(.caption).foregroundColor(.secondary)
      }
      Menu("workspace_pane_sizes") {
        Button("workspace_equal") { resetRatio() }
        Button("workspace_source_larger") { adjustRatio(by: 0.05, axis: resolution.axis) }
        Button("workspace_result_larger") { adjustRatio(by: -0.05, axis: resolution.axis) }
      }
      .font(.caption)
      .frame(minHeight: AppControlMetrics.height)
    }
  }

  private func resetRatio() {
    preferences.value.horizontalRatio = 0.5
    preferences.value.verticalRatio = 0.5
  }

  private func adjustRatio(by delta: Double, axis: WorkspaceLayoutResolution.Axis) {
    let value = min(0.7, max(0.3, preferences.value.ratio(for: axis) + delta))
    if axis == .horizontal {
      preferences.value.horizontalRatio = value
    } else {
      preferences.value.verticalRatio = value
    }
  }
}

struct WorkspaceLayoutPicker: View {
  @Binding var selection: WorkspaceLayoutPreference.Axis
  let effectiveAxis: WorkspaceLayoutResolution.Axis

  var body: some View {
    HStack(spacing: 0) {
      option(.horizontal, title: "workspace_horizontal", symbol: "rectangle.split.2x1")
      option(.vertical, title: "workspace_vertical", symbol: "rectangle.split.1x2")
    }
    .appSegmentTrack()
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text("workspace_layout"))
  }

  private func option(_ axis: WorkspaceLayoutPreference.Axis, title: String, symbol: String) -> some View {
    let selected = selection == axis || (selection == .automatic && effectiveAxis.rawValue == axis.rawValue)
    return Button { selection = axis } label: {
      Label(title.localizedStringKey, systemImage: symbol)
    }
    .buttonStyle(AppSegmentButtonStyle(selected: selected))
    #if os(iOS)
      .keyboardShortcut(axis == .horizontal ? "1" : "2", modifiers: [.command, .option])
    #endif
      .accessibilityIdentifier("workspace-\(axis.rawValue)")
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct WorkspacePanes: View {
  let resolution: WorkspaceLayoutResolution
  @Binding var preference: WorkspaceLayoutPreference
  let availableHeight: CGFloat
  var export: () -> Void
  @State private var sourceSize = CGSize.zero
  @State private var resultSize = CGSize.zero
  @State private var dragStart: Double?

  var body: some View {
    let horizontal = resolution.axis == .horizontal
    let widths = resolution.paneLengths(totalLength: resolution.editorWidth - 8, preference: preference)
    let ratio = preference.ratio(for: resolution.axis)
    let editorBudget = max(360, availableHeight - 340)
    let sourceEditorHeight = horizontal ? max(240, availableHeight - 220) : max(180, editorBudget * ratio)
    let resultEditorHeight = horizontal ? max(240, availableHeight - 100) : max(180, editorBudget * (1 - ratio))
    let sourceWidth = horizontal ? widths.source : max(0, resolution.editorWidth - 8)
    let resultWidth = horizontal ? widths.result : max(0, resolution.editorWidth - 8)
    let divider = resolution.dividerSize
    ZStack(alignment: .topLeading) {
      SourcePane(editorHeight: sourceEditorHeight, paneHeight: horizontal ? availableHeight : nil, showsConversionAction: false)
        .frame(width: sourceWidth)
        .workspaceFocusSection()
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(3)
        .readSize {
          if sourceSize != $0 {
            sourceSize = $0
          }
        }
      ResultPane(editorHeight: resultEditorHeight, paneHeight: horizontal ? availableHeight : nil, export: export)
        .frame(width: resultWidth)
        .workspaceFocusSection()
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
        .readSize {
          if resultSize != $0 {
            resultSize = $0
          }
        }
        .offset(x: horizontal ? sourceWidth + divider : 0,
                y: horizontal ? 0 : sourceSize.height + divider)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.secondary.opacity(0.35))
        .frame(width: horizontal ? 4 : 48, height: horizontal ? 48 : 4)
        .frame(width: horizontal ? divider : sourceWidth,
               height: horizontal ? max(sourceSize.height, resultSize.height) : divider)
        .contentShape(Rectangle())
        .offset(x: horizontal ? sourceWidth : 0, y: horizontal ? 0 : sourceSize.height)
        .gesture(DragGesture(minimumDistance: 2).onChanged { gesture in
          if dragStart == nil {
            dragStart = ratio
          }
          let delta = horizontal ? gesture.translation.width / max(1, resolution.editorWidth)
            : gesture.translation.height / max(1, editorBudget)
          setRatio((dragStart ?? ratio) + delta)
        }.onEnded { _ in dragStart = nil })
        .accessibilityElement()
        .accessibilitySortPriority(2)
        .accessibilityLabel(Text("workspace_pane_sizes"))
        .accessibilityValue(Text("\(Int(ratio * 100))%"))
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: setRatio(ratio + 0.05)
          case .decrement: setRatio(ratio - 0.05)
          @unknown default: break
          }
        }
    }
    .frame(width: max(0, resolution.editorWidth - 8),
           height: horizontal ? max(sourceSize.height, resultSize.height) : sourceSize.height + divider + resultSize.height,
           alignment: .topLeading)
  }

  private func setRatio(_ value: Double) {
    if resolution.axis == .horizontal {
      preference.horizontalRatio = min(0.7, max(0.3, value))
    } else {
      preference.verticalRatio = min(0.7, max(0.3, value))
    }
  }
}

private extension View {
  @ViewBuilder func workspaceFocusSection() -> some View {
    #if os(macOS)
    if #available(macOS 13.0, *) {
      focusSection()
    } else {
      self
    }
    #else
    self
    #endif
  }
}

struct ConversionSettingsSheet: View {
  @EnvironmentObject private var windowState: WhatsNewWindowState
  @Environment(\.sizeCategory) private var sizeCategory
  var body: some View {
    VStack(spacing: 0) {
      Group {
        if sizeCategory.isAccessibilityCategory {
          VStack(alignment: .leading, spacing: 8) {
            HStack { Spacer(); doneButton }
            Text("workspace_settings").font(.headline)
              .fixedSize(horizontal: false, vertical: true)
          }
        } else {
          HStack {
            Text("workspace_settings").font(.headline)
            Spacer()
            doneButton
          }
        }
      }.padding()
      ScrollView { ConversionInspector(showsPresetList: true).padding() }
    }
    .background(Color.Neumorphic.main)
    #if os(macOS)
      .frame(minWidth: 320, idealWidth: 380, minHeight: 400, idealHeight: 550)
    #endif
  }

  private var doneButton: some View {
    Button { windowState.showingConversionSettings = false } label: {
      Text("Done")
    }
    .appNeumorphicButtonStyle(RoundedRectangle(cornerRadius: 8))
  }
}

#if os(macOS)
  extension Notification.Name {
    static let workspaceCommand = Notification.Name("WorkspaceCommand")
  }
#endif

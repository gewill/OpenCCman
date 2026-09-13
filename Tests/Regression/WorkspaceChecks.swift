import Foundation

@main
struct WorkspaceChecks {
  static func main() {
    var preference = WorkspaceLayoutPreference(axis: .horizontal)
    var previous: WorkspaceLayoutResolution.Axis? = nil
    for (width, expected) in [(719.0, false), (720, false), (759, false), (760, true),
                              (759, true), (720, true), (719, false), (759, false), (760, true)] {
      let resolved = WorkspaceLayoutResolution.resolve(preference: preference, width: width,
                                                        platform: .mac, accessibility: false, previousAxis: previous)
      precondition((resolved.axis == .horizontal) == expected, "Hysteresis at \(width)")
      previous = resolved.axis
    }
    precondition(preference.axis == .horizontal)
    preference.axis = .vertical
    let vertical = WorkspaceLayoutResolution.resolve(preference: preference, width: 2000, platform: .mac,
                                                     accessibility: false, previousAxis: .horizontal)
    precondition(vertical.axis == .vertical)
    preference.axis = .horizontal
    for platform in [WorkspaceLayoutResolution.Platform.mac, .pad, .phone] {
      let accessible = WorkspaceLayoutResolution.resolve(preference: preference, width: 1400,
                                                          platform: platform, accessibility: true)
      precondition(accessible.axis == .vertical && accessible.inspectorWidth == 0)
      let normal = WorkspaceLayoutResolution.resolve(preference: preference, width: 1400,
                                                      platform: platform, accessibility: false)
      precondition((normal.axis == .horizontal) == (platform != .phone))
    }
    preference.inspector = .shown
    let narrow = WorkspaceLayoutResolution.resolve(preference: preference, width: 500, platform: .pad, accessibility: false)
    precondition(narrow.inspectorWidth == 0)
    let sidebar = WorkspaceLayoutResolution.resolve(preference: preference, width: 1050, platform: .mac, accessibility: false)
    precondition(sidebar.inspectorWidth == 264 && sidebar.editorWidth == 762 && sidebar.axis == .horizontal)
    preference.inspector = .hidden
    let hidden = WorkspaceLayoutResolution.resolve(preference: preference, width: 1050, platform: .mac, accessibility: false)
    precondition(hidden.editorWidth == 1050)
    for platform in [WorkspaceLayoutResolution.Platform.mac, .pad] {
      let resolved = WorkspaceLayoutResolution.resolve(preference: preference, width: 1200,
                                                        platform: platform, accessibility: false)
      let panes = resolved.paneLengths(totalLength: 1200, preference: preference)
      precondition(resolved.dividerSize == (platform == .mac ? 16 : 44))
      precondition(panes.source + panes.result + resolved.dividerSize == 1200)
    }
    var otherWindow = preference
    otherWindow.axis = .vertical
    otherWindow.horizontalRatio = 0.7
    precondition(preference.axis == .horizontal && preference.horizontalRatio == 0.5)
    for invalid in [Double.nan, .infinity, -.infinity] {
      preference.horizontalRatio = invalid
      precondition(preference.ratio(for: .horizontal) == 0.5)
    }
    preference.horizontalRatio = 9
    preference.verticalRatio = 0.1
    precondition(preference.ratio(for: .horizontal) == 0.7 && preference.ratio(for: .vertical) == 0.3)
    let minimum = hidden.paneLengths(totalLength: 760, preference: preference)
    precondition(minimum.result == 320 && minimum.source >= 320)
    let short = vertical.paneLengths(totalLength: 100, preference: preference)
    precondition(short.source == 180 && short.result == 180)
    for width in [Double.nan, .infinity, -1] {
      let result = WorkspaceLayoutResolution.resolve(preference: preference, width: width, platform: .mac, accessibility: false)
      precondition(result.axis == .vertical && result.editorWidth == 0)
    }
    print("Workspace checks passed: hysteresis, user intent, inspector budget, accessibility, phone, window isolation, ratio recovery and pane minima")
  }
}

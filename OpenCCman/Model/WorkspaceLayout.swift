import Foundation

/// User intent is never rewritten by temporary space or accessibility constraints.
struct WorkspaceLayoutPreference: Equatable {
  enum Axis: String, CaseIterable { case automatic, horizontal, vertical }
  enum Inspector: String { case automatic, shown, hidden }
  var axis: Axis = .automatic
  var inspector: Inspector = .automatic
  var horizontalRatio: Double = 0.5
  var verticalRatio: Double = 0.5

  func ratio(for axis: WorkspaceLayoutResolution.Axis) -> Double {
    let value = axis == .horizontal ? horizontalRatio : verticalRatio
    return value.isFinite ? min(0.7, max(0.3, value)) : 0.5
  }
}

struct WorkspaceLayoutResolution: Equatable {
  enum Axis: String { case horizontal, vertical }
  enum Platform { case mac, pad, phone }
  static let enterHorizontal = 760.0
  static let retainHorizontal = 720.0
  let dividerSize: Double
  let axis: Axis
  let inspectorWidth: Double
  let editorWidth: Double
  let isTemporaryVertical: Bool

  static func resolve(preference: WorkspaceLayoutPreference, width: Double,
                      platform: Platform, accessibility: Bool,
                      previousAxis: Axis? = nil) -> Self {
    let available = width.isFinite ? max(0, width) : 0
    let supportsColumns = platform != .phone && !accessibility
    let sidebarBudget = platform == .mac ? 264.0 : 248.0
    let wantsInspector = preference.inspector == .shown
      || (preference.inspector == .automatic && available >= 1100)
    // Even an explicitly shown inspector moves into a panel when space is scarce.
    let sidebar = supportsColumns && wantsInspector && available >= sidebarBudget + 24 + 320
      ? sidebarBudget : 0
    let editorWidth = max(0, available - (sidebar > 0 ? sidebar + 24 : 0))
    let threshold = previousAxis == .horizontal ? retainHorizontal : enterHorizontal
    let horizontal = supportsColumns && preference.axis != .vertical && editorWidth >= threshold
    return Self(dividerSize: platform == .mac ? 16 : 44, axis: horizontal ? .horizontal : .vertical, inspectorWidth: sidebar,
                editorWidth: editorWidth,
                isTemporaryVertical: !horizontal && preference.axis == .horizontal)
  }

  /// Available length excludes the divider. A short window scrolls instead of
  /// compressing either pane below its readable minimum.
  func paneLengths(totalLength: Double, preference: WorkspaceLayoutPreference) -> (source: Double, result: Double) {
    let minimum = axis == .horizontal ? 320.0 : 180.0
    let available = max(minimum * 2, (totalLength.isFinite ? totalLength : 0) - dividerSize)
    let source = min(available - minimum, max(minimum, available * preference.ratio(for: axis)))
    return (source, available - source)
  }
}

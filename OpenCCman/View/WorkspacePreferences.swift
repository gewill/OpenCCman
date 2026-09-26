import SwiftUI

/// SceneStorage scopes these small UI preferences to one window; drafts and
/// conversion tasks remain owned by RootView's existing HomeViewModel.
struct WorkspacePreferences: DynamicProperty {
  @SceneStorage("workspace.axis") private var axis = "automatic"
  @SceneStorage("workspace.inspector") private var inspector = "automatic"
  @SceneStorage("workspace.horizontalRatio") private var horizontalRatio = 0.5
  @SceneStorage("workspace.verticalRatio") private var verticalRatio = 0.5

  var value: WorkspaceLayoutPreference {
    get {
      WorkspaceLayoutPreference(axis: .init(rawValue: axis) ?? .automatic,
                                inspector: .init(rawValue: inspector) ?? .automatic,
                                horizontalRatio: horizontalRatio, verticalRatio: verticalRatio)
    }
    nonmutating set {
      axis = newValue.axis.rawValue
      inspector = newValue.inspector.rawValue
      horizontalRatio = newValue.ratio(for: .horizontal)
      verticalRatio = newValue.ratio(for: .vertical)
    }
  }
}

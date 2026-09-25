#if os(macOS)
import CoreGraphics

/// A window-owned reading anchor independent of the native editor's lifetime.
@MainActor
final class WorkspaceEditorReadingState {
  struct Position {
    let character: Int
    let lineOffset: CGFloat
  }

  var position: Position?

  func invalidate() { position = nil }
}
#endif

#if os(macOS)
/// A Mac workspace editor's text: the object that reads and writes the window
/// model's property, and a revision that changes whenever the text does.
///
/// SwiftUI compares each view's new value with the previous one on every update.
/// A `Binding<String>` keeps a copy of the text in each value, and two copies
/// compare by canonical equivalence up to their first difference. Every
/// keystroke compared the source document three times, about 0.3–0.5 s at
/// 10 MiB (#352). This value holds an object and a number, which SwiftUI
/// compares in constant time; the editor reads the text itself.
struct WorkspaceEditorText {
  let source: WorkspaceEditorTextSource
  /// SwiftUI updates the editor when this differs from the previous value.
  let revision: Int

  @MainActor var value: String { source.read() }

  /// Sends a native edit to the model. `changed` is true when AppKit replaced
  /// text with different text, decided from the edited ranges alone; the model
  /// then skips its own byte comparison, which for an equal-length edit reads
  /// the document up to the edit. A read-only pane has no writer.
  @MainActor func publish(_ text: String, changed: Bool) { source.write?(text, changed) }
}

/// Reads, and for an editable pane writes, one window-model property. The model
/// keeps one per pane, so SwiftUI sees the same object on every update.
@MainActor
final class WorkspaceEditorTextSource {
  fileprivate let read: @MainActor () -> String
  fileprivate let write: (@MainActor (_ text: String, _ changed: Bool) -> Void)?

  init(read: @escaping @MainActor () -> String,
       write: (@MainActor (_ text: String, _ changed: Bool) -> Void)? = nil) {
    self.read = read
    self.write = write
  }
}
#endif

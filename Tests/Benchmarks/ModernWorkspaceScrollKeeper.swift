// Injected into a private benchmark snapshot only. Not compiled in the app.
// Uses only modern TextKit APIs so a diagnostic NSTextView cannot silently
// switch to the legacy layout network while preserving a visible character.
@MainActor
final class ModernWorkspaceScrollKeeper {
  private struct Anchor {
    let character: Int
    let selection: NSRange
  }

  private weak var editor: NSTextView?
  private weak var clip: NSClipView?
  private var observations: [NSObjectProtocol] = []
  private var size = NSSize.zero
  private var anchor: Anchor?
  private var restoring = false
  private var capturing = false
  private var revision = 0

  func attach(_ editor: NSTextView) {
    guard let clip = editor.enclosingScrollView?.contentView,
          editor.textLayoutManager != nil else { return }
    observations.forEach(NotificationCenter.default.removeObserver)
    observations.removeAll()
    self.editor = editor
    self.clip = clip
    size = clip.bounds.size
    clip.postsBoundsChangedNotifications = true
    clip.postsFrameChangedNotifications = true
    for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
      observations.append(NotificationCenter.default.addObserver(forName: name, object: clip, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.viewportChanged() }
      })
    }
    observations.append(NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification,
                                                                object: editor.textStorage, queue: .main) { [weak self] note in
      guard let storage = note.object as? NSTextStorage, storage.editedMask.contains(.editedCharacters) else { return }
      MainActor.assumeIsolated { self?.textChanged() }
    })
    capture()
  }

  private func textChanged() {
    revision += 1
    anchor = nil
    let currentRevision = revision
    DispatchQueue.main.async { [weak self] in
      guard let self, revision == currentRevision else { return }
      capture()
    }
  }

  private func viewportChanged() {
    guard let clip, let editor, !restoring else { return }
    if size != clip.bounds.size {
      size = clip.bounds.size
      guard let saved = anchor, saved.selection == editor.selectedRange() else {
        anchor = nil
        DispatchQueue.main.async { [weak self] in self?.capture() }
        return
      }
      let selection = editor.selectedRange()
      let currentRevision = revision
      // The first targeted scroll runs before the next display flush. Delaying
      // all restoration until an async pass can materialize the whole document.
      restore(saved, ifSelectionIs: selection)
      DispatchQueue.main.async { [weak self] in
        guard let self, revision == currentRevision else { return }
        restore(saved, ifSelectionIs: selection)
        capture()
      }
    } else {
      capture()
    }
  }

  private func capture() {
    guard !capturing, let editor, let clip, let layout = editor.textLayoutManager,
          let content = layout.textContentManager else { return }
    capturing = true
    defer { capturing = false }
    let point = editor.convert(clip.bounds.origin, from: clip)
    let y = max(0, point.y - editor.textContainerOrigin.y)
    guard let fragment = layout.textLayoutFragment(for: CGPoint(x: 0, y: y)),
          let line = fragment.textLineFragments.first(where: {
            fragment.layoutFragmentFrame.minY + $0.typographicBounds.maxY > y
          }) ?? fragment.textLineFragments.last else { return }
    let start = content.offset(from: content.documentRange.location, to: fragment.rangeInElement.location)
    guard start != NSNotFound else { return }
    anchor = Anchor(character: start + line.characterRange.location,
                    selection: editor.selectedRange())
  }

  private func restore(_ saved: Anchor, ifSelectionIs selection: NSRange) {
    guard let editor, editor.selectedRange() == selection,
          saved.character < (editor.textStorage?.length ?? 0),
          editor.textLayoutManager != nil else { return }
    restoring = true
    defer { restoring = false }
    editor.scrollRangeToVisible(NSRange(location: saved.character, length: 0))
  }

  deinit { observations.forEach(NotificationCenter.default.removeObserver) }
}

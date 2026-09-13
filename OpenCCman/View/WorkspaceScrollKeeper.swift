import SwiftUI
#if os(macOS)
  import AppKit

  /// Observes the existing TextEditor; never replaces its delegate or selection.
  @MainActor
  final class WorkspaceScrollKeeper: ObservableObject {
    private struct Anchor {
      let character: Int
      let lineOffset: CGFloat
    }

    private weak var editor: NSTextView?
    private weak var clip: NSClipView?
    private var observations: [NSObjectProtocol] = []
    private var size = NSSize.zero
    private var anchor: Anchor?
    private var pending: Anchor?
    private var revision = 0
    private var restoring = false

    func attach(_ editor: NSTextView) {
      guard self.editor !== editor, let clip = editor.enclosingScrollView?.contentView else { return }
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      revision += 1
      pending = nil
      anchor = nil
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
      observations.append(NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: editor.textStorage, queue: .main) { [weak self] note in
        guard let storage = note.object as? NSTextStorage, storage.editedMask.contains(.editedCharacters) else { return }
        MainActor.assumeIsolated { self?.textChanged() }
      })
      capture()
    }

    private func textChanged() {
      revision += 1
      pending = nil
      anchor = nil
      let currentRevision = revision
      // NSTextStorage posts during editing. Wait for the native layout to settle.
      DispatchQueue.main.async { [weak self] in
        guard let self, revision == currentRevision else { return }
        capture()
      }
    }

    private func viewportChanged() {
      guard let clip, !restoring else { return }
      if size != clip.bounds.size {
        size = clip.bounds.size
        if pending == nil {
          pending = anchor
        }
        let currentRevision = revision
        DispatchQueue.main.async { [weak self] in
          guard let self, revision == currentRevision, let pending else { return }
          self.pending = nil
          restore(pending)
        }
      } else if pending == nil {
        capture()
      }
    }

    private func capture() {
      guard let editor, let clip, let layout = editor.layoutManager,
            let container = editor.textContainer, let storage = editor.textStorage, storage.length > 0
      else {
        anchor = nil
        return
      }
      let point = editor.convert(clip.bounds.origin, from: clip)
      let origin = editor.textContainerOrigin
      let nearest = layout.characterIndex(for: NSPoint(x: max(0, point.x - origin.x), y: max(0, point.y - origin.y)),
                                          in: container, fractionOfDistanceBetweenInsertionPoints: nil)
      guard nearest != NSNotFound else { return }
      let character = min(nearest, storage.length - 1)
      let glyph = layout.glyphIndexForCharacter(at: character)
      let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      anchor = Anchor(character: character, lineOffset: point.y - origin.y - rect.minY)
    }

    private func restore(_ anchor: Anchor) {
      guard let editor, let clip, let layout = editor.layoutManager,
            let storage = editor.textStorage, anchor.character < storage.length else { return }
      restoring = true
      defer { restoring = false; capture() }
      layout.ensureLayout(forCharacterRange: NSRange(location: anchor.character, length: 1))
      let glyph = layout.glyphIndexForCharacter(at: anchor.character)
      let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      let y = rect.minY + editor.textContainerOrigin.y + anchor.lineOffset
      let maximum = max(0, editor.bounds.height - clip.bounds.height)
      clip.scroll(to: NSPoint(x: clip.bounds.minX, y: min(maximum, max(0, y))))
      editor.enclosingScrollView?.reflectScrolledClipView(clip)
    }

    deinit { observations.forEach(NotificationCenter.default.removeObserver) }
  }

#endif

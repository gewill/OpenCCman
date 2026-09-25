import SwiftUI
#if os(macOS)
  import AppKit

  /// Observes the existing TextEditor; never replaces its delegate or selection.
  @MainActor
  final class WorkspaceScrollKeeper: ObservableObject {
    typealias ReadingPosition = WorkspaceEditorReadingState.Position

    private weak var editor: NSTextView?
    private weak var clip: NSClipView?
    private var observations: [NSObjectProtocol] = []
    private var size = NSSize.zero
    private var anchor: ReadingPosition?
    private var pending: ReadingPosition?
    private var revision = 0
    private var restoring = false
    private var restorationScheduled = false
    private var capturing = false
    private var changingTypography = false

    #if WORKSPACE_SCROLL_CHECKS
      // Test synchronization only; absent from application builds. A timed
      // RunLoop spin does not establish completion of both queued passes.
      var isRestorationPending: Bool { restorationScheduled || restoring }
    #endif

    func attach(_ editor: NSTextView) {
      guard self.editor !== editor, let clip = editor.enclosingScrollView?.contentView else { return }
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      revision += 1
      pending = nil
      restorationScheduled = false
      anchor = nil
      self.editor = editor
      self.clip = clip
      size = clip.bounds.size
      // The glyph-based scroll bridge uses TextKit 1. Permit distant paragraphs
      // to lay out independently, without an idle sweep of the whole document.
      editor.layoutManager?.allowsNonContiguousLayout = true
      editor.layoutManager?.backgroundLayoutEnabled = false
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

    func currentReadingPosition() -> ReadingPosition? {
      if pending == nil { capture() }
      return pending ?? anchor
    }

    func restoreReadingPosition(_ position: ReadingPosition) {
      guard let editor, let storage = editor.textStorage,
            position.character < storage.length else { return }
      let selection = editor.selectedRange()
      pending = position
      restorationScheduled = true
      let currentRevision = revision
      DispatchQueue.main.async { [weak self] in
        guard let self, revision == currentRevision, let pending = self.pending else { return }
        restore(pending, ifSelectionIs: selection)
        DispatchQueue.main.async { [weak self] in
          guard let self, revision == currentRevision, let pending = self.pending else { return }
          restore(pending, ifSelectionIs: selection)
          self.pending = nil
          restorationScheduled = false
          capture()
        }
      }
    }

    func changeTypography(_ change: () -> Void) {
      guard let editor, let clip else { change(); return }
      capture()
      let readingAnchor = anchor
      let selection = editor.selectedRange()
      restoring = true
      changingTypography = true
      change()
      changingTypography = false
      restoring = false
      guard let readingAnchor else { return }
      pending = readingAnchor
      restorationScheduled = true
      let currentRevision = revision
      DispatchQueue.main.async { [weak self] in
        guard let self, revision == currentRevision, let pending = self.pending else { return }
        restore(pending, ifSelectionIs: selection)
        DispatchQueue.main.async { [weak self] in
          guard let self, revision == currentRevision, let pending = self.pending else { return }
          restore(pending, ifSelectionIs: selection)
          self.pending = nil
          restorationScheduled = false
          self.size = clip.bounds.size
          capture()
        }
      }
    }

    private func textChanged() {
      // Replacing the attributed spelling of the same plain text is a visual
      // change, not a new document. Keep the captured reading anchor.
      guard !changingTypography else { return }
      revision += 1
      pending = nil
      restorationScheduled = false
      anchor = nil
      let currentRevision = revision
      // NSTextStorage posts during editing. Wait for the native layout to settle.
      DispatchQueue.main.async { [weak self] in
        guard let self, revision == currentRevision else { return }
        capture()
      }
    }

    private func viewportChanged() {
      guard let clip, let editor, !restoring else { return }
      if size != clip.bounds.size {
        size = clip.bounds.size
        if pending == nil {
          pending = anchor
        }
        guard pending != nil, !restorationScheduled else { return }
        restorationScheduled = true
        let currentRevision = revision
        let selection = editor.selectedRange()
        DispatchQueue.main.async { [weak self] in
          guard let self, revision == currentRevision, let pending else { return }
          restore(pending, ifSelectionIs: selection)
          // Noncontiguous layout initially estimates offscreen geometry. Keep
          // the logical anchor through the native scroll/layout adjustment,
          // then place it once more using the settled local line geometry.
          DispatchQueue.main.async { [weak self] in
            guard let self, revision == currentRevision else { return }
            restore(pending, ifSelectionIs: selection)
            self.pending = nil
            restorationScheduled = false
            capture()
          }
        }
      } else if pending == nil {
        capture()
      }
    }

    private func capture() {
      guard !capturing else { return }
      guard let editor, let clip, let layout = editor.layoutManager,
            let container = editor.textContainer, let storage = editor.textStorage, storage.length > 0
      else {
        anchor = nil
        return
      }
      capturing = true
      defer { capturing = false }
      // On-demand layout can adjust the clip origin while a glyph query is in
      // progress. Resolve only the visible area, then re-read its coordinates;
      // nested bounds notifications must not overwrite this capture halfway.
      for _ in 0..<3 {
        let origin = editor.textContainerOrigin
        let visible = editor.convert(clip.bounds, from: clip).offsetBy(dx: -origin.x, dy: -origin.y)
        layout.ensureLayout(forBoundingRect: visible, in: container)
        let bounds = clip.bounds
        let point = editor.convert(bounds.origin, from: clip)
        let glyph = layout.glyphIndex(for: NSPoint(x: max(0, point.x - origin.x), y: max(0, point.y - origin.y)),
                                      in: container)
        guard glyph != NSNotFound else { return }
        let character = min(layout.characterIndexForGlyph(at: glyph), storage.length - 1)
        let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let offset = point.y - origin.y - rect.minY
        guard clip.bounds == bounds, offset >= -origin.y, offset < rect.height else { continue }
        anchor = ReadingPosition(character: character, lineOffset: offset)
        return
      }
      // An unresolved estimate is not a reading position. Do not restore it as
      // though its offset belonged to the observed line.
      anchor = nil
    }

    private func restore(_ anchor: ReadingPosition, ifSelectionIs selection: NSRange) {
      guard let editor, let clip, let layout = editor.layoutManager,
            let storage = editor.textStorage, anchor.character < storage.length else { return }
      // A new caret/selection navigation takes precedence over a queued width
      // restoration. Never scroll the new selection back to an obsolete anchor.
      guard editor.selectedRange() == selection else { return }
      restoring = true
      defer { restoring = false; capture() }
      editor.scrollRangeToVisible(NSRange(location: anchor.character, length: 0))
      layout.ensureLayout(forCharacterRange: NSRange(location: anchor.character, length: 1))
      let glyph = layout.glyphIndexForCharacter(at: anchor.character)
      let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
      let y = rect.minY + editor.textContainerOrigin.y + anchor.lineOffset
      clip.scroll(to: NSPoint(x: clip.bounds.minX, y: max(0, y)))
      editor.enclosingScrollView?.reflectScrolledClipView(clip)
    }

    deinit { observations.forEach(NotificationCenter.default.removeObserver) }
  }

#endif

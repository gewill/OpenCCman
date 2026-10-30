#if os(iOS)
  import SwiftUI

  /// Observe keyboard intersection in this view's own window. No global keyboard
  /// height or manual bottom inset competes with SwiftUI's safe-area adjustment.
  struct WorkspaceKeyboardProbe: UIViewRepresentable {
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

  /// Opt-in diagnostics for the isolated QA bundle. No document text is logged,
  /// and none of this probe exists in a Release or ordinary older-SDK build.
  struct WorkspaceDiagnostics: View {
    let axis: WorkspaceLayoutResolution.Axis
    let modelID: UUID
    let layoutSize: CGSize
    let layoutInsets: EdgeInsets
    #if DEBUG && OPENCCMAN_DUO_SDK
    @EnvironmentObject private var viewModel: HomeViewModel
    #endif

    @ViewBuilder var body: some View {
      #if DEBUG && OPENCCMAN_DUO_SDK
      if Bundle.main.bundleIdentifier == "org.gewill.OpenCCman.WhatsNewUITests",
         ProcessInfo.processInfo.arguments.contains("-qa-duo-trace") {
        if #available(iOS 27.1, *) {
          GeometryReader { proxy in
            let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
            let payload: [String: Any] = [
              "axis": axis.rawValue, "model": modelID.uuidString,
              "container": [layoutSize.width, layoutSize.height],
              "safe_area": [layoutInsets.top, layoutInsets.leading, layoutInsets.bottom, layoutInsets.trailing],
              "probe_size": [proxy.size.width, proxy.size.height],
              "probe_origin": [proxy.frame(in: .global).minX, proxy.frame(in: .global).minY],
              "pro_alert": viewModel.showingProAlert, "quota_exhausted": TestNumbersPerDayManager.isToMax,
              "busy": viewModel.isLoading, "input_characters": viewModel.inputText.utf16.count,
              "result_characters": viewModel.resultText.utf16.count,
              "division": regions.map { region -> [String: Any] in
                ["active": region.isActive,
                 "frame": [region.frame.minX, region.frame.minY, region.frame.width, region.frame.height]]
              },
            ]
            WorkspaceDiagnosticEmitter(payload: payload).frame(width: 0, height: 0)
          }
          .allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      #endif
    }
  }

  #if DEBUG && OPENCCMAN_DUO_SDK
  private struct WorkspaceDiagnosticEmitter: UIViewRepresentable {
    let payload: [String: Any]
    func makeUIView(context _: Context) -> Recorder { Recorder() }
    func updateUIView(_ view: Recorder, context _: Context) { view.record(payload) }

    final class Recorder: UIView {
      private var lastPayload: Data?
      private static var didPrepareTrace = false
      private static var traceBytes = 0

      func record(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
              data != lastPayload else { return }
        lastPayload = data
        DispatchQueue.main.async { [weak self] in
          guard let window = self?.window else { return }
          var snapshot = payload
          snapshot["window"] = [window.bounds.width, window.bounds.height]
          snapshot["scene"] = window.windowScene?.session.persistentIdentifier
          func editors(in view: UIView) -> [UITextView] {
            (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { editors(in: $0) }
          }
          snapshot["editors"] = editors(in: window).map { editor -> [String: Any] in
            ["identity": String(describing: ObjectIdentifier(editor)), "editable": editor.isEditable,
             "frame": [window.convert(editor.bounds, from: editor).minX, window.convert(editor.bounds, from: editor).minY,
                       editor.bounds.width, editor.bounds.height],
             "characters": editor.text.utf16.count, "selection": [editor.selectedRange.location, editor.selectedRange.length],
             "marked": editor.markedTextRange != nil, "focused": editor.isFirstResponder,
             "offset": [editor.contentOffset.x, editor.contentOffset.y]]
          }
          if let encoded = try? JSONSerialization.data(withJSONObject: snapshot, options: .sortedKeys),
             let line = String(data: encoded, encoding: .utf8) {
            FileHandle.standardOutput.write(Data(("OPENCCMAN_DUO " + line + "\n").utf8))
            // A bounded, QA-only metadata file lets host-driven tests collect
            // editor identity without relying on Simulator console buffering.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("duo-layout-trace.jsonl")
            if !Self.didPrepareTrace {
              try? Data().write(to: url)
              Self.didPrepareTrace = true
            }
            let record = Data((line + "\n").utf8)
            if Self.traceBytes + record.count <= 512 * 1024,
               let handle = try? FileHandle(forWritingTo: url) {
              defer { try? handle.close() }
              _ = try? handle.seekToEnd()
              try? handle.write(contentsOf: record)
              Self.traceBytes += record.count
            }
          }
        }
      }
    }
  }
  #endif
#endif

import AppKit
import SwiftUI
import SwiftUIIntrospect

// The unrelated convenience modifier is copied from Styles.swift by the runner;
// the native editor, keeper, version policy and window reader are actual app source.
@MainActor
private final class Observations {
  weak var source: NSTextView?
  weak var result: NSTextView?
  weak var window: NSWindow?
  var legacyCalls = 0
}

@MainActor
private struct Editors: View {
  let observations: Observations
  @State private var source = "原文 é 👩🏽‍💻"

  var body: some View {
    HStack {
      WorkspaceTextEditor(text: $source, label: "Source")
      WorkspaceTextEditor(text: .constant("結果"), isEditable: false, label: "Result")
    }
    .background(MainWindowReader { observations.window = $0 }
      .allowsHitTesting(false).accessibilityHidden(true))
    .introspect(.window, on: .macOS(.v11, .v12, .v13, .v14, .v15, .v26)) { _ in
      observations.legacyCalls += 1
    }
  }
}

@main
enum IntrospectionChecks {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let observations = Observations()
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 240),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: Editors(observations: observations))
    window.orderFront(nil)
    defer { window.close() }

    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline && (observations.source == nil || observations.result == nil || observations.window == nil) {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      let editors = window.contentView.map(textViews) ?? []
      observations.source = editors.first { $0.string == "原文 é 👩🏽‍💻" }
      observations.result = editors.first { $0.string == "結果" }
    }
    guard let source = observations.source, let result = observations.result else {
      preconditionFailure("Workspace editors must expose native NSTextViews on this tested runtime")
    }
    precondition(observations.window === window, "MainWindowReader must resolve this actual hosting window")
    precondition(source !== result)
    precondition(source.accessibilityLabel() == "Source" && result.accessibilityLabel() == "Result")
    precondition(source.isEditable && !result.isEditable, "Result read-only configuration must execute")
    precondition(source.string == "原文 é 👩🏽‍💻" && result.string == "結果")
    for editor in [source, result] {
      if #available(macOS 12, *) {
        // Read the new manager first: querying layoutManager can itself switch
        // an unconfigured editor to compatibility mode and invalidate the test.
        precondition(editor.textLayoutManager == nil, "Keeper must already have selected TextKit 1")
      }
      precondition(editor.layoutManager?.allowsNonContiguousLayout == true)
      precondition(editor.layoutManager?.backgroundLayoutEnabled == false)
      precondition(editor.textContainerInset == NSSize(width: 0, height: 1))
      precondition(editor.textContainer?.lineFragmentPadding == 0)
      precondition(editor.backgroundColor == .clear)
    }
    if #available(macOS 28, *) {
      preconditionFailure("Future major runtime requires a new explicit validation, not an open-ended opt-in")
    } else if #available(macOS 27, *) {
      precondition(observations.legacyCalls == 0, "Negative control: the old explicit list skips macOS 27")
    } else {
      precondition(observations.legacyCalls > 0, "Existing supported runtime keeps the original path")
    }
    print("PASS: native workspace source/result and window callback; result read-only; TextKit 1 configured before inspection; content and style preserved; legacy window predicate control. \(ProcessInfo.processInfo.operatingSystemVersionString)")
  }

  @MainActor private static func textViews(_ view: NSView) -> [NSTextView] {
    if let editor = view as? NSTextView { return [editor] }
    return view.subviews.flatMap(textViews)
  }
}

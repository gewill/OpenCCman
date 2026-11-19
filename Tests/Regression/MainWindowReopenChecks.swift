import AppKit

@main
struct MainWindowReopenChecks {
  @MainActor static func main() {
    _ = NSApplication.shared
    let editor = NSWindow(contentRect: .zero, styleMask: [.titled, .miniaturizable],
                          backing: .buffered, defer: true)
    let panel = NSPanel()
    // Hidden and minimized editors may have neither key/main status nor
    // canBecomeMain. Readiness is independent of those AppKit properties.
    let selected = MainWindowReopenController.selectWindow(key: panel, main: nil,
      windows: [panel, editor], isReady: { $0 === editor })
    precondition(selected === editor)
    precondition(MainWindowReopenController.selectWindow(key: nil, main: nil, windows: [panel],
                                                         isReady: { _ in false }) == nil)
    let controller = MainWindowReopenController()
    var completions: [MainWindowReopenController.Completion] = []
    var failures = 0
    let request = {
      controller.request(open: { completions.append($0) }, onFailure: { _ in failures += 1 })
    }
    request()
    request()
    precondition(completions.count == 1, "A burst must request only one reopen")
    completions[0](nil)
    request()
    precondition(completions.count == 1, "Process launch success is not window readiness")

    controller.windowBecameReady()
    request()
    precondition(completions.count == 2, "A later closed-window cycle can reopen")
    let failure = NSError(domain: "WindowReopenChecks", code: 1)
    completions[0](failure)
    precondition(failures == 0, "An obsolete callback must not cancel the current request")
    request()
    precondition(completions.count == 2)

    completions[1](failure)
    precondition(failures == 1)
    request()
    precondition(completions.count == 3, "A failed reopen must allow explicit retry")
    controller.windowBecameReady()
    completions[2](failure)
    precondition(failures == 1, "Late failure cannot invalidate an already ready window")
    print("PASS: burst coalescing, process/window readiness, failure retry, obsolete callbacks")
  }
}

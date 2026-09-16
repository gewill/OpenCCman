import AppKit
import Foundation

/// Exercise the real model subscribers, without registering Services or opening UI.
@MainActor
func checkWindowNotifications() async {
  _ = NSApplication.shared
  let firstWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
  let secondWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
  firstWindow.isReleasedWhenClosed = false
  secondWindow.isReleasedWhenClosed = false
  defer { firstWindow.close(); secondWindow.close() }

  let first = HomeViewModel()
  let second = HomeViewModel()
  let unbound = HomeViewModel()
  first.window = firstWindow
  second.window = secondWindow
  first.replaceSource("first sentinel")
  second.replaceSource("second sentinel")
  unbound.replaceSource("unbound sentinel")
  let quotaBefore = coreQuotaCount
  let original = "原稿\0鼠标\r\n👩🏽‍💻 e\u{301}"
  let converted = "原稿\0滑鼠\r\n👩🏽‍💻 e\u{301}"

  for name in [Notification.Name.textConversionServiceDidReceiveText, .globalShortcutDidConvertText] {
    first.replaceSource("first sentinel")
    second.replaceSource("second sentinel")
    // An explicit target must work even when it is not the application's key window.
    NotificationCenter.default.post(name: name, object: firstWindow,
                                    userInfo: ["originalText": original, "convertedText": converted])
    await drainWindowNotifications()
    precondition(Data(first.inputText.utf8) == Data(original.utf8))
    precondition(Data(first.resultText.utf8) == Data(converted.utf8))
    precondition(first.exportSnapshot?.text == converted)
    precondition(first.resultFilename == "OpenCCman-converted.txt" && first.localProgress == 1)
    precondition(second.inputText == "second sentinel" && second.resultText.isEmpty)
    precondition(unbound.inputText == "unbound sentinel" && unbound.resultText.isEmpty)

    NotificationCenter.default.post(name: name, object: secondWindow,
                                    userInfo: ["originalText": "second original", "convertedText": "second result"])
    await drainWindowNotifications()
    precondition(second.inputText == "second original" && second.resultText == "second result")
    precondition(first.inputText == original && first.resultText == converted)
  }

  // Opening new source clears only the target's prior result/export snapshot.
  NotificationCenter.default.post(name: .textServiceDidReceiveText, object: firstWindow,
                                  userInfo: ["originalText": "replacement"])
  await drainWindowNotifications()
  precondition(first.inputText == "replacement" && first.resultText.isEmpty && first.exportSnapshot == nil)
  precondition(first.localProgress == 0 && !first.isLoading)
  precondition(second.resultText == "second result" && second.exportSnapshot?.text == "second result")

  // A missing payload must not clear an existing document.
  NotificationCenter.default.post(name: .textConversionServiceDidReceiveText, object: firstWindow,
                                  userInfo: ["originalText": "invalid"])
  await drainWindowNotifications()
  precondition(first.inputText == "replacement")
  precondition(coreQuotaCount == quotaBefore, "External Services/shortcut results never consume home quota")
  print("PASS: real model notification subscribers; two explicit window targets; unbound rejection; exact Unicode/NUL/CRLF; export replacement; malformed payload; unchanged quota")
}

@MainActor
private func drainWindowNotifications() async {
  // Each subscriber enqueues one main-queue block synchronously during post.
  // A FIFO barrier waits for all receivers, including negative assertions.
  await withCheckedContinuation { continuation in
    DispatchQueue.main.async { continuation.resume() }
  }
}

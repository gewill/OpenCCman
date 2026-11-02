import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Entry point of the Share sheet action. It never edits the host's content:
/// the result goes back only when the user taps Done, and the host decides
/// whether to use it.
final class ActionViewController: UIViewController {
  private let model = TextActionModel()

  override func viewDidLoad() {
    super.viewDidLoad()
    let host = UIHostingController(rootView: TextActionView(
      model: model,
      cancel: { [weak self] in self?.cancel() },
      done: { [weak self] in self?.finish(returning: $0) },
      copy: { UIPasteboard.general.string = $0 },
      share: { [weak self] in self?.share($0) }
    ))
    addChild(host)
    host.view.frame = view.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(host.view)
    host.didMove(toParent: self)

    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    model.receive { try await TextActionInput.read(items) }
  }

  private func cancel() {
    extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
  }

  private func finish(returning result: String) {
    let item = NSExtensionItem()
    item.attachments = [NSItemProvider(item: result as NSString, typeIdentifier: UTType.plainText.identifier)]
    extensionContext?.completeRequest(returningItems: [item])
  }

  private func share(_ result: String) {
    let activity = UIActivityViewController(activityItems: [result], applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = view
      popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY, width: 0, height: 0)
      popover.permittedArrowDirections = .down
    }
    present(activity, animated: true)
  }
}

import AppKit
import ApplicationServices
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "org.gewill.OpenCCman.WhatsNewUITests").first!
let element = AXUIElementCreateApplication(app.processIdentifier)
func read(_ e: AXUIElement, _ key: String) -> CFTypeRef? { var value: CFTypeRef?; AXUIElementCopyAttributeValue(e, key as CFString, &value); return value }
if let bar = read(element, "AXExtrasMenuBar") {
 let e = bar as! AXUIElement
 let children = read(e, "AXChildren") as? [AXUIElement] ?? []
 print("Status items: \(children.count)")
 for c in children { print("Identifier:", read(c,"AXIdentifier") ?? "missing" as CFString, "Title:", read(c,"AXTitle") ?? "" as CFString) }
} else { print("Status items: 0") }

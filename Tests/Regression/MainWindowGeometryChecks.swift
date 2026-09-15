import Foundation
import CoreGraphics

@main
enum MainWindowGeometryChecks {
  static func main() {
    let main = CGRect(x: 0, y: 40, width: 1280, height: 760)
    let left = CGRect(x: -1920, y: 0, width: 1920, height: 1050)
    func fit(_ frame: CGRect, _ screens: [CGRect] = []) -> CGRect {
      MainWindowGeometry.constrained(frame, visibleScreens: screens, fallback: main)
    }
    let saved = CGRect(x: 80, y: 100, width: 800, height: 600)
    precondition(fit(saved, [main, left]) == saved, "A valid restored frame must not be replaced with defaults")
    let external = CGRect(x: -1800, y: 100, width: 1000, height: 700)
    precondition(fit(external, [main, left]) == external, "Negative-origin monitors must be preserved")
    precondition(main.contains(fit(external, [main])), "Disconnected monitor must return to visible screen")
    precondition(main.contains(fit(CGRect(x: 1000, y: 700, width: 1600, height: 1200), [main])))
    let spanning = CGRect(x: -600, y: 70, width: 800, height: 600)
    precondition(left.contains(fit(spanning, [main, left])), "Choose the display containing most of the window")
    precondition(MainWindowGeometry.hasSavedFrame("510 330 900 450 0 0 1920 1050 "))
    for invalid: String? in [nil, "", "x", "0 0 0 400 0 0 1920 1080", "0 0 nan 400 0 0 1920 1080"] {
      precondition(!MainWindowGeometry.hasSavedFrame(invalid))
    }
    let once = fit(spanning, [main, left])
    precondition(fit(once, [main, left]) == once, "Screen correction must be idempotent")
    precondition(MainWindowGeometry.minimumContentSize.width == 300)
    print("PASS: saved geometry, corrupt history, negative-origin and disconnected displays, oversized windows and idempotence")
  }
}

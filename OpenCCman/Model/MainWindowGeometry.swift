import Foundation
import CoreGraphics

/// Sizes are content points. Screen constraints use the entire window frame.
enum MainWindowGeometry {
  static let recommendedContentSize = CGSize(width: 1024, height: 768)
  static let minimumContentSize = CGSize(width: 300, height: 360)

  static func isValid(_ rect: CGRect) -> Bool {
    [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy(\.isFinite)
      && rect.width > 0 && rect.height > 0
  }

  static func hasSavedFrame(_ value: String?) -> Bool {
    guard let value else { return false }
    let fields = value.split(whereSeparator: { $0.isWhitespace })
    guard fields.count == 8 else { return false }
    let components = fields.compactMap { Double($0) }
    guard components.count == 8, components.allSatisfy(\.isFinite) else { return false }
    return components[2] > 0 && components[3] > 0 && components[6] > 0 && components[7] > 0
  }

  /// Retain the display with the largest intersection; disconnected displays fall back to the current one.
  static func constrained(_ frame: CGRect, visibleScreens: [CGRect], fallback: CGRect) -> CGRect {
    let screens = visibleScreens.filter(isValid)
    let screen = screens.max { lhs, rhs in
      intersectionArea(frame, lhs) < intersectionArea(frame, rhs)
    }.flatMap { intersectionArea(frame, $0) > 0 ? $0 : nil } ?? fallback
    guard isValid(screen), isValid(frame) else { return frame }
    let size = CGSize(width: min(frame.width, screen.width), height: min(frame.height, screen.height))
    return CGRect(x: min(max(frame.minX, screen.minX), screen.maxX - size.width),
                  y: min(max(frame.minY, screen.minY), screen.maxY - size.height),
                  width: size.width, height: size.height)
  }

  private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
    let intersection = a.intersection(b)
    return intersection.isNull ? 0 : intersection.width * intersection.height
  }
}

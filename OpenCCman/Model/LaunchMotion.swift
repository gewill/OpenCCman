import CoreGraphics
import Foundation

/// Motion spec for the cold-launch transition, in seconds from the first frame
/// after the launch screen. The design study lives in OpenCCman-motion/launch.
enum LaunchMotion {
  /// A spring with SwiftUI's `response` and `dampingFraction` (unit mass).
  struct Spring: Equatable {
    let response: Double
    let damping: Double

    /// Progress from 0 towards 1, `t` seconds after the spring starts.
    func value(at t: Double) -> Double {
      guard t > 0 else { return 0 }
      let w = 2 * Double.pi / response
      if damping < 1 {
        let wd = w * (1 - damping * damping).squareRoot()
        return 1 - exp(-damping * w * t) * (cos(wd * t) + damping * w / wd * sin(wd * t))
      }
      return 1 - exp(-w * t) * (1 + w * t)
    }

    /// When the spring stays within `tolerance` of its target.
    func settlingTime(tolerance: Double = 0.01) -> Double {
      var last = 0.0
      for step in 0 ... 2000 {
        let t = Double(step) / 1000
        if abs(1 - value(at: t)) > tolerance { last = t }
      }
      return last
    }
  }

  /// CSS-style cubic Bézier timing curve from (0, 0) to (1, 1).
  struct CubicBezier: Equatable {
    let x1, y1, x2, y2: Double

    func value(at x: Double) -> Double {
      if x <= 0 { return 0 }
      if x >= 1 { return 1 }
      var lo = 0.0, hi = 1.0
      for _ in 0 ..< 40 {
        let mid = (lo + hi) / 2
        if coordinate(mid, x1, x2) < x { lo = mid } else { hi = mid }
      }
      return coordinate((lo + hi) / 2, y1, y2)
    }

    private func coordinate(_ t: Double, _ a: Double, _ b: Double) -> Double {
      3 * a * t * (1 - t) * (1 - t) + 3 * b * t * t * (1 - t) + t * t * t
    }
  }

  static let exchange = Spring(response: 0.35, damping: 0.85)
  static let exchangeTurn = 180.0

  static let irisDelay = 0.22
  static let irisDuration = 0.40
  static let iris = CubicBezier(x1: 0.65, y1: 0, x2: 0.35, y2: 1)

  static let handoffDelay = 0.30
  static let handoffStagger = 0.03
  static let handoff = Spring(response: 0.40, damping: 0.90)
  static let labelFadeDelay = 0.56
  static let labelFadeDuration = 0.14

  static let settle = Spring(response: 0.32, damping: 0.86)
  static let pop = Spring(response: 0.34, damping: 0.68)
  static let settleOffset: CGFloat = 16
  static let settleScale: CGFloat = 0.965
  static let popScale: CGFloat = 0.6

  static let reduceMotionFade = 0.20

  static let macDelay = 0.06
  static let macStagger = 0.04
  static let macDuration = 0.18
  static let macOffset: CGFloat = 10
  /// The Mac window settles in three staggered groups.
  static let macTotal = macDelay + 2 * macStagger + macDuration

  /// The overlay is removed after this; every element has settled by then.
  static let duration = 0.80

  /// iOS cross-fades the launch screen out over the app's first frame, starting
  /// when the scene becomes active. Holding the mark at rest until that fade
  /// ends avoids a doubled mark (the fade measured about 300 ms on an
  /// iPhone 17 Pro simulator, iOS 26.5). macOS has no launch screen.
  static let systemHandoff = 0.30

  /// A window whose scene has not become active by then (a covered launch)
  /// starts anyway, so the workspace is never left hidden.
  static let activationTimeout = 0.7

  /// If no window has started by then, the transition is dropped for the process.
  static let launchWatchdog = 3.0

  static func irisRadius(at t: Double, maxRadius: CGFloat) -> CGFloat {
    let p = min(max((t - irisDelay) / irisDuration, 0), 1)
    return maxRadius * CGFloat(iris.value(at: p))
  }

  /// When the iris wavefront reaches `distance` from the mark centre.
  static func irisArrival(distance: CGFloat, maxRadius: CGFloat) -> Double {
    guard maxRadius > 0 else { return irisDelay }
    let target = Double(min(max(distance / maxRadius, 0), 1))
    var lo = 0.0, hi = 1.0
    for _ in 0 ..< 40 {
      let mid = (lo + hi) / 2
      if iris.value(at: mid) < target { lo = mid } else { hi = mid }
    }
    return irisDelay + irisDuration * hi
  }

  /// Covers the corners of a window of this size.
  static func maxRadius(for size: CGSize) -> CGFloat {
    (size.width * size.width + size.height * size.height).squareRoot() / 2 + 24
  }
}

/// The launch mark: the app icon's ring and glyphs without the plate, drawn in
/// the icon's 1024 pt design space and shown at `size` points. The launch
/// screen image (Assets `LaunchMark`) is rendered from the same geometry.
enum LaunchMark {
  static let designSize: CGFloat = 1024
  static let size: CGFloat = 300
  static var scale: CGFloat { size / designSize }
  static let center = CGPoint(x: 512, y: 512)
  static let ringRadius: CGFloat = 348
  static let lineWidth: CGFloat = 26
  /// Arrowhead ends, measured from the icon. Each arc ends a quarter turn after it starts.
  static let blueHead = CGPoint(x: 782, y: 426)
  static let purpleHead = CGPoint(x: 242, y: 598)
  static let jian = CGRect(x: 227, y: 228, width: 287, height: 304)
  static let fan = CGRect(x: 503, y: 475, width: 301, height: 309)

  /// Points along one arc and its arrowhead, in design space, turned by `rotation`
  /// degrees and grown by `growth` about the centre.
  static func arrow(startAngle: Double, head: CGPoint, rotation: Double, growth: CGFloat, segments: Int = 48) -> [CGPoint] {
    let end = startAngle + 90
    var points: [CGPoint] = (0 ... segments).map { i in
      let a = (startAngle + (end - startAngle) * Double(i) / Double(segments)) * .pi / 180
      return CGPoint(x: center.x + ringRadius * growth * CGFloat(cos(a)), y: center.y + ringRadius * growth * CGFloat(sin(a)))
    }
    let a = end * .pi / 180
    let tip = CGPoint(x: center.x + ringRadius * CGFloat(cos(a)), y: center.y + ringRadius * CGFloat(sin(a)))
    let last = points[points.count - 1]
    points.append(CGPoint(x: last.x + (head.x - tip.x) * growth, y: last.y + (head.y - tip.y) * growth))
    let r = rotation * .pi / 180
    return points.map { p in
      let dx = p.x - center.x, dy = p.y - center.y
      return CGPoint(x: center.x + dx * CGFloat(cos(r)) - dy * CGFloat(sin(r)),
                     y: center.y + dx * CGFloat(sin(r)) + dy * CGFloat(cos(r)))
    }
  }
}

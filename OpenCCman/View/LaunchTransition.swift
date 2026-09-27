import SwiftUI

// MARK: - Coordinator

/// Cold-launch transition shared by every window. Windows that appear before
/// the first transition ends take part; later windows open without it.
@MainActor
final class LaunchTransitionCoordinator: ObservableObject {
  enum Style: Equatable {
    /// iOS: the launch mark unpacks into the workspace.
    case unpack
    /// iOS with Reduce Motion: the launch screen fades out.
    case fade
    /// macOS: no launch screen; the first window's content settles.
    case settle
    case none
  }

  let style: Style
  @Published private(set) var starts: [UUID: Date] = [:]
  @Published private(set) var finished: Set<UUID> = []
  @Published private(set) var accepting: Bool

  convenience init(arguments: [String] = ProcessInfo.processInfo.arguments) {
    #if os(iOS)
      let reduceMotion = UIAccessibility.isReduceMotionEnabled
      let voiceOver = UIAccessibility.isVoiceOverRunning
    #else
      let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      let voiceOver = NSWorkspace.shared.isVoiceOverEnabled
    #endif
    self.init(arguments: arguments, reduceMotion: reduceMotion, voiceOver: voiceOver)
  }

  init(arguments: [String], reduceMotion: Bool, voiceOver: Bool) {
    if arguments.contains("-skip-launch-transition") || voiceOver {
      style = .none
    } else {
      #if os(iOS)
        style = reduceMotion ? .fade : .unpack
      #else
        style = reduceMotion ? .none : .settle
      #endif
    }
    accepting = style != .none
    guard accepting else { return }
    // Fail open: never keep a pending window hidden behind the launch mark.
    DispatchQueue.main.asyncAfter(deadline: .now() + LaunchMotion.launchWatchdog) { [weak self] in
      guard let self, starts.isEmpty else { return }
      accepting = false
    }
  }

  func stage(for window: UUID) -> LaunchReveal.Stage {
    if let start = starts[window] {
      return finished.contains(window) ? .finished : .running(start)
    }
    return accepting ? .pending : .finished
  }

  func start(window: UUID) {
    guard accepting, starts[window] == nil else { return }
    // The start may lie ahead: the mark rests until the system's launch-screen fade ends.
    let hold = style == .settle ? 0 : LaunchMotion.systemHandoff
    starts[window] = Date().addingTimeInterval(hold)
    let duration: Double
    switch style {
    case .fade: duration = LaunchMotion.reduceMotionFade
    case .settle: duration = LaunchMotion.macTotal
    case .unpack, .none: duration = LaunchMotion.duration
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + hold + duration + 0.05) { [weak self] in
      guard let self else { return }
      finished.insert(window)
      accepting = false
    }
  }
}

// MARK: - Environment

struct LaunchReveal: Equatable {
  enum Stage: Equatable {
    case pending
    case running(Date)
    case finished
  }

  var stage: Stage = .finished
  var style: LaunchTransitionCoordinator.Style = .none
  /// Window centre in global coordinates, where the mark sits.
  var center: CGPoint = .zero
  var maxRadius: CGFloat = 0

  var isActive: Bool { stage != .finished && style != .none }
}

private struct LaunchRevealKey: EnvironmentKey {
  static let defaultValue = LaunchReveal()
}

extension EnvironmentValues {
  var launchReveal: LaunchReveal {
    get { self[LaunchRevealKey.self] }
    set { self[LaunchRevealKey.self] = newValue }
  }
}

enum LaunchHandoffTarget: Hashable {
  case source, result

  var index: Int { self == .source ? 0 : 1 }
}

struct LaunchHandoffKey: PreferenceKey {
  static let defaultValue: [LaunchHandoffTarget: Anchor<CGRect>] = [:]
  static func reduce(value: inout [LaunchHandoffTarget: Anchor<CGRect>], nextValue: () -> [LaunchHandoffTarget: Anchor<CGRect>]) {
    value.merge(nextValue()) { current, _ in current }
  }
}

extension View {
  /// Hidden until the iris reaches it, then settles with the launch spring.
  /// `order` staggers the Mac variant, which has no iris.
  func launchSettle(pop: Bool = false, order: Int = 0) -> some View {
    modifier(LaunchSettleModifier(pop: pop, order: order))
  }

  /// A pane title that receives a glyph from the launch mark.
  func launchHandoffTarget(_ target: LaunchHandoffTarget) -> some View {
    modifier(LaunchHandoffTargetModifier(target: target))
  }
}

extension LaunchMotion.Spring {
  var animation: Animation { .spring(response: response, dampingFraction: damping) }
}

// MARK: - Modifiers

private struct LaunchSettleModifier: ViewModifier {
  let pop: Bool
  let order: Int
  @Environment(\.launchReveal) private var reveal
  @State private var arrived = false
  @State private var frame: CGRect?

  func body(content: Content) -> some View {
    let moves = reveal.style == .unpack || reveal.style == .settle
    let hidden = moves && reveal.isActive && !arrived
    let scale = pop ? LaunchMotion.popScale : reveal.style == .settle ? 1 : LaunchMotion.settleScale
    let offset = pop ? 0 : reveal.style == .settle ? LaunchMotion.macOffset : LaunchMotion.settleOffset
    content
      .opacity(hidden ? 0 : 1)
      .scaleEffect(hidden ? scale : 1)
      .offset(y: hidden ? offset : 0)
      .background(GeometryReader { proxy in
        Color.clear.onAppear {
          let frame = proxy.frame(in: .global)
          self.frame = frame
          schedule(reveal, frame: frame)
        }
      })
      .onAppear { schedule(reveal, frame: frame) }
      // An onChange action belongs to the previous render: use the value it is given.
      .onChange(of: reveal) { schedule($0, frame: frame) }
  }

  private func schedule(_ reveal: LaunchReveal, frame: CGRect?) {
    guard !arrived else { return }
    switch reveal.stage {
    case .pending:
      return
    case .finished:
      arrived = true
    case let .running(start):
      let delay: Double
      let animation: Animation
      switch reveal.style {
      case .unpack:
        guard let frame else { return }
        let distance = hypot(frame.midX - reveal.center.x, frame.midY - reveal.center.y)
        delay = LaunchMotion.irisArrival(distance: distance, maxRadius: reveal.maxRadius)
        animation = (pop ? LaunchMotion.pop : LaunchMotion.settle).animation
      case .settle:
        delay = LaunchMotion.macDelay + Double(order) * LaunchMotion.macStagger
        animation = .easeOut(duration: LaunchMotion.macDuration)
      case .fade, .none:
        arrived = true
        return
      }
      let wait = max(0, delay - Date().timeIntervalSince(start))
      withAnimation(animation.delay(wait)) { arrived = true }
    }
  }
}

private struct LaunchHandoffTargetModifier: ViewModifier {
  let target: LaunchHandoffTarget
  @Environment(\.launchReveal) private var reveal
  @State private var shown = false

  func body(content: Content) -> some View {
    let hidden = reveal.style == .unpack && reveal.isActive && !shown
    content
      .opacity(hidden ? 0 : 1)
      .anchorPreference(key: LaunchHandoffKey.self, value: .bounds) { [target: $0] }
      .onAppear { schedule(reveal) }
      .onChange(of: reveal) { schedule($0) }
  }

  private func schedule(_ reveal: LaunchReveal) {
    guard !shown else { return }
    switch reveal.stage {
    case .pending:
      return
    case .finished:
      shown = true
    case let .running(start):
      guard reveal.style == .unpack else {
        shown = true
        return
      }
      let delay = LaunchMotion.labelFadeDelay + Double(target.index) * LaunchMotion.handoffStagger
      withAnimation(.easeOut(duration: LaunchMotion.labelFadeDuration).delay(max(0, delay - Date().timeIntervalSince(start)))) {
        shown = true
      }
    }
  }
}

// MARK: - Overlay

/// Launch-screen cover with an opening iris, the turning ring and the glyphs
/// flying to their pane titles. It never takes input or accessibility focus.
struct LaunchTransitionOverlay: View {
  let reveal: LaunchReveal
  let targets: [LaunchHandoffTarget: CGRect]

  var body: some View {
    GeometryReader { proxy in
      TimelineView(.animation(minimumInterval: nil, paused: !isRunning)) { context in
        frame(t: elapsed(at: context.date), size: proxy.size)
      }
    }
  }

  private var isRunning: Bool {
    if case .running = reveal.stage { return true }
    return false
  }

  private func elapsed(at date: Date) -> Double {
    if case let .running(start) = reveal.stage { return max(0, date.timeIntervalSince(start)) }
    return 0
  }

  @ViewBuilder
  private func frame(t: Double, size: CGSize) -> some View {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    if reveal.style == .fade {
      ZStack {
        Color("LaunchBackground")
        mark(t: 0, center: center, size: size)
      }
      .opacity(1 - min(t / LaunchMotion.reduceMotionFade, 1))
    } else {
      let maxRadius = LaunchMotion.maxRadius(for: size)
      let radius = LaunchMotion.irisRadius(at: t, maxRadius: maxRadius)
      ZStack {
        Path { path in
          path.addRect(CGRect(origin: .zero, size: size))
          path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        .fill(Color("LaunchBackground"), style: FillStyle(eoFill: true))
        mark(t: t, center: center, size: size, radius: radius, maxRadius: maxRadius)
      }
    }
  }

  private func mark(t: Double, center: CGPoint, size: CGSize, radius: CGFloat = 0, maxRadius: CGFloat = 1) -> some View {
    let k = LaunchMark.scale
    let ringRadius = LaunchMark.ringRadius * k
    let growth = max(1, radius / ringRadius)
    let fade = min(max((radius - ringRadius) / (0.59 * maxRadius), 0), 1)
    let rotation = LaunchMotion.exchangeTurn * LaunchMotion.exchange.value(at: t)
    let pulse = 1 + 0.05 * CGFloat(sin(min(t / 0.3, 1) * .pi))
    return ZStack {
      arrow(.blue, rotation: rotation, growth: growth * pulse, center: center, fade: fade)
      arrow(.purple, rotation: rotation, growth: growth * pulse, center: center, fade: fade)
      glyph(.source, t: t, center: center, width: size.width)
      glyph(.result, t: t, center: center, width: size.width)
    }
  }

  private enum Arc { case blue, purple }

  private func arrow(_ arc: Arc, rotation: Double, growth: CGFloat, center: CGPoint, fade: CGFloat) -> some View {
    let k = LaunchMark.scale
    let points = arc == .blue
      ? LaunchMark.arrow(startAngle: -90, head: LaunchMark.blueHead, rotation: rotation, growth: growth)
      : LaunchMark.arrow(startAngle: 90, head: LaunchMark.purpleHead, rotation: rotation, growth: growth)
    return Path { path in
      path.addLines(points.map { CGPoint(x: center.x + ($0.x - LaunchMark.center.x) * k, y: center.y + ($0.y - LaunchMark.center.y) * k) })
    }
    .stroke(Color(arc == .blue ? "LaunchRingBlue" : "LaunchRingPurple"),
            style: StrokeStyle(lineWidth: LaunchMark.lineWidth * k * (1 - 0.4 * fade), lineCap: .butt, lineJoin: .miter))
    .opacity(Double(1 - fade))
  }

  private func glyph(_ target: LaunchHandoffTarget, t: Double, center: CGPoint, width: CGFloat) -> some View {
    let k = LaunchMark.scale
    let box = target == .source ? LaunchMark.jian : LaunchMark.fan
    let home = CGPoint(x: center.x + (box.midX - LaunchMark.center.x) * k, y: center.y + (box.midY - LaunchMark.center.y) * k)
    let lag = Double(target.index) * LaunchMotion.handoffStagger
    let p = CGFloat(min(max(LaunchMotion.handoff.value(at: t - LaunchMotion.handoffDelay - lag), 0), 1.08))
    let fade = min(max((t - LaunchMotion.labelFadeDelay - lag) / LaunchMotion.labelFadeDuration, 0), 1)
    let breathe = 1 - 0.05 * CGFloat(sin(min(t / 0.3, 1) * .pi))
    var position = home
    var scale: CGFloat = breathe
    if let rect = targets[target] {
      let bend = (target == .source ? -46 : 46) * width / 440
      position = CGPoint(x: home.x + (rect.midX - home.x) * p + CGFloat(sin(Double(p) * .pi)) * bend,
                         y: home.y + (rect.midY - home.y) * p)
      let end = rect.height * 1.05 / (box.height * k)
      scale = (1 + (end - 1) * min(p, 1)) * breathe
    }
    return Image(target == .source ? "LaunchGlyphJian" : "LaunchGlyphFan")
      .resizable()
      .renderingMode(.template)
      .foregroundColor(Color("LaunchInk"))
      .frame(width: box.width * k, height: box.height * k)
      .scaleEffect(scale)
      .position(position)
      .opacity(1 - fade)
  }
}

import Foundation
import SwiftUI

@main
enum LaunchTransitionChecks {
  @MainActor
  static func main() {
    // Curves: springs start at rest and settle; the iris ease is monotonic and symmetric.
    for spring in [LaunchMotion.exchange, LaunchMotion.handoff, LaunchMotion.settle, LaunchMotion.pop] {
      precondition(spring.value(at: 0) == 0 && abs(1 - spring.value(at: 2)) < 1e-4)
    }
    precondition(LaunchMotion.exchange.settlingTime() <= 0.30, "The exchange settles within its 300 ms phase")
    precondition(LaunchMotion.iris.value(at: 0) == 0 && LaunchMotion.iris.value(at: 1) == 1)
    precondition(abs(LaunchMotion.iris.value(at: 0.5) - 0.5) < 1e-6)
    var previous = 0.0
    for step in 0 ... 200 {
      let value = LaunchMotion.iris.value(at: Double(step) / 200)
      precondition(value >= previous - 1e-12, "The iris never closes")
      previous = value
    }

    // Each element settles when the wavefront reaches it.
    let maxRadius = LaunchMotion.maxRadius(for: CGSize(width: 402, height: 874))
    for distance in stride(from: CGFloat(0), through: maxRadius, by: 20) {
      let t = LaunchMotion.irisArrival(distance: distance, maxRadius: maxRadius)
      precondition(abs(LaunchMotion.irisRadius(at: t, maxRadius: maxRadius) - distance) < 0.5)
      precondition(t >= LaunchMotion.irisDelay && t <= LaunchMotion.irisDelay + LaunchMotion.irisDuration)
    }

    // Phase budget: 0.8 s on iOS, about 320 ms for the Mac window.
    precondition(LaunchMotion.irisDelay + LaunchMotion.irisDuration <= LaunchMotion.duration)
    precondition(LaunchMotion.labelFadeDelay + LaunchMotion.handoffStagger + LaunchMotion.labelFadeDuration <= LaunchMotion.duration)
    precondition(LaunchMotion.macTotal <= 0.32 + 1e-9)

    // Mark geometry matches the icon; half a turn swaps the arrows.
    let blue = LaunchMark.arrow(startAngle: -90, head: LaunchMark.blueHead, rotation: 0, growth: 1)
    precondition(near(blue[0], CGPoint(x: 512, y: 164)) && near(blue[blue.count - 1], LaunchMark.blueHead))
    let purple = LaunchMark.arrow(startAngle: 90, head: LaunchMark.purpleHead, rotation: 0, growth: 1)
    precondition(near(purple[0], CGPoint(x: 512, y: 860)) && near(purple[purple.count - 1], LaunchMark.purpleHead))
    let turned = LaunchMark.arrow(startAngle: -90, head: LaunchMark.blueHead, rotation: 180, growth: 1)
    precondition(near(turned[0], purple[0]) && near(turned[turned.count - 1], LaunchMark.purpleHead))

    // Opt-outs.
    precondition(LaunchTransitionCoordinator(arguments: ["-skip-launch-transition"], reduceMotion: false, voiceOver: false).style == .none)
    precondition(LaunchTransitionCoordinator(arguments: [], reduceMotion: false, voiceOver: true).style == .none)
    #if os(macOS)
      precondition(LaunchTransitionCoordinator(arguments: [], reduceMotion: true, voiceOver: false).style == .none)
      let mac = LaunchTransitionCoordinator(arguments: [], reduceMotion: false, voiceOver: false)
      precondition(mac.style == .settle)
      let macWindow = UUID()
      mac.start(window: macWindow)
      precondition(mac.starts[macWindow].map { abs($0.timeIntervalSinceNow) < 0.05 } == true, "No launch screen to wait for on Mac")
      RunLoop.main.run(until: Date().addingTimeInterval(LaunchMotion.macTotal + 0.15))
      precondition(mac.stage(for: macWindow) == .finished, "The Mac window stops blocking What’s New once it has settled")
    #endif
    let skipped = LaunchTransitionCoordinator(arguments: ["-skip-launch-transition"], reduceMotion: false, voiceOver: false)
    precondition(skipped.stage(for: UUID()) == .finished)

    // Windows present at launch take part once; later windows open without it.
    let launch = LaunchTransitionCoordinator(arguments: [], reduceMotion: false, voiceOver: false)
    let first = UUID(), restored = UUID(), later = UUID()
    precondition(launch.stage(for: first) == .pending && launch.stage(for: restored) == .pending)
    launch.start(window: first)
    let started = launch.starts[first]
    guard case .running = launch.stage(for: first) else { preconditionFailure("The first window runs") }
    launch.start(window: first)
    precondition(launch.starts[first] == started, "A window starts once")
    launch.start(window: restored)
    guard case .running = launch.stage(for: restored) else { preconditionFailure("Restored windows take part") }
    RunLoop.main.run(until: Date().addingTimeInterval(LaunchMotion.duration + 0.25))
    precondition(launch.stage(for: first) == .finished && launch.stage(for: restored) == .finished)
    precondition(launch.stage(for: later) == .finished, "Later windows open without the transition")
    launch.start(window: later)
    precondition(launch.stage(for: later) == .finished)

    // Fail open: with no window started, pending windows are released.
    let idle = LaunchTransitionCoordinator(arguments: [], reduceMotion: false, voiceOver: false)
    let waiting = UUID()
    precondition(idle.stage(for: waiting) == .pending)
    RunLoop.main.run(until: Date().addingTimeInterval(LaunchMotion.launchWatchdog + 0.2))
    precondition(idle.stage(for: waiting) == .finished, "The watchdog releases a window that never started")
    precondition(LaunchMotion.activationTimeout < LaunchMotion.launchWatchdog, "The forced start comes before the watchdog")

    // The overlay never outlives the What’s New blocker it sets.
    var eligibility = WhatsNewEligibility(isActive: true, isHome: true)
    eligibility.isLaunchTransitionRunning = true
    precondition(!eligibility.canPresent)
    print("PASS: launch curves, iris wavefront timing, phase budget, mark geometry, window stages and opt-outs")
  }

  private static func near(_ a: CGPoint, _ b: CGPoint) -> Bool {
    abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01
  }
}

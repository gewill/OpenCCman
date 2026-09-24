import Foundation

@main
enum WhatsNewChecks {
  @MainActor
  static func main() {
    let suite = "OpenCCman.WhatsNewChecks.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let key = WhatsNewCoordinator.lastPresentedVersionKey
    let first = UUID(), second = UUID()
    let ready = WhatsNewEligibility(isActive: true, isHome: true)
    let coordinator = WhatsNewCoordinator(version: "2.0", defaults: defaults)

    precondition(WhatsNewRelease.hasUnreadContent(for: "2.0", defaults: defaults))
    precondition(!WhatsNewRelease.hasUnreadContent(for: "9.9", defaults: defaults))

    precondition(coordinator.release?.cards.map(\.id) == ["workspace", "presets", "files", "reliability"])
    precondition(WhatsNewRelease.content(for: "1.3")?.cards.map(\.id) == ["presets", "files", "reliability"])
    precondition(WhatsNewRelease.content(for: "1.2") == nil)
    precondition(WhatsNewRelease.content(for: "1.4") == nil)
    precondition(WhatsNewRelease.content(for: "") == nil)
    let unknown = WhatsNewCoordinator(version: "1.4", defaults: defaults)
    precondition(unknown.reserve(for: first, eligibility: ready, manually: true) == nil)

    // Every blocker defers both automatic and manual requests, without writing defaults.
    let blockers: [WritableKeyPath<WhatsNewEligibility, Bool>] = [
      \.isConverting, \.isImporting, \.hasFilePanel, \.hasAlert, \.hasProSheet, \.hasSettingsSheet,
    ]
    for blocker in blockers {
      var busy = ready
      busy[keyPath: blocker] = true
      for manually in [false, true] {
        precondition(coordinator.reserve(for: first, eligibility: busy, manually: manually) == nil)
        precondition(defaults.string(forKey: key) == nil && coordinator.owner == nil)
      }
    }
    var inactive = ready
    inactive.isActive = false
    precondition(coordinator.reserve(for: first, eligibility: inactive, manually: false) == nil)
    precondition(coordinator.reserve(for: first, eligibility: inactive, manually: true) == nil)
    var settings = ready
    settings.isHome = false
    precondition(coordinator.reserve(for: first, eligibility: settings, manually: false) == nil)
    var otherRoute = settings
    otherRoute.isSupportedRoute = false
    precondition(coordinator.reserve(for: first, eligibility: otherRoute, manually: true) == nil)

    let windowState = WhatsNewWindowState()
    windowState.showingProSheet = true
    windowState.showingProSheet = false
    precondition(windowState.proSheetIsActive, "Keep blocking until the Pro sheet’s onDismiss callback")
    windowState.proSheetIsActive = false

    // Settings dismissal must defer a pending card until the system has finished.
    let secondWindowState = WhatsNewWindowState()
    windowState.showingConversionSettings = true
    windowState.showingConversionSettings = false
    precondition(windowState.conversionSettingsIsActive)
    precondition(!secondWindowState.conversionSettingsIsActive)
    var dismissing = ready
    dismissing.hasSettingsSheet = windowState.conversionSettingsIsActive
    precondition(coordinator.reserve(for: first, eligibility: dismissing, manually: true) == nil)
    precondition(coordinator.owner == nil && defaults.string(forKey: key) == nil)
    windowState.conversionSettingsIsActive = false // Host onDismiss.
    dismissing.hasSettingsSheet = windowState.conversionSettingsIsActive
    precondition(coordinator.reserve(for: first, eligibility: dismissing, manually: true) != nil)
    coordinator.finish(in: first)

    precondition(coordinator.reserve(for: first, eligibility: ready, manually: false) != nil)
    precondition(defaults.string(forKey: key) == nil, "Reservation alone must not mark a version seen")
    precondition(coordinator.reserve(for: second, eligibility: ready, manually: false) == nil)
    precondition(coordinator.reserve(for: second, eligibility: settings, manually: true) == nil)
    coordinator.didAppear(in: second)
    coordinator.finish(in: second)
    precondition(defaults.string(forKey: key) == nil && coordinator.owner == first)
    coordinator.finish(in: first) // Window closes before sheet appears.
    precondition(defaults.string(forKey: key) == nil)
    precondition(coordinator.reserve(for: second, eligibility: ready, manually: false) != nil)
    coordinator.didAppear(in: first) // Stale callback from the closed window.
    precondition(defaults.string(forKey: key) == nil)
    coordinator.didAppear(in: second)
    precondition(defaults.string(forKey: key) == "2.0")
    precondition(!WhatsNewRelease.hasUnreadContent(for: "2.0", defaults: defaults))
    coordinator.finish(in: second)
    precondition(coordinator.reserve(for: first, eligibility: ready, manually: false) == nil)

    let relaunched = WhatsNewCoordinator(version: "2.0", defaults: defaults)
    precondition(relaunched.reserve(for: first, eligibility: ready, manually: false) == nil,
                 "Relaunches and build-number changes within the marketing version must stay quiet")
    precondition(relaunched.reserve(for: first, eligibility: settings, manually: true) != nil)
    relaunched.didAppear(in: first)
    relaunched.finish(in: first)

    defaults.set("1.3", forKey: key)
    let upgraded = WhatsNewCoordinator(version: "2.0", defaults: defaults)
    precondition(upgraded.reserve(for: first, eligibility: settings, manually: true) != nil)
    upgraded.didAppear(in: first)
    upgraded.finish(in: first)
    precondition(upgraded.reserve(for: first, eligibility: ready, manually: false) == nil,
                 "Manual viewing before automatic presentation also counts")
    defaults.set("1.3", forKey: key)
    let skipped = WhatsNewCoordinator(version: "2.0", defaults: defaults, skipAutomatic: true)
    precondition(skipped.reserve(for: first, eligibility: ready, manually: false) == nil)
    precondition(skipped.reserve(for: first, eligibility: settings, manually: true) != nil)
    skipped.finish(in: first)
    let newVersion = WhatsNewCoordinator(version: "2.0", defaults: defaults)
    precondition(newVersion.reserve(for: first, eligibility: ready, manually: false) != nil)
    print("PASS: What’s New content, version persistence, presentation blockers, multi-window ownership, manual viewing and test opt-out")
  }
}

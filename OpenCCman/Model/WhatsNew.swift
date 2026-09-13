import Combine
import Foundation

struct WhatsNewRelease: Identifiable {
  struct Card: Identifiable {
    let id: String
    let symbol: String
    var titleKey: String { "whats_new_\(id)_title" }
    var detailKey: String { "whats_new_\(id)_detail" }
  }

  let version: String
  let cards: [Card]
  var id: String { version }

  static func content(for version: String) -> WhatsNewRelease? {
    guard version == "1.3" else { return nil }
    return WhatsNewRelease(version: version, cards: [
      Card(id: "presets", symbol: "slider.horizontal.3"),
      Card(id: "files", symbol: "doc.text"),
      Card(id: "reliability", symbol: "checkmark.shield"),
    ])
  }
}

/// Shared by all WindowGroups. Reserving a window never records a presentation.
@MainActor
final class WhatsNewCoordinator: ObservableObject {
  static let lastPresentedVersionKey = "lastPresentedWhatsNewVersion"
  let release: WhatsNewRelease?
  @Published private(set) var owner: UUID?
  private(set) var hasAppeared = false
  private let defaults: UserDefaults
  private let skipAutomatic: Bool

  init(version: String, defaults: UserDefaults = .standard, skipAutomatic: Bool = false) {
    release = WhatsNewRelease.content(for: version)
    self.defaults = defaults
    self.skipAutomatic = skipAutomatic
  }

  func reserve(for window: UUID, eligibility: WhatsNewEligibility, manually: Bool) -> WhatsNewRelease? {
    guard let release, owner == nil, eligibility.canPresent,
          manually || (eligibility.isHome && !skipAutomatic
            && defaults.string(forKey: Self.lastPresentedVersionKey) != release.version) else { return nil }
    hasAppeared = false
    owner = window
    return release
  }

  func didAppear(in window: UUID) {
    guard owner == window, let release else { return }
    hasAppeared = true
    defaults.set(release.version, forKey: Self.lastPresentedVersionKey)
  }

  func finish(in window: UUID) {
    guard owner == window else { return }
    hasAppeared = false
    owner = nil
  }
}

struct WhatsNewEligibility: Equatable {
  var isActive = false
  var isHome = false
  var isSupportedRoute = true
  var isConverting = false
  var isImporting = false
  var hasFilePanel = false
  var hasAlert = false
  var hasProSheet = false

  var canPresent: Bool {
    isActive && isSupportedRoute && !isConverting && !isImporting && !hasFilePanel && !hasAlert && !hasProSheet
  }
}

/// Window-local system presentations are visible to the root presentation host.
final class WhatsNewWindowState: ObservableObject {
  @Published var showingImporter = false
  @Published var showingExporter = false
  @Published var showingProSheet = false {
    didSet { if showingProSheet { proSheetIsActive = true } }
  }
  @Published var proSheetIsActive = false
  @Published var manualRequest: UUID?
}

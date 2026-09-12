import Foundation

enum TestNumbersPerDayManager {
  // Reservations can be released by a task or view model's deinit. Protect the
  // entire read/check/write operation, including the shared date formatter.
  private static let lock = NSLock()
  private static var pending: [UUID: String] = [:]

  final class Reservation: Sendable {
    fileprivate let id = UUID()

    fileprivate init() {}

    func commit() { TestNumbersPerDayManager.finish(self, successful: true) }
    func release() { TestNumbersPerDayManager.finish(self, successful: false) }
    deinit { release() }
  }

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  static func reserve() -> Reservation? {
    lock.lock()
    defer { lock.unlock() }
    guard !isPro else { return Reservation() }
    let today = dayFormatter.string(from: Date())
    guard usedCount(on: today) < FreeFeature.maxTestNumber else { return nil }
    let reservation = Reservation()
    pending[reservation.id] = today
    return reservation
  }

  static var isToMax: Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !isPro else { return false }
    let today = dayFormatter.string(from: Date())
    return usedCount(on: today) >= FreeFeature.maxTestNumber
  }

  private static var isPro: Bool {
    UserDefaults.standard.bool(forKey: UserDefaultsKeys.isPro.rawValue)
  }

  private static func usedCount(on day: String) -> Int {
    (appDefaults[\.testNumbersPerDay][day] ?? 0)
      + pending.values.filter { $0 == day }.count
  }

  private static func finish(_ reservation: Reservation, successful: Bool) {
    lock.lock()
    defer { lock.unlock() }
    // Removing the token makes success, cancellation and cleanup idempotent.
    guard let day = pending.removeValue(forKey: reservation.id), successful, !isPro else { return }
    let today = dayFormatter.string(from: Date())
    // A conversion belongs to its starting day. Do not overwrite today's
    // count when yesterday's conversion finishes after midnight.
    guard day == today else { return }
    let count = appDefaults[\.testNumbersPerDay][today] ?? 0
    appDefaults[\.testNumbersPerDay] = [today: count + 1]
  }
}

import Foundation

/// Observe real HomeViewModel ownership without a window, SwiftUI root or router.
@main
struct ModelLifetimeChecks {
  private final class WeakModel {
    weak var value: HomeViewModel?
    init(_ value: HomeViewModel) { self.value = value }
  }

  @MainActor @inline(never)
  private static func createAndRelease(_ number: Int) -> WeakModel {
    autoreleasepool {
      let model = HomeViewModel()
      model.inputText = "Lifetime fixture \(number): 中文 é 👩🏽‍💻"
      let reference = WeakModel(model)
      withExtendedLifetime(model) {}
      return reference
    }
  }

  @MainActor
  static func main() async throws {
    defer { UserDefaults.standard.removePersistentDomain(forName: coreSuite) }
    var observations: [WeakModel] = []
    for batch in 1...3 {
      for index in 0..<10 {
        observations.append(createAndRelease(batch * 10 + index))
      }
      await Task.yield()
      try await Task.sleep(nanoseconds: 100_000_000)
      let alive = observations.filter { $0.value != nil }.count
      let record: [String: Any] = ["event": "standalone-model-lifetime", "batch": batch,
                                 "created": observations.count, "alive": alive,
                                 "os": ProcessInfo.processInfo.operatingSystemVersionString]
      FileHandle.standardError.write(try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]))
      FileHandle.standardError.write(Data([10]))
      precondition(alive == 0, "Models with no remaining owner must deinitialize")
    }
    precondition(coreQuotaCount == 0, "Model lifecycle checks must not consume conversion quota")
    print("PASS: 30 real HomeViewModel instances released without any UI host; quota unchanged")
  }
}

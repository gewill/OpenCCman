import Darwin
import Foundation
import OpenCC

/// Launched only by check-mobile-file-jobs.py in an isolated temporary root.
/// SIGKILL deliberately skips Swift cleanup; a different process then recovers.
@main enum MobileFileJobProbe {
  static func main() async throws {
    let arguments = CommandLine.arguments
    let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let mode = arguments[1]
    let hooks = MobileLargeFileService.Hooks(boundary: { stage in
      if mode == stage.rawValue {
        raise(SIGKILL)
        // Signal delivery can be asynchronous across threads. Do not execute
        // another filesystem operation while the process is being killed.
        while true { pause() }
      }
    })
    let service = MobileLargeFileService(root: root, protection: .init(available: true), hooks: hooks)
    if mode == "recover-empty" {
      guard try await service.recover() == .empty else { throw MobileLargeFileService.JobError.invalidJournal }
      print("PASS: fresh process removed incomplete job")
    } else if mode == "recover-ready" {
      guard case .ready(let ready) = try await service.recover() else { throw MobileLargeFileService.JobError.invalidJournal }
      guard try Data(contentsOf: ready.url) == Data("滑鼠\0漢字\r\n".utf8) else { throw MobileLargeFileService.JobError.invalidJournal }
      try await service.discard(ready.id)
      print("PASS: fresh process validated and exported complete result")
    } else {
      _ = try await service.convert(source: URL(fileURLWithPath: arguments[3]), options: [.traditionalize, .twIdiom])
      guard mode == "ready" else { throw MobileLargeFileService.JobError.invalidJournal }
      raise(SIGKILL)
    }
  }
}

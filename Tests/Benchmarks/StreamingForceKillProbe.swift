import Darwin
import Foundation
import OpenCC

/// Child process for scripts/probe-streaming-force-kill.py. All paths point to
/// generated fixtures; the parent owns cleanup because SIGKILL skips defer.
@main enum StreamingForceKillProbe {
  static func main() async throws {
    let args = CommandLine.arguments
    guard args.count == 3, ["middle", "before-commit", "normal"].contains(args[1]) else {
      fatalError("Usage: StreamingForceKillProbe <middle|before-commit|normal> <fixture-directory>")
    }

    let phase = args[1]
    let fixture = URL(fileURLWithPath: args[2], isDirectory: true)
    let ready = fixture.appendingPathComponent("ready.txt")
    let stageRecord = fixture.appendingPathComponent("staging-path.txt")
    let source = try OpenedTextFile(url: fixture.appendingPathComponent("source.txt"))

    let hooks = StreamingTextFileService.Hooks(
      temporaryDirectoryCreated: { directory in
        try! Data(directory.path.utf8).write(to: stageRecord, options: .atomic)
      },
      beforeCommit: {
        if phase == "before-commit" {
          try Data("before-commit".utf8).write(to: ready, options: .atomic)
          holdForParent()
        }
      }
    )
    _ = try await StreamingTextFileService.convert(
      source: source,
      destination: fixture.appendingPathComponent("converted.txt"),
      options: .traditionalize,
      progress: { processed, _ in
        if phase == "middle", processed >= 1024 * 1024, !FileManager.default.fileExists(atPath: ready.path) {
          try! Data("middle".utf8).write(to: ready, options: .atomic)
          holdForParent()
        }
      },
      hooks: hooks
    )
    precondition(phase == "normal", "The parent should have terminated the blocked child")
  }

  private static func holdForParent() -> Never {
    while true { Thread.sleep(forTimeInterval: 1) }
  }
}

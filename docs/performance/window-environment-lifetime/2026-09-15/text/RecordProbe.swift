import AppKit
import AVFoundation
import ScreenCaptureKit

final class RecordingStatus: NSObject, SCRecordingOutputDelegate, SCStreamDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var ended = false
  private var failed = false
  var isEnded: Bool { lock.withLock { ended } }
  var didFail: Bool { lock.withLock { failed } }
  func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) { print("RECORDING_STARTED"); fflush(stdout) }
  func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
    lock.withLock { ended = true }; print("RECORDING_FINISHED"); fflush(stdout)
  }
  func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { finish(error) }
  func stream(_ stream: SCStream, didStopWithError error: Error) { finish(error) }
  private func finish(_ error: Error) {
    lock.withLock { ended = true; failed = true }
    print("RECORDING_ERROR: \(error)"); fflush(stdout)
  }
}

@main struct RecordOwnedApp {
  @MainActor static func main() async throws {
    let bundle = "org.gewill.OpenCCman.MinimalTextProbe"
    guard CommandLine.arguments.count == 3, CGPreflightScreenCaptureAccess() else {
      throw NSError(domain: "Recording", code: 77, userInfo: [NSLocalizedDescriptionKey: "Arguments or existing Screen Recording permission missing; no permission requested"])
    }
    let output = URL(fileURLWithPath: CommandLine.arguments[1])
    let stop = CommandLine.arguments[2]
    guard !FileManager.default.fileExists(atPath: output.path), !FileManager.default.fileExists(atPath: stop) else {
      throw NSError(domain: "Recording", code: 2, userInfo: [NSLocalizedDescriptionKey: "Refusing an existing output/stop marker"])
    }
    let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
    guard let app = content.applications.first(where: { $0.bundleIdentifier == bundle }),
          let window = content.windows.first(where: { $0.owningApplication?.processID == app.processID && $0.frame.width >= 300 }),
          let display = content.displays.first(where: { $0.frame.contains(CGPoint(x: window.frame.midX, y: window.frame.midY)) }) else {
      throw NSError(domain: "Recording", code: 3, userInfo: [NSLocalizedDescriptionKey: "Owned diagnostic app/window/display not found"])
    }
    let filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width
    config.height = display.height
    config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
    config.capturesAudio = false
    config.captureMicrophone = false
    config.showsCursor = false
    let background = CGColor(gray: 0, alpha: 1)
    config.backgroundColor = background
    defer { withExtendedLifetime(background) {} }
    let status = RecordingStatus()
    let stream = SCStream(filter: filter, configuration: config, delegate: status)
    let recording = SCRecordingOutputConfiguration()
    recording.outputURL = output
    recording.videoCodecType = .h264
    recording.outputFileType = .mp4
    let destination = SCRecordingOutput(configuration: recording, delegate: status)
    try stream.addRecordingOutput(destination)
    print("OWNED_APP pid=\(app.processID) display=\(display.displayID) output=\(config.width)x\(config.height) audio=false microphone=false cursor=false"); fflush(stdout)
    try await stream.startCapture()
    let deadline = Date(timeIntervalSinceNow: 300)
    while Date() < deadline && !status.isEnded && !FileManager.default.fileExists(atPath: stop) {
      try await Task.sleep(nanoseconds: 250_000_000)
    }
    try await stream.stopCapture()
    let finishDeadline = Date(timeIntervalSinceNow: 5)
    while !status.isEnded && Date() < finishDeadline { try await Task.sleep(nanoseconds: 100_000_000) }
    guard status.isEnded && !status.didFail else { throw NSError(domain: "Recording", code: 4) }
  }
}

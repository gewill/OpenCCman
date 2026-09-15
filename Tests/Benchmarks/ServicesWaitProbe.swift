// Manual macOS Services caller; intentionally not linked into the app or CI.
import AppKit
import CryptoKit
import Foundation

private func emit(_ fields: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
}

private func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func run() throws -> Int32 {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 4, let samples = Int(args[3]), (1...20).contains(samples) else {
        FileHandle.standardError.write(Data("Usage: services-wait-probe SERVICE_NAME INPUT_UTF8 EXPECTED_UTF8 SAMPLES(1...20)\n".utf8))
        return 2
    }
    let inputData = try Data(contentsOf: URL(fileURLWithPath: args[1]))
    let expected = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    guard let input = String(data: inputData, encoding: .utf8), !input.isEmpty,
          String(data: expected, encoding: .utf8) != nil else {
        emit(["event": "precondition_failed", "reason": "Input must be nonempty UTF-8; expected output must be UTF-8."])
        return 2
    }
    // NSPerformService uses the application connection, even for a CLI caller.
    _ = NSApplication.shared
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    emit([
        "event": "metadata", "protocol": 1, "service_name": args[0],
        "caller": "NSPerformService CLI", "os": ProcessInfo.processInfo.operatingSystemVersionString,
        "input_bytes": inputData.count, "input_sha256": digest(inputData),
        "expected_bytes": expected.count, "expected_sha256": digest(expected),
        "samples_requested": samples,
        "provider_identity": "Not verified by NSPerformService; record unique registration and artifact separately.",
        "provider_startup_state": "Unobserved; sample index is not proof of cold or warm startup."
    ])
    for sample in 1...samples {
        let succeeded: Bool = autoreleasepool {
            board.clearContents()
            guard board.setString(input, forType: .string) else {
                emit(["event": "pasteboard_write_failed", "sample": sample])
                return false
            }
            // This event survives a terminated caller. It is not a completed sample.
            emit(["event": "sample_started", "sample": sample])
            let start = DispatchTime.now().uptimeNanoseconds
            let serviceSucceeded = NSPerformService(args[0], board)
            let end = DispatchTime.now().uptimeNanoseconds
            // Reading, encoding, hashing, and comparing happen strictly after stopping.
            let readStart = DispatchTime.now().uptimeNanoseconds
            let output = board.string(forType: .string).map { Data($0.utf8) }
            let readEnd = DispatchTime.now().uptimeNanoseconds
            let matches = output == expected
            var result: [String: Any] = [
                "event": "sample_completed", "sample": sample,
                "service_succeeded": serviceSucceeded, "output_matches_expected": matches,
                "service_call_ms": Double(end - start) / 1_000_000,
                "output_read_encode_ms": Double(readEnd - readStart) / 1_000_000
            ]
            if let output {
                result["output_bytes"] = output.count
                result["output_sha256"] = digest(output)
                result["pasteboard_unchanged"] = output == inputData
            }
            emit(result)
            return serviceSucceeded && matches
        }
        // Do not repeat a failed service, or fold failure time into success medians.
        guard succeeded else { return 4 }
    }
    emit(["event": "run_completed", "samples": samples])
    return 0
}

do { exit(try run()) }
catch {
    // Avoid printing filenames or document contents into a public report.
    emit(["event": "precondition_failed", "reason": "Unable to read the supplied UTF-8 fixture files."])
    exit(2)
}

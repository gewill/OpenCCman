#!/usr/bin/env python3
"""Run the actual shared pump on an explicitly selected Xcode destination.

Generates independent 100 MiB whole-text reference hashes on the Mac, then
compiles copied production sources and XCTest checks in an isolated SwiftPM
package. The simulator generates input and hashes output in bounded blocks.
Does not install the production App, change preferences, or enable its feature.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "OpenCCman/Services/ChineseConversionService.swift",
    "OpenCCman/Services/TextFileService.swift",
    "OpenCCman/Services/StreamingConversionPump.swift",
    "OpenCCman/Services/FileConversionPolicy.swift",
]
CHECKS = [
    "Tests/Regression/StreamingPumpChecks.swift",
    "Tests/Regression/StreamingPumpCapacityFixture.swift",
]


def run(command, directory, log, timeout=900):
    with log.open("w") as stream:
        subprocess.run(command, cwd=directory, stdout=stream, stderr=subprocess.STDOUT,
                       check=True, timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--destination", required=True,
                        help="Explicit Xcode destination, e.g. platform=iOS Simulator,id=<dedicated UDID>")
    parser.add_argument("--opencc-path", type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    lockfile = ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    original_lock = lockfile.read_bytes()
    pin = next(p for p in json.loads(original_lock)["pins"] if p["identity"] == "swiftyopencc")
    if args.opencc_path:
        wrapper = args.opencc_path.resolve()
        revision = subprocess.check_output(["git", "-C", str(wrapper), "rev-parse", "HEAD"], text=True).strip()
        if revision != pin["state"]["revision"]:
            parser.error("Local SwiftyOpenCC checkout must match the App's resolved revision")
        if subprocess.check_output(["git", "-C", str(wrapper), "status", "--porcelain"], text=True).strip():
            parser.error("Local SwiftyOpenCC checkout must be clean, including its submodules")
        dependency = f'.package(name: "swiftyopencc", path: {json.dumps(str(wrapper))})'
    else:
        dependency = f'.package(url: {json.dumps(pin["location"])}, revision: {json.dumps(pin["state"]["revision"])})'

    tracked = SOURCES + CHECKS + ["Tests/Benchmarks/StreamingPumpOracle.swift", "scripts/check-streaming-core.py"]
    metadata = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "app_sha": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        "wrapper_sha": pin["state"]["revision"],
        "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in tracked},
        "destination": args.destination,
        "scope": "Shared pump in an isolated test host; not App UI, providers, Pro or device memory acceptance",
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
    }
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")

    oracle = output / "oracle-package"
    oracle_sources = oracle / "Sources/StreamingPumpOracle"
    oracle_sources.mkdir(parents=True)
    for name in [SOURCES[0], CHECKS[1], "Tests/Benchmarks/StreamingPumpOracle.swift"]:
        shutil.copy2(ROOT / name, oracle_sources / Path(name).name)
    (oracle / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "StreamingPumpOracle", platforms: [.macOS(.v12)],
  dependencies: [DEPENDENCY],
  targets: [.executableTarget(name: "StreamingPumpOracle",
    dependencies: [.product(name: "OpenCC", package: "swiftyopencc")])])
'''.replace("DEPENDENCY", dependency))
    run(["swift", "run", "-c", "release", "--package-path", str(oracle),
         "StreamingPumpOracle", str(output)], ROOT, output / "oracle.log")

    package = output / "test-package"
    sources = package / "Sources/StreamingCore"
    tests = package / "Tests/StreamingCoreTests"
    sources.mkdir(parents=True)
    tests.mkdir(parents=True)
    for name in SOURCES:
        shutil.copy2(ROOT / name, sources / Path(name).name)
    for name in CHECKS:
        (tests / Path(name).name).write_text("@testable import StreamingCore\n" + (ROOT / name).read_text())
    shutil.copy2(output / "oracle.json", tests / "oracle.json")
    (tests / "StreamingCoreTests.swift").write_text('''import Foundation
import OpenCC
import XCTest
@testable import StreamingCore

final class StreamingCoreTests: XCTestCase {
  func testCrossPlatformSemanticsAndFailures() async throws {
    try await checkStreamingPump()
  }

  func test100MiBAgainstWholeFileOracle() async throws {
    let reference = try XCTUnwrap(Bundle.module.url(forResource: "oracle", withExtension: "json"))
    let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: reference)) as? [String: Any])
    let rows = try XCTUnwrap(report["references"] as? [[String: Any]])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stream-capacity-\\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("source.txt")
    let destination = directory.appendingPathComponent("partial.txt")
    try StreamingPumpCapacityFixture.write(to: source)
    XCTAssertEqual(try StreamingPumpCapacityFixture.hash(source), report["input_sha256"] as? String)
    XCTAssertEqual(StreamingPumpCapacityFixture.byteCount, FileConversionPolicy.mobileMaximumBytes)
    XCTAssertEqual(TextFileService.maximumBytes, FileConversionPolicy.editorMaximumBytes)
    XCTAssertEqual(rows.count, streamingPumpOptions.count)
    for options in streamingPumpOptions {
      let expected = try XCTUnwrap(rows.first { ($0["options"] as? Int) == options.rawValue })
      let result = try await runStreamingPump(source: source, destination: destination,
        expectedBytes: StreamingPumpCapacityFixture.byteCount, options: options)
      XCTAssertEqual(result.inputBytes, StreamingPumpCapacityFixture.byteCount)
      XCTAssertEqual(result.outputBytes, (expected["output_bytes"] as? NSNumber)?.uint64Value)
      XCTAssertEqual(try StreamingPumpCapacityFixture.hash(destination), expected["output_sha256"] as? String)
      print("PASS: 100 MiB shared pump, options=\\(options.rawValue), output=\\(result.outputBytes), full SHA256 matched Mac whole-text oracle")
    }
  }
}
''')
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "StreamingCore", platforms: [.macOS(.v12), .iOS(.v15)],
  dependencies: [DEPENDENCY], targets: [
    .target(name: "StreamingCore", dependencies: [.product(name: "OpenCC", package: "swiftyopencc")]),
    .testTarget(name: "StreamingCoreTests",
      dependencies: ["StreamingCore", .product(name: "OpenCC", package: "swiftyopencc")],
      resources: [.copy("oracle.json")])])
'''.replace("DEPENDENCY", dependency))
    run(["swift", "package", "--package-path", str(package), "resolve"], ROOT, output / "resolve.log")
    command = ["xcodebuild", "-scheme", "StreamingCore-Package", "-destination", args.destination,
               "-configuration", "Release", "-parallel-testing-enabled", "NO",
               "-derivedDataPath", str(output / "DerivedData"),
               "-resultBundlePath", str(output / "StreamingCore.xcresult"),
               "-onlyUsePackageVersionsFromResolvedFile", "CODE_SIGNING_ALLOWED=NO",
               "ENABLE_TESTABILITY=YES", "IPHONEOS_DEPLOYMENT_TARGET=15.0",
               "MACOSX_DEPLOYMENT_TARGET=12.0", "test"]
    metadata["test_command"] = command
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    run(command, package, output / "test.log")
    summary = subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary",
                                       "--path", str(output / "StreamingCore.xcresult")], text=True)
    (output / "test-summary.json").write_text(summary)
    result = json.loads(summary)
    if result.get("failedTests") or result.get("passedTests") != 2:
        raise RuntimeError(f"Expected two passing XCTest cases, got {result}")
    if lockfile.read_bytes() != original_lock:
        raise RuntimeError("Application Package.resolved changed during isolated verification")
    metadata["completed_at"] = datetime.now(timezone.utc).isoformat()
    metadata["passed_tests"] = result["passedTests"]
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"PASS: shared pump and seven 100 MiB full-hash comparisons on {args.destination}; evidence: {output}")


if __name__ == "__main__":
    main()

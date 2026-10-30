#!/usr/bin/env python3
"""Check actual mobile job services in isolated packages; optional native iOS XCTest.

Native probes SIGKILL only their own processes and recover using a fresh process.
They never access the production App container or user-selected files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [f"OpenCCman/Services/{name}.swift" for name in (
    "ChineseConversionService", "TextFileService", "StreamingConversionPump",
    "FileConversionPolicy", "MobileLargeFileService", "MobileLargeFileCoordinator", "MobileFileLifecycle")]
SOURCES.append("OpenCCman/Model/ConversionConfiguration.swift")
CHECK = "Tests/Regression/MobileFileJobChecks.swift"
PROBE = "Tests/Regression/MobileFileJobProbe.swift"
COORDINATOR_CHECK = "Tests/Regression/MobileCoordinatorChecks.swift"
LIFECYCLE_CHECK = "Tests/Regression/MobileLifecycleChecks.swift"


def run(command, cwd, log):
    with log.open("w") as stream:
        subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                       check=True, timeout=900)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--opencc-path", required=True, type=Path)
    parser.add_argument("--destination", help="Optional explicit iOS Simulator Xcode destination")
    parser.add_argument("--check-capacity-refresh", action="store_true",
                        help="Opt-in local real-disk probe: same service before/after a 256 MiB allocation")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    wrapper = args.opencc_path.resolve()
    lock = ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    lock_bytes = lock.read_bytes()
    pin = next(p for p in json.loads(lock_bytes)["pins"] if p["identity"] == "swiftyopencc")
    revision = subprocess.check_output(["git", "-C", str(wrapper), "rev-parse", "HEAD"], text=True).strip()
    if revision != pin["state"]["revision"] or subprocess.check_output(
        ["git", "-C", str(wrapper), "status", "--porcelain"], text=True).strip():
        parser.error("SwiftyOpenCC must be a clean checkout at the locked revision")
    package = output / "package"
    sources = package / "Sources/FileJobs"
    tests = package / "Tests/FileJobsTests"
    probe = package / "Sources/JobProbe"
    for directory in (sources, tests, probe):
        directory.mkdir(parents=True)
    for name in SOURCES:
        shutil.copy2(ROOT / name, sources / Path(name).name)
    (tests / Path(CHECK).name).write_text("@testable import FileJobs\n" + (ROOT / CHECK).read_text())
    (tests / Path(COORDINATOR_CHECK).name).write_text("@testable import FileJobs\n" + (ROOT / COORDINATOR_CHECK).read_text())
    (tests / Path(LIFECYCLE_CHECK).name).write_text("@testable import FileJobs\n" + (ROOT / LIFECYCLE_CHECK).read_text())
    (tests / "FileJobsTests.swift").write_text('''import XCTest
@testable import FileJobs
final class FileJobsTests: XCTestCase {
  func testJobs() async throws { try await checkMobileFileJobs() }
  func testCoordinator() async throws { try await checkMobileCoordinator() }
  #if os(iOS)
  func testLifecycleAdapter() async throws { try await checkMobileLifecycle() }
  #endif
}
''')
    (probe / "Main.swift").write_text("@testable import FileJobs\n" + (ROOT / PROBE).read_text())
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FileJobs", platforms: [.macOS(.v12), .iOS(.v15)],
 dependencies: [.package(name: "swiftyopencc", path: WRAPPER)], targets: [
 .target(name: "FileJobs", dependencies: [.product(name: "OpenCC", package: "swiftyopencc")]),
 .executableTarget(name: "JobProbe", dependencies: ["FileJobs", .product(name: "OpenCC", package: "swiftyopencc")]),
 .testTarget(name: "FileJobsTests", dependencies: ["FileJobs", .product(name: "OpenCC", package: "swiftyopencc")])])
'''.replace("WRAPPER", json.dumps(str(wrapper))))
    run(["swift", "test", "-c", "release", "-Xswiftc", "-enable-testing"], package, output / "native.log")
    source = output / "source.txt"
    source.write_bytes("鼠标\0汉字\r\n".encode())
    original = source.read_bytes()
    executable = package / ".build/release/JobProbe"
    if args.check_capacity_refresh:
        run([str(executable), "capacity-refresh", str(output / "capacity-probe"),
             str(output / "capacity-refresh.json")], package, output / "capacity-refresh.log")
    rows = []
    for stage in ("snapshotWrite", "conversionWrite", "outputSync", "afterOutputRename", "ready"):
        job_root = output / ("kill-" + stage)
        killed = subprocess.run([str(executable), stage, str(job_root), str(source)], capture_output=True)
        if killed.returncode != -signal.SIGKILL:
            raise RuntimeError(f"Probe did not reach SIGKILL at {stage}: {killed.returncode} {killed.stderr!r}")
        if source.read_bytes() != original:
            raise RuntimeError("Source changed")
        recovery = "recover-ready" if stage == "ready" else "recover-empty"
        run([str(executable), recovery, str(job_root)], package, output / f"{stage}.log")
        if list(job_root.iterdir()):
            raise RuntimeError("Owned job files remained after recovery/discard")
        rows.append({"stage": stage, "signal": "SIGKILL", "fresh_process_recovery": recovery,
                     "source_unchanged": True, "owned_files_remaining": 0})
    if args.destination:
        run(["xcodebuild", "-scheme", "FileJobs", "-destination", args.destination,
             "-configuration", "Release", "-parallel-testing-enabled", "NO",
             "-derivedDataPath", str(output / "DerivedData"), "-resultBundlePath", str(output / "FileJobs.xcresult"),
             "CODE_SIGNING_ALLOWED=NO", "ENABLE_TESTABILITY=YES", "IPHONEOS_DEPLOYMENT_TARGET=15.0", "test"],
            package, output / "ios.log")
        summary = subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path",
                                           str(output / "FileJobs.xcresult")], text=True)
        (output / "ios-summary.json").write_text(summary)
        result = json.loads(summary)
        if result.get("passedTests") != 3 or result.get("failedTests"):
            raise RuntimeError("Expected three passing job regression suites")
    if lock.read_bytes() != lock_bytes:
        raise RuntimeError("Application dependencies changed")
    report = {"source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                                 for name in SOURCES + [CHECK, COORDINATOR_CHECK, LIFECYCLE_CHECK, PROBE, "scripts/check-mobile-file-jobs.py"]},
              "wrapper_revision": revision, "kill_probes": rows, "ios_destination": args.destination,
              "real_capacity_probe": args.check_capacity_refresh,
              "scope": "Service tests; no UIKit lifecycle, real provider, protected-device, Pro or device memory acceptance"}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS: mobile job regression and five fresh-process SIGKILL recoveries; {output}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Probe SIGKILL at two real streaming-file boundaries in a child process.

This unsandboxed service probe does not replace native App, external-volume, or
power-loss acceptance. It generates only fixed test text and removes its own
staging directories after recording their identities and contents.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import signal
import stat
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "OpenCCman/Services/ChineseConversionService.swift",
    "OpenCCman/Services/TextFileService.swift",
    "OpenCCman/Services/StreamingTextFileService.swift",
    "OpenCCman/Services/StreamingConversionPump.swift",
    "OpenCCman/Services/FileConversionPolicy.swift",
    "Tests/Benchmarks/StreamingForceKillProbe.swift",
]
SIZE = 20 * 1024 * 1024
SOURCE_TILE = "头发干杯\n".encode()
OUTPUT_TILE = "頭髮乾杯\n".encode()
PRESERVED = b"EXISTING DESTINATION\n"


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(256 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def fixture_text(path):
    repetitions, remainder = divmod(SIZE, len(SOURCE_TILE))
    with path.open("wb") as stream:
        for _ in range(repetitions):
            stream.write(SOURCE_TILE)
        stream.write(b"a" * remainder)
    expected = hashlib.sha256(OUTPUT_TILE * repetitions + b"a" * remainder).hexdigest()
    return expected


def snapshot(directory):
    children = []
    for item in directory.iterdir():
        info = item.lstat()
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"Unexpected non-file staging child; preserve for inspection: {item}")
        children.append({"name": item.name, "bytes": info.st_size})
    return sorted(children, key=lambda item: item["name"])


def remove_owned_stage(directory, identity, children):
    """Never recursively remove a path that differs from this child record."""
    current = directory.lstat()
    if (not directory.is_absolute() or directory.parent.name != "TemporaryItems"
            or not re.fullmatch(r"NSIRD_StreamingForceKillProbe_[A-Za-z0-9]+", directory.name)
            or not stat.S_ISDIR(current.st_mode)
            or (current.st_dev, current.st_ino) != identity
            or snapshot(directory) != children
            or len(list(directory.iterdir())) != len(children)
            or any(not re.fullmatch(r"[0-9A-F-]+\.txt", item["name"]) for item in children)):
        raise RuntimeError(f"Generated staging identity changed; preserve for inspection: {directory}")
    shutil.rmtree(directory)


def run_case(binary, phase, fixtures, output):
    fixture = fixtures / phase
    fixture.mkdir()
    source, destination = fixture / "source.txt", fixture / "converted.txt"
    expected = fixture_text(source)
    destination.write_bytes(PRESERVED)
    source_hash, destination_hash = digest(source), digest(destination)
    stage = None
    stage_identity = None
    stage_children = None
    process = None
    try:
        with (output / f"{phase}.child.log").open("w") as log:
            process = subprocess.Popen([str(binary), phase, str(fixture)], stdout=log, stderr=subprocess.STDOUT)
            ready = fixture / "ready.txt"
            deadline = time.monotonic() + 30
            while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            if not ready.exists() or process.poll() is not None:
                raise RuntimeError(f"{phase}: child did not reach the requested boundary")
            stage = Path((fixture / "staging-path.txt").read_text())
            current = stage.lstat()
            stage_identity = (current.st_dev, current.st_ino)
            before = snapshot(stage)
            process.send_signal(signal.SIGKILL)
            code = process.wait(timeout=10)
        if code != -signal.SIGKILL:
            raise RuntimeError(f"{phase}: expected SIGKILL exit, got {code}")
        stage_children = snapshot(stage)
        if stage_children != before or digest(source) != source_hash or digest(destination) != destination_hash:
            raise RuntimeError(f"{phase}: observed files changed across SIGKILL")
        with (output / f"{phase}.next-process.log").open("w") as log:
            subprocess.run([str(binary), "normal", str(fixture)], stdout=log,
                           stderr=subprocess.STDOUT, check=True, timeout=30)
        if digest(source) != source_hash or digest(destination) != expected:
            raise RuntimeError(f"{phase}: the next process produced incorrect output")
        return {
            "phase": phase,
            "source_bytes": SIZE,
            "source_sha256": source_hash,
            "destination_sha256_before_and_after_kill": destination_hash,
            "destination_sha256_after_next_process": digest(destination),
            "staging_path": str(stage),
            "staging_after_kill": stage_children,
            "orphan_staging_after_next_process": stage.exists(),
            "child_exit": code,
        }
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=10)
        if stage is not None and stage.exists() and stage_identity is not None and stage_children is not None:
            remove_owned_stage(stage, stage_identity, stage_children)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path, help="New report directory")
    parser.add_argument("--opencc-path", type=Path, help="Clean checkout at the locked SwiftyOpenCC revision")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    pin_file = ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    pin = next(item for item in json.loads(pin_file.read_text())["pins"] if item["identity"] == "swiftyopencc")
    revision = pin["state"]["revision"]
    if args.opencc_path:
        checkout = args.opencc_path.resolve()
        actual = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        changes = subprocess.check_output(["git", "-C", str(checkout), "status", "--short"], text=True).strip()
        if actual != revision or changes:
            raise SystemExit("Local SwiftyOpenCC checkout must be clean and match Package.resolved")
        dependency = f'.package(name: "swiftyopencc", path: {json.dumps(str(checkout))})'
    else:
        dependency = f'.package(url: {json.dumps(pin["location"])}, revision: {json.dumps(revision)})'
    report = {
        "app_sha": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        "wrapper_sha": revision,
        "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES},
        "platform": platform.platform(),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "scope": "Unsandboxed copied service sources, fixed generated UTF-8 text, 20 MiB existing-target cases",
    }
    with tempfile.TemporaryDirectory(prefix="openccman-217-", dir=output) as temporary:
        temporary = Path(temporary)
        package = temporary / "package"
        sources = package / "Sources/StreamingForceKillProbe"
        sources.mkdir(parents=True)
        for name in SOURCES:
            shutil.copy2(ROOT / name, sources / Path(name).name)
        (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "StreamingForceKillProbe", platforms: [.macOS(.v12)],
  dependencies: [''' + dependency + '''],
  targets: [.executableTarget(name: "StreamingForceKillProbe",
    dependencies: [.product(name: "OpenCC", package: "swiftyopencc")])])
''')
        with (output / "build.log").open("w") as log:
            subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package)],
                           stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
        binary = package / ".build/release/StreamingForceKillProbe"
        report["binary_sha256"] = digest(binary)
        fixtures = temporary / "fixtures"
        fixtures.mkdir()
        report["cases"] = [run_case(binary, phase, fixtures, output) for phase in ("middle", "before-commit")]
    report["completed_at"] = datetime.now(timezone.utc).isoformat()
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"PASS: source and existing target preserved after both SIGKILL boundaries; report: {output / 'report.json'}")


if __name__ == "__main__":
    main()

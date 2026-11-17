#!/usr/bin/env python3
"""Repeatable, isolated Release probe of real OpenCC output; not App UI acceptance.

Requires a new output directory outside the repository. Limits are experimental
arguments, not product defaults. Each sample runs in a separate process.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", required=True, type=Path)
parser.add_argument("--opencc-path", type=Path, help="Read a local Git object store; never change its checkout")
parser.add_argument("--characters", nargs="+", type=int, default=[10000, 49000, 50001])
parser.add_argument("--character-cap", type=int, required=True)
parser.add_argument("--cell-cap", type=int, required=True)
parser.add_argument("--hunk-cap", type=int, required=True)
args = parser.parse_args()
output = args.output.expanduser().resolve()
if output == root or root in output.parents:
    parser.error("Evidence and build products must be outside the repository")
if any(n <= 0 for n in args.characters + [args.character_cap, args.cell_cap, args.hunk_cap]):
    parser.error("Counts and experimental limits must be positive")
output.mkdir(parents=True, exist_ok=False)
pins = json.loads((root / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())["pins"]
pin = next(p for p in pins if p["identity"] == "swiftyopencc")

def capture(command):
    return subprocess.check_output(command, cwd=root, text=True).strip()

paths = [root / "README.md"] + sorted((root / "docs").glob("*.md"))
corpus = "\n\n".join(p.read_text() for p in paths)
(output / "corpus.txt").write_text(corpus)
files = [root / "OpenCCman/Model/ConversionDiff.swift",
         root / "OpenCCman/Services/ChineseConversionService.swift",
         root / "Tests/Benchmarks/ConversionDiffBenchmark.swift", Path(__file__).resolve()]
context = {
    "started_at": datetime.now(timezone.utc).isoformat(),
    "source_sha": capture(["git", "rev-parse", "HEAD"]),
    "status": capture(["git", "status", "--porcelain"]),
    "source_sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
    "corpus_sources": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
    "corpus_sha256": hashlib.sha256(corpus.encode()).hexdigest(),
    "opencc_pin": pin, "system": capture(["sw_vers"]),
    "hardware": capture(["sysctl", "-n", "hw.model", "hw.memsize", "machdep.cpu.brand_string"]),
    "xcode": capture(["xcodebuild", "-version"]), "configuration": "Release",
    "limits": {"characters": args.character_cap, "cells": args.cell_cap, "hunks": args.hunk_cap},
}
(output / "context.json").write_text(json.dumps(context, ensure_ascii=False, indent=2) + "\n")
dependency = output / "SwiftyOpenCC"
with (output / "dependency.log").open("w") as log:
    subprocess.run(["git", "clone", "--no-hardlinks", "--no-checkout", str(args.opencc_path or pin["location"]), str(dependency)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    subprocess.run(["git", "-C", str(dependency), "checkout", "--detach", pin["state"]["revision"]], stdout=log, stderr=subprocess.STDOUT, check=True)
    subprocess.run(["git", "-C", str(dependency), "submodule", "update", "--init", "--recursive"], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=300)
package = output / "Pilot"
sources = package / "Sources/DiffBenchmark"
sources.mkdir(parents=True)
for source in files[:3]:
    shutil.copy2(source, sources / source.name)
(package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DiffBenchmark", platforms: [.macOS(.v12)],
    dependencies: [.package(path: "../SwiftyOpenCC")],
    targets: [.executableTarget(name: "DiffBenchmark", dependencies: [
        .product(name: "OpenCC", package: "SwiftyOpenCC")])])
''')
with (output / "build.log").open("w") as log:
    subprocess.run(["swift", "build", "-c", "release", "--package-path", str(package)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
binary = Path(capture(["swift", "build", "-c", "release", "--show-bin-path", "--package-path", str(package)])) / "DiffBenchmark"
records = []
for count in args.characters:
    for iteration in range(1, 4):
        result = subprocess.run([str(binary), str(output / "corpus.txt"), str(count), str(args.character_cap), str(args.cell_cap), str(args.hunk_cap)], capture_output=True, text=True, timeout=30)
        (output / f"run-{count}-{iteration}.log").write_text(result.stdout + result.stderr)
        result.check_returncode()
        record = json.loads(result.stdout.splitlines()[0])
        record.update(requested_characters=count, iteration=iteration)
        records.append(record)
        print(json.dumps(record), flush=True)
(output / "results.json").write_text(json.dumps(records, indent=2) + "\n")
print("PASS: isolated Release diff measurements saved; native App responsiveness remains unverified")

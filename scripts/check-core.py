#!/usr/bin/env python3
"""Compile the actual conversion/model sources with their locked dependencies.

Runs on macOS without Xcode Build, a simulator, or modifying the app's defaults.
Optional local checkouts must match Package.resolved exactly.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--opencc-path", type=Path)
parser.add_argument("--defaults-path", type=Path)
parser.add_argument("--benchmark", action="store_true", help="Compare conversion processing with the cc8c7e8 baseline")
args = parser.parse_args()
pins = json.loads((root / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())["pins"]
pins = {pin["identity"]: pin for pin in pins}
dependencies = []
for identity, local in [("swiftyopencc", args.opencc_path), ("swiftyuserdefaults", args.defaults_path)]:
    pin = pins[identity]
    if local:
        revision = subprocess.check_output(["git", "-C", str(local), "rev-parse", "HEAD"], text=True).strip()
        if revision != pin["state"]["revision"]:
            raise SystemExit(f"{identity}: local checkout does not match Package.resolved")
        dependencies.append(f'.package(name: {json.dumps(identity)}, path: {json.dumps(str(local.resolve()))})')
    else:
        dependencies.append(f'.package(url: {json.dumps(pin["location"])}, revision: {json.dumps(pin["state"]["revision"])})')

with tempfile.TemporaryDirectory(prefix="openccman-core-") as directory:
    package = Path(directory)
    sources = package / "Sources/CoreChecks"
    sources.mkdir(parents=True)
    for path in [
        root / "OpenCCman/Services/ChineseConversionService.swift",
        root / "OpenCCman/Scene/HomeViewModel.swift",
        root / "Tests/Regression/CoreSupport.swift",
        root / ("Tests/Benchmarks/ConversionBenchmark.swift" if args.benchmark else "Tests/Regression/CoreChecks.swift"),
    ]:
        shutil.copy2(path, sources / path.name)
    (package / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "OpenCCmanCoreChecks",
    platforms: [.macOS(.v11)],
    dependencies: [\n''' + ",\n".join(dependencies) + '''\n],
    targets: [.executableTarget(name: "CoreChecks", dependencies: [
        .product(name: "OpenCC", package: "swiftyopencc"),
        .product(name: "SwiftyUserDefaults", package: "swiftyuserdefaults")
    ])]
)
''')
    subprocess.run(["swift", "run", "-c", "release", "--package-path", str(package), "CoreChecks"], check=True)

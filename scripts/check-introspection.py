#!/usr/bin/env python3
"""Exercise app editor predicates and the native window reader with pinned Introspect."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--introspect-path", type=Path)
args = parser.parse_args()
pins = json.loads((root / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved").read_text())["pins"]
pin = next(p for p in pins if p["identity"] == "swiftui-introspect")
with tempfile.TemporaryDirectory(prefix="openccman-introspection-") as directory:
    package = Path(directory)
    if args.introspect_path:
        checkout = args.introspect_path.resolve()
        revision = subprocess.check_output(["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True).strip()
        dirty = subprocess.check_output(["git", "-C", str(checkout), "status", "--porcelain", "--untracked-files=no"], text=True)
        if revision != pin["state"]["revision"] or dirty:
            raise SystemExit("Local Introspect checkout must be clean and exactly match Package.resolved")
        # Build a private copy, never write a build cache into the supplied checkout.
        dependency = package / "Introspect"
        dependency.mkdir()
        shutil.copy2(checkout / "Package.swift", dependency / "Package.swift")
        shutil.copytree(checkout / "Sources", dependency / "Sources")
        declaration = '.package(name: "swiftui-introspect", path: "Introspect")'
    else:
        declaration = f'.package(url: {json.dumps(pin["location"])}, revision: {json.dumps(pin["state"]["revision"])})'
    sources = package / "Sources/Checks"
    sources.mkdir(parents=True)
    for relative in ["OpenCCman/extensions/ViewExtensions.swift", "OpenCCman/extensions/StringExtensions.swift", "OpenCCman/View/WorkspaceScrollKeeper.swift", "OpenCCman/View/WorkspaceTextEditor.swift", "Tests/Regression/IntrospectionChecks.swift", "OpenCCman/View/MainWindowSizing.swift", "OpenCCman/Model/MainWindowGeometry.swift"]:
        shutil.copy2(root / relative, sources / Path(relative).name)
    styles = (root / "OpenCCman/Styles/Styles.swift").read_text()
    anchor = "extension View {\n  @ViewBuilder\n  func modify"
    if styles.count(anchor) != 1:
        raise SystemExit("Expected one unrelated modify helper in Styles.swift")
    (sources / "Modify.swift").write_text("import SwiftUI\n" + styles[styles.index(anchor):])
    (package / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "IntrospectionChecks", platforms: [.macOS(.v11)],
    dependencies: [''' + declaration + '''], targets: [
        .executableTarget(name: "Checks", dependencies: [
            .product(name: "SwiftUIIntrospect", package: "swiftui-introspect")
        ], swiftSettings: [.swiftLanguageMode(.v5)])
    ])
''')
    subprocess.run(["swift", "run", "-c", "release", "--package-path", str(package), "Checks"], check=True, timeout=300)

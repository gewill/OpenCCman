#!/usr/bin/env python3
"""Build an isolated SwiftUI WindowGroup lifetime control; never launch it.

The output directory must not exist. Launch/close windows through the normal UI,
then read the PID-specific JSONL in the user's temporary directory. No app
dependency, preference, notification registration or release branch is changed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=("notifications", "editor", "text"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = (root / "Tests/Benchmarks/MinimalWindowLifetime.swift").read_text()
    name, title = {
        "notifications": ("MinimalLifetime", "Minimal Lifetime Probe"),
        "editor": ("MinimalPlain", "Minimal Plain Probe"),
        "text": ("MinimalText", "Minimal Text Probe"),
    }[args.variant]
    block = '''
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
        _ = model.text.count
      }'''
    if args.variant != "notifications":
        if source.count(block) != 1:
            raise RuntimeError("Notification control no longer matches the measured source")
        source = source.replace(block, "")
    if args.variant == "text":
        if source.count("TextEditor(text: $model.text)") != 1:
            raise RuntimeError("Editor control no longer matches the measured source")
        source = source.replace("TextEditor(text: $model.text)", "Text(model.text)")
    source = source.replace("Minimal Lifetime Probe", title)
    swift = output / "Probe.swift"
    swift.write_text(source)
    app = output / f"{name}.app"
    executable = app / "Contents/MacOS" / name
    executable.parent.mkdir(parents=True)
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
        "CFBundleExecutable": name,
        "CFBundleIdentifier": f"org.gewill.OpenCCman.{name}Probe",
        "CFBundleName": title,
        "CFBundlePackageType": "APPL",
        "LSMinimumSystemVersion": "11.0",
        "NSPrincipalClass": "NSApplication",
    }))
    architecture = subprocess.check_output(["uname", "-m"], text=True).strip()
    command = ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library", "-O",
               "-target", f"{architecture}-apple-macosx11.0", str(swift), "-o", str(executable)]
    with (output / "build.log").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
        subprocess.run(["codesign", "--sign", "-", str(app)], stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=30)
    result = {
        "variant": args.variant, "app": str(app), "command": command,
        "source_sha256": hashlib.sha256(swift.read_bytes()).hexdigest(),
        "base_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True)),
        "compiler": subprocess.check_output(["xcrun", "swiftc", "--version"],
                                             text=True, stderr=subprocess.STDOUT),
        "os": subprocess.check_output(["sw_vers"], text=True),
    }
    (output / "preparation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

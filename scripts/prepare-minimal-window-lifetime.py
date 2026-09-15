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
    parser.add_argument("--variant", choices=("notifications", "editor", "text", "observed"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--automatic", action="store_true",
                        help="Build a macOS 13+ self-driving diagnostic for an isolated runner")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = (root / "Tests/Benchmarks/MinimalWindowLifetime.swift").read_text()
    name, title = {
        "notifications": ("MinimalLifetime", "Minimal Lifetime Probe"),
        "editor": ("MinimalPlain", "Minimal Plain Probe"),
        "text": ("MinimalText", "Minimal Text Probe"),
        "observed": ("MinimalObserved", "Minimal Observed Probe"),
    }[args.variant]
    block = '''
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeMainNotification)) { _ in
        _ = model.text.count
      }'''
    if args.variant != "notifications":
        if source.count(block) != 1:
            raise RuntimeError("Notification control no longer matches the measured source")
        source = source.replace(block, "")
    if args.variant in ("text", "observed"):
        if source.count("TextEditor(text: $model.text)") != 1:
            raise RuntimeError("Editor control no longer matches the measured source")
        source = source.replace("TextEditor(text: $model.text)", "Text(model.text)")
    if args.variant == "observed":
        # Match the text-only control except for the model's delivery path.
        # Root retains its StateObject; the child observes the explicit input.
        for old, new in (
            ("ProbeChild().environmentObject(model)", "ProbeChild(model: model)"),
            ("@EnvironmentObject var model: ProbeModel", "@ObservedObject var model: ProbeModel"),
        ):
            if source.count(old) != 1:
                raise RuntimeError("Environment control no longer matches the measured source")
            source = source.replace(old, new)
    source = source.replace("Minimal Lifetime Probe", title)
    minimum = "11.0"
    if args.automatic:
        if args.variant not in ("text", "observed"):
            raise ValueError("Automatic comparison supports only text and observed controls")
        original = f'WindowGroup("{title}") {{ ProbeRoot() }}'
        if source.count(original) != 1:
            raise RuntimeError("WindowGroup control no longer matches the measured source")
        source = source.replace(original,
                                f'WindowGroup("{title}", id: "lifetime") {{ ProbeRoot().background(LifetimeDriverView()) }}')
        source += "\n" + (root / "Tests/Benchmarks/WindowLifetimeDriver.swift").read_text()
        name += "Auto"
        title += " Automatic"
        minimum = "13.0"
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
        "LSMinimumSystemVersion": minimum,
        "NSPrincipalClass": "NSApplication",
    }))
    architecture = subprocess.check_output(["uname", "-m"], text=True).strip()
    command = ["xcrun", "swiftc", "-swift-version", "5", "-parse-as-library", "-O",
               "-target", f"{architecture}-apple-macosx{minimum}", str(swift), "-o", str(executable)]
    with (output / "build.log").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
        subprocess.run(["codesign", "--sign", "-", str(app)], stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=30)
    result = {
        "variant": args.variant, "automatic": args.automatic, "app": str(app), "command": command,
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

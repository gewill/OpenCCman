#!/usr/bin/env python3
"""Parse every app source and localization; discovery or command errors are fatal."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def required_files(directory, suffix):
    if not directory.is_dir():
        raise ValueError(f"Missing source directory: {directory}")
    def fail(error):
        raise error
    # os.walk(onerror=...) reports enumeration errors instead of silently skipping.
    files = sorted(Path(parent) / name
                   for parent, _, names in os.walk(directory, onerror=fail)
                   for name in names if name.endswith(suffix))
    if not files:
        raise ValueError(f"No {suffix} files found in {directory}")
    return files


def main():
    sources = required_files(ROOT / "OpenCCman", ".swift")
    localizations = required_files(ROOT / "OpenCCman", ".strings")
    subprocess.run(["plutil", "-lint", *map(str, [
        ROOT / "OpenCCman.xcodeproj/project.pbxproj",
        ROOT / "OpenCCman/Info.plist", ROOT / "OpenCCman/OpenCCman.entitlements",
        ROOT / "OpenCCman/PrivacyInfo.xcprivacy",
    ])], check=True)
    for source in sources:
        subprocess.run(["xcrun", "swiftc", "-frontend", "-parse", str(source)], check=True)
    for localization in localizations:
        subprocess.run(["plutil", "-lint", str(localization)], check=True)
    print(f"PASS: parsed {len(sources)} Swift sources and {len(localizations)} localization files", flush=True)


if __name__ == "__main__":
    main()

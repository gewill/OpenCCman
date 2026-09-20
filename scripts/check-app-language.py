#!/usr/bin/env python3
"""Check the actual app language constants against an isolated preferences domain.

Covers the stored representation only. Whether a running app redraws in the
selected language, and what a relaunch changes, still needs runtime QA.
"""
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="openccman-app-language-") as temporary:
        output = Path(temporary)
        constants = (root / "OpenCCman/Constants.swift").read_text()
        # This import is unused by the constants; do not build a UI dependency for a storage check.
        assert constants.count("import Neumorphic\n") == 1
        (output / "Constants.swift").write_text(constants.replace("import Neumorphic\n", ""))
        keys = (root / "OpenCCman/Model/UserDefaultsKeys.swift").read_text()
        (output / "UserDefaultsKeys.swift").write_text(keys[keys.index("enum UserDefaultsKeys: String"):])
        subprocess.run([
            "xcrun", "swiftc", "-swift-version", "5", "-O",
            str(output / "Constants.swift"), str(output / "UserDefaultsKeys.swift"),
            str(root / "Tests/Regression/AppLanguageChecks.swift"), "-o", str(output / "check"),
        ], check=True, timeout=120)
        subprocess.run([str(output / "check")], check=True, timeout=30)


if __name__ == "__main__":
    main()

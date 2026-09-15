#!/usr/bin/env python3
"""Check actual app IAP/locale sources against a recording SDK boundary.

No RevenueCat requests or UI are performed. Real SDK API compatibility remains
covered by the app builds, and official UI language selection needs runtime QA.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manager-source", type=Path, help="Private baseline fixture for a negative check")
    parser.add_argument("--bootstrap-only", action="store_true", help="Skip the newly added runtime update API")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="openccman-iap-locale-") as temporary:
        output = Path(temporary)
        subprocess.run([
            "xcrun", "swiftc", "-swift-version", "5", "-emit-library", "-emit-module",
            "-module-name", "RevenueCat", "-emit-module-path", str(output / "RevenueCat.swiftmodule"),
            str(root / "Tests/Regression/IAPLocaleSDKDouble.swift"),
            "-o", str(output / "libRevenueCat.dylib"),
        ], check=True, timeout=120)
        constants = (root / "OpenCCman/Constants.swift").read_text()
        # This import is unused by the constants; do not build a UI dependency for a boundary check.
        assert constants.count("import Neumorphic\n") == 1
        (output / "Constants.swift").write_text(constants.replace("import Neumorphic\n", ""))
        keys = (root / "OpenCCman/Model/UserDefaultsKeys.swift").read_text()
        (output / "UserDefaultsKeys.swift").write_text(keys[keys.index("enum UserDefaultsKeys: String"):])
        shutil.copy2(args.manager_source or root / "OpenCCman/IAPManager.swift", output / "IAPManager.swift")
        command = ["xcrun", "swiftc", "-swift-version", "5", "-O", "-I", str(output), "-L", str(output),
                   "-lRevenueCat", "-Xlinker", "-rpath", "-Xlinker", str(output)]
        if args.bootstrap_only:
            command += ["-D", "IAP_LOCALE_BOOTSTRAP_ONLY"]
        command += [str(output / name) for name in ("Constants.swift", "UserDefaultsKeys.swift", "IAPManager.swift")]
        command += [str(root / "OpenCCman/Model/ProAccessUpdate.swift"),
                    str(root / "Tests/Regression/IAPLocaleChecks.swift"), "-o", str(output / "check")]
        subprocess.run(command, check=True, timeout=120)
        subprocess.run([str(output / "check")], check=True, timeout=30)


if __name__ == "__main__":
    main()

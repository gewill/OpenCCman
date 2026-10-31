#!/usr/bin/env python3
"""Build isolated Duo candidates and verify the artifacts, without distribution."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def version(value):
    return tuple(int(part) for part in str(value).split("."))


def validate_plist(info, platform, selected_sdk=None):
    sdk = info.get("DTSDKName", "")
    match = re.fullmatch(r"(iphonesimulator|macosx)([\d.]+)", sdk)
    expected = "iphonesimulator" if platform == "ios" else "macosx"
    if not match or match[1] != expected or (platform == "ios" and version(match[2]) < (27, 1)):
        raise ValueError(f"Unexpected SDK for {platform}: {sdk!r}")
    if selected_sdk and version(match[2]) != version(selected_sdk):
        raise ValueError(f"Artifact SDK {sdk!r} differs from the selected SDK {selected_sdk!r}")
    floor = info.get("MinimumOSVersion" if platform == "ios" else "LSMinimumSystemVersion")
    if version(floor) != ((15, 0) if platform == "ios" else (12, 0)):
        raise ValueError(f"Deployment floor changed: {floor!r}")
    if platform == "ios":
        if not isinstance(info.get("UIApplicationSceneManifest"), dict):
            raise ValueError("Generated scene manifest is missing")
        if not isinstance(info.get("UILaunchScreen"), dict):
            raise ValueError("Generated launch screen is missing")
        if info.get("UIApplicationSupportsIndirectInputEvents") is not True:
            raise ValueError("Indirect input is not enabled in the generated plist")
        if set(info.get("UIDeviceFamily", [])) != {1, 2}:
            raise ValueError("The candidate must retain both iPhone and iPad")
        phone_key = ("UISupportedInterfaceOrientations~iphone" if "UISupportedInterfaceOrientations~iphone" in info
                     else "UISupportedInterfaceOrientations")
        for key in (phone_key, "UISupportedInterfaceOrientations~ipad"):
            orientations = info.get(key, [])
            if not {"UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight"}.issubset(orientations):
                raise ValueError(f"Missing supported orientations: {key}")
    return {key: value for key, value in info.items() if key.startswith(("DT", "UI"))
            or key in ("MinimumOSVersion", "LSMinimumSystemVersion", "CFBundleIdentifier",
                       "CFBundleShortVersionString", "CFBundleVersion")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--developer-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--derived-data", required=True, type=Path)
    parser.add_argument("--platform", choices=("all", "ios", "mac"), default="all")
    parser.add_argument("--configuration", choices=("Debug", "Release"), default="Debug")
    parser.add_argument("--build-wrapper", type=Path, help="Optional verified axbuild executable")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    derived = args.derived_data.expanduser().resolve()
    if output.is_relative_to(ROOT) or derived.is_relative_to(ROOT):
        parser.error("Evidence and DerivedData must be outside the checkout")
    if output.exists() and any(output.iterdir()):
        parser.error("Use a new evidence directory; previous results are never overwritten")
    if not args.developer_dir.is_dir():
        parser.error("Developer directory does not exist")
    if args.build_wrapper and not os.access(args.build_wrapper, os.X_OK):
        parser.error("Build wrapper is not executable")
    output.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, DEVELOPER_DIR=str(args.developer_dir.resolve()))

    def capture(command, name, check=True):
        if command[0] == "xcodebuild" or (args.build_wrapper and command[0] == str(args.build_wrapper)):
            inventory = subprocess.run(["pgrep", "-lx", "xcodebuild"], capture_output=True, text=True)
            if inventory.returncode != 1:
                raise RuntimeError(f"Resolve existing Xcode builds before continuing: {inventory.stdout or inventory.stderr}")
        target = output / name
        print(f"Running {name}", flush=True)
        with target.open("w") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        if check and result.returncode:
            raise RuntimeError(f"Exit {result.returncode}: inspect {target}")
        return target.read_text()

    def source_state():
        def git(*parts):
            return subprocess.check_output(["git", *parts], cwd=ROOT)
        untracked = git("ls-files", "--others", "--exclude-standard", "-z").decode().split("\0")
        return {"commit": git("rev-parse", "HEAD").decode().strip(),
                "status": git("status", "--porcelain").decode(),
                "diff_sha256": hashlib.sha256(git("diff", "HEAD", "--binary")).hexdigest(),
                "untracked_sha256": {path: digest(ROOT / path) for path in untracked if path},
                "package_resolved_sha256": digest(LOCK)}

    report = {"source": source_state(), "developer_dir": env["DEVELOPER_DIR"],
              "configuration": args.configuration, "artifacts": {}, "status": "running"}
    report_path = output / "report.json"
    try:
        report["xcode"] = capture(["xcodebuild", "-version"], "xcode-version.log").strip()
        xcode_version = re.search(r"Xcode ([\d.]+)", report["xcode"])
        if not xcode_version or version(xcode_version[1]) < (27, 1):
            raise ValueError("Select an Xcode 27.1+ developer directory explicitly")
        report["system"] = capture(["sw_vers"], "system.log").strip()
        platforms = ("ios", "mac") if args.platform == "all" else (args.platform,)
        for platform in platforms:
            sdk_name = "iphonesimulator" if platform == "ios" else "macosx"
            selected_sdk = capture(["xcrun", "--sdk", sdk_name, "--show-sdk-version"],
                                   f"{platform}-sdk.log").strip()
            destination = "generic/platform=iOS Simulator" if platform == "ios" else "platform=macOS"
            archs = "arm64" if platform == "ios" else "arm64 x86_64"
            platform_derived = derived / platform
            native = ["xcodebuild", "-project", "OpenCCman.xcodeproj", "-scheme", "OpenCCman",
                      "-configuration", args.configuration, "-destination", destination,
                      "-derivedDataPath", str(platform_derived), "-disableAutomaticPackageResolution",
                      "-onlyUsePackageVersionsFromResolvedFile", "CODE_SIGNING_ALLOWED=NO",
                      f"ARCHS={archs}", "ONLY_ACTIVE_ARCH=NO",
                      "PRODUCT_BUNDLE_IDENTIFIER=org.gewill.OpenCCman.WhatsNewUITests"]
            if platform == "ios" and version(selected_sdk) >= (27, 1):
                # Compile the opt-in QA probe only with an SDK that declares it.
                # Ordinary Xcode 26.3/27.0 builds keep their existing code path.
                native.append("OTHER_SWIFT_FLAGS=$(inherited) -D OPENCCMAN_DUO_SDK")
            settings = capture(native + ["-showBuildSettings", "-json"], f"{platform}-settings.json")
            # Xcode can prepend package-resolution diagnostics to its JSON output.
            start = settings.find("[\n")
            if start < 0:
                raise ValueError("Build settings did not contain a JSON array")
            json.loads(settings[start:])
            command = ([str(args.build_wrapper)] if args.build_wrapper else []) + native + ["build"]
            capture(command, f"{platform}-build.log")
            suffix = "-iphonesimulator" if platform == "ios" else ""
            app = platform_derived / "Build/Products" / (args.configuration + suffix) / "OpenCCman.app"
            plist = app / ("Info.plist" if platform == "ios" else "Contents/Info.plist")
            info = plistlib.loads(plist.read_bytes())
            verified = validate_plist(info, platform, selected_sdk)
            executable = app / ("" if platform == "ios" else "Contents/MacOS") / info["CFBundleExecutable"]
            binary = capture(["xcrun", "vtool", "-show-build", str(executable)], f"{platform}-mach-o.log")
            binary_sdks = re.findall(r"^\s*sdk\s+([\d.]+)", binary, re.MULTILINE)
            if not binary_sdks or any(version(sdk) != version(selected_sdk) for sdk in binary_sdks):
                raise ValueError(f"Binary SDK differs from selected SDK {selected_sdk}: {binary_sdks}")
            report["artifacts"][platform] = {"command": native + ["build"], "app": str(app),
                "plist": verified, "binary_sdks": binary_sdks,
                "executable_sha256": digest(executable), "info_plist_sha256": digest(plist)}
        if source_state() != report["source"]:
            raise RuntimeError("Source or dependency lock changed during validation; do not reuse these results")
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(f"Report: {report_path}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)

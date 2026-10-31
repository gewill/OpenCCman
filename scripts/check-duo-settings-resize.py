#!/usr/bin/env python3
"""Run one isolated settings-sheet resize case against a verified Debug QA app."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import runpy
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "org.gewill.OpenCCman.WhatsNewUITests"
TEST = "WhatsNewPresentationTests/DuoReadinessTests/testHostResizeWithConversionSettingsKeepsDocument"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_state():
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=ROOT)
    return {"commit": git("rev-parse", "HEAD").decode().strip(),
            "diff_sha256": hashlib.sha256(git("diff", "HEAD", "--binary")).hexdigest(),
            "untracked": {p: digest(ROOT / p) for p in git("ls-files", "--others", "--exclude-standard").decode().splitlines()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--developer-dir", required=True, type=Path)
    parser.add_argument("--device", required=True)
    parser.add_argument("--app-build-report", required=True, type=Path)
    parser.add_argument("--derived-data", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--language", choices=["en", "zh-Hans", "zh-Hant"], default="en")
    parser.add_argument("--content-size", choices=["large", "extra-extra-extra-large"], default="large")
    parser.add_argument("--build-wrapper", type=Path)
    parser.add_argument("--reuse-test-build", type=Path, help="Prior report whose test source and compiled runner still match")
    parser.add_argument("--record-video", action="store_true")
    parser.add_argument("--device-hub-pointer", action="store_true", help="Assisted actual pointer input; XCTest verifies the outcome")
    args = parser.parse_args()
    out, derived = args.output.expanduser().resolve(), args.derived_data.expanduser().resolve()
    if out.is_relative_to(ROOT) or derived.is_relative_to(ROOT):
        parser.error("Evidence and DerivedData must be outside the checkout")
    if out.exists() and any(out.iterdir()):
        parser.error("Use a new evidence directory; existing results are never overwritten")
    if not args.developer_dir.is_dir():
        parser.error("Developer directory does not exist")
    if args.build_wrapper and not os.access(args.build_wrapper, os.X_OK):
        parser.error("Build wrapper is not executable")
    if shutil.disk_usage(out.parent if out.parent.exists() else ROOT).free < 8 * 1024**3:
        parser.error("At least 8 GiB of free space is required")
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, DEVELOPER_DIR=str(args.developer_dir.resolve()))
    wrapper = [str(args.build_wrapper.resolve())] if args.build_wrapper else []
    report = {"source": source_state(), "language": args.language, "content_size": args.content_size,
              "device": args.device, "developer_dir": env["DEVELOPER_DIR"], "commands": [], "status": "running",
              "input_driver": "Device Hub pointer (assisted)" if args.device_hub_pointer else "XCTest tap"}
    test = resize = recording = None
    prior_font = None
    handles = []

    def inventory():
        p = subprocess.run(["pgrep", "-lx", "xcodebuild"], capture_output=True, text=True)
        if p.returncode != 1:
            raise RuntimeError("Resolve existing Xcode builds before continuing: " + p.stdout + p.stderr)

    def run(command, name, timeout=30):
        report["commands"].append(command)
        with (out / name).open("w") as log:
            p = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        if p.returncode:
            raise RuntimeError(f"Exit {p.returncode}: inspect {name}")
        return (out / name).read_text()

    def start(command, name):
        report["commands"].append(command)
        log = (out / name).open("w")
        handles.append(log)
        return subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)

    def native_log(name):
        p = out / name
        lines = p.read_text().splitlines()
        try:
            return Path(json.loads(lines[0])["path"]) / "build.log"
        except (IndexError, ValueError, KeyError):
            return p

    def sim(*parts):
        return ["xcrun", "simctl", *parts]

    try:
        inventory()
        report["xcode"] = run(["xcodebuild", "-version"], "xcode.log").strip()
        report["devicectl"] = run(["xcrun", "devicectl", "--version"], "devicectl.log").strip()
        devices = json.loads(run(sim("list", "devices", "--json"), "devices.json"))["devices"]
        selected = [(runtime, d) for runtime, group in devices.items() for d in group if d["udid"] == args.device]
        if len(selected) != 1 or selected[0][1]["state"] != "Booted":
            raise RuntimeError("Select and boot a dedicated simulator explicitly")
        report["runtime"], report["simulator"] = selected[0]
        build_report = json.loads(args.app_build_report.read_text())
        if build_report.get("status") != "passed" or build_report.get("configuration") != "Debug":
            raise RuntimeError("Use a successful Debug Duo app build report")
        artifact = build_report["artifacts"]["ios"]
        app = Path(artifact["app"])
        info = plistlib.loads((app / "Info.plist").read_bytes())
        if info["CFBundleIdentifier"] != APP_ID:
            raise RuntimeError("Refusing to replace a non-QA bundle")
        runpy.run_path(str(ROOT / "scripts/build-duo-validation.py"))["validate_plist"](info, "ios")
        if digest(app / info["CFBundleExecutable"]) != artifact["executable_sha256"] or digest(app / "Info.plist") != artifact["info_plist_sha256"]:
            raise RuntimeError("App artifact no longer matches its build report")
        report["app"] = {"build_source": build_report["source"], "artifact": artifact}
        shutil.copy2(args.app_build_report, out / "app-build-report.json")
        run(sim("install", args.device, str(app)), "install.log")
        prior_font = run(sim("ui", args.device, "content_size"), "prior-font.log").strip()
        if not re.fullmatch(r"[a-z-]+", prior_font):
            raise RuntimeError("Cannot safely restore the simulator's original content size")
        run(sim("ui", args.device, "content_size", args.content_size), "set-font.log")
        sdk = run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"], "sdk.log").strip()
        if tuple(map(int, sdk.split("."))) < (27, 1):
            raise RuntimeError("Select an iOS Simulator 27.1+ SDK explicitly")
        native = ["xcodebuild", "-project", "Tests/UI/WhatsNewPresentation/WhatsNewPresentation.xcodeproj",
                  "-scheme", "WhatsNewPresentationTests", "-destination", "platform=iOS Simulator,id=" + args.device,
                  "-derivedDataPath", str(derived), "-parallel-testing-enabled", "NO", "CODE_SIGNING_ALLOWED=NO"]
        reused = json.loads(args.reuse_test_build.read_text()) if args.reuse_test_build else None
        if reused:
            built = reused["test_build"]
            if (built["source"] != report["source"] or reused["developer_dir"] != report["developer_dir"]
                    or digest(Path(built["binary"])) != built["binary_sha256"]
                    or digest(Path(built["xctestrun"])) != built["xctestrun_sha256"]):
                raise RuntimeError("Test source, developer directory or compiled runner changed; rebuild explicitly")
        else:
            inventory()
            run(wrapper + native + ["build-for-testing"], "build.log", timeout=180)
            shutil.copy2(native_log("build.log"), out / "build-native.log")
        products = derived / "Build/Products"
        candidates = list(products.glob(f"WhatsNewPresentationTests_iphonesimulator{sdk}-*.xctestrun"))
        if len(candidates) != 1:
            raise RuntimeError("Cannot unambiguously locate the newly built test configuration")
        def resolve(value):
            if isinstance(value, str):
                return value.replace("__TESTROOT__", str(products))
            if isinstance(value, list):
                return [resolve(v) for v in value]
            if isinstance(value, dict):
                return {k: resolve(v) for k, v in value.items()}
            return value
        config = resolve(plistlib.loads(candidates[0].read_bytes()))
        target = config["WhatsNewPresentationTests"]
        bundle = Path(target["TestBundlePath"].replace("__TESTHOST__", target["TestHostPath"]))
        binary = bundle / plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleExecutable"]
        report["test_build"] = {"source": report["source"], "binary": str(binary), "binary_sha256": digest(binary),
            "xctestrun": str(candidates[0]), "xctestrun_sha256": digest(candidates[0]), "reused": bool(reused)}
        target.setdefault("EnvironmentVariables", {}).update(OPENCCMAN_DUO_EXTERNAL_RESIZE="1",
            OPENCCMAN_DUO_DEVICE_HUB_POINTER="1" if args.device_hub_pointer else "0",
            OPENCCMAN_DUO_LANGUAGE=args.language, OPENCCMAN_DUO_RECORDING="1" if args.record_video else "0")
        test_config = out / "settings.xctestrun"
        test_config.write_bytes(plistlib.dumps(config))
        inventory()
        test = start(wrapper + ["xcodebuild", "-xctestrun", str(test_config), "-destination",
            "platform=iOS Simulator,id=" + args.device, "-parallel-testing-enabled", "NO",
            "-resultBundlePath", str(out / "settings.xcresult"), "-collect-test-diagnostics", "never",
            "-only-testing:" + TEST, "test-without-building"], "test.log")
        deadline = time.monotonic() + 360
        def wait_for(predicate):
            while time.monotonic() < deadline:
                if predicate():
                    return
                if test.poll() is not None or (resize and resize.poll() is not None):
                    raise RuntimeError("Test or resize session ended before the required state; inspect logs")
                if recording and recording.poll() is not None:
                    raise RuntimeError("Recorder ended before the test completed; inspect video.log")
                time.sleep(0.2)
            raise TimeoutError("Settings resize run exceeded 360 seconds")
        def marker(value):
            wait_for(lambda: value in native_log("test.log").read_text())
        marker("OPENCCMAN_DUO_READY_FOR_RESIZE")
        resize = start(["xcrun", "devicectl", "device", "appResize", "start", "--device", args.device,
                        "--preferred-size", "950x669"], "resize.log")
        marker("OPENCCMAN_DUO_READY_FOR_WIDE_CAPTURE")
        run(["xcrun", "devicectl", "device", "info", "appResize", "--device", args.device,
             "--json-output", str(out / "wide-state.json")], "wide-state.log")
        if args.record_video:
            ports = run(sim("io", args.device, "enumerate"), "displays.log")
            display = re.search(r"\(\d+\) Resizable:.*?Unique ID:\s*([A-F0-9-]+)", ports, re.S)
            if not display:
                raise RuntimeError("Resizable display was not found")
            recording = start(["xcrun", "devicectl", "device", "capture", "screen-record", "--device", args.device,
                "--display-unique-id", display[1], "--destination", str(out / "settings-original.mp4"),
                "--duration", "360"], "video.log")
            wait_for(lambda: "Recording started." in (out / "video.log").read_text())
            runner = Path(run(sim("get_app_container", args.device, target["TestHostBundleIdentifier"], "data"), "runner.log").strip())
            (runner / "tmp/duo-settings-recording-ready").touch()
        marker("OPENCCMAN_DUO_READY_FOR_COMPACT")
        run(["xcrun", "devicectl", "device", "appResize", "set", "--device", args.device,
             "--preferred-size", "400x750", "--json-output", str(out / "compact-state.json")], "compact-state.log")
        code = test.wait(timeout=max(1, deadline - time.monotonic()))
        report["test_exit"] = code
        if code or not re.search(r"testHostResizeWithConversionSettingsKeepsDocument\]' passed", native_log("test.log").read_text()):
            raise RuntimeError("The selected case did not pass; skipped is not success")
        if recording and recording.poll() is not None:
            raise RuntimeError("Recording ended before the final test result")
        report["status"] = "passed"
    except (Exception, KeyboardInterrupt) as error:
        report.update(status="failed", error=f"{type(error).__name__}: {error}")
    finally:
        for child in (recording, resize, test):
            if child and child.poll() is None:
                child.send_signal(signal.SIGINT)
                try:
                    child.wait(timeout=25)
                except subprocess.TimeoutExpired:
                    report.update(status="failed", cleanup_error=f"Owned process {child.pid} did not stop")
        for handle in handles:
            handle.close()
        if (out / "test.log").exists():
            shutil.copy2(native_log("test.log"), out / "test-native.log")
        if prior_font:
            try:
                run(sim("ui", args.device, "content_size", prior_font), "restore-font.log")
            except Exception as error:
                report.update(status="failed", font_restore_error=str(error))
        try:
            container = Path(run(sim("get_app_container", args.device, APP_ID, "data"), "container.log").strip())
            trace = container / "tmp/duo-layout-trace.jsonl"
            shutil.copy2(trace, out / "trace.jsonl")
            records = [json.loads(line) for line in trace.read_text().splitlines()]
            converted = [x for x in records if x["input_characters"] > 0 and x["result_characters"] > 0]
            sizes = {tuple(x["window"]) for x in converted}
            identities = {tuple(e["identity"] for e in x["editors"]) for x in converted}
            models, scenes = {x["model"] for x in converted}, {x["scene"] for x in converted}
            counts = {(x["input_characters"], x["result_characters"]) for x in converted}
            if not {(950, 669), (400, 750)}.issubset(sizes) or len(identities) != 1 or len(next(iter(identities))) != 2 or len(models) != 1 or len(scenes) != 1 or len(counts) != 1:
                raise ValueError("Native continuity evidence is missing or changed")
            report["continuity"] = {"sizes": sorted(sizes), "editor_pairs": sorted(identities),
                "models": sorted(models), "scenes": sorted(scenes), "character_counts": sorted(counts),
                "trace_sha256": digest(out / "trace.jsonl")}
        except Exception as error:
            report.update(status="failed", continuity_error=str(error))
        report["final_source"] = source_state()
        if report["final_source"] != report["source"]:
            report.update(status="failed", source_error="Source changed during validation")
        (out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"{report['status']}: {out / 'report.json'}")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())

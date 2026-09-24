#!/usr/bin/env python3
"""Capture bounded heap/VM snapshots of an owned, cleared native editor app."""

import argparse
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("measure_native_textkit", ROOT / "scripts/measure-native-textkit.py")
MEASURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MEASURE)


def wait_for_hold(path, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            report = json.loads(path.read_text())
            if report.get("rows") and report["rows"][-1]["name"] == "profiling_hold":
                return report
        time.sleep(0.1)
    raise TimeoutError("Native editor did not reach the post-clear hold")


def verify_hold(report, mode, paired, width):
    rows = report["rows"]
    expected = ["empty_ready", "first_display", "scroll_start", "scroll_middle", "scroll_end",
                "recovery_before_clear", "recovery_clear_ack", "recovery_after_5s",
                "recovery_after_30s", "profiling_hold"]
    if ([row["name"] for row in rows] != expected or report["mode"] != mode or
            not all(row["app_active"] and row["visible"] and row["fallback_events"] == 0 for row in rows) or
            not all(row["textkit2"] is (mode == "tk2") and row["editor_viewport_width"] == width for row in rows) or
            any(row["editor_utf16"] != 0 or row["storage_utf16"] != 0 for row in rows[-4:])):
        raise ValueError("Incomplete or inactive native recovery hold")
    if paired and any(row["second_textkit2"] is not (mode == "tk2") or
                      row["second_viewport_width"] != width or
                      row["second_editor_utf16"] != 0 or row["second_storage_utf16"] != 0
                      for row in rows[-4:]):
        raise ValueError("Second native editor did not clear")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--modes", nargs="+", choices=("tk1", "tk2"), default=["tk1", "tk2"])
    parser.add_argument("--hold-seconds", type=int, default=60)
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if (output.exists() or output == ROOT or ROOT in output.parents or
            not 30 <= args.hold_seconds <= 120):
        parser.error("Use a fresh output outside the repository and a 30–120 second hold")
    metadata = json.loads((build / "metadata.json").read_text())
    if (not metadata["build_only"] or metadata["source_status"] or not metadata["recovery"] or
            not metadata["activate_process"] or metadata["sizes_mib"] != [1] or
            metadata["pattern"] != "app-mixed" or metadata["content_width_points"] != 440 or
            not metadata["second_editor"] or set(args.modes) - set(metadata["modes"])):
        parser.error("Requires a clean, paired, 1 MiB native recovery build")
    app = build / "NativeTextKitMemory.app"
    binary = app / "Contents/MacOS/native-textkit-memory"
    if MEASURE.sha(binary) != metadata["binary_sha256"]:
        parser.error("Native binary differs from the verified build")
    output.mkdir(parents=True)
    manifest = {"schema": 1, "source_commit": metadata["source_commit"],
                "build_metadata_sha256": MEASURE.sha(build / "metadata.json"),
                "driver_sha256": MEASURE.sha(Path(__file__)), "hold_seconds": args.hold_seconds,
                "modes": args.modes, "captures": []}
    for mode in args.modes:
        report_path = output / f"{mode}-hold.json"
        command = ["open", "-n", "-W", "-a", str(app), "--args", "--mode", mode,
                   "--input", str(build / "app-mixed-1MiB.txt"), "--output", str(report_path),
                   "--content-width", "440", "--recovery", "--second-editor",
                   "--hold-after-recovery", str(args.hold_seconds)]
        entry = {"mode": mode, "command": ["open", "-n", "-W", "-a", "<build>/NativeTextKitMemory.app",
                                          "--args", "--mode", mode, "--input", "<build>/app-mixed-1MiB.txt",
                                          "--output", f"<output>/{mode}-hold.json", "--content-width", "440",
                                          "--recovery", "--second-editor", "--hold-after-recovery",
                                          str(args.hold_seconds)]}
        prior = MEASURE.owned_pids(binary)
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        pid = None
        try:
            pid = MEASURE.activate_owned_app(binary, prior)
            entry["pid"] = pid
            report = wait_for_hold(report_path, timeout=45)
            if report["pid"] != pid or pid not in MEASURE.owned_pids(binary):
                raise RuntimeError("Hold belongs to a different process")
            verify_hold(report, mode, paired=True, width=440)
            for tool in ("heap", "vmmap"):
                path = output / f"{mode}-{tool}.txt"
                args_for_tool = [tool, "-s", "-H", "-q", str(pid)] if tool == "heap" else [tool, "-summary", str(pid)]
                with path.open("w") as stream:
                    subprocess.run(args_for_tool, stdout=stream, check=True, timeout=25)
                entry[f"{tool}_sha256"] = MEASURE.sha(path)
            entry["report_sha256"] = MEASURE.sha(report_path)
            entry["captured"] = True
            print(f"{mode}: captured", flush=True)
        finally:
            if pid is not None and pid in MEASURE.owned_pids(binary):
                os.kill(pid, signal.SIGTERM)
                entry["terminated_owned_app"] = True
            try:
                _, stderr = process.communicate(timeout=5)
                if stderr:
                    (output / f"{mode}.stderr").write_text(stderr)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.communicate(timeout=5)
            manifest["captures"].append(entry)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()

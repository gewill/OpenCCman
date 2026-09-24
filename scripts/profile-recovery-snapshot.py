#!/usr/bin/env python3
"""Capture class and VM summaries from an owned, cleared private editor app."""

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def import_script(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BENCHMARK = import_script("benchmark_app", ROOT / "scripts/benchmark-app.py")
PROFILE = import_script("profile_paragraph_phases", ROOT / "scripts/profile-paragraph-phases.py")


def wait_for_status(report, expected, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if report.exists():
            data = json.loads(report.read_text())
            if data.get("status") in expected:
                return data
        time.sleep(0.2)
    raise TimeoutError(f"Private app did not reach {expected}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--attempts", type=int, default=1)
    parser.add_argument("--footprint-below-mib", type=float, help="Repeat until a cleared process is below this bound")
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if args.attempts < 1 or output.exists() or output == ROOT or ROOT in output.parents:
        parser.error("Use positive attempts and a fresh output outside the repository")
    metadata = BENCHMARK.verify_build(build)
    conditions = metadata["conditions"]
    variant = metadata["application_variant"]
    if (metadata["source_status"] or conditions["suite"] != "reflow" or
            conditions["input_profile"] != "single-paragraph" or
            conditions["reflow_max_mib"] != 1 or conditions["profiling_start_gate"] or
            not conditions["navigation_target"].startswith("middle composed character") or
            variant not in ("unchanged", "textkit2-single-target")):
        parser.error("Requires a clean, ungated, 1 MiB private reflow build")
    app = build / "derived/Build/Products/Release/OpenCCman.app"
    executable = app / "Contents/MacOS/OpenCCman"
    output.mkdir(parents=True)
    manifest = {"schema": 1, "source_commit": metadata["source_commit"], "variant": variant,
                "build_metadata_sha256": PROFILE.sha256(build / "metadata.json"),
                "driver_sha256": PROFILE.sha256(Path(__file__)), "attempts": []}
    for index in range(1, args.attempts + 1):
        attempt = output / f"attempt-{index:02}"
        attempt.mkdir()
        report = attempt / "run.json"
        command = ["open", "-n", "-a", str(app), "--args", "-performance-output", str(report),
                   "-skip-whats-new", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Light",
                   "-performance-reflow", "-performance-single-paragraph", "-performance-middle-composed",
                   "-performance-reflow-max-mib", "1", "-performance-recovery", "-performance-reflow-profile-hold"]
        if variant == "textkit2-single-target":
            command.append("-performance-require-textkit2")
        entry = {"index": index, "command": command}
        pid = None
        try:
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
            initial = wait_for_status(report, {"running", "failed", "profiling_hold"}, 30)
            pid = initial["pid"]
            if not PROFILE.owned_process(pid, executable):
                raise RuntimeError("Run did not identify the owned private app")
            entry["pid"] = pid
            subprocess.run(["open", "-a", str(app)], check=True, stdout=subprocess.DEVNULL)
            final = wait_for_status(report, {"profiling_hold", "failed"}, 90)
            if final["status"] != "profiling_hold":
                raise RuntimeError(f"Private app failed: {final.get('error')}")
            rows = final["rows"]
            if (not all(row["app_active"] for row in rows[1:]) or
                    [row["name"] for row in rows[-5:]] != ["recovery_before_clear", "recovery_clear_ack",
                                                           "recovery_after_5s", "recovery_after_30s", "profiling_hold"]):
                entry["excluded"] = "inactive or incomplete recovery"
                continue
            footprint = rows[-2]["memory"]["physical_footprint_bytes"] / (1024 * 1024)
            entry["footprint_after_30s_mib"] = round(footprint, 1)
            if args.footprint_below_mib is not None and footprint >= args.footprint_below_mib:
                entry["excluded"] = "above requested footprint bound"
                continue
            if not PROFILE.owned_process(pid, executable):
                raise RuntimeError("Owned app exited before snapshot")
            with (attempt / "heap.txt").open("w") as stream:
                subprocess.run(["heap", "-s", "-H", "-q", str(pid)], stdout=stream, check=True)
            with (attempt / "vmmap.txt").open("w") as stream:
                subprocess.run(["vmmap", "-summary", str(pid)], stdout=stream, check=True)
            entry["heap_sha256"] = PROFILE.sha256(attempt / "heap.txt")
            entry["vmmap_sha256"] = PROFILE.sha256(attempt / "vmmap.txt")
            entry["captured"] = True
            print(f"Captured attempt {index}: {footprint:.1f} MiB", flush=True)
            break
        finally:
            if report.exists():
                entry["report_sha256"] = PROFILE.sha256(report)
            if pid is not None and PROFILE.owned_process(pid, executable):
                entry["terminated_owned_app"] = PROFILE.terminate_owned(pid, executable)
            manifest["attempts"].append(entry)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if not any(entry.get("captured") for entry in manifest["attempts"]):
        raise SystemExit("No valid private snapshot was captured")


if __name__ == "__main__":
    main()

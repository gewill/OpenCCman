#!/usr/bin/env python3
"""Capture CPU stacks and signposts from an owned private 5 MiB app build."""

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("benchmark_app", ROOT / "scripts/benchmark-app.py")
BENCHMARK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BENCHMARK)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def report_at(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def wait_for_report(path, process, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        report = report_at(path)
        if report is not None and report.get("pid"):
            return report
        if process.poll() is not None:
            raise RuntimeError(f"Diagnostic app exited before its first record: {process.returncode}")
        time.sleep(0.05)
    raise TimeoutError("Diagnostic app did not publish its PID")


def owned_process(pid, executable):
    result = subprocess.run(["ps", "-p", str(pid), "-o", "command="], capture_output=True, text=True)
    return result.returncode == 0 and str(executable) in result.stdout


def terminate_owned(pid, executable):
    if not owned_process(pid, executable):
        return False
    os.kill(pid, signal.SIGTERM)
    for _ in range(50):
        if not owned_process(pid, executable):
            return True
        time.sleep(0.1)
    if owned_process(pid, executable):
        os.kill(pid, signal.SIGKILL)
    return True


def idle_seconds():
    result = subprocess.run(["ioreg", "-c", "IOHIDSystem", "-d", "4"], capture_output=True, text=True, check=True)
    match = re.search(r'"HIDIdleTime"\s*=\s*(\d+)', result.stdout)
    return int(match.group(1)) / 1_000_000_000 if match else None


def trace_bytes(path):
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file()) if path.exists() else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path, help="Verified private benchmark build")
    parser.add_argument("--output", required=True, type=Path, help="Fresh directory outside the repository")
    parser.add_argument("--probe-only", action="store_true",
                        help="Attach for five seconds without explicit reopen; the app may start work automatically")
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        parser.error("Output must be a new directory outside the repository")
    metadata = BENCHMARK.verify_build(build)
    conditions = metadata["conditions"]
    if (metadata["application_variant"] != "unchanged" or conditions["suite"] != "reflow" or
            conditions["input_profile"] != "single-paragraph" or conditions["reflow_max_mib"] != 5 or
            not conditions["navigation_target"].startswith("middle composed character")):
        parser.error("Requires the unchanged, app-matched 1/5 MiB private reflow build")

    output.mkdir(parents=True)
    source_app = build / "derived/Build/Products/Release/OpenCCman.app"
    app = output / "OpenCCman-Profile.app"
    subprocess.run(["cp", "-cR", str(source_app), str(app)], check=True)
    entitlement = output / "debug-entitlements.plist"
    entitlement.write_bytes(plistlib.dumps({"com.apple.security.get-task-allow": True}))
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", "--entitlements", str(entitlement), str(app)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    executable = app / "Contents/MacOS/OpenCCman"
    report_path = output / "run.json"
    trace_path = output / "paragraph-phases.trace"
    trace_log = output / "xctrace.log"
    launch_log = output / "launch.log"
    launch_command = ["open", "-n", "-W", "-a", str(app), "--args", "-performance-output", str(report_path),
                      "-skip-whats-new", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Light",
                      "-performance-reflow", "-performance-single-paragraph", "-performance-reflow-max-mib", "5",
                      "-performance-middle-composed"]
    trace_command = ["xcrun", "xctrace", "record", "--instrument", "CPU Profiler",
                     "--instrument", "Points of Interest", "--attach", "<owned PID>",
                     "--time-limit", "190s" if not args.probe_only else "5s",
                     "--no-prompt", "--output", str(trace_path)]
    manifest = {"schema": 1, "build_metadata_sha256": sha256(build / "metadata.json"),
                "source_commit": metadata["source_commit"], "driver_sha256": sha256(Path(__file__)),
                "debug_entitlements_sha256": sha256(entitlement), "signature_verified": True,
                "mode": "probe" if args.probe_only else "workload", "launch_command": launch_command,
                "trace_command": trace_command, "idle_before_seconds": idle_seconds()}
    app_process = None
    trace_process = None
    owned_pid = None
    try:
        with launch_log.open("w") as log:
            app_process = subprocess.Popen(launch_command, stdout=log, stderr=subprocess.STDOUT)
        initial = wait_for_report(report_path, app_process, 30)
        owned_pid = initial["pid"]
        if not isinstance(owned_pid, int) or not owned_process(owned_pid, executable):
            raise RuntimeError("First record did not identify the copied diagnostic app")
        manifest["pid"] = owned_pid
        manifest["initial_stage"] = initial["rows"][-1]["name"]
        actual_trace_command = [str(owned_pid) if item == "<owned PID>" else item for item in trace_command]
        with trace_log.open("w") as log:
            trace_process = subprocess.Popen(actual_trace_command, stdout=log, stderr=subprocess.STDOUT)
        attach_deadline = time.monotonic() + 25
        while not trace_path.exists() and trace_process.poll() is None and time.monotonic() < attach_deadline:
            time.sleep(0.1)
        if trace_process.poll() is not None or not trace_path.exists():
            raise RuntimeError("CPU Profiler did not attach to the owned process")
        # The trace bundle can exist before recording actually begins. Allow
        # startup to settle, then verify signposts and process identity later.
        time.sleep(3)
        if trace_process.poll() is not None:
            raise RuntimeError("CPU Profiler exited before the workload")
        manifest["stage_before_reopen"] = (report_at(report_path) or initial)["rows"][-1]["name"]
        if not args.probe_only:
            subprocess.run(["open", "-a", str(app)], check=True)
            manifest["reopened"] = True
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                if app_process.poll() is not None:
                    break
                if trace_process.poll() is not None:
                    raise RuntimeError("CPU Profiler exited while the app was running")
                time.sleep(0.25)
            manifest["app_timed_out"] = app_process.poll() is None
        else:
            manifest["reopened"] = False
        if app_process.poll() is None and owned_pid is not None:
            manifest["owned_app_termination_requested"] = terminate_owned(owned_pid, executable)
        if app_process is not None:
            try:
                manifest["launch_exit_code"] = app_process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                app_process.terminate()
                manifest["launch_exit_code"] = app_process.wait(timeout=5)
        if trace_process is not None:
            try:
                manifest["xctrace_exit_code"] = trace_process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                trace_process.send_signal(signal.SIGINT)
                manifest["xctrace_exit_code"] = trace_process.wait(timeout=15)
        final = report_at(report_path)
        manifest["app_status"] = final.get("status") if final else None
        manifest["last_recorded_stage"] = final["rows"][-1]["name"] if final and final.get("rows") else None
        manifest["recorded_stage_count"] = len(final["rows"]) if final else 0
        manifest["all_workload_rows_active"] = bool(final) and all(
            row["app_active"] for row in final["rows"] if row["name"] != "process_initialized")
        manifest["trace_bytes"] = trace_bytes(trace_path)
        manifest["idle_after_seconds"] = idle_seconds()
    finally:
        if owned_pid is not None and owned_process(owned_pid, executable):
            manifest["owned_app_termination_requested"] = terminate_owned(owned_pid, executable)
        if app_process is not None and app_process.poll() is None:
            app_process.terminate()
            app_process.wait(timeout=5)
        if trace_process is not None and trace_process.poll() is None:
            trace_process.send_signal(signal.SIGINT)
            try:
                trace_process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                trace_process.kill()
                trace_process.wait()
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    if manifest.get("xctrace_exit_code") or not manifest.get("all_workload_rows_active"):
        raise SystemExit(4)


if __name__ == "__main__":
    main()

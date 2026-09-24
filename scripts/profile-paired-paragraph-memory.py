#!/usr/bin/env python3
"""Capture one gate-aligned 1 MiB private TextKit Allocations/VM trace."""

import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import signal
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path, help="Verified, gated private benchmark build")
    parser.add_argument("--output", required=True, type=Path, help="Fresh directory outside the repository")
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        parser.error("Output must be a new directory outside this repository")
    metadata = BENCHMARK.verify_build(build)
    conditions = metadata["conditions"]
    variant = metadata["application_variant"]
    if (metadata["source_status"] or variant not in ("unchanged", "textkit2-modern-anchor") or
            not conditions.get("profiling_start_gate") or conditions["suite"] != "reflow" or
            conditions["input_profile"] != "single-paragraph" or conditions["reflow_max_mib"] != 1 or
            not conditions["navigation_target"].startswith("middle composed character")):
        parser.error("Requires the clean, gated, 1 MiB single-paragraph private build")

    output.mkdir(parents=True)
    app = output / "OpenCCman-Profile.app"
    subprocess.run(["cp", "-cR", str(build / "derived/Build/Products/Release/OpenCCman.app"), str(app)], check=True)
    entitlement = output / "debug-entitlements.plist"
    entitlement.write_bytes(plistlib.dumps({"com.apple.security.get-task-allow": True}))
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", "--entitlements", str(entitlement), str(app)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    executable = app / "Contents/MacOS/OpenCCman"
    gate = output / "start-gate.ready"
    run_path = output / "run.json"
    trace = output / "paired-memory.trace"
    launch_command = ["open", "-n", "-W", "-a", str(app), "--args", "-performance-output", str(run_path),
                      "-skip-whats-new", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Light",
                      "-performance-reflow", "-performance-single-paragraph", "-performance-reflow-max-mib", "1",
                      "-performance-middle-composed", "-performance-start-gate", str(gate)]
    if variant == "textkit2-modern-anchor":
        launch_command.append("-performance-require-textkit2")
    trace_command = ["xcrun", "xctrace", "record", "--instrument", "Allocations", "--instrument", "VM Tracker",
                     "--instrument", "Points of Interest", "--attach", "<owned PID>",
                     "--time-limit", "120s", "--no-prompt", "--output", str(trace)]
    manifest = {"schema": 1, "source_commit": metadata["source_commit"], "application_variant": variant,
                "build_metadata_sha256": PROFILE.sha256(build / "metadata.json"),
                "driver_sha256": PROFILE.sha256(Path(__file__)), "signature_verified": True,
                "launch_command": launch_command, "trace_command": trace_command,
                "idle_before_seconds": PROFILE.idle_seconds()}
    app_process = None
    trace_process = None
    pid = None
    try:
        with (output / "launch.log").open("w") as log:
            app_process = subprocess.Popen(launch_command, stdout=log, stderr=subprocess.STDOUT)
        initial = PROFILE.wait_for_report(run_path, app_process, 30)
        pid = initial["pid"]
        if not isinstance(pid, int) or not PROFILE.owned_process(pid, executable):
            raise RuntimeError("First record did not identify the owned private app")
        manifest["pid"] = pid
        manifest["initial_stage"] = initial["rows"][-1]["name"]
        subprocess.run(["open", "-a", str(app)], check=True)
        manifest["reopened"] = True
        actual_trace = [str(pid) if item == "<owned PID>" else item for item in trace_command]
        with (output / "xctrace.log").open("w") as log:
            trace_process = subprocess.Popen(actual_trace, stdout=log, stderr=subprocess.STDOUT)
        attach_deadline = time.monotonic() + 25
        while not trace.exists() and trace_process.poll() is None and time.monotonic() < attach_deadline:
            time.sleep(0.1)
        if not trace.exists() or trace_process.poll() is not None:
            raise RuntimeError("Allocations/VM did not attach to the owned app")
        time.sleep(3)
        if trace_process.poll() is not None:
            raise RuntimeError("Allocations/VM exited before gate release")
        before = PROFILE.report_at(run_path) or initial
        manifest["stage_before_gate"] = before["rows"][-1]["name"]
        if manifest["stage_before_gate"] != "process_initialized":
            raise RuntimeError("Private workload began before the trace gate was released")
        gate.touch()
        manifest["gate_released"] = True
        deadline = time.monotonic() + 110
        while app_process.poll() is None and time.monotonic() < deadline:
            if trace_process.poll() is not None:
                raise RuntimeError("Allocations/VM exited while the app was running")
            time.sleep(0.2)
        manifest["app_timed_out"] = app_process.poll() is None
        if manifest["app_timed_out"]:
            manifest["owned_app_termination_requested"] = PROFILE.terminate_owned(pid, executable)
        manifest["launch_exit_code"] = app_process.wait(timeout=10)
        try:
            manifest["xctrace_exit_code"] = trace_process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            trace_process.send_signal(signal.SIGINT)
            manifest["xctrace_exit_code"] = trace_process.wait(timeout=15)
        final = PROFILE.report_at(run_path)
        manifest["app_status"] = final.get("status") if final else None
        manifest["recorded_stage_count"] = len(final["rows"]) if final else 0
        manifest["last_recorded_stage"] = final["rows"][-1]["name"] if final and final.get("rows") else None
        manifest["all_workload_rows_active"] = bool(final) and all(
            row["app_active"] for row in final["rows"] if row["name"] != "process_initialized")
        manifest["trace_bytes"] = PROFILE.trace_bytes(trace)
        manifest["idle_after_seconds"] = PROFILE.idle_seconds()
    finally:
        if pid is not None and PROFILE.owned_process(pid, executable):
            manifest["owned_app_termination_requested"] = PROFILE.terminate_owned(pid, executable)
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
    if (manifest.get("xctrace_exit_code") != 0 or manifest.get("app_status") != "complete" or
            manifest.get("app_timed_out") or not manifest.get("all_workload_rows_active") or
            manifest.get("stage_before_gate") != "process_initialized"):
        raise SystemExit(4)


if __name__ == "__main__":
    main()

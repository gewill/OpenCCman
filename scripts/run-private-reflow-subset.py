#!/usr/bin/env python3
"""Repeat a bounded reflow workload from an already verified private build."""

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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--max-mib", required=True, type=int, choices=(1, 5, 10))
    parser.add_argument("--samples", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    build = args.build.resolve()
    output = args.output.resolve()
    if args.samples < 1 or args.timeout < 1 or output.exists() or output == ROOT or ROOT in output.parents:
        parser.error("Use positive limits and a fresh output directory outside the repository")
    metadata = BENCHMARK.verify_build(build)
    conditions = metadata["conditions"]
    if (metadata["source_status"] or conditions["suite"] != "reflow" or
            conditions["input_profile"] != "single-paragraph" or
            conditions["profiling_start_gate"] or
            not conditions["navigation_target"].startswith("middle composed character") or
            args.max_mib > conditions["reflow_max_mib"] or
            metadata["application_variant"] not in ("unchanged", "textkit2-modern-anchor", "textkit2-single-target")):
        parser.error("Requires a clean, ungated single-paragraph build with matching bounds")
    app = build / "derived/Build/Products/Release/OpenCCman.app"
    executable = app / "Contents/MacOS/OpenCCman"
    output.mkdir(parents=True)
    manifest = {
        "schema": 1, "build_metadata_sha256": PROFILE.sha256(build / "metadata.json"),
        "driver_sha256": PROFILE.sha256(Path(__file__)),
        "source_commit": metadata["source_commit"],
        "application_variant": metadata["application_variant"],
        "input_profile": conditions["input_profile"],
        "build_reflow_max_mib": conditions["reflow_max_mib"],
        "run_reflow_max_mib": args.max_mib, "samples_requested": args.samples,
        "timeout_seconds": args.timeout, "runs": [],
    }
    for index in range(1, args.samples + 1):
        run = output / f"run-{index:02}.json"
        command = ["open", "-n", "-W", "-a", str(app), "--args", "-performance-output", str(run),
                   "-skip-whats-new", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Light",
                   "-performance-reflow", "-performance-single-paragraph",
                   "-performance-middle-composed", "-performance-reflow-max-mib", str(args.max_mib)]
        if metadata["application_variant"].startswith("textkit2-"):
            command.append("-performance-require-textkit2")
        entry = {"index": index, "command": command, "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        pid = None
        try:
            initial = PROFILE.wait_for_report(run, process, 30)
            pid = initial.get("pid")
            if not isinstance(pid, int) or not PROFILE.owned_process(pid, executable):
                raise RuntimeError("Run did not identify the owned private app")
            entry["pid"] = pid
            subprocess.run(["open", "-a", str(app)], check=True, stdout=subprocess.DEVNULL)
            entry["reopened"] = True
            process.wait(timeout=args.timeout)
            final = json.loads(run.read_text())
            entry["status"] = final.get("status")
            entry["rows"] = len(final.get("rows", []))
            entry["last_stage"] = final["rows"][-1]["name"] if final.get("rows") else None
            entry["run_sha256"] = PROFILE.sha256(run)
            if entry["status"] != "complete":
                raise RuntimeError(f"Sample {index} finished with status {entry['status']}")
            print(f"Sample {index}: complete", flush=True)
        except subprocess.TimeoutExpired as error:
            entry["status"] = "timeout"
            if run.exists():
                partial = json.loads(run.read_text())
                entry["rows"] = len(partial.get("rows", []))
                entry["last_stage"] = partial["rows"][-1]["name"] if partial.get("rows") else None
                entry["run_sha256"] = PROFILE.sha256(run)
            raise RuntimeError(f"Sample {index} timed out at {entry.get('last_stage')}") from error
        finally:
            if pid is not None and PROFILE.owned_process(pid, executable):
                PROFILE.terminate_owned(pid, executable)
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
            manifest["runs"].append(entry)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        time.sleep(1)


if __name__ == "__main__":
    main()

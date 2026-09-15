#!/usr/bin/env python3
"""Run the two self-driving, dependency-free WindowGroup fixtures on macOS CI.

Local preparation remains build-only; this launcher refuses non-CI execution.
It records outcomes rather than asserting that a retained model proves a leak.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def validate(rows):
    for row in rows:
        if (not isinstance(row.get("event"), str)
                or not isinstance(row.get("elapsed"), (int, float))
                or not math.isfinite(row["elapsed"])
                or any(type(row.get(key)) is not int for key in ("visible", "created", "alive"))
                or not 0 <= row["alive"] <= row["created"] <= 2):
            raise ValueError("Malformed native diagnostic record")
    expected = {
        "driver_pair_visible": 2,
        "driver_before_second_close": 2,
        "driver_second_closed": 1,
        "driver_second_plus_5": 1,
        "driver_second_plus_20": 1,
        "driver_final_closed": 0,
        "driver_final_plus_5": 0,
        "driver_final_plus_20": 0,
        "driver_finished": 0,
    }
    observations = {}
    starts = [row for row in rows if row["event"] == "driver_started"]
    if len(starts) != 1 or starts[0]["created"] != 1:
        raise ValueError("Missing/invalid driver startup")
    for event, visible in expected.items():
        matches = [row for row in rows if row["event"] == event]
        if len(matches) != 1 or matches[0]["visible"] != visible or matches[0]["created"] != 2:
            raise ValueError(f"Missing/invalid native window transition: {event}")
        observations[event] = matches[0]
    times = [row["elapsed"] for row in observations.values()]
    if times != sorted(times) or any(row["event"].startswith("driver_failed") for row in rows):
        raise ValueError("Driver failed or events are out of order")
    if observations["driver_before_second_close"]["elapsed"] - observations["driver_pair_visible"]["elapsed"] < 10:
        raise ValueError("Second-window observation interval too short")
    if observations["driver_pair_visible"]["elapsed"] - starts[0]["elapsed"] < 10:
        raise ValueError("Initial-window observation interval too short")
    for prefix in ("second", "final"):
        for delay in (5, 20):
            elapsed = (observations[f"driver_{prefix}_plus_{delay}"]["elapsed"]
                       - observations[f"driver_{prefix}_closed"]["elapsed"])
            if elapsed < delay:
                raise ValueError("Observation interval shorter than declared")
    return observations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_OS") != "macOS":
        parser.error("This launcher is CI-only; prepare the app and launch it through the normal UI locally")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parents[1]
    results = {}
    failed = False
    for variant in ("text", "observed"):
        folder = output / variant
        process = None
        result = {}
        try:
            preparation = subprocess.run(
                [sys.executable, str(root / "scripts/prepare-minimal-window-lifetime.py"),
                 "--variant", variant, "--automatic", "--output", str(folder)],
                cwd=root, text=True, capture_output=True, timeout=180, check=True)
            metadata = json.loads(preparation.stdout)
            app = Path(metadata["app"])
            executable = app / "Contents/MacOS" / app.stem
            with (folder / "process.log").open("w") as log:
                process = subprocess.Popen([str(executable)], stdout=log, stderr=subprocess.STDOUT)
                result["pid"] = process.pid
                result["exit_code"] = process.wait(timeout=100)
            if result["exit_code"] != 0:
                raise ValueError("Fixture exited unsuccessfully")
            raw = Path(tempfile.gettempdir()) / f"OpenCCman-MinimalLifetime-{process.pid}.jsonl"
            data = raw.read_bytes()
            (folder / "raw.jsonl").write_bytes(data)
            result["observations"] = validate([json.loads(line) for line in data.splitlines()])
            result["raw_sha256"] = hashlib.sha256(data).hexdigest()
            result["valid_protocol"] = True
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            failed = True
            result["valid_protocol"] = False
            result["error"] = str(error)
        finally:
            if process is not None:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                result["process_exited"] = process.poll() is not None
                raw = Path(tempfile.gettempdir()) / f"OpenCCman-MinimalLifetime-{process.pid}.jsonl"
                if raw.exists():
                    (folder / "raw.jsonl").write_bytes(raw.read_bytes())
            results[variant] = result
            (output / "result.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))
    return 4 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

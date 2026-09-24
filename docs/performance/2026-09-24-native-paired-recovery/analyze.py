#!/usr/bin/env python3
"""Verify the two-editor native TextKit recovery control and prior baselines."""

from contextlib import redirect_stdout
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import statistics
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE / "raw"
SINGLE = HERE.parent / "2026-09-24-native-recovery-control" / "analyze.py"
SOURCE_COMMIT = "125862843a9d7ab7d30facf1e4ec229310377166"
MIB = 1024 * 1024
STAGES = ("empty_ready", "first_display", "scroll_start", "scroll_middle", "scroll_end",
          "recovery_before_clear", "recovery_clear_ack", "recovery_after_5s", "recovery_after_30s")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_text())


def stage(run, name):
    found = [item for item in run["rows"] if item["name"] == name]
    require(len(found) == 1, f"Expected one {name}")
    return found[0]


def verify_raw():
    expected = load(RAW / "checksums.json")
    actual = {path.name for path in RAW.iterdir()} - {"checksums.json"}
    require(len(expected) == 13 and set(expected) == actual, "Raw file list changed")
    for name, checksum in expected.items():
        require(digest((RAW / name).read_bytes()) == checksum, f"Checksum changed: {name}")
    fixture = gzip.decompress((RAW / "fixture.txt.gz").read_bytes())
    require(len(fixture) == MIB and b"\n" not in fixture and b"\r" not in fixture,
            "Wrong paired-editor input")
    return digest(fixture)


def verify_build(metadata, fixture_hash):
    require(metadata["schema"] == 1 and metadata["source_commit"] == SOURCE_COMMIT and
            metadata["source_status"] == "", "Unpinned source")
    for path, key in (("Tests/Benchmarks/NativeTextKitMemory.swift", "source_sha256"),
                      ("scripts/measure-native-textkit.py", "driver_sha256")):
        committed = subprocess.check_output(["git", "show", f"{SOURCE_COMMIT}:{path}"], cwd=ROOT)
        require(metadata[key] == digest(committed), f"Source hash changed: {path}")
    require(metadata["pattern"] == "app-mixed" and metadata["fixture_sha256"]["1"] == fixture_hash and
            metadata["sizes_mib"] == [1] and metadata["modes"] == ["tk1", "tk2"] and
            metadata["samples"] == 1 and metadata["content_width_points"] == 440 and
            metadata["window_content_points"] == [880, 800] and metadata["second_editor"] and
            metadata["recovery"] and metadata["activate_process"] and not metadata["width_switch"] and
            metadata["target"] == "arm64-apple-macos12.0" and metadata["macos"] == "27.0" and
            "Xcode 27.0" in metadata["xcode"] and
            metadata["signature"].startswith("ad hoc, verified"), "Paired build conditions changed")


def verify_run(run, metadata_hash, mode):
    require(run["status"] == "complete" and run["mode"] == mode and
            run["metadata_sha256"] == metadata_hash and run["activated_pid"] == run["pid"] and
            run["source_utf8_bytes"] == MIB and run["source_utf16"] == 402196 and
            run["window_content_points"] == [880, 800] and
            [item["name"] for item in run["rows"]] == list(STAGES) and
            "--second-editor" in run["command"] and "--recovery" in run["command"],
            "Incomplete paired run")
    for item in run["rows"]:
        name = item["name"]
        length = 0 if name == "empty_ready" or name == "recovery_clear_ack" or name.startswith("recovery_after_") else 402196
        require(item["app_active"] and item["visible"] and item["fallback_events"] == 0 and
                item["textkit2"] is (mode == "tk2") and item["second_textkit2"] is (mode == "tk2") and
                item["editor_viewport_width"] == item["second_viewport_width"] == 440 and
                item["editor_utf16"] == item["storage_utf16"] == length and
                item["second_editor_utf16"] == item["second_storage_utf16"] == length and
                item["physical_footprint_bytes"] > 0 and item["rss_bytes"] > 0,
                f"Invalid stage: {mode} {name}")
        if name.startswith("scroll_"):
            require(item["target_visible"] and item["second_target_visible"] and
                    item["scroll_attempts"] >= 1, f"Offscreen target: {mode} {name}")


def summarize(numbers):
    return {"median_mib": round(statistics.median(numbers), 1),
            "range_mib": [round(min(numbers), 1), round(max(numbers), 1)]}


def prior_results():
    spec = importlib.util.spec_from_file_location("single_recovery", SINGLE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    stream = io.StringIO()
    with redirect_stdout(stream):
        module.main()
    return json.loads(stream.getvalue())


def main():
    fixture_hash = verify_raw()
    prior = prior_results()
    require(prior["fixture_sha256"] == fixture_hash, "Prior single/app input differs")
    paired = {}
    for mode in ("tk1", "tk2"):
        values = {name: [] for name in ("recovery_before_clear", "recovery_after_5s", "recovery_after_30s")}
        for group in "abc":
            metadata_path = RAW / f"{group}-metadata.json"
            metadata = load(metadata_path)
            verify_build(metadata, fixture_hash)
            run = load(RAW / f"{group}-{mode}-app-mixed-1MiB-01.json")
            verify_run(run, digest(metadata_path.read_bytes()), mode)
            stored = load(RAW / f"{group}-summary.json")
            require(not stored["incomplete"] and stored["complete"][f"{mode}-app-mixed-1MiB"]["complete_samples"] == 1,
                    "Driver summary differs")
            for name in values:
                values[name].append(stage(run, name)["physical_footprint_bytes"] / MIB)
        paired[mode] = {name: summarize(numbers) for name, numbers in values.items()}
    require(paired["tk1"]["recovery_after_30s"]["median_mib"] == 74.6 and
            paired["tk2"]["recovery_after_30s"]["median_mib"] == 268.6,
            "Documented paired result changed")
    print(json.dumps({"source_commit": SOURCE_COMMIT, "fixture_sha256": fixture_hash,
                      "native_paired": paired,
                      "native_single": prior["native_single_editor"],
                      "app_two_editors": prior["app_two_editors"]}, indent=2))


if __name__ == "__main__":
    main()

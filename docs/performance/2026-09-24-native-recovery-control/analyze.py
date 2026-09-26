#!/usr/bin/env python3
"""Verify the same-input, same-viewport native TextKit recovery control for #68."""

import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import statistics
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE / "raw"
APP = HERE.parent / "2026-09-24-recovery-retention"
MIB = 1024 * 1024
SOURCE_COMMIT = "252d7e7cd6a35746f0bac46a894a39672d0fcf0a"
STAGES = ("empty_ready", "first_display", "scroll_start", "scroll_middle", "scroll_end",
          "recovery_before_clear", "recovery_clear_ack", "recovery_after_5s", "recovery_after_30s")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_text())


def row(run, name):
    found = [item for item in run["rows"] if item["name"] == name]
    require(len(found) == 1, f"Missing or duplicate {name}")
    return found[0]


def verify_raw():
    expected = load(RAW / "checksums.json")
    actual = {path.name for path in RAW.iterdir()} - {"checksums.json"}
    require(len(expected) == 13 and set(expected) == actual, "Raw evidence file list changed")
    for name, checksum in expected.items():
        require(digest((RAW / name).read_bytes()) == checksum, f"Checksum changed: {name}")

    fixture = gzip.decompress((RAW / "fixture.txt.gz").read_bytes())
    require(len(fixture) == MIB and b"\r" not in fixture and b"\n" not in fixture,
            "Wrong single-paragraph fixture")
    require(len(fixture.decode("utf-8").encode("utf-16-le")) // 2 == 402196,
            "Fixture UTF-16 length changed")
    return digest(fixture)


def verify_build(metadata, path, fixture_hash):
    require(metadata["schema"] == 1 and metadata["source_commit"] == SOURCE_COMMIT and
            metadata["source_status"] == "", f"Unpinned build: {path}")
    for relative, field in (("Tests/Benchmarks/NativeTextKitMemory.swift", "source_sha256"),
                            ("scripts/measure-native-textkit.py", "driver_sha256")):
        committed = subprocess.check_output(["git", "show", f"{SOURCE_COMMIT}:{relative}"], cwd=ROOT)
        require(metadata[field] == digest(committed), f"Built source differs: {relative}")
    require(metadata["pattern"] == "app-mixed" and metadata["sizes_mib"] == [1] and
            metadata["modes"] == ["tk1", "tk2"] and metadata["samples"] == 1 and
            metadata["content_width_points"] == 440 and metadata["window_content_points"] == [440, 800] and
            metadata["recovery"] and metadata["activate_process"] and not metadata["width_switch"] and
            metadata["fixture_sha256"]["1"] == fixture_hash, f"Wrong protocol: {path}")
    require(metadata["target"] == "arm64-apple-macos12.0" and metadata["arch"] == "arm64" and
            metadata["macos"] == "27.0" and "Xcode 27.0" in metadata["xcode"] and
            metadata["signature"].startswith("ad hoc, verified"), f"Wrong environment: {path}")


def verify_run(run, metadata_hash, mode):
    require(run["status"] == "complete" and run["mode"] == mode and
            run["metadata_sha256"] == metadata_hash and run["activated_pid"] == run["pid"] and
            run["source_utf8_bytes"] == MIB and run["source_utf16"] == 402196 and
            [item["name"] for item in run["rows"]] == list(STAGES), "Incomplete native run")
    require("--recovery" in run["command"] and run["command"][run["command"].index("--content-width") + 1] == "440",
            "Wrong run command")
    for item in run["rows"]:
        name = item["name"]
        length = 0 if name == "empty_ready" or name == "recovery_clear_ack" or name.startswith("recovery_after_") else 402196
        require(item["app_active"] and item["visible"] and item["fallback_events"] == 0 and
                item["textkit2"] is (mode == "tk2") and item["editor_viewport_width"] == 440 and
                item["editor_utf16"] == item["storage_utf16"] == length and
                item["physical_footprint_bytes"] > 0 and item["rss_bytes"] > 0,
                f"Invalid native stage: {mode} {name}")
        if name.startswith("scroll_"):
            require(item["target_visible"] and item["scroll_attempts"] >= 1,
                    f"Native target not visible: {mode} {name}")


def summary(values):
    return {"median_mib": round(statistics.median(values), 1),
            "range_mib": [round(min(values), 1), round(max(values), 1)]}


def verify_app_input(fixture_hash):
    spec = importlib.util.spec_from_file_location("app_recovery", APP / "analyze.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.verify_checksums()
    module.verify_builds()
    result = module.verify_runs()
    names = [f"tk1-run-{index:02}.json" for index in range(1, 4)] + [
        f"tk2-{group}-run-{index:02}.json" for group in "ab" for index in range(1, 4)]
    for name in names:
        run = load(APP / "raw" / name)
        last = row(run, "layout_end_1_402194_horizontal")
        require(last["input_sha256"] == fixture_hash and last["source_viewport_width"] == 440,
                f"Native and app input/viewport differ: {name}")
    return result


def main():
    fixture_hash = verify_raw()
    native = {}
    for mode in ("tk1", "tk2"):
        values = {name: [] for name in ("recovery_before_clear", "recovery_after_5s", "recovery_after_30s")}
        for group in "abc":
            metadata_path = RAW / f"{group}-metadata.json"
            metadata = load(metadata_path)
            verify_build(metadata, metadata_path.name, fixture_hash)
            run = load(RAW / f"{group}-{mode}-app-mixed-1MiB-01.json")
            verify_run(run, digest(metadata_path.read_bytes()), mode)
            stored = load(RAW / f"{group}-summary.json")
            require(not stored["incomplete"] and stored["complete"][f"{mode}-app-mixed-1MiB"]["complete_samples"] == 1,
                    "Driver summary differs")
            for name in values:
                values[name].append(row(run, name)["physical_footprint_bytes"] / MIB)
        native[mode] = {name: summary(numbers) for name, numbers in values.items()}
    require(native["tk1"]["recovery_after_30s"]["median_mib"] == 52.1 and
            native["tk2"]["recovery_after_30s"]["median_mib"] == 169.3,
            "Documented result changed")
    app = verify_app_input(fixture_hash)
    print(json.dumps({"source_commit": SOURCE_COMMIT, "fixture_sha256": fixture_hash,
                      "native_single_editor": native, "app_two_editors": app}, indent=2))


if __name__ == "__main__":
    main()

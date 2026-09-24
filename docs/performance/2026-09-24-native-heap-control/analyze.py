#!/usr/bin/env python3
"""Verify bounded native paired-editor heap and VM snapshots for #68."""

from contextlib import redirect_stdout
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = HERE / "raw"
PAIR = HERE.parent / "2026-09-24-native-paired-recovery" / "analyze.py"
APP_RAW = HERE.parent / "2026-09-24-recovery-retention" / "raw"
SOURCE_COMMIT = "7ff9e1a3c8c5be1621f818c90a53336493755402"
MIB = 1024 * 1024
STAGES = ("empty_ready", "first_display", "scroll_start", "scroll_middle", "scroll_end",
          "recovery_before_clear", "recovery_clear_ack", "recovery_after_5s", "recovery_after_30s",
          "profiling_hold")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return json.loads(path.read_text())


def committed_hash(path):
    return digest(subprocess.check_output(["git", "show", f"{SOURCE_COMMIT}:{path}"], cwd=ROOT))


def heap_type(text, name):
    found = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) > 3 and parts[0].isdigit() and parts[3] == name:
            found.append((int(parts[0]), parts[1]))
    require(len(found) <= 1, f"Duplicate heap class: {name}")
    return found[0] if found else (0, "0")


def verify_raw():
    expected = load(RAW / "checksums.json")
    actual = {path.name for path in RAW.iterdir()} - {"checksums.json"}
    require(len(expected) == 9 and set(expected) == actual, "Raw snapshot list changed")
    for name, checksum in expected.items():
        require(digest((RAW / name).read_bytes()) == checksum, f"Checksum changed: {name}")
    fixture = gzip.decompress((RAW / "fixture.txt.gz").read_bytes())
    require(len(fixture) == MIB and b"\n" not in fixture and b"\r" not in fixture,
            "Wrong native input")
    return digest(fixture)


def verify_build_and_manifest(fixture_hash):
    metadata_path = RAW / "build-metadata.json"
    metadata = load(metadata_path)
    manifest = load(RAW / "manifest.json")
    require(metadata["schema"] == 1 and metadata["source_commit"] == SOURCE_COMMIT and
            metadata["source_status"] == "" and metadata["build_only"] and
            metadata["source_sha256"] == committed_hash("Tests/Benchmarks/NativeTextKitMemory.swift") and
            metadata["driver_sha256"] == committed_hash("scripts/measure-native-textkit.py") and
            metadata["pattern"] == "app-mixed" and metadata["fixture_sha256"]["1"] == fixture_hash and
            metadata["sizes_mib"] == [1] and metadata["content_width_points"] == 440 and
            metadata["window_content_points"] == [880, 800] and metadata["second_editor"] and
            metadata["recovery"] and metadata["activate_process"] and
            metadata["target"] == "arm64-apple-macos12.0" and metadata["macos"] == "27.0" and
            "Xcode 27.0" in metadata["xcode"] and metadata["signature"].startswith("ad hoc, verified"),
            "Native build conditions changed")
    require(manifest["schema"] == 1 and manifest["source_commit"] == SOURCE_COMMIT and
            manifest["build_metadata_sha256"] == digest(metadata_path.read_bytes()) and
            manifest["driver_sha256"] == committed_hash("scripts/profile-native-recovery.py") and
            manifest["hold_seconds"] == 60 and manifest["modes"] == ["tk1", "tk2"] and
            len(manifest["captures"]) == 2, "Snapshot manifest changed")
    return manifest


def verify_capture(entry):
    mode = entry["mode"]
    path = RAW / f"{mode}-hold.json"
    report = load(path)
    require(entry["captured"] and entry["terminated_owned_app"] and
            entry["report_sha256"] == digest(path.read_bytes()) and report["pid"] == entry["pid"] and
            report["status"] == "running" and report["mode"] == mode and
            report["source_utf8_bytes"] == MIB and report["source_utf16"] == 402196 and
            report["window_content_points"] == [880, 800] and
            [item["name"] for item in report["rows"]] == list(STAGES), f"Incomplete hold: {mode}")
    for item in report["rows"]:
        name = item["name"]
        length = 0 if name == "empty_ready" or name == "recovery_clear_ack" or name.startswith("recovery_after_") or name == "profiling_hold" else 402196
        require(item["app_active"] and item["visible"] and item["fallback_events"] == 0 and
                item["textkit2"] is (mode == "tk2") and item["second_textkit2"] is (mode == "tk2") and
                item["editor_viewport_width"] == item["second_viewport_width"] == 440 and
                item["editor_utf16"] == item["storage_utf16"] == length and
                item["second_editor_utf16"] == item["second_storage_utf16"] == length,
                f"Invalid hold stage: {mode} {name}")
        if name.startswith("scroll_"):
            require(item["target_visible"] and item["second_target_visible"],
                    f"Offscreen native target: {mode} {name}")
    result = {"physical_footprint_after_30s_mib": round(report["rows"][-2]["physical_footprint_bytes"] / MIB, 1)}
    for tool in ("heap", "vmmap"):
        with gzip.open(RAW / f"{mode}-{tool}.txt.gz", "rb") as stream:
            content = stream.read()
        require(digest(content) == entry[f"{tool}_sha256"], f"Original {tool} output changed: {mode}")
        result[tool] = content.decode()
    reported = re.search(r"Physical footprint:\s+([0-9.]+)M", result["vmmap"])
    require(reported and abs(float(reported.group(1)) - result["physical_footprint_after_30s_mib"]) < 1,
            f"VM snapshot does not match the held process: {mode}")
    classes = ("CTRun", "CTLine", "NSTextLineFragment", "NSTextLayoutFragment", "NSTextLayoutManager")
    result["heap_classes"] = {name: heap_type(result["heap"], name)[0] for name in classes}
    del result["heap"]
    del result["vmmap"]
    return result


def verify_prior(fixture_hash):
    spec = importlib.util.spec_from_file_location("paired_recovery", PAIR)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    output = io.StringIO()
    with redirect_stdout(output):
        module.main()
    prior = json.loads(output.getvalue())
    require(prior["fixture_sha256"] == fixture_hash, "Earlier input differs")
    app_counts = {}
    for label in ("tk2-high", "tk2-low"):
        with gzip.open(APP_RAW / f"{label}-heap.txt.gz", "rt") as stream:
            heap = stream.read()
        app_counts[label] = {kind: heap_type(heap, kind)[0] for kind in ("CTRun", "NSTextLineFragment")}
    return prior, app_counts


def main():
    fixture_hash = verify_raw()
    manifest = verify_build_and_manifest(fixture_hash)
    captures = {entry["mode"]: verify_capture(entry) for entry in manifest["captures"]}
    require(captures["tk1"]["heap_classes"]["CTRun"] == 8 and
            captures["tk2"]["heap_classes"]["CTRun"] == 96776 and
            captures["tk2"]["heap_classes"]["NSTextLineFragment"] == 13616 and
            captures["tk2"]["heap_classes"]["NSTextLayoutManager"] == 2,
            "Documented native object counts changed")
    prior, app_counts = verify_prior(fixture_hash)
    print(json.dumps({"source_commit": SOURCE_COMMIT, "fixture_sha256": fixture_hash,
                      "native_snapshots": captures, "app_textkit2_snapshots": app_counts,
                      "native_paired_runs": prior["native_paired"]}, indent=2))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify paired editor recovery runs and bounded heap-reference evidence."""

import gzip
import hashlib
import json
from pathlib import Path
import re
import statistics

RAW = Path(__file__).resolve().parent / "raw"
MIB = 1024 * 1024
LABELS = ("tk1", "tk2-single-target")
RECOVERY = ("recovery_before_clear", "recovery_clear_ack", "recovery_after_5s", "recovery_after_30s")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(name):
    return json.loads((RAW / name).read_text())


def row(run, name):
    found = [item for item in run["rows"] if item["name"] == name]
    require(len(found) == 1, f"Expected one {name}")
    return found[0]


def verify_checksums():
    expected = load("checksums.json")
    actual_files = {p.name for p in RAW.iterdir()} - {"checksums.json"}
    require(len(expected) == 26 and set(expected) == actual_files, "Evidence file list changed")
    for name, digest in expected.items():
        require(hashlib.sha256((RAW / name).read_bytes()).hexdigest() == digest, f"Checksum changed: {name}")


def verify_builds():
    builds = {name: load(f"{name}-metadata.json") for name in LABELS}
    first, second = builds.values()
    for name in LABELS:
        marker = load(f"{name}-build-complete.json")
        metadata_hash = hashlib.sha256((RAW / f"{name}-metadata.json").read_bytes()).hexdigest()
        require(marker["metadata_sha256"] == metadata_hash and marker["app_hashes"], f"Invalid build marker: {name}")
    for field in ("source_commit", "source_status", "os", "hardware", "xcode", "pins", "resolved_checkout_revisions", "conditions"):
        require(first[field] == second[field], f"Build {field} differs")
    require(first["source_status"] == "" and first["application_variant"] == "unchanged" and
            second["application_variant"] == "textkit2-single-target", "Wrong build variants")
    require(first["conditions"]["suite"] == "reflow" and first["conditions"]["input_profile"] == "single-paragraph" and
            first["conditions"]["reflow_max_mib"] == 1 and not first["conditions"]["profiling_start_gate"], "Wrong build conditions")
    changed = {path for path in first["source_hashes"] if first["source_hashes"][path] != second["source_hashes"].get(path)}
    require(changed == {"OpenCCman/View/WorkspaceScrollKeeper.swift", "OpenCCman/View/WorkspaceTextEditor.swift",
                        "Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift"}, f"Unexpected source differences: {changed}")
    return first["source_commit"]


def verify_runs():
    files = {
        "tk1": [f"tk1-run-{number:02}.json" for number in range(1, 4)],
        "tk2-single-target": [f"{group}-run-{number:02}.json" for group in ("tk2-a", "tk2-b") for number in range(1, 4)],
    }
    hashes = set()
    results = {}
    for name, paths in files.items():
        before = []
        after = []
        rss_after = []
        for path in paths:
            run = load(path)
            require(run["schema"] == 1 and run["status"] == "complete" and len(run["rows"]) == 41, f"Incomplete run: {path}")
            require(all(item["app_active"] for item in run["rows"][1:]), f"Background run: {path}")
            layouts = [item for item in run["rows"] if item["name"].startswith("layout_end_1_")]
            require(len(layouts) == 6 and all(item["selection_visible"] is True and
                    item["textkit2"] is (name == "tk2-single-target") for item in layouts), f"Wrong editor or selection: {path}")
            hashes.add((layouts[-1]["input_sha256"], layouts[-1]["output_sha256"]))
            records = [row(run, stage) for stage in RECOVERY]
            require(records[0]["source_utf16_units"] == records[0]["result_utf16_units"] == 402196, f"Wrong initial text: {path}")
            require(all(record["source_utf16_units"] == record["result_utf16_units"] == 0 for record in records[1:]), f"Text not cleared: {path}")
            require(records[1]["source_can_undo"] is False, f"Undo retained old document: {path}")
            before.append(records[0]["memory"]["physical_footprint_bytes"] / MIB)
            after.append(records[-1]["memory"]["physical_footprint_bytes"] / MIB)
            rss_after.append(records[-1]["memory"]["rss_bytes"] / MIB)
        results[name] = {
            "processes": len(paths),
            "footprint_before_mib_median": round(statistics.median(before), 1),
            "footprint_after_30s_mib_median": round(statistics.median(after), 1),
            "footprint_after_30s_mib_range": [round(min(after), 1), round(max(after), 1)],
            "rss_after_30s_mib_range": [round(min(rss_after), 1), round(max(rss_after), 1)],
            "after_30s_below_250_mib": sum(value < 250 for value in after),
        }
    require(len(hashes) == 1 and all(len(digest) == 64 for digest in next(iter(hashes))), "Text hashes differ")
    return results


def heap_type(text, kind):
    lines = [line.split() for line in text.splitlines()]
    found = [(int(parts[0]), parts[1]) for parts in lines if len(parts) > 3 and parts[0].isdigit() and parts[3] == kind]
    require(len(found) <= 1, f"Duplicate heap class: {kind}")
    return found[0] if found else (0, "0")


def verify_heap():
    result = {}
    for label in ("tk1", "tk2-high", "tk2-low"):
        run = load(f"{label}-hold.json")
        require(run["status"] == "profiling_hold" and all(item["app_active"] for item in run["rows"][1:]), f"Invalid hold: {label}")
        require([item["name"] for item in run["rows"][-5:]] == [*RECOVERY, "profiling_hold"], f"Wrong hold stages: {label}")
        footprint = run["rows"][-2]["memory"]["physical_footprint_bytes"] / MIB
        with gzip.open(RAW / f"{label}-heap.txt.gz", "rt") as stream:
            heap = stream.read()
        with gzip.open(RAW / f"{label}-vmmap.txt.gz", "rt") as stream:
            vmmap = stream.read()
        reported = re.search(r"Physical footprint:\s+([0-9.]+)M", vmmap)
        require(reported and abs(float(reported.group(1)) - footprint) < 1, f"VM snapshot differs: {label}")
        result[label] = {
            "footprint_mib": round(footprint, 1),
            "ctrun": heap_type(heap, "CTRun"),
            "ctline": heap_type(heap, "CTLine"),
            "text_line_fragment": heap_type(heap, "NSTextLineFragment"),
        }
    require(result["tk2-high"]["ctrun"][0] > result["tk2-low"]["ctrun"][0] > result["tk1"]["ctrun"][0], "CTRun ordering changed")
    reference = load("tk2-reference-hold.json")
    require(reference["status"] == "profiling_hold" and all(item["app_active"] for item in reference["rows"][1:]), "Invalid reference-tree process")
    managers = set()
    views = set()
    for label in ("first", "second"):
        with gzip.open(RAW / f"tk2-reference-{label}-tree.txt.gz", "rt") as stream:
            first_lines = "\n".join(stream.read().splitlines()[:22])
        require(all(kind in first_lines for kind in ("CTRun", "CTLine", "NSTextLineFragment", "NSTextLayoutFragment",
                                                  "_textLayoutFragmentTable", "NSTextLayoutManager", "NSTextView")), "Incomplete ownership chain")
        manager = re.search(r"<NSTextLayoutManager (0x[0-9a-f]+)>", first_lines)
        view = re.search(r"<NSTextView (0x[0-9a-f]+)>", first_lines)
        require(manager and view, "Missing editor addresses")
        managers.add(manager.group(1))
        views.add(view.group(1))
    require(len(managers) == len(views) == 2, "Ownership paths do not identify two distinct editors")
    with gzip.open(RAW / "tk2-reference-leaks.txt.gz", "rt") as stream:
        leak_scan = stream.read()
    summary = re.search(r"Process \d+: (\d+) leaks for (\d+) total leaked bytes", leak_scan)
    require(summary and int(summary.group(2)) == 20016 and "CTRun" not in leak_scan, "Leak scan result changed")
    result["reference_paths"] = "two live NSTextView layout-manager fragment tables reach CTRun objects"
    return result


if __name__ == "__main__":
    verify_checksums()
    print(json.dumps({"source_commit": verify_builds(), "runs": verify_runs(), "heap": verify_heap()}, indent=2))

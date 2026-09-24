#!/usr/bin/env python3
"""Verify the archived same-source 1 MiB TextKit pair and 5 MiB partial runs."""

import hashlib
import json
from pathlib import Path
import statistics

RAW = Path(__file__).resolve().parent / "raw"
MIB = 1024 * 1024
FINAL = "layout_end_1_402194_horizontal"
PARTIAL_LAST = "layout_begin_5_1005490_vertical"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(name):
    return json.loads((RAW / name).read_text())


def row(run, name):
    found = [item for item in run["rows"] if item["name"] == name]
    require(len(found) == 1, f"Expected exactly one {name}")
    return found[0]


def verify_checksums():
    entries = json.loads((RAW / "checksums.json").read_text())
    require(len(entries) == 13, "Expected two builds, six complete runs and three partial runs")
    require(set(entries) == {p.name for p in RAW.glob("*.json")} - {"checksums.json"}, "Evidence file list changed")
    for name, expected in entries.items():
        require(hashlib.sha256((RAW / name).read_bytes()).hexdigest() == expected, f"Checksum changed: {name}")


def verify_pair():
    builds = {kind: load(f"{kind}-metadata.json") for kind in ("tk1", "tk2-single-target")}
    for kind in builds:
        marker = load(f"{kind}-build-complete.json")
        digest = hashlib.sha256((RAW / f"{kind}-metadata.json").read_bytes()).hexdigest()
        require(marker["metadata_sha256"] == digest and marker["app_hashes"], f"Invalid build marker: {kind}")
    first, second = builds.values()
    for field in ("source_commit", "source_status", "pins", "resolved_checkout_revisions", "os", "hardware", "xcode", "conditions"):
        require(first[field] == second[field], f"Build {field} differs")
    require(first["source_status"] == second["source_status"] == "", "Built source was dirty")
    require(first["application_variant"] == "unchanged" and second["application_variant"] == "textkit2-single-target", "Wrong variants")
    require(first["conditions"]["input_profile"] == "single-paragraph" and first["conditions"]["reflow_max_mib"] == 10, "Wrong build profile")
    differing = {name for name in first["source_hashes"] if first["source_hashes"][name] != second["source_hashes"].get(name)}
    require(differing == {
        "OpenCCman/View/WorkspaceTextEditor.swift",
        "OpenCCman/View/WorkspaceScrollKeeper.swift",
        "Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift",
    }, f"Unexpected source changes: {differing}")
    all_hashes = set()
    results = {}
    for kind, expected_textkit2 in (("tk1", False), ("tk2-single-target", True)):
        runs = [load(f"{kind}-run-{number:02}.json") for number in range(1, 4)]
        finish_rss = []
        peak_rss = []
        action_medians = []
        for run in runs:
            require(run["schema"] == 1 and run["status"] == "complete" and len(run["rows"]) == 37, "Incomplete 1 MiB run")
            require(all(item["app_active"] for item in run["rows"][1:]), "Background run")
            layouts = [item for item in run["rows"] if item["name"].startswith("layout_end_1_")]
            require(len(layouts) == 6, "Missing layout checks")
            require(all(item["selection_visible"] is True and item["textkit2"] is expected_textkit2 for item in layouts), "Wrong editor identity or invisible selection")
            require(all(row(run, f"scroll_end_1_{position}")["selection_visible"] is True for position in (0, 201098, 402194)), "Invisible scroll selection")
            finish = row(run, FINAL)
            all_hashes.add((finish["input_sha256"], finish["output_sha256"]))
            finish_rss.append(finish["memory"]["rss_bytes"] / MIB)
            peak_rss.append(finish["memory"]["process_peak_rss_bytes"] / MIB)
            action_medians.append(statistics.median(item["action_ms"] for item in layouts))
        results[kind] = {
            "final_rss_mib_median": round(statistics.median(finish_rss), 1),
            "final_rss_mib_range": [round(min(finish_rss), 1), round(max(finish_rss), 1)],
            "process_peak_rss_mib_range": [round(min(peak_rss), 1), round(max(peak_rss), 1)],
            "layout_action_ms_median_of_run_medians": round(statistics.median(action_medians), 1),
            "layout_action_ms_run_median_range": [round(min(action_medians), 1), round(max(action_medians), 1)],
            "visible_layout_checks": "18/18",
        }
    require(len(all_hashes) == 1, "Input or output hashes differ across the six runs")
    require(all(len(value) == 64 for value in next(iter(all_hashes))), "Invalid text hashes")
    return first["source_commit"], results


def verify_partials():
    excluded = load("tk1-5mib-partial.json")
    require(len(excluded["rows"]) == 63 and excluded["rows"][-1]["name"] == PARTIAL_LAST, "Excluded run stage differs")
    require(any(item["app_active"] is False for item in excluded["rows"][1:]), "TextKit 1 exclusion reason changed")
    retry = load("tk1-5mib-retry-excluded.json")
    require(retry["status"] == "running" and retry["rows"][-1]["name"] == "layout_begin_5_0_vertical", "Excluded retry stage differs")
    require(any(item["app_active"] is False for item in retry["rows"][1:]), "TextKit 1 retry exclusion reason changed")
    run = load("tk2-single-target-5mib-partial.json")
    require(run["status"] == "timeout" and len(run["rows"]) == 63 and run["rows"][-1]["name"] == PARTIAL_LAST, "Candidate timeout stage differs")
    require(all(item["app_active"] for item in run["rows"][1:]), "Candidate lost foreground")
    layouts = [row(run, f"layout_end_5_0_{direction}") for direction in ("vertical", "horizontal")]
    require(all(item["selection_visible"] is True for item in layouts), "Invisible 5 MiB selection")
    return {
        "tk1": "excluded: foreground lost after conversion",
        "tk2_single_target": {
            "last_stage_at_300s": PARTIAL_LAST,
            "first_5mib_layout_action_seconds": [round(item["action_ms"] / 1000, 1) for item in layouts],
            "rss_mib_after_first_horizontal_layout": round(layouts[-1]["memory"]["rss_bytes"] / MIB, 1),
        },
    }


if __name__ == "__main__":
    verify_checksums()
    commit, comparison = verify_pair()
    print(json.dumps({"source_commit": commit, "one_mib": comparison, "five_mib_partial": verify_partials()}, indent=2))

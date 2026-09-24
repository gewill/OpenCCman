#!/usr/bin/env python3
"""Verify archived #68 CPU trace evidence; optionally verify the local trace bundle."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
RAW = ROOT / "raw"
SOURCE_COMMIT = "b5c0f270543d73091416efaf6abb49686bf6dece"
MIB = 1048576


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((RAW / name).read_text())


def stage(run, name):
    found = [row for row in run["rows"] if row["name"] == name]
    require(len(found) == 1, f"missing or duplicate stage {name}")
    return found[0]


def tree_digest(files):
    stream = "".join(f"{item['path']}\0{item['bytes']}\0{item['sha256']}\n" for item in files).encode()
    return hashlib.sha256(stream).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-trace", type=Path, help="Optional original .trace bundle for file-by-file verification")
    args = parser.parse_args()
    manifest = json.loads((ROOT / "checksums.json").read_text())
    actual = {str(path.relative_to(ROOT)): sha256(path) for path in sorted(RAW.rglob("*")) if path.is_file()}
    require(manifest == {"algorithm": "SHA-256", "files": actual} and len(actual) == 11,
            "archived raw checksums")

    build = read("build-metadata.json")
    marker = read("build-complete.json")
    capture = read("manifest.json")
    probe = read("probe-manifest.json")
    run = read("run.json")
    summary = read("cpu-summary.json")
    target = read("trace-target.json")
    tree = read("trace-tree.json")
    entitlements = plistlib.loads((RAW / "debug-entitlements.plist").read_bytes())
    require(build["source_commit"] == build["measurement_harness_commit"] == SOURCE_COMMIT and
            build["source_status"] == "" and build["application_variant"] == "unchanged" and
            build["conditions"]["suite"] == "reflow" and
            build["conditions"]["input_profile"] == "single-paragraph" and
            build["conditions"]["reflow_max_mib"] == 5 and
            build["conditions"]["navigation_target"].startswith("middle composed character") and
            build["hardware"].endswith("Apple M4 Pro") and
            build["os"]["version"] == "27.0" and
            build["xcode"].startswith("Xcode 27.0"),
            "private build provenance or protocol")
    require(marker["metadata_sha256"] == capture["build_metadata_sha256"] == sha256(RAW / "build-metadata.json") and
            capture["source_commit"] == SOURCE_COMMIT and capture["mode"] == "workload" and
            capture["signature_verified"] and entitlements == {"com.apple.security.get-task-allow": True},
            "build identity or copied-app signature")
    require(capture["pid"] == run["pid"] == summary["pid"] and
            capture["xctrace_exit_code"] == 0 and capture["launch_exit_code"] == 0 and
            capture["app_timed_out"] and capture["owned_app_termination_requested"] and
            capture["app_status"] == "running" and
            capture["last_recorded_stage"] == "layout_begin_5_0_vertical" and
            capture["recorded_stage_count"] == len(run["rows"]) == 57 and
            capture["all_workload_rows_active"] and
            all(row["app_active"] for row in run["rows"] if row["name"] != "process_initialized") and
            capture["idle_after_seconds"] > capture["idle_before_seconds"],
            "bounded capture, foreground or stage status")
    converted = stage(run, "reflow_convert_5MiB")
    app_reference = json.loads((REPO / "docs/performance/2026-09-24-textkit-content-ablation/raw/content-mixed/run-01.json").read_text())
    reference = stage(app_reference, "reflow_convert_5MiB")
    require(converted["input_bytes"] == converted["output_bytes"] == 5 * MIB and
            converted["input_sha256"] == reference["input_sha256"] and
            converted["output_sha256"] == reference["output_sha256"] and
            converted["editors_match_model"] and converted["export_matches_result"],
            "5 MiB fixture or conversion integrity")
    require(probe["mode"] == "probe" and probe["pid"] != run["pid"] and
            probe["xctrace_exit_code"] == 0 and not probe["reopened"] and
            probe["owned_app_termination_requested"],
            "attach preflight was not independent")

    processes = [item for item in target["processes"] if item["name"] == "OpenCCman" and
                 item["pid"] == str(run["pid"])]
    require(processes and any(item["termination_reason"] == "exit(0)" for item in processes) and
            {"cpu-profile", "OSSignpostIntervals", "PointsOfInterestEvents"}.issubset(target["schemas"]),
            "trace target or instruments missing")
    require(summary["app_run_sha256"] == sha256(RAW / "run.json") and
            summary["signpost_export_sha256"] == sha256(RAW / "signpost-intervals.xml") and
            summary["pid"] == run["pid"] and summary["source_commit"] == SOURCE_COMMIT and
            summary["trace_bytes"] == capture["trace_bytes"],
            "CPU summary source identity")
    intervals = ET.parse(RAW / "signpost-intervals.xml").getroot().findall(".//row")
    require(len(intervals) == len(summary["signposts"]) == 8 and
            abs(summary["clock_alignment"]["source_offset_ns"] -
                summary["clock_alignment"]["conversion_offset_ns"]) < 5_000_000,
            "signpost count or clock alignment")
    require(set(summary["phases"]) == {"source_ack", "conversion_and_publication", "first_layout"},
            "phase coverage")
    for name, values in summary["phases"].items():
        total = values["samples"]
        require(total > 10000 and values["unresolved_backtraces"] == 0 and
                0 < values["stack_contains"]["combining_marks"] <= total and
                values["top_leaf_functions"][0][1] <= total and
                "TCombiningEngine::ResolveCombiningMarks" in values["top_leaf_functions"][0][0],
                f"{name}: insufficient or contradictory CPU samples")
    require(summary["phases"]["source_ack"]["stack_contains"]["workspace_update"] > 0.95 *
            summary["phases"]["source_ack"]["samples"] and
            summary["phases"]["conversion_and_publication"]["stack_contains"]["workspace_update"] > 0.95 *
            summary["phases"]["conversion_and_publication"]["samples"],
            "editor update path does not support report")

    files = tree["files"]
    require(tree["algorithm"] == "SHA-256" and tree["file_count"] == len(files) and
            tree["total_bytes"] == capture["trace_bytes"] == sum(item["bytes"] for item in files) and
            tree["tree_sha256"] == tree_digest(files),
            "trace file manifest")
    if args.local_trace:
        path = args.local_trace.resolve()
        require(path.is_dir() and all((path / item["path"]).is_file() and
                                          (path / item["path"]).stat().st_size == item["bytes"] and
                                          sha256(path / item["path"]) == item["sha256"] for item in files),
                "local trace bundle differs from archived tree hash")
        require(summary["cpu_export_sha256"] == sha256(path.parent / "cpu-profile.xml"),
                "local CPU XML export differs from archived analysis")

    for name, values in summary["phases"].items():
        total = values["samples"]
        mark = values["stack_contains"]["combining_marks"]
        update = values["stack_contains"].get("workspace_update", 0)
        print(f"{name}: {total:,} main-thread samples; combining marks {mark / total:.1%}; "
              f"editor update {update / total:.1%}")
    print("PASS: archived PID, signposts, input/output hashes, stage status, and trace tree" +
          (" + local trace bytes" if args.local_trace else " (raw trace local verification omitted)"))


if __name__ == "__main__":
    main()

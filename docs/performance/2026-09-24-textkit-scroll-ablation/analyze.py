#!/usr/bin/env python3
"""Verify and summarize the private #68 firstRect/selection-scroll ablation."""

import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NO_SCROLL = "firstrect-no-selection-scroll"
WITH_SCROLL = "firstrect-with-selection-scroll"
VARIANTS = (NO_SCROLL, WITH_SCROLL)
EXPECTED_RUNS = {NO_SCROLL: 6, WITH_SCROLL: 3}
STAGES = (
    "reflow_convert_1MiB",
    "reflow_convert_5MiB",
    "reflow_convert_10MiB",
    "layout_end_10_2256432_vertical",
    "layout_end_10_2256432_horizontal",
    "layout_end_10_4512863_vertical",
)
REMOVED_SCROLL = """    if saved.selectionWasVisible {
      editor.scrollRangeToVisible(NSRange(location: selection.location, length: 0))
    }
"""
ABLATION_COMMENT = "    // Ablation: retain firstRect capture, omit the conditional selection scroll.\n"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name):
    root = ROOT / "raw" / name
    metadata_path = root / "metadata.json"
    metadata = json.loads(metadata_path.read_text())
    build = json.loads((root / "build-complete.json").read_text())
    source_path = root / "ModernWorkspaceScrollKeeper.swift.txt"
    require(build["metadata_sha256"] == sha256(metadata_path), f"{name}: build metadata hash")
    require(metadata["source_hashes"]["Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift"] ==
            sha256(source_path), f"{name}: source hash")
    require(metadata["source_commit"] == "be827fc6bbc010d8a1aec7874991c11a6a72c31e",
            f"{name}: source commit")
    require(metadata["application_variant"] == "textkit2-modern-anchor", f"{name}: variant")
    files = sorted(root.glob("run-*.json"))
    require(len(files) == EXPECTED_RUNS[name], f"{name}: run count")
    runs = [json.loads(path.read_text()) for path in files]
    for run in runs:
        require(run["status"] == "complete", f"{name}: incomplete run")
        require(len(run["rows"]) == 59, f"{name}: stage count")
        stages = {row["name"]: row for row in run["rows"]}
        require(all(stage in stages for stage in STAGES), f"{name}: missing stage")
        for stage in STAGES:
            row = stages[stage]
            require(row["app_active"], f"{name}: inactive at {stage}")
            if stage.startswith("reflow_convert"):
                require(row["editors_match_model"] and row["export_matches_result"],
                        f"{name}: content mismatch at {stage}")
            else:
                require(row["textkit2"] and row["result_textkit2"],
                        f"{name}: legacy editor at {stage}")
            require(row["memory"]["rusage_status"] == 0 and
                    row["memory"]["task_info_status"] == 0,
                    f"{name}: invalid memory sample at {stage}")
    return metadata, source_path.read_text(), runs


def value(run, stage, key):
    row = next(row for row in run["rows"] if row["name"] == stage)
    if key in row["memory"]:
        return row["memory"][key] / 1048576
    return row[key]


def summary(runs, stage, key):
    values = [value(run, stage, key) for run in runs]
    return f"{statistics.median(values):.1f} ({min(values):.1f}–{max(values):.1f})"


def main():
    manifest = json.loads((ROOT / "checksums.json").read_text())
    require(manifest["algorithm"] == "SHA-256", "checksum algorithm")
    archived = {
        str(path.relative_to(ROOT)): sha256(path)
        for path in sorted((ROOT / "raw").rglob("*")) if path.is_file()
    }
    require(archived == manifest["files"], "raw file checksums")
    order = json.loads((ROOT / "run-order.json").read_text())["events"]
    expected_order = ([f"raw/{NO_SCROLL}/run-{i:02d}.json" for i in range(1, 4)] +
                      [f"raw/{WITH_SCROLL}/run-{i:02d}.json" for i in range(1, 4)] +
                      [f"raw/{NO_SCROLL}/run-{i:02d}.json" for i in range(4, 7)])
    require([event["file"] for event in order] == expected_order, "A-B-A run order")
    require(all(order[i]["saved_utc"] < order[i + 1]["saved_utc"]
                for i in range(len(order) - 1)), "run save order")
    data = {name: load(name) for name in VARIANTS}
    a_meta, a_source, a_runs = data[NO_SCROLL]
    b_meta, b_source, b_runs = data[WITH_SCROLL]
    require(b_source.count(REMOVED_SCROLL) == 1, "ambiguous source ablation")
    require(a_source == b_source.replace(REMOVED_SCROLL, ABLATION_COMMENT),
            "source differs beyond conditional selection scroll")
    for key in ("source_commit", "application_variant", "conditions", "pins",
                "resolved_checkout_revisions"):
        require(a_meta[key] == b_meta[key], f"metadata differs: {key}")
    hash_differences = {
        key for key in set(a_meta["source_hashes"]) | set(b_meta["source_hashes"])
        if a_meta["source_hashes"].get(key) != b_meta["source_hashes"].get(key)
    }
    require(hash_differences == {
        "Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift",
        "OpenCCman/View/WorkspaceScrollKeeper.swift",
    }, f"unexpected source differences: {hash_differences}")
    for stage in ("reflow_convert_1MiB", "reflow_convert_5MiB", "reflow_convert_10MiB"):
        for key in ("input_sha256", "output_sha256", "input_bytes", "output_bytes"):
            values = {value(run, stage, key) for _, _, runs in data.values() for run in runs}
            require(len(values) == 1, f"{stage}: inconsistent {key}")

    print("| Metric, median (range) | firstRect without selection scroll, n=6 |"
          " firstRect with selection scroll, n=3 |")
    print("| --- | ---: | ---: |")
    for stage, label, key in (
        ("reflow_convert_1MiB", "1 MiB conversion RSS, MiB", "rss_bytes"),
        ("reflow_convert_5MiB", "5 MiB conversion RSS, MiB", "rss_bytes"),
        ("reflow_convert_10MiB", "10 MiB conversion RSS, MiB", "rss_bytes"),
        ("reflow_convert_10MiB", "10 MiB conversion physical footprint, MiB",
         "physical_footprint_bytes"),
        ("layout_end_10_4512863_vertical", "10 MiB end vertical peak RSS, MiB",
         "process_peak_rss_bytes"),
        ("layout_end_10_4512863_vertical", "10 MiB end vertical action, ms", "action_ms"),
    ):
        print(f"| {label} | {summary(a_runs, stage, key)} | {summary(b_runs, stage, key)} |")
    for stage in ("layout_end_10_2256432_vertical",
                  "layout_end_10_2256432_horizontal"):
        counts = []
        for runs in (a_runs, b_runs):
            counts.append(sum(bool(value(run, stage, "selection_visible")) for run in runs))
        print(f"{stage}: selected caret visible {counts[0]}/{len(a_runs)} vs"
              f" {counts[1]}/{len(b_runs)}")
    print("PASS: archived hashes, source ablation, metadata, stage and input/output checks")


if __name__ == "__main__":
    main()

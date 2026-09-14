#!/usr/bin/env python3
"""Validate the archived final-source samples and reproduce descriptive statistics."""
import hashlib
import importlib.util
import json
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location("comparison", ROOT / "scripts/compare-app-performance.py")
comparison = importlib.util.module_from_spec(spec)
spec.loader.exec_module(comparison)
SOURCE = "5d527bd3978d73be5f028804d579c86da0f66752"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def describe(values):
    return {"n": len(values), "median": statistics.median(values),
            "min": min(values), "max": max(values)}


def load(suite, count):
    directory = HERE / suite
    metadata = json.loads((directory / "metadata.json").read_text())
    require(metadata["schema"] == comparison.PROTOCOL, "Wrong protocol")
    require(metadata["source_commit"] == SOURCE, "Unexpected source")
    require(metadata["conditions"]["suite"] == suite, "Unexpected suite")
    comparison.validate_pins(metadata)
    if suite == "conversion":
        _, runs = comparison.load(directory)
    else:
        runs = [json.loads(p.read_text()) for p in sorted(directory.glob("run-*.json"))]
    require(len(runs) == count, "Wrong process count")
    require(len({run["pid"] for run in runs}) == count, "Repeated process")
    names = [row["name"] for row in runs[0]["rows"]]
    require(len(names) == len(set(names)), "Duplicate stage")
    digest = hashlib.sha256((directory / "metadata.json").read_bytes()).hexdigest()
    for run in runs:
        require(run["status"] == "complete", "Incomplete run")
        require(run["metadata_sha256"] == digest, "Wrong provenance")
        require([row["name"] for row in run["rows"]] == names, "Different stages")
        foreground = False
        for row in run["rows"]:
            foreground |= row["name"] == "root_layout_ready"
            require(not foreground or (row["app_active"] and row["visible_window_count"] > 0), "Not visible/active")
            require(row["memory"]["task_info_status"] == row["memory"]["rusage_status"] == 0, "Memory collection failed")
            require(row.get("editors_match_model") is not False, "Editor mismatch")
            require(row.get("export_matches_result") is not False, "Export mismatch")
        if suite == "reflow":
            layouts = [r for r in run["rows"] if r["name"].startswith("layout_end_")]
            require(len(layouts) == 18, "Missing layout coverage")
            require(sum(r["name"].startswith("scroll_end_") for r in run["rows"]) == 9, "Missing scroll coverage")
            for mib in (1, 5, 10):
                converted = next(r for r in run["rows"] if r["name"] == f"reflow_convert_{mib}MiB")
                rows = [r for r in layouts if r["name"].startswith(f"layout_end_{mib}_")]
                require(len(rows) == 6, "Missing axis/position coverage")
                for r in rows:
                    require(r["textkit2"] is False, "Unexpected text engine")
                    for key in ("input_sha256", "output_sha256"):
                        require(r[key] == converted[key], "Changed document")
    return runs


def summarize(runs):
    stages = {}
    for index, row in enumerate(runs[0]["rows"]):
        metrics = {}
        for key in ("model_completion_ms", "result_layout_flush_ms", "process_start_to_root_layout_ms", "app_init_to_root_layout_ms", "action_ms"):
            if key in row:
                metrics[key] = describe([r["rows"][index][key] for r in runs])
        if metrics:
            stages[row["name"]] = metrics
    return {
        "processes": len(runs), "stages": stages,
        "whole_process_peak_rss_MiB": describe([max(row["memory"]["process_peak_rss_bytes"] for row in run["rows"]) / 1048576 for run in runs]),
        "whole_suite_main_timer_max_gap_ms": describe([max(row["maximum_main_timer_gap_ms"] for row in run["rows"]) for run in runs]),
    }


def main():
    conversion = load("conversion", 5)
    reflow = load("reflow", 3)
    result = {"source_commit": SOURCE, "conversion": summarize(conversion), "reflow": summarize(reflow)}
    result["conversion"]["hot_model_ms_per_process_median"] = describe([
        statistics.median(row["model_completion_ms"] for row in run["rows"] if row["name"].startswith("hot_"))
        for run in conversion
    ])
    result["conversion"]["closed_window_models_still_alive"] = [
        run["rows"][-1]["all_extra_models_alive"] for run in conversion
    ]
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

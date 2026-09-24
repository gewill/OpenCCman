#!/usr/bin/env python3
"""Verify #68 single-paragraph app runs and bounded timeout evidence."""

import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VARIANTS = {
    "tk1-max1": (1, 2, 3),
    "tk2-max1": (4, 5, 6),
}
STAGES = (
    "reflow_convert_1MiB",
    "scroll_end_1_0",
    "layout_end_1_0_vertical",
    "layout_end_1_0_horizontal",
    "scroll_end_1_201098",
    "layout_end_1_201098_vertical",
    "layout_end_1_201098_horizontal",
    "scroll_end_1_402194",
    "layout_end_1_402194_vertical",
    "layout_end_1_402194_horizontal",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name, indexes):
    folder = ROOT / "raw" / name
    metadata_path = folder / "metadata.json"
    metadata = json.loads(metadata_path.read_text())
    build = json.loads((folder / "build-complete.json").read_text())
    require(build["metadata_sha256"] == sha256(metadata_path), f"{name}: metadata hash")
    runs = [json.loads((folder / f"run-{i:02d}.json").read_text()) for i in indexes]
    return metadata, runs


def stage(run, name):
    return next(row for row in run["rows"] if row["name"] == name)


def values(runs, name, key):
    rows = [stage(run, name) for run in runs]
    if key in rows[0]["memory"]:
        return [row["memory"][key] / 1048576 for row in rows]
    return [row[key] for row in rows]


def formatted(data):
    return f"{statistics.median(data):.1f} ({min(data):.1f}–{max(data):.1f})"


def main():
    manifest = json.loads((ROOT / "checksums.json").read_text())
    require(manifest["algorithm"] == "SHA-256", "checksum algorithm")
    actual = {
        str(path.relative_to(ROOT)): sha256(path)
        for path in sorted((ROOT / "raw").rglob("*")) if path.is_file()
    }
    require(actual == manifest["files"], "raw file checksums")
    order = json.loads((ROOT / "run-order.json").read_text())["events"]
    # The TextKit 2 paired runs were numbered 4–6 in its existing build.
    expected = [f"raw/tk1-max1/run-{index:02d}.json" if i % 2 == 0
                else f"raw/tk2-max1/run-{index + 3:02d}.json"
                for index in range(1, 4) for i in (0, 1)]
    require([event["file"] for event in order] == expected, "paired run order")
    require(all(order[i]["saved_utc"] < order[i + 1]["saved_utc"]
                for i in range(len(order) - 1)), "run save times")

    data = {name: load(name, indexes) for name, indexes in VARIANTS.items()}
    a_meta, a_runs = data["tk1-max1"]
    b_meta, b_runs = data["tk2-max1"]
    require(a_meta["source_commit"] == "9cf787907648353ccc3d5631b5e435f996167cfa",
            "paired source commit")
    for key in ("source_commit", "conditions", "pins", "resolved_checkout_revisions",
                "hardware", "os", "xcode"):
        require(a_meta[key] == b_meta[key], f"paired metadata mismatch: {key}")
    conditions = a_meta["conditions"]
    require(conditions["input_profile"] == "single-paragraph" and
            conditions["reflow_max_mib"] == 1 and conditions["suite"] == "reflow" and
            conditions["navigation_target"].startswith("middle composed character"),
            "paired protocol conditions")
    source_differences = {
        key for key in set(a_meta["source_hashes"]) | set(b_meta["source_hashes"])
        if a_meta["source_hashes"].get(key) != b_meta["source_hashes"].get(key)
    }
    require(source_differences == {
        "OpenCCman/View/WorkspaceScrollKeeper.swift",
        "OpenCCman/View/WorkspaceTextEditor.swift",
        "Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift",
    }, f"unexpected source differences: {source_differences}")
    keeper = ROOT.parent / "2026-09-24-textkit-scroll-ablation/raw/firstrect-single-target-scroll/ModernWorkspaceScrollKeeper.swift.txt"
    require(b_meta["source_hashes"]["Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift"] ==
            sha256(keeper), "TextKit 2 keeper differs from archived candidate")

    unit = "汉语转换，软件与网络。繁體中文👨‍👩‍👧‍👦e\u0301"
    size = 1048576
    fixture = (unit * (size // len(unit.encode())) +
               "a" * (size % len(unit.encode()))).encode()
    require(len(fixture) == size and b"\r" not in fixture and b"\n" not in fixture,
            "fixture is not exactly one MiB and one paragraph")
    input_hash = hashlib.sha256(fixture).hexdigest()
    for name, (metadata, runs) in data.items():
        require(len(runs) == 3, f"{name}: run count")
        for run in runs:
            require(run["status"] == "complete" and len(run["rows"]) == 21,
                    f"{name}: incomplete protocol")
            require(all(any(row["name"] == key for row in run["rows"]) for key in STAGES),
                    f"{name}: missing stage")
            converted = stage(run, "reflow_convert_1MiB")
            require(converted["input_bytes"] == size and converted["input_sha256"] == input_hash,
                    f"{name}: fixture hash")
            require(converted["editors_match_model"] and converted["export_matches_result"],
                    f"{name}: content mismatch")
            for key in STAGES:
                row = stage(run, key)
                require(row["app_active"] and row["memory"]["rusage_status"] == 0 and
                        row["memory"]["task_info_status"] == 0,
                        f"{name}: invalid stage {key}")
                if key.startswith("layout_end"):
                    expected_textkit2 = name == "tk2-max1"
                    require(row["textkit2"] == expected_textkit2 and
                            row["result_textkit2"] == expected_textkit2,
                            f"{name}: wrong text system at {key}")
    require(len({stage(run, "reflow_convert_1MiB")["output_sha256"]
                 for _, runs in data.values() for run in runs}) == 1,
            "converted output hash differs")

    print("| 1 MiB single paragraph, median (range) | TextKit 1, n=3 | TextKit 2 single-target, n=3 |")
    print("| --- | ---: | ---: |")
    for name, label, key in (
        ("reflow_convert_1MiB", "Conversion-end RSS, MiB", "rss_bytes"),
        ("layout_end_1_402194_horizontal", "Final peak RSS, MiB", "process_peak_rss_bytes"),
        ("layout_end_1_402194_horizontal", "Final physical footprint, MiB", "physical_footprint_bytes"),
        ("scroll_end_1_201098", "Middle remote scroll, ms", "action_ms"),
        ("scroll_end_1_402194", "End remote scroll, ms", "action_ms"),
        ("layout_end_1_201098_vertical", "Middle vertical switch, ms", "action_ms"),
        ("layout_end_1_201098_horizontal", "Middle horizontal switch, ms", "action_ms"),
    ):
        print(f"| {label} | {formatted(values(a_runs, name, key))} |"
              f" {formatted(values(b_runs, name, key))} |")

    for name in ("tk1-max10-timeout", "tk2-max10-timeout"):
        metadata, (run,) = load(name, (1,))
        note = json.loads((ROOT / "raw" / name / "attempt.json").read_text())
        require(metadata["source_commit"] == "2e6e079644c8578b80986e555b023f0d207e4c95",
                f"{name}: source commit")
        require(metadata["conditions"]["input_profile"] == "single-paragraph" and
                metadata["conditions"].get("reflow_max_mib", 10) == 10, f"{name}: profile")
        require(note["outcome"] == "deadline_exceeded" and note["deadline_seconds"] == 120 and
                note["target_pid"] == run["pid"] and note["run_json_status_at_timeout"] == run["status"],
                f"{name}: timeout observation")
        require(run["status"] == "running" and
                note["last_recorded_stage"] == run["rows"][-1]["name"] ==
                "layout_begin_5_0_vertical", f"{name}: last stage")
        require(stage(run, "reflow_convert_5MiB")["input_bytes"] == 5 * size,
                f"{name}: 5 MiB conversion not complete")
        print(f"{name}: 120 s deadline; final recorded stage {note['last_recorded_stage']};"
              f" RSS {run['rows'][-1]['memory']['rss_bytes'] / 1048576:.1f} MiB")
    smoke = json.loads((ROOT / "raw/timeout-smoke/run-04.json").read_text())
    require(smoke["status"] == "timeout" and smoke["timeout_seconds"] == 2 and
            smoke["last_recorded_stage"] == smoke["rows"][-1]["name"] ==
            "root_layout_ready" and
            smoke["metadata_sha256"] ==
            sha256(ROOT / "raw/tk1-max1/metadata.json"),
            "timeout smoke evidence")
    print("PASS: source, fixture, paired runs, and bounded timeout evidence")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Recompute the archived #68 phase and allocation tables from raw exports."""

import hashlib
import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VARIANTS = ("baseline", "first-rect")
SOURCE_COMMITS = {
    "baseline": "17e6d6b63c0f436f7b3bcc18fc5e5177796156f4",
    "first-rect": "be827fc6bbc010d8a1aec7874991c11a6a72c31e",
}
STAGES = (
    "reflow_convert_1MiB",
    "reflow_convert_5MiB",
    "reflow_convert_10MiB",
    "scroll_begin_10_0",
    "layout_end_10_4512863_vertical",
)
CATEGORIES = (
    "All Heap & Anonymous VM",
    "NSTextParagraph",
    "NSTextLayoutFragment",
    "NSCountableTextRange",
    "NSCountableTextLocation",
    "NSCoreTypesetter",
)


def load(name):
    folder = ROOT / name
    run = json.loads((folder / "run-01.json").read_text())
    summary = json.loads((folder / "trace-summary.json").read_text())
    for filename, expected_key in (
        ("run-01.json", "run_01_json_sha256"),
        ("allocations-statistics.xml", "allocations_statistics_xml_sha256"),
        ("allocations-statistics-after-5MiB-convert.xml",
         "allocations_statistics_after_5MiB_convert_xml_sha256"),
        ("allocations-statistics-before-10MiB-scroll.xml",
         "allocations_statistics_before_10MiB_scroll_xml_sha256"),
    ):
        actual = hashlib.sha256((folder / filename).read_bytes()).hexdigest()
        assert actual == summary["exports"][expected_key], f"{name}/{filename}: export hash mismatch"
    categories = {
        row.attrib["category"]: row.attrib
        for row in ET.parse(folder / "allocations-statistics.xml").iter("row")
    }
    assert run["status"] == "complete" and len(run["rows"]) == 59
    assert run["pid"] == summary["trace"]["target_pid"]
    assert summary["trace"]["target_type"] == "attached"
    assert summary["trace"]["target_exit_status"] == "0"
    assert summary["trace"]["template"] == "Allocations"
    assert summary["source_commit"] == SOURCE_COMMITS[name]
    assert set(summary["trace"]["tracks"]) >= {"Allocations", "VM Tracker"}
    assert summary["run"]["all_conversion_stages_active"]
    stages = {row["name"]: row for row in run["rows"]}
    assert all(stage in stages for stage in STAGES)
    assert all(category in categories for category in CATEGORIES)
    windows = {}
    for label, filename, mib, cutoff_key in (
        ("after_5MiB", "allocations-statistics-after-5MiB-convert.xml", 5, "after_5MiB_ms"),
        ("before_10MiB_scroll", "allocations-statistics-before-10MiB-scroll.xml", 10,
         "before_10MiB_scroll_ms"),
    ):
        rows = {row.attrib["category"]: row.attrib for row in ET.parse(folder / filename).iter("row")}
        assert all(category in rows for category in CATEGORIES)
        alignment = summary["time_alignment"]
        cutoff = alignment["export_cutoffs_ms"][cutoff_key]
        stage_offsets = alignment["stage_trace_offsets_ms"]
        assert stage_offsets[f"reflow_convert_{mib}MiB"] < cutoff < stage_offsets[f"scroll_begin_{mib}_0"]
        windows[label] = rows
    return stages, categories, windows


def print_table(title, rows):
    print(f"\n{title}")
    print("| 项目 | 现代锚点 | firstRect 候选 |")
    print("| --- | ---: | ---: |")
    for label, values in rows:
        print(f"| {label} | {values[0]} | {values[1]} |")


def main():
    data = {name: load(name) for name in VARIANTS if (ROOT / name / "run-01.json").exists()}
    assert "baseline" in data
    complete = len(data) == 2

    def metric(name, stage, key):
        if name not in data:
            return "待录制"
        return f"{data[name][0][stage]['memory'][key] / 1048576:.1f}"

    phase_rows = []
    for stage in STAGES:
        phase_rows.append((f"{stage} RSS (MiB)",
                           [metric(name, stage, "rss_bytes") for name in VARIANTS]))
    print_table("阶段内存：带 Allocations 录制的单次样本", phase_rows)

    object_rows = []
    for category in CATEGORIES:
        object_rows.append((f"{category} count-persistent",
                            [data[name][1][category]["count-persistent"] if name in data
                             else "待录制" for name in VARIANTS]))
        object_rows.append((f"{category} count-events",
                            [data[name][1][category]["count-events"] if name in data
                             else "待录制" for name in VARIANTS]))
    print_table("Allocations 全 trace 分类计数：不等于泄漏或相同数量的 RSS", object_rows)

    for stage, title in (("after_5MiB", "5 MiB 转换结束、首次滚动前"),
                         ("before_10MiB_scroll", "10 MiB 转换结束、首次滚动前")):
        rows = []
        for category in ("All Heap & Anonymous VM", "NSTextParagraph", "NSCountableTextRange",
                         "NSCountableTextLocation"):
            for key in ("count-persistent", "count-events"):
                rows.append((f"{category} {key}",
                             [data[name][2][stage][category][key] if name in data
                              else "待录制" for name in VARIANTS]))
        print_table(f"{title}的 trace 时间窗：切点位于转换与滚动记录之间", rows)

    if complete:
        base = data["baseline"][0]["reflow_convert_10MiB"]
        candidate = data["first-rect"][0]["reflow_convert_10MiB"]
        for key in ("input_sha256", "output_sha256", "input_bytes", "output_bytes"):
            assert base[key] == candidate[key], f"10 MiB {key} differs"
        print("\nPASS: 10 MiB input/output hashes and lengths match; this is still one traced run per variant.")
    else:
        print("\nINCOMPLETE: firstRect trace not archived; no candidate attribution is possible.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify paired, gated 1 MiB TextKit 1/2 memory traces and their limits."""

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
RAW = ROOT / "raw"
MIB = 1024 * 1024
VARIANTS = (("tk1", "unchanged", False), ("tk2", "textkit2-modern-anchor", True))
STAGES = ("source_editor_ack_end_1MiB", "reflow_convert_1MiB",
          "layout_end_1_402194_vertical", "layout_end_1_402194_horizontal")
CATEGORIES = ("All Heap & Anonymous VM", "CG::DisplayListEntryGlyphs", "CTRun")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(8 * MIB), b""):
            digest.update(part)
    return digest.hexdigest()


def read(path):
    return json.loads(path.read_text())


def stage(run, name):
    found = [row for row in run["rows"] if row["name"] == name]
    require(len(found) == 1, f"missing or duplicate {name}")
    return found[0]


def signposts(path):
    root = ET.parse(path).getroot()
    names = {item.get("id"): item.text for item in root.findall(".//signpost-name") if item.get("id")}
    result = []
    for row in root.findall(".//row"):
        item = row.find("signpost-name")
        result.append((names.get(item.get("ref"), item.text), int(row.findtext("start-time")),
                       int(row.findtext("duration"))))
    return result


def vm_types(path):
    groups = defaultdict(lambda: {"regions": 0, "virtual_bytes": 0, "resident_bytes": 0,
                                  "dirty_bytes": 0, "swapped_bytes": 0})
    for row in ET.parse(path).iter("row"):
        a = row.attrib
        group = groups[a.get("type", "unknown")]
        group["regions"] += 1
        for source, target in (("virtual-size", "virtual_bytes"), ("resident-size", "resident_bytes"),
                               ("dirty-size", "dirty_bytes"), ("swapped-size", "swapped_bytes")):
            group[target] += int(a.get(source, "0"))
    return dict(sorted(groups.items()))


def tree_digest(files):
    stream = "".join(f"{item['path']}\0{item['bytes']}\0{item['sha256']}\n" for item in files).encode()
    return hashlib.sha256(stream).hexdigest()


def load(name, expected_variant, expect_textkit2, local_trace):
    folder = RAW / name
    metadata = read(folder / "metadata.json")
    marker = read(folder / "build-complete.json")
    manifest = read(folder / "manifest.json")
    run = read(folder / "run.json")
    target = read(folder / "trace-target.json")
    vm = read(folder / "vm-region-types.json")
    tree = read(folder / "trace-tree.json")
    entitlements = plistlib.loads((folder / "debug-entitlements.plist").read_bytes())
    require(metadata["source_commit"] == metadata["measurement_harness_commit"] ==
                "ea76273ff1fe9af61cb685fb5771d8aa0c30d9b1" and
            metadata["source_status"] == "" and metadata["application_variant"] == expected_variant and
            metadata["conditions"]["profiling_start_gate"] is True and
            metadata["conditions"]["input_profile"] == "single-paragraph" and
            metadata["conditions"]["reflow_max_mib"] == 1 and
            metadata["conditions"]["suite"] == "reflow" and
            marker["metadata_sha256"] == manifest["build_metadata_sha256"] == sha256(folder / "metadata.json") and
            manifest["source_commit"] == metadata["source_commit"] and
            manifest["application_variant"] == expected_variant and
            manifest["driver_sha256"] == sha256(REPO / "scripts/profile-paired-paragraph-memory.py") and
            manifest["signature_verified"] and entitlements == {"com.apple.security.get-task-allow": True},
            f"{name}: build or driver provenance")
    require(manifest["pid"] == run["pid"] and manifest["stage_before_gate"] == "process_initialized" and
            manifest["gate_released"] and manifest["app_status"] == run["status"] == "complete" and
            manifest["recorded_stage_count"] == len(run["rows"]) == 38 and
            manifest["last_recorded_stage"] == "layout_end_1_402194_horizontal" and
            manifest["all_workload_rows_active"] and not manifest["app_timed_out"] and
            manifest["xctrace_exit_code"] == manifest["launch_exit_code"] == 0 and
            manifest["idle_after_seconds"] > manifest["idle_before_seconds"] and
            all(row["app_active"] for row in run["rows"] if row["name"] != "process_initialized") and
            len([row for row in run["rows"] if row["name"] == "profiling_gate_release"]) == 1,
            f"{name}: incomplete or background run")
    for label in STAGES:
        stage(run, label)
    conversion = stage(run, "reflow_convert_1MiB")
    require(conversion["input_bytes"] == conversion["output_bytes"] == MIB and
            conversion["editors_match_model"] and conversion["export_matches_result"] and
            all(stage(run, label)["textkit2"] is expect_textkit2 and
                stage(run, label)["result_textkit2"] is expect_textkit2 and
                isinstance(stage(run, label)["selection_visible"], bool) and
                (expect_textkit2 or stage(run, label)["selection_visible"])
                for label in STAGES if label.startswith("layout_end")),
            f"{name}: conversion integrity or actual TextKit identity")
    processes = [item for item in target["processes"] if item["pid"] == str(run["pid"]) and
                 item["name"] == "OpenCCman"]
    require(any(item.get("termination-reason") == "exit(0)" for item in processes) and
            set(target["tracks"]) >= {"Allocations", "VM Tracker"}, f"{name}: trace target")
    posts = signposts(folder / "signposts.xml")
    offsets = []
    for row_name, post_name in (("source_editor_ack_begin_1MiB", "Source editor acknowledgement"),
                                ("model_conversion_begin_reflow_convert_1MiB", "Model conversion")):
        matches = [post for post in posts if post[0] == post_name]
        require(len(matches) == 1, f"{name}: missing signpost {post_name}")
        offsets.append(matches[0][1] - round(stage(run, row_name)["elapsed_ms"] * 1_000_000))
    require(abs(offsets[0] - offsets[1]) < 5_000_000, f"{name}: signpost clocks diverged")
    allocations = {row.attrib["category"]: row.attrib for row in
                   ET.parse(folder / "allocations-statistics.xml").iter("row")}
    require(set(CATEGORIES) <= set(allocations), f"{name}: missing Allocations categories")
    require(vm["source"].startswith("VM Tracker Regions Map") and
            vm["types"]["Malloc Small"]["resident_bytes"] > 0,
            f"{name}: VM region type export")
    files = tree["files"]
    require(tree["algorithm"] == "SHA-256" and tree["file_count"] == len(files) and
            tree["total_bytes"] == manifest["trace_bytes"] == sum(item["bytes"] for item in files) and
            tree["tree_sha256"] == tree_digest(files), f"{name}: trace tree")
    if local_trace:
        trace = local_trace.resolve()
        require(trace.is_dir() and all((trace / item["path"]).is_file() and
                                       (trace / item["path"]).stat().st_size == item["bytes"] and
                                       sha256(trace / item["path"]) == item["sha256"] for item in files),
                f"{name}: local trace bytes differ")
        require(vm_types(trace.parent / "vm-regions.xml") == vm["types"],
                f"{name}: VM type totals differ from local raw export")
    return metadata, manifest, run, allocations, vm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tk1-trace", type=Path)
    parser.add_argument("--tk2-trace", type=Path)
    args = parser.parse_args()
    require(bool(args.tk1_trace) == bool(args.tk2_trace), "supply both local traces or neither")
    expected = read(ROOT / "checksums.json")
    actual = {str(path.relative_to(ROOT)): sha256(path) for path in sorted(RAW.rglob("*")) if path.is_file()}
    require(expected == {"algorithm": "SHA-256", "files": actual} and len(actual) == 23,
            "archived file checksums")
    runs = {}
    for name, variant, textkit2 in VARIANTS:
        trace = args.tk1_trace if name == "tk1" else args.tk2_trace
        runs[name] = load(name, variant, textkit2, trace)
    old, new = runs["tk1"], runs["tk2"]
    for key in ("source_commit", "measurement_harness_commit", "pins", "resolved_checkout_revisions",
                "os", "hardware", "xcode", "conditions"):
        require(old[0][key] == new[0][key], f"paired build {key} differs")
    changed_sources = {path for path in old[0]["source_hashes"]
                       if old[0]["source_hashes"][path] != new[0]["source_hashes"].get(path)}
    require(set(old[0]["source_hashes"]) == set(new[0]["source_hashes"]) and
            changed_sources == {"OpenCCman/View/WorkspaceScrollKeeper.swift",
                                "OpenCCman/View/WorkspaceTextEditor.swift"},
            "paired build changed unrelated source")
    for key in ("input_bytes", "output_bytes", "input_sha256", "output_sha256", "options"):
        require(stage(old[2], "reflow_convert_1MiB")[key] == stage(new[2], "reflow_convert_1MiB")[key],
                f"paired conversion {key} differs")
    excluded = read(RAW / "excluded-trace-save.json")
    require(excluded["application_variant"] == "textkit2-modern-anchor" and
            excluded["xctrace_exit_code"] != 0 and excluded["app_status"] == "complete" and
            excluded["all_workload_rows_active"], "failed trace-save run must remain excluded")
    for name, data in runs.items():
        _, _, run, allocations, vm = data
        rss = stage(run, "layout_end_1_402194_horizontal")["memory"]["rss_bytes"] / MIB
        heap = int(allocations["All Heap & Anonymous VM"]["persistent-bytes"]) / MIB
        glyphs = int(allocations["CG::DisplayListEntryGlyphs"]["persistent-bytes"]) / MIB
        runs_count = int(allocations["CTRun"]["count-persistent"])
        malloc = vm["types"]["Malloc Small"]["resident_bytes"] / MIB
        visible = [stage(run, label)["selection_visible"] for label in STAGES if label.startswith("layout_end")]
        print(f"{name}: final-stage RSS {rss:.1f} MiB; Allocations persistent classification {heap:.1f} MiB; "
              f"DisplayList glyphs {glyphs:.1f} MiB; CTRun {runs_count:,}; VM Malloc Small {malloc:.1f} MiB; "
              f"selection visible {visible}")
    print("PASS: paired build, gate, input/output, actual TextKit, foreground, trace, and archived exports" +
          (" + local raw traces" if args.tk1_trace else " (local raw traces not checked)"))


if __name__ == "__main__":
    main()

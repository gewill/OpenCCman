#!/usr/bin/env python3
"""Check the archived, foreground 5 MiB Allocations/VM trace evidence."""

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
RAW = ROOT / "raw"
MIB = 1024 * 1024
WINDOWS = (
    ("source_start", "allocations-source-start.xml", 17754),
    ("source_end", "allocations-source-end.xml", 67810),
    ("after_conversion", "allocations-after-conversion.xml", 118800),
    ("layout_start", "allocations-layout-start.xml", 119200),
    ("trace_end", "allocations-statistics.xml", None),
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * MIB), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read(name):
    return json.loads((RAW / name).read_text())


def stage(run, name):
    rows = [row for row in run["rows"] if row["name"] == name]
    require(len(rows) == 1, f"missing or duplicate {name}")
    return rows[0]


def signposts(path):
    root = ET.parse(path).getroot()
    names = {item.get("id"): item.text for item in root.findall(".//signpost-name") if item.get("id")}
    rows = []
    for row in root.findall(".//row"):
        item = row.find("signpost-name")
        rows.append((names.get(item.get("ref"), item.text), int(row.findtext("start-time")),
                     int(row.findtext("duration"))))
    return rows


def trace_tree_digest(files):
    data = "".join(f"{item['path']}\0{item['bytes']}\0{item['sha256']}\n" for item in files)
    return hashlib.sha256(data.encode()).hexdigest()


def vm_types(path):
    groups = defaultdict(lambda: {"regions": 0, "virtual_bytes": 0, "resident_bytes": 0,
                                  "dirty_bytes": 0, "swapped_bytes": 0})
    for row in ET.parse(path).iter("row"):
        attributes = row.attrib
        group = groups[attributes.get("type", "unknown")]
        group["regions"] += 1
        for source, key in (("virtual-size", "virtual_bytes"), ("resident-size", "resident_bytes"),
                            ("dirty-size", "dirty_bytes"), ("swapped-size", "swapped_bytes")):
            group[key] += int(attributes.get(source, "0"))
    return dict(sorted(groups.items()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-trace", type=Path,
                        help="Optionally verify the local .trace bundle and VM Regions XML sidecar")
    args = parser.parse_args()
    checksums = json.loads((ROOT / "checksums.json").read_text())
    actual = {str(path.relative_to(ROOT)): sha256(path) for path in sorted(RAW.iterdir()) if path.is_file()}
    require(checksums == {"algorithm": "SHA-256", "files": actual} and len(actual) == 13,
            "archived file checksums")

    manifest = read("manifest.json")
    run = read("run.json")
    target = read("trace-target.json")
    vm = read("vm-region-types.json")
    tree = read("trace-tree.json")
    excluded = read("excluded-run.json")
    cpu_manifest = json.loads((REPO / "docs/performance/2026-09-24-paragraph-cpu-trace/raw/manifest.json").read_text())
    cpu_run = json.loads((REPO / "docs/performance/2026-09-24-paragraph-cpu-trace/raw/run.json").read_text())
    require(manifest["source_commit"] == cpu_manifest["source_commit"] and
            manifest["build_metadata_sha256"] == cpu_manifest["build_metadata_sha256"] and
            manifest["driver_sha256"] == sha256(REPO / "scripts/profile-paragraph-phases.py") and
            manifest["profile"] == "memory" and manifest["mode"] == "workload" and
            manifest["instruments"] == ["Allocations", "VM Tracker", "Points of Interest"] and
            manifest["signature_verified"] and manifest["pid"] == run["pid"] and
            manifest["xctrace_exit_code"] == manifest["launch_exit_code"] == 0 and
            manifest["app_timed_out"] and manifest["owned_app_termination_requested"] and
            manifest["all_workload_rows_active"] and manifest["recorded_stage_count"] == len(run["rows"]) == 57 and
            manifest["last_recorded_stage"] == "layout_begin_5_0_vertical" and
            manifest["idle_after_seconds"] > manifest["idle_before_seconds"] and
            all(row["app_active"] for row in run["rows"] if row["name"] != "process_initialized"),
            "private build, owned foreground process, or bounded trace")
    require(excluded["profile"] == "memory" and not excluded["all_workload_rows_active"] and
            excluded["idle_after_seconds"] < excluded["idle_before_seconds"] and
            excluded["pid"] != run["pid"],
            "excluded focus-loss run is not distinct")
    own = stage(run, "reflow_convert_5MiB")
    reference = stage(cpu_run, "reflow_convert_5MiB")
    require(all(own[key] == reference[key] for key in
                ("input_bytes", "output_bytes", "input_sha256", "output_sha256")) and
            own["input_bytes"] == own["output_bytes"] == 5 * MIB and
            own["editors_match_model"] and own["export_matches_result"],
            "5 MiB input/output differs from matched CPU run")

    processes = [item for item in target["processes"] if item["pid"] == str(run["pid"]) and
                 item["name"] == "OpenCCman"]
    require(any(item.get("termination-reason") == "exit(0)" for item in processes) and
            set(target["tracks"]) >= {"Allocations", "VM Tracker"}, "trace target identity")
    posts = signposts(RAW / "signposts.xml")
    source = [item for item in posts if item[0] == "Source editor acknowledgement" and item[1] > 10_000_000_000]
    conversion = [item for item in posts if item[0] == "Model conversion" and item[1] > 10_000_000_000]
    require(len(source) == len(conversion) == 1, "5 MiB signpost identity")
    offset_source = source[0][1] - round(stage(run, "source_editor_ack_begin_5MiB")["elapsed_ms"] * 1_000_000)
    offset_conversion = conversion[0][1] - round(
        stage(run, "model_conversion_begin_reflow_convert_5MiB")["elapsed_ms"] * 1_000_000)
    require(abs(offset_source - offset_conversion) < 5_000_000, "signpost/app clock alignment")
    offset = (offset_source + offset_conversion) // 2
    layout_ns = round(stage(run, "layout_begin_5_0_vertical")["elapsed_ms"] * 1_000_000) + offset
    cutoffs = {name: milliseconds * 1_000_000 for name, _, milliseconds in WINDOWS if milliseconds is not None}
    require(source[0][1] - 5_000_000 <= cutoffs["source_start"] <= source[0][1] and
            source[0][1] + source[0][2] <= cutoffs["source_end"] < conversion[0][1] and
            conversion[0][1] + conversion[0][2] <= cutoffs["after_conversion"] < layout_ns and
            layout_ns <= cutoffs["layout_start"] < layout_ns + 200_000_000,
            "allocation export cutoffs do not bracket the intended phases")

    allocations = {}
    for name, filename, _ in WINDOWS:
        rows = {row.attrib["category"]: row.attrib for row in ET.parse(RAW / filename).iter("row")}
        require({"All Heap & Anonymous VM", "CTRun"} <= set(rows), f"missing allocation categories in {name}")
        allocations[name] = rows
    for category in ("All Heap & Anonymous VM", "CTRun"):
        events = [int(allocations[name][category]["count-events"]) for name, _, _ in WINDOWS]
        require(all(after > before for before, after in zip(events, events[1:])),
                f"non-increasing allocation events in {category}")
        print(f"{category} cumulative events: " + " → ".join(f"{value:,}" for value in events))
    # Xcode 27 returns negative `count-persistent` for intermediate `--time-end`
    # exports; do not interpret them as retained-object snapshots.
    require(int(allocations["source_start"]["All Heap & Anonymous VM"]["count-persistent"]) < 0 and
            int(allocations["trace_end"]["CTRun"]["count-persistent"]) > 0,
            "unexpected allocation Statistics semantics")
    types = vm["types"]
    require(vm["source"].startswith("VM Tracker Regions Map") and
            types["Malloc Small"]["resident_bytes"] > 0 and
            types["Malloc Large"]["resident_bytes"] > 0 and
            all(value >= 0 for data in types.values() for value in data.values()),
            "sanitized VM region classes")

    files = tree["files"]
    require(tree["algorithm"] == "SHA-256" and len(files) == tree["file_count"] and
            sum(item["bytes"] for item in files) == tree["total_bytes"] == manifest["trace_bytes"] and
            tree["tree_sha256"] == trace_tree_digest(files), "trace file-tree integrity")
    if args.local_trace:
        trace = args.local_trace.resolve()
        require(trace.is_dir() and all((trace / item["path"]).is_file() and
                                       (trace / item["path"]).stat().st_size == item["bytes"] and
                                       sha256(trace / item["path"]) == item["sha256"] for item in files),
                "local trace differs from archived hashes")
        require(vm_types(trace.parent / "vm-regions.xml") == types,
                "VM type totals differ from local raw Regions Map export")
    print(f"VM Tracker default export: {sum(data['regions'] for data in types.values()):,} region rows; "
          f"Malloc Small {types['Malloc Small']['resident_bytes'] / MIB:.1f} MiB resident")
    print("PASS: archive, foreground stages, input hashes, signposts, allocation cutoffs, VM groups, and trace tree" +
          (" + local raw trace" if args.local_trace else " (local raw trace not checked)"))


if __name__ == "__main__":
    main()

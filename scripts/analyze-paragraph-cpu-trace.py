#!/usr/bin/env python3
"""Summarize main-thread CPU samples around the private 5 MiB signposts."""

import argparse
from collections import Counter
import hashlib
import html
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

TIME_VALUE = re.compile(r'<sample-time\s+id="(\d+)"[^>]*>(\d+)</sample-time>')
TIME_REF = re.compile(r'<sample-time\s+ref="(\d+)"')
THREAD = re.compile(r'<thread\s+(?:id|ref)="(\d+)"')
BACKTRACE = re.compile(r'<tagged-backtrace\s+(id|ref)="(\d+)"')
FRAME = re.compile(r"<frame\s+([^>]*)>")
ID = re.compile(r'\bid="(\d+)"')
REF = re.compile(r'\bref="(\d+)"')
NAME = re.compile(r'\bname="([^"]*)"')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signposts(path):
    root = ET.parse(path).getroot()
    names = {element.get("id"): element.text for element in root.findall(".//signpost-name") if element.get("id")}
    found = []
    for row in root.findall(".//row"):
        element = row.find("signpost-name")
        name = names.get(element.get("ref"), element.text)
        found.append({"name": name, "start_ns": int(row.findtext("start-time")),
                      "duration_ns": int(row.findtext("duration"))})
    return found


def only_interval(intervals, name, minimum_start=0):
    matches = [item for item in intervals if item["name"] == name and item["start_ns"] >= minimum_start]
    if len(matches) != 1:
        raise ValueError(f"Expected one {name} signpost after {minimum_start} ns, got {len(matches)}")
    return matches[0]


def row_by_name(run, name):
    rows = [row for row in run["rows"] if row["name"] == name]
    if len(rows) != 1:
        raise ValueError(f"Expected one application stage {name}")
    return rows[0]


def phase_windows(run, intervals):
    source = only_interval(intervals, "Source editor acknowledgement", 10_000_000_000)
    conversion = only_interval(intervals, "Model conversion", source["start_ns"])
    source_row = row_by_name(run, "source_editor_ack_begin_5MiB")
    conversion_row = row_by_name(run, "model_conversion_begin_reflow_convert_5MiB")
    source_offset = source["start_ns"] - round(source_row["elapsed_ms"] * 1_000_000)
    conversion_offset = conversion["start_ns"] - round(conversion_row["elapsed_ms"] * 1_000_000)
    if abs(source_offset - conversion_offset) > 5_000_000:
        raise ValueError("Application clock and trace signposts did not align within 5 ms")
    offset = (source_offset + conversion_offset) // 2
    layout_row = row_by_name(run, "layout_begin_5_0_vertical")
    layout_start = round(layout_row["elapsed_ms"] * 1_000_000) + offset
    if layout_start < conversion["start_ns"] + conversion["duration_ns"]:
        raise ValueError("Layout began before conversion signpost ended")
    return {
        "source_ack": (source["start_ns"], source["start_ns"] + source["duration_ns"]),
        "conversion_and_publication": (conversion["start_ns"],
                                       conversion["start_ns"] + conversion["duration_ns"]),
        "first_layout": (layout_start, None),
    }, {"source_offset_ns": source_offset, "conversion_offset_ns": conversion_offset,
        "layout_start_trace_ns": layout_start}


def classify(time_ns, windows):
    for name, (start, end) in windows.items():
        if time_ns >= start and (end is None or time_ns < end):
            return name
    return None


def parse_samples(path, windows, pid):
    main_thread_id = None
    frame_names = {}
    stacks = {}
    times = {}
    counts = {name: {"samples": 0, "unresolved_backtraces": 0, "leaf": Counter(),
                     "stack_contains": Counter(), "example_stack": []} for name in windows}
    total_main = 0
    total_rows = 0
    last_time = 0
    with path.open() as input_file:
        for line in input_file:
            if "<row>" not in line:
                continue
            line = line[line.index("<row>"):]
            total_rows += 1
            found_time = TIME_VALUE.search(line)
            referenced_time = TIME_REF.search(line) if found_time is None else None
            found_thread = THREAD.search(line)
            found_backtrace = BACKTRACE.search(line)
            if not ((found_time or referenced_time) and found_thread and found_backtrace):
                raise ValueError("Malformed CPU profile row")
            if found_time:
                time_ns = int(found_time.group(2))
                times[found_time.group(1)] = time_ns
            else:
                time_ns = times.get(referenced_time.group(1))
                if time_ns is None:
                    raise ValueError("Unresolved CPU sample time reference")
            last_time = max(last_time, time_ns)
            if main_thread_id is None and 'fmt="Main Thread' in line:
                main_thread_id = found_thread.group(1)
                if f"pid: {pid}" not in line:
                    raise ValueError("Trace main thread belongs to another process")
            stack_kind, stack_id = found_backtrace.groups()
            if stack_kind == "id":
                symbols = []
                for frame in FRAME.finditer(line):
                    attributes = frame.group(1)
                    name = NAME.search(attributes)
                    identifier = ID.search(attributes)
                    reference = REF.search(attributes)
                    if name:
                        symbol = html.unescape(name.group(1))
                        if identifier:
                            frame_names[identifier.group(1)] = symbol
                    elif reference:
                        symbol = frame_names.get(reference.group(1), "<unresolved frame>")
                    else:
                        symbol = "<unknown frame>"
                    symbols.append(symbol)
                stacks[stack_id] = tuple(symbols)
            else:
                symbols = stacks.get(stack_id, ())
            if found_thread.group(1) != main_thread_id:
                continue
            total_main += 1
            phase = classify(time_ns, windows)
            if phase is None:
                continue
            result = counts[phase]
            result["samples"] += 1
            if not symbols:
                result["unresolved_backtraces"] += 1
                continue
            result["leaf"][symbols[0]] += 1
            if (not result["example_stack"] and len(symbols) >= 12 and
                    any("TCombiningEngine::ResolveCombiningMarks" in symbol for symbol in symbols)):
                result["example_stack"] = list(symbols)
            for label, needle in (("combining_marks", "TCombiningEngine::ResolveCombiningMarks"),
                                  ("text_view_replace", "NSTextView replaceCharactersInRange"),
                                  ("layout_manager", "NSLayoutManager"),
                                  ("workspace_update", "NativeWorkspaceTextEditor.updateNSView"),
                                  ("opencc_engine", "opencc::")):
                if any(needle in symbol for symbol in symbols):
                    result["stack_contains"][label] += 1
    if main_thread_id is None or total_main == 0:
        raise ValueError("No target application main-thread CPU samples")
    return counts, {"cpu_rows": total_rows, "main_thread_samples": total_main,
                    "last_sample_trace_ns": last_time, "stack_definitions": len(stacks),
                    "frame_definitions": len(frame_names)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path,
                        help="Local directory containing manifest, stage JSON, and xctrace XML exports")
    args = parser.parse_args()
    directory = args.run_dir.resolve()
    manifest = json.loads((directory / "manifest.json").read_text())
    run = json.loads((directory / "run.json").read_text())
    if (manifest["mode"] != "workload" or manifest["xctrace_exit_code"] != 0 or
            manifest["pid"] != run["pid"] or not manifest["all_workload_rows_active"] or
            manifest["last_recorded_stage"] != "layout_begin_5_0_vertical"):
        raise ValueError("Wrong or incomplete private paragraph trace")
    intervals = signposts(directory / "signpost-intervals.xml")
    windows, alignment = phase_windows(run, intervals)
    counts, sample_metadata = parse_samples(directory / "cpu-profile.xml", windows, run["pid"])
    summary = {
        "schema": 1, "pid": run["pid"], "source_commit": manifest["source_commit"],
        "trace_bytes": manifest["trace_bytes"],
        "cpu_export_sha256": sha256(directory / "cpu-profile.xml"),
        "signpost_export_sha256": sha256(directory / "signpost-intervals.xml"),
        "app_run_sha256": sha256(directory / "run.json"),
        "windows_trace_ns": windows, "clock_alignment": alignment,
        "signposts": intervals, "sample_metadata": sample_metadata,
        "phases": {name: {"samples": values["samples"],
                          "unresolved_backtraces": values["unresolved_backtraces"],
                          "top_leaf_functions": values["leaf"].most_common(12),
                          "stack_contains": dict(values["stack_contains"]),
                          "example_stack": values["example_stack"]}
                   for name, values in counts.items()},
    }
    (directory / "cpu-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    for name, values in summary["phases"].items():
        print(name, values["samples"], values["stack_contains"], values["top_leaf_functions"][:3])


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify #68 keeper and character-content ablations without treating timeouts as samples."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MIB = 1048576
COMMIT_KEEPER = "049bf626018a7f9ac1a0d7cf9c56e90c9593cd20"
COMMIT_PLAIN = "255eca731cd1b9c19e868f7d16f812dba9a4784d"
COMMIT_CHARACTERS = "bbdde9b36bb4266941f1d12598e03f9d452932bc"
UNITS = {
    "mixed": "汉语转换，软件与网络。繁體中文👨‍👩‍👧‍👦e\u0301",
    "plain": "汉语转换，软件与网络。繁體中文",
    "emoji": "汉语转换，软件与网络。繁體中文👨‍👩‍👧‍👦",
    "combining": "汉语转换，软件与网络。繁體中文e\u0301",
}
VARIANTS = {
    "keeper-baseline": (COMMIT_KEEPER, "single-paragraph", "mixed", "timeout"),
    "keeper-ablated": (COMMIT_KEEPER, "single-paragraph", "mixed", "timeout"),
    "content-mixed": (COMMIT_PLAIN, "single-paragraph", "mixed", "timeout"),
    "content-plain": (COMMIT_PLAIN, "plain-paragraph", "plain", "complete"),
    "content-emoji": (COMMIT_CHARACTERS, "emoji-paragraph", "emoji", "complete"),
    "content-combining": (COMMIT_CHARACTERS, "combining-paragraph", "combining", "timeout"),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(run, name):
    return next((row for row in run["rows"] if row["name"] == name), None)


def fixture(profile):
    unit = UNITS[profile]
    bytes_per_unit = len(unit.encode())
    count, remainder = divmod(5 * MIB, bytes_per_unit)
    contents = (unit * count + "a" * remainder).encode()
    require(len(contents) == 5 * MIB and b"\r" not in contents and b"\n" not in contents,
            f"{profile}: wrong fixture size or paragraph structure")
    return hashlib.sha256(contents).hexdigest(), count


def main():
    manifest = json.loads((ROOT / "checksums.json").read_text())
    actual = {str(path.relative_to(ROOT)): sha256(path)
              for path in sorted((ROOT / "raw").rglob("*")) if path.is_file()}
    require(manifest == {"algorithm": "SHA-256", "files": actual} and len(actual) == 23,
            "raw checksums")
    excluded = ROOT / "raw/content-combining-excluded"
    excluded_run = json.loads((excluded / "run-01.json").read_text())
    require(excluded_run["status"] == "timeout" and
            any(not row["app_active"] for row in excluded_run["rows"]
                if row["name"] != "process_initialized"),
            "the interrupted combining run must remain excluded")
    data = {}
    for name, (commit, input_profile, fixture_profile, outcome) in VARIANTS.items():
        folder = ROOT / "raw" / name
        metadata_path = folder / "metadata.json"
        metadata = json.loads(metadata_path.read_text())
        build = json.loads((folder / "build-complete.json").read_text())
        run_name = "run-02.json" if name == "content-combining" else "run-01.json"
        run = json.loads((folder / run_name).read_text())
        require(build["metadata_sha256"] == sha256(metadata_path), f"{name}: metadata hash")
        require(metadata["source_commit"] == metadata["measurement_harness_commit"] == commit and
                not metadata["source_status"], f"{name}: source provenance")
        conditions = metadata["conditions"]
        require(conditions["suite"] == "reflow" and conditions["input_profile"] == input_profile and
                conditions["reflow_max_mib"] == 5 and
                conditions["navigation_target"].startswith("middle composed character"),
                f"{name}: protocol")
        require(run["metadata_sha256"] == sha256(metadata_path) and run["status"] == outcome,
                f"{name}: run status")
        if outcome == "timeout":
            require(run["timeout_seconds"] == 180 and
                    run["last_recorded_stage"] == run["rows"][-1]["name"] == "layout_begin_5_0_vertical",
                    f"{name}: timeout boundary")
        else:
            require(len(run["rows"]) == 72 and
                    run["rows"][-1]["name"].startswith("layout_end_5_") and
                    run["rows"][-1]["name"].endswith("_horizontal") and
                    len([row for row in run["rows"] if row["name"].startswith("scroll_end_5_")]) == 3,
                    f"{name}: full 5 MiB reflow missing")
        require(all(row["app_active"] for row in run["rows"] if row["name"] != "process_initialized"),
                f"{name}: app lost foreground")
        require(len([row for row in run["rows"] if row["name"].startswith("layout_end_1_") and
                     row["name"].endswith("_horizontal")]) == 3,
                f"{name}: 1 MiB reflow incomplete")
        require(stage(run, "layout_end_1_0_vertical")["textkit2"] is False,
                f"{name}: unexpected text system")
        converted = stage(run, "reflow_convert_5MiB")
        expected_hash, unit_count = fixture(fixture_profile)
        require(converted is not None and converted["input_bytes"] == 5 * MIB and
                converted["input_sha256"] == expected_hash and converted["editors_match_model"] and
                converted["export_matches_result"], f"{name}: fixture or conversion mismatch")
        require(stage(run, "source_editor_ack_end_5MiB") is not None and
                stage(run, "model_conversion_end_reflow_convert_5MiB") is not None,
                f"{name}: missing phase records")
        data[name] = (metadata, run, unit_count)

    combining_meta, combining_run, _ = data["content-combining"]
    require(json.loads((excluded / "metadata.json").read_text()) == combining_meta and
            excluded_run["metadata_sha256"] == combining_run["metadata_sha256"] and
            excluded_run["pid"] != combining_run["pid"],
            "the valid combining run must reuse the same verified build in a new process")

    for left, right, allowed_source_differences in (
        ("keeper-baseline", "keeper-ablated", {"OpenCCman/View/WorkspaceTextEditor.swift"}),
        ("content-mixed", "content-plain", set()),
        ("content-emoji", "content-combining", set()),
    ):
        a_meta, a_run, _ = data[left]
        b_meta, b_run, _ = data[right]
        for key in ("source_commit", "pins", "resolved_checkout_revisions", "hardware", "os", "xcode"):
            require(a_meta[key] == b_meta[key], f"{left}/{right}: unmatched {key}")
        differences = {key for key in set(a_meta["source_hashes"]) | set(b_meta["source_hashes"])
                       if a_meta["source_hashes"].get(key) != b_meta["source_hashes"].get(key)}
        require(differences == allowed_source_differences,
                f"{left}/{right}: unexpected source differences {differences}")
        if left == "keeper-baseline":
            require(a_meta["conditions"] == b_meta["conditions"] and
                    stage(a_run, "reflow_convert_5MiB")["input_sha256"] ==
                    stage(b_run, "reflow_convert_5MiB")["input_sha256"] and
                    stage(a_run, "reflow_convert_5MiB")["output_sha256"] ==
                    stage(b_run, "reflow_convert_5MiB")["output_sha256"],
                    "keeper ablation changed the input or output")

    for sample_name in ("result-publication.sample.txt", "layout.sample.txt"):
        sample = (ROOT / "raw/keeper-ablated" / sample_name).read_text()
        pid = data["keeper-ablated"][1]["pid"]
        require(f"OpenCCman (pid {pid})" in sample and
                "org.gewill.OpenCCman.PerformanceAudit" in sample and
                "TCombiningEngine::ResolveCombiningMarks" in sample and
                "NSLayoutManager" in sample and "NSTextView" in sample,
                f"{sample_name}: wrong process or missing stack")

    print("| 5 MiB single paragraph, one new process per variant | Source editor ack | Model continuation return | Final status |")
    print("| --- | ---: | ---: | --- |")
    for name in VARIANTS:
        _, run, count = data[name]
        source_seconds = stage(run, "source_editor_ack_end_5MiB")["action_ms"] / 1000
        model_seconds = stage(run, "model_conversion_end_reflow_convert_5MiB")["action_ms"] / 1000
        print(f"| {name} ({count:,} units) | {source_seconds:.3f} s | {model_seconds:.3f} s | {run['status']} |")
    print("PASS: six runs, paired provenance, exact-byte fixtures, and two matching stack samples")


if __name__ == "__main__":
    main()

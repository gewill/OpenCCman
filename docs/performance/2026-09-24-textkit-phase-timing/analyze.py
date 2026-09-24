#!/usr/bin/env python3
"""Verify the bounded #68 single-paragraph source/result phase records."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VARIANTS = {
    "source-only-tk1": ("1f64600df06efab5c5097ba4eec506586f296509", "layout_begin_5_0_vertical"),
    "source-only-tk2": ("1f64600df06efab5c5097ba4eec506586f296509", "layout_begin_5_0_horizontal"),
    "source-and-result-tk1": ("3baa36c53d8fe3eb577d920046a71e5f778defb2", "layout_begin_5_0_vertical"),
    "source-and-result-tk2": ("3baa36c53d8fe3eb577d920046a71e5f778defb2", "layout_begin_5_0_horizontal"),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(run, name):
    return next((row for row in run["rows"] if row["name"] == name), None)


def main():
    manifest = json.loads((ROOT / "checksums.json").read_text())
    actual = {str(path.relative_to(ROOT)): sha256(path)
              for path in sorted((ROOT / "raw").rglob("*")) if path.is_file()}
    require(manifest == {"algorithm": "SHA-256", "files": actual}, "raw checksums")
    require(len(actual) == 12, "raw file count")

    data = {}
    for name, (commit, last_stage) in VARIANTS.items():
        folder = ROOT / "raw" / name
        metadata_path = folder / "metadata.json"
        metadata = json.loads(metadata_path.read_text())
        build = json.loads((folder / "build-complete.json").read_text())
        run = json.loads((folder / "run-01.json").read_text())
        require(build["metadata_sha256"] == sha256(metadata_path), f"{name}: metadata hash")
        require(metadata["source_commit"] == metadata["measurement_harness_commit"] == commit,
                f"{name}: source commit")
        require(not metadata["source_status"], f"{name}: dirty source")
        conditions = metadata["conditions"]
        require(conditions["suite"] == "reflow" and conditions["input_profile"] == "single-paragraph"
                and conditions["reflow_max_mib"] == 5 and
                conditions["navigation_target"].startswith("middle composed character"),
                f"{name}: protocol")
        require(run["status"] == "timeout" and run["timeout_seconds"] == 180 and
                run["metadata_sha256"] == sha256(metadata_path) and
                run["last_recorded_stage"] == run["rows"][-1]["name"] == last_stage,
                f"{name}: bounded timeout")
        require(all(row["app_active"] for row in run["rows"] if row["name"] != "process_initialized"),
                f"{name}: lost foreground activity")
        require(stage(run, "layout_end_1_402194_horizontal") is not None,
                f"{name}: 1 MiB reflow did not complete")
        require(stage(run, "layout_end_1_0_vertical")["textkit2"] == name.endswith("tk2") and
                stage(run, "layout_end_1_0_vertical")["result_textkit2"] == name.endswith("tk2"),
                f"{name}: wrong text system")
        require(stage(run, "source_fixture_end_5MiB")["input_bytes"] == 5 * 1048576,
                f"{name}: incorrect 5 MiB fixture")
        for phase in ("source_fixture", "source_replace", "source_editor_ack",
                      "source_exact_validation"):
            begin = stage(run, f"{phase}_begin_5MiB")
            end = stage(run, f"{phase}_end_5MiB")
            require(begin is not None and end is not None and
                    begin["elapsed_ms"] <= end["elapsed_ms"] and end["action_ms"] >= 0,
                    f"{name}: invalid source phase {phase}")
        converted = stage(run, "reflow_convert_5MiB")
        require(converted is not None and converted["input_bytes"] == 5 * 1048576 and
                converted["editors_match_model"] and converted["export_matches_result"],
                f"{name}: incomplete 5 MiB conversion")
        if name.startswith("source-and-result"):
            for phase in ("model_conversion", "result_editor_ack",
                          "result_exact_validation", "result_digest"):
                begin = stage(run, f"{phase}_begin_reflow_convert_5MiB")
                end = stage(run, f"{phase}_end_reflow_convert_5MiB")
                require(begin is not None and end is not None and
                        begin["elapsed_ms"] <= end["elapsed_ms"] and end["action_ms"] >= 0,
                        f"{name}: invalid result phase {phase}")
            require(converted["model_completion_ms"] <=
                    stage(run, "model_conversion_end_reflow_convert_5MiB")["action_ms"],
                    f"{name}: completion signal after continuation return")
        data[name] = (metadata, run)

    for phase in ("source-only", "source-and-result"):
        a_meta, a_run = data[f"{phase}-tk1"]
        b_meta, b_run = data[f"{phase}-tk2"]
        for key in ("source_commit", "conditions", "pins", "resolved_checkout_revisions",
                    "hardware", "os", "xcode"):
            require(a_meta[key] == b_meta[key], f"{phase}: unmatched {key}")
        differences = {key for key in set(a_meta["source_hashes"]) | set(b_meta["source_hashes"])
                       if a_meta["source_hashes"].get(key) != b_meta["source_hashes"].get(key)}
        require(differences == {
            "OpenCCman/View/WorkspaceScrollKeeper.swift",
            "OpenCCman/View/WorkspaceTextEditor.swift",
        }, f"{phase}: unexpected source differences {differences}")
        for key in ("input_sha256", "output_sha256"):
            require(stage(a_run, "reflow_convert_5MiB")[key] ==
                    stage(b_run, "reflow_convert_5MiB")[key], f"{phase}: different {key}")
    for kit in ("tk1", "tk2"):
        for key in ("input_sha256", "output_sha256"):
            require(stage(data[f"source-only-{kit}"][1], "reflow_convert_5MiB")[key] ==
                    stage(data[f"source-and-result-{kit}"][1], "reflow_convert_5MiB")[key],
                    f"{kit}: different {key} between instruments")

    print("| Single 5 MiB attempt per variant | TextKit 1 | TextKit 2 private candidate |")
    print("| --- | ---: | ---: |")
    for phase, label, suffix, field in (
        ("source-only", "Source editor acknowledgement, first instrument", "source_editor_ack_end_5MiB", "action_ms"),
        ("source-and-result", "Source editor acknowledgement, second instrument", "source_editor_ack_end_5MiB", "action_ms"),
        ("source-and-result", "Model completion signal", "reflow_convert_5MiB", "model_completion_ms"),
        ("source-and-result", "Model continuation return", "model_conversion_end_reflow_convert_5MiB", "action_ms"),
        ("source-and-result", "Result editor acknowledgement", "result_editor_ack_end_reflow_convert_5MiB", "action_ms"),
        ("source-and-result", "Result exact validation", "result_exact_validation_end_reflow_convert_5MiB", "action_ms"),
    ):
        values = [stage(data[f"{phase}-{kit}"][1], suffix)[field] / 1000 for kit in ("tk1", "tk2")]
        print(f"| {label} | {values[0]:.3f} s | {values[1]:.3f} s |")
    print("PASS: four bounded runs, source/build/fixture parity, and phase records")


if __name__ == "__main__":
    main()

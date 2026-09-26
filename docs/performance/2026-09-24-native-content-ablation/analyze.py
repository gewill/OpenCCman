#!/usr/bin/env python3
"""Verify app-matched native TextKit paragraph runs and excluded launch probes."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
APP = REPO / "docs/performance/2026-09-24-textkit-content-ablation/raw"
SOURCE_COMMIT = "3c0618214372c313214e4e7d72694c288688dcf3"
PROFILES = ("plain", "emoji", "combining", "mixed")
MIB = 1048576
PREFIX = "汉语转换，软件与网络。繁體中文"
UNITS = {
    "plain": PREFIX,
    "emoji": PREFIX + "👨‍👩‍👧‍👦",
    "combining": PREFIX + "e\u0301",
    "mixed": PREFIX + "👨‍👩‍👧‍👦e\u0301",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def app_run(profile):
    run_name = "run-02.json" if profile == "combining" else "run-01.json"
    return read(APP / f"content-{profile}" / run_name)


def fixture(profile, mib):
    unit = UNITS[profile].encode("utf-8")
    count, remainder = divmod(mib * MIB, len(unit))
    encoded = unit * count + b"a" * remainder
    require(len(encoded) == mib * MIB and b"\r" not in encoded and b"\n" not in encoded,
            f"{profile}/{mib}: fixture shape")
    return hashlib.sha256(encoded).hexdigest(), len(encoded.decode("utf-8").encode("utf-16-le")) // 2


def validate_run(run, mode, mib, metadata_hash, expected_utf16):
    require(run["status"] == "complete" and run["mode"] == mode and
            run["metadata_sha256"] == metadata_hash and
            run["source_utf8_bytes"] == mib * MIB and
            run["source_utf16"] == expected_utf16 and
            run["window_content_points"] == [1200, 800],
            f"{mode}/{mib}: run identity or input")
    names = [row["name"] for row in run["rows"]]
    require(names == ["empty_ready", "first_display", "scroll_start", "scroll_middle", "scroll_end"],
            f"{mode}/{mib}: incomplete stages")
    for row in run["rows"]:
        require(row["app_active"] and row["visible"] and not row["fallback_events"] and
                row["textkit2"] == (mode == "tk2") and
                row["editor_utf16"] == (0 if row["name"] == "empty_ready" else expected_utf16) and
                row["rss_bytes"] > 0 and row["physical_footprint_bytes"] > 0,
                f"{mode}/{mib}: foreground, text-system, editor or memory check")
        if row["name"].startswith("scroll"):
            require(row["target_visible"] and row["scroll_attempts"] >= 1,
                    f"{mode}/{mib}: target not visible")
    return {row["name"]: row for row in run["rows"]}


def main():
    manifest = read(ROOT / "checksums.json")
    actual = {str(path.relative_to(ROOT)): digest(path)
              for path in sorted((ROOT / "raw").rglob("*")) if path.is_file()}
    require(manifest == {"algorithm": "SHA-256", "files": actual} and len(actual) == 31,
            "raw archive checksums")

    for label in ("direct", "finish-launching", "regular-binary"):
        folder = ROOT / "raw/excluded-launch-probes" / label
        run = read(folder / "tk1-app-plain-1MiB-01.json")
        failure = read(folder / "tk1-app-plain-1MiB-01.json.incomplete.json")
        require(run["status"] == "complete" and
                all(row["app_active"] is False for row in run["rows"]) and
                failure["reason"] == "failed" and
                failure["detail"] == "Native benchmark lost foreground focus",
                f"{label}: a launch probe was included as valid data")

    common = None
    results = {}
    for profile in PROFILES:
        folder = ROOT / "raw" / profile
        metadata_path = folder / "metadata.json"
        metadata = read(metadata_path)
        require(metadata["source_commit"].startswith(SOURCE_COMMIT) and
                metadata["source_status"] == "" and metadata["pattern"] == "app-" + profile and
                metadata["samples"] == 1 and metadata["modes"] == ["tk1", "tk2"] and
                metadata["target"] == "arm64-apple-macos12.0" and
                metadata["window_content_points"] == [1200, 800] and
                metadata["signature"].startswith("ad hoc, verified") and
                metadata["limit_seconds_per_process"] == 180 and
                not metadata["width_switch"],
                f"{profile}: metadata protocol")
        machine = tuple(metadata[key] for key in ("source_commit", "source_sha256", "driver_sha256",
                                                    "macos", "macos_build", "xcode", "arch"))
        if common is None:
            common = machine
        require(machine == common, f"{profile}: machine or source drift")
        app = app_run(profile)
        converted = next(row for row in app["rows"] if row["name"] == "reflow_convert_5MiB")
        require(converted["input_bytes"] == 5 * MIB and
                metadata["fixture_sha256"]["5"] == converted["input_sha256"],
                f"{profile}: input bytes differ from the application experiment")
        require(metadata["sizes_mib"] == ([1, 5] if profile == "combining" else [5]),
                f"{profile}: unrecorded size")
        for mib in metadata["sizes_mib"]:
            fixture_hash, expected_length = fixture(profile, mib)
            require(metadata["fixture_sha256"][str(mib)] == fixture_hash,
                    f"{profile}/{mib}: generated input mismatch")
            for mode in ("tk1", "tk2"):
                run = read(folder / f"{mode}-app-{profile}-{mib}MiB-01.json")
                rows = validate_run(run, mode, mib, digest(metadata_path), expected_length)
                results[(profile, mib, mode)] = rows
        summary = read(folder / "summary.json")
        require(not summary["incomplete"] and
                all(item["complete_samples"] == item["expected_samples"] == 1
                    for item in summary["complete"].values()) and
                len(summary["complete"]) == 2 * len(metadata["sizes_mib"]),
                f"{profile}: summary mismatch")

    print("| 5 MiB input | Text system | First display | Midpoint scroll | End RSS |")
    print("| --- | --- | ---: | ---: | ---: |")
    for profile in PROFILES:
        for mode in ("tk1", "tk2"):
            rows = results[(profile, 5, mode)]
            first = rows["first_display"]
            middle = rows["scroll_middle"]
            print(f"| {profile} | {mode} | {first['action_ms'] / 1000:.3f} s | "
                  f"{middle['action_ms'] / 1000:.3f} s | "
                  f"{rows['scroll_end']['rss_bytes'] / MIB:.1f} MiB |")
    print("PASS: eight 5 MiB native runs, two 1 MiB controls, exact application fixture hashes, "
          "and three excluded background launch probes")


if __name__ == "__main__":
    main()

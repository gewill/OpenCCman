#!/usr/bin/env python3
"""Validate the archived Services samples without launching an app."""

import hashlib
import json
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parent


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    context = json.loads((ROOT / "context.json").read_text())
    fixtures = json.loads((ROOT / "fixture-manifest.json").read_text())
    summary = json.loads((ROOT / "summary.json").read_text())
    assert context["fixtures"]["fixtureManifestSHA256"] == digest(ROOT / "fixture-manifest.json")
    expected = {(case["shape"], case["inputBytes"]): case for case in fixtures["cases"]
                if case["mode"] == "s2t"}
    assert len(expected) == 8
    assert set(summary) == {
        "continuous-short-1024", "continuous-short-1048576",
        "continuous-short-5242880", "continuous-short-10485760",
        "paced-short-10MiB", "paced-long-10MiB",
    }

    sample_count = 0
    for name, item in summary.items():
        shape = "long-paragraphs" if name == "paced-long-10MiB" else "short-paragraphs"
        case = expected[(shape, item["inputBytes"])]
        assert item["inputSHA256"] == case["inputSHA256"]
        assert item["expectedSHA256"] == case["expectedSHA256"]
        assert item["expectedBytes"] == case["expectedBytes"]
        times = []
        for relpath in item["files"]:
            path = (ROOT / relpath).resolve()
            assert path.is_relative_to(ROOT / "final")
            events = [json.loads(line) for line in path.read_text().splitlines()]
            assert events[0]["event"] == "metadata"
            assert events[-1]["event"] == "run_completed"
            meta = events[0]
            assert meta["service_name"] == context["qa"]["convertService"]
            assert meta["input_bytes"] == case["inputBytes"]
            assert meta["input_sha256"] == case["inputSHA256"]
            assert meta["expected_bytes"] == case["expectedBytes"]
            assert meta["expected_sha256"] == case["expectedSHA256"]
            samples = [event for event in events if event["event"] == "sample_completed"]
            assert len(samples) == meta["samples_requested"] == events[-1]["samples"]
            assert [event["sample"] for event in samples] == list(range(1, len(samples) + 1))
            assert all(event["service_succeeded"] and event["output_matches_expected"]
                       and event["output_bytes"] == case["expectedBytes"]
                       and event["output_sha256"] == case["expectedSHA256"] for event in samples)
            times.extend(event["service_call_ms"] for event in samples)
        assert len(times) == item["samples"] == 5
        assert times == item["serviceCallMilliseconds"]
        assert median(times) == item["medianMilliseconds"]
        assert min(times) == item["minMilliseconds"]
        assert max(times) == item["maxMilliseconds"]
        sample_count += len(times)

    priming = [json.loads(line) for line in (ROOT / "final/priming.jsonl").read_text().splitlines()]
    assert priming[-1]["event"] == "run_completed"
    assert priming[-1]["samples"] == 1
    assert priming[-2]["output_matches_expected"]
    assert len(list((ROOT / "final").glob("*.jsonl"))) == 15
    print(f"PASS: {sample_count} final samples plus one priming call; all outputs match pinned fixtures")


if __name__ == "__main__":
    main()

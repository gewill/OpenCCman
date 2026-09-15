"""Reject missing or misleading lifecycle evidence; retention is an outcome."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("window_lifetime", ROOT / "scripts/diagnose-window-lifetime.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class WindowLifetimeEvidenceTests(unittest.TestCase):
    def setUp(self):
        fixture = ROOT / "docs/performance/window-environment-lifetime/2026-09-15/ax-control/one-ax/raw.jsonl"
        self.rows = [json.loads(line) for line in fixture.read_text().splitlines()]

    def test_retention_is_reported_not_mistaken_for_protocol_failure(self):
        result = MODULE.validate(self.rows)
        self.assertEqual(result["driver_final_plus_20"]["alive"], 2)

    def test_missing_final_observation_is_not_success(self):
        rows = [row for row in self.rows if row["event"] != "driver_final_plus_20"]
        with self.assertRaises(ValueError):
            MODULE.validate(rows)

    def test_reopened_window_invalidates_zero_window_observation(self):
        rows = copy.deepcopy(self.rows)
        next(row for row in rows if row["event"] == "driver_final_plus_20")["visible"] = 1
        with self.assertRaises(ValueError):
            MODULE.validate(rows)

    def test_early_sample_cannot_claim_twenty_seconds(self):
        rows = copy.deepcopy(self.rows)
        start = next(row for row in rows if row["event"] == "driver_final_closed")["elapsed"]
        next(row for row in rows if row["event"] == "driver_final_plus_20")["elapsed"] = start + 19
        with self.assertRaises(ValueError):
            MODULE.validate(rows)

    def test_failed_driver_cannot_be_hidden_by_complete_samples(self):
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows + [{"event": "driver_failed:timeout"}])


class WeakHostEvidenceTests(unittest.TestCase):
    def setUp(self):
        WindowLifetimeEvidenceTests.setUp(self)
        seen = 0
        for row in self.rows:
            seen = max(seen, row["visible"])
            row["hosts"] = [dict(id=i, windowAlive=i <= row["visible"],
                                 windowVisible=i <= row["visible"],
                                 initialContentAlive=True, initialContentType="FixtureHostingView")
                            for i in range(1, seen + 1)]

    def test_closed_window_and_retained_content_are_distinct_outcomes(self):
        result = MODULE.validate(self.rows, require_hosts=True)
        host = result["driver_final_plus_20"]["hosts"][1]
        self.assertFalse(host["windowAlive"])
        self.assertTrue(host["initialContentAlive"])

    def test_missing_host_data_cannot_pass_required_observation(self):
        del self.rows[-1]["hosts"]
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows, require_hosts=True)

    def test_missing_closed_host_identity_is_rejected(self):
        self.rows[-1]["hosts"].pop()
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows, require_hosts=True)

    def test_dead_weak_window_cannot_reappear(self):
        self.rows[-1]["hosts"][1]["windowAlive"] = True
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows, require_hosts=True)

    def test_visible_host_must_match_actual_window_count(self):
        row = next(r for r in self.rows if r["event"] == "driver_pair_visible")
        row["hosts"][1]["windowVisible"] = False
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows, require_hosts=True)

    def test_numeric_booleans_are_not_valid_weak_state(self):
        self.rows[-1]["hosts"][1]["windowAlive"] = 0
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows, require_hosts=True)

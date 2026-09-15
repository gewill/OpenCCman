import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("byte_scan", ROOT / "scripts/benchmark-byte-scan.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
CAPTURE = ROOT / "docs/performance/2026-09-15-byte-scan/run-2/samples.jsonl"


class ByteScanReportChecks(unittest.TestCase):
    def setUp(self):
        self.records = [json.loads(line) for line in CAPTURE.read_text().splitlines()]

    def summarize(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "samples.jsonl"
            path.write_text("\n".join(json.dumps(r) for r in self.records))
            return MODULE.summarize(path)

    def sample(self):
        return next(r for r in self.records if r["event"] == "sample")

    def test_real_capture_reproduces_recorded_medians(self):
        rows = self.summarize()
        self.assertEqual(len(rows), 28)
        row = next(r for r in rows if (r["mode"], r["representation"], r["inputBytes"]) == ("s2t", "pasteboard", 10485760))
        self.assertEqual(row["baseline"]["medianMS"], 369.664333)
        self.assertEqual(row["current"]["medianMS"], 224.992042)

    def test_incomplete_process_is_not_a_result(self):
        self.records.pop()
        with self.assertRaises(ValueError):
            self.summarize()

    def test_output_mismatch_is_not_a_timing_sample(self):
        self.sample()["outputMatchesExpected"] = False
        with self.assertRaises(ValueError):
            self.summarize()

    def test_wrong_hash_is_rejected_even_with_success_flag(self):
        self.sample()["outputSHA256"] = "0" * 64
        with self.assertRaises(ValueError):
            self.summarize()

    def test_duplicate_pair_cannot_replace_a_missing_pair(self):
        self.sample()["pair"] = 3
        with self.assertRaises(ValueError):
            self.summarize()

    def test_altered_execution_order_is_rejected(self):
        self.sample()["position"] = 1
        with self.assertRaises(ValueError):
            self.summarize()

    def test_nonfinite_zero_and_negative_times_are_rejected(self):
        for elapsed in (float("nan"), float("inf"), 0, -1, True):
            with self.subTest(elapsed=elapsed):
                self.sample()["elapsedMS"] = elapsed
                with self.assertRaises(ValueError):
                    self.summarize()

    def test_duplicate_case_is_rejected(self):
        self.records.insert(1, copy.deepcopy(next(r for r in self.records if r["event"] == "case")))
        with self.assertRaises(ValueError):
            self.summarize()


if __name__ == "__main__":
    unittest.main()

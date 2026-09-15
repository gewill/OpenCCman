"""Exercise rejection of mixed-process or incomplete real-model evidence."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('native_lifecycle', ROOT / 'scripts/check-native-window-lifecycle.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NativeLifecycleEvidenceTests(unittest.TestCase):
    def setUp(self):
        # Schema-transformed fixture, not evidence of an actual OpenCCman run.
        path = ROOT / 'docs/performance/window-environment-lifetime/2026-09-15/ax-control/one-ax/raw.jsonl'
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        self.rows = [{
            'event': row['event'], 'pid': 123, 'elapsed_ms': row['elapsed'] * 1000,
            'created_total': row['created'],
            'live_model_numbers': list(range(1, row['alive'] + 1)),
            'visible_main_capable_windows': row['visible'],
        } for row in rows]

    def test_retained_models_are_an_outcome(self):
        result = MODULE.validate(self.rows)
        self.assertEqual(result['driver_final_plus_20']['live_model_numbers'], [1, 2])

    def test_mixed_process_logs_are_rejected(self):
        self.rows[-1]['pid'] = 124
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows)

    def test_duplicate_model_identity_is_rejected(self):
        self.rows[-1]['live_model_numbers'] = [1, 1]
        with self.assertRaises(ValueError):
            MODULE.validate(self.rows)

    def test_missing_final_observation_is_rejected(self):
        rows = [row for row in self.rows if row['event'] != 'driver_final_plus_20']
        with self.assertRaises(ValueError):
            MODULE.validate(rows)

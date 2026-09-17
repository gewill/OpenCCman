"""Exercise rejection of mixed-process or incomplete real-model evidence."""
import importlib.util
import json
from pathlib import Path
import unittest
import subprocess
import sys
import tempfile

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


class ModelReleaseGateTests(unittest.TestCase):
    setUp = NativeLifecycleEvidenceTests.setUp

    def released_rows(self):
        rows = [dict(row) for row in self.rows]
        for row in rows:
            if row['event'].endswith('_plus_20'):
                row['live_model_numbers'] = [1] if row['visible_main_capable_windows'] else []
        return rows

    def test_retention_passes_protocol_but_fails_release_gate(self):
        MODULE.validate(self.rows)
        with self.assertRaisesRegex(ValueError, 'Model release failed'):
            MODULE.verify_model_release(self.rows)

    def test_released_objects_pass(self):
        rows = self.released_rows()
        MODULE.validate(rows)
        result = MODULE.verify_model_release(rows)
        self.assertEqual(result['driver_second_plus_20'], [1])
        self.assertEqual(result['driver_final_plus_20'], [])

    def test_wrong_survivor_with_same_count_fails(self):
        rows = self.released_rows()
        for row in rows:
            if row['event'] == 'driver_second_plus_20':
                row['live_model_numbers'] = [2]
        MODULE.validate(rows)
        with self.assertRaisesRegex(ValueError, 'driver_second_plus_20'):
            MODULE.verify_model_release(rows)

    def test_retained_anchor_after_final_close_fails(self):
        rows = self.released_rows()
        for row in rows:
            if row['event'] == 'driver_final_plus_20':
                row['live_model_numbers'] = [1]
        with self.assertRaisesRegex(ValueError, 'driver_final_plus_20'):
            MODULE.verify_model_release(rows)

    def test_cli_returns_failure_without_losing_valid_protocol_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            raw = directory / 'raw.jsonl'
            raw.write_text(''.join(json.dumps(row) + '\n' for row in self.rows))
            report = directory / 'report'
            result = subprocess.run([
                sys.executable, str(ROOT / 'scripts/check-native-window-lifecycle.py'),
                '--raw', str(raw), '--require-model-release', '--output', str(report),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 4, result.stderr)
            evidence = json.loads((report / 'result.json').read_text())
            self.assertTrue(evidence['valid_protocol'])
            self.assertFalse(evidence['model_release_passed'])
            self.assertEqual((report / 'raw.jsonl').read_bytes(), raw.read_bytes())

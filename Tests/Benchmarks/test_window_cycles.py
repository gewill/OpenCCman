"""Synthetic protocol failure cases; these are not native-run evidence."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('cycle_check', ROOT / 'scripts/check-native-window-lifecycle.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class WindowCycleTests(unittest.TestCase):
    def setUp(self):
        self.rows = []
        def row(event, time, created, visible):
            self.rows.append(dict(event=event, elapsed_ms=time, created_total=created,
                                  pid=42, visible_main_capable_windows=visible,
                                  live_model_numbers=list(range(1, created + 1)),
                                  anchor_fingerprint='a' * 64, quota={},
                                  content_sizes=[dict(number=i, source_bytes=0, result_bytes=0)
                                                 for i in range(2, created + 1)]))
        row('cycles_started', 0, 1, 1)
        row('cycles_anchor_ready', 10000, 1, 1)
        time = 10100
        for cycle in range(1, 4):
            count = 1 + 2 * cycle
            row(f'cycle_{cycle}_ready', time, count, 3)
            row(f'cycle_{cycle}_before_close', time + 10000, count, 3)
            row(f'cycle_{cycle}_closed', time + 10100, count, 1)
            row(f'cycle_{cycle}_plus_5', time + 15100, count, 1)
            row(f'cycle_{cycle}_plus_20', time + 30100, count, 1)
            time += 30200
        row('cycles_final_closed', time, 7, 0)
        row('cycles_final_plus_5', time + 5000, 7, 0)
        row('cycles_final_plus_20', time + 20000, 7, 0)
        row('cycles_finished', time + 20100, 7, 0)

    def test_retention_is_an_outcome_not_hidden(self):
        result = MODULE.validate(self.rows, cycles=True)
        self.assertEqual(result['cycles_final_plus_20']['live_model_numbers'], list(range(1, 8)))

    def test_incomplete_third_cycle_is_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.validate([r for r in self.rows if r['event'] != 'cycle_3_plus_20'], cycles=True)

    def test_changed_anchor_is_rejected(self):
        self.rows[8]['anchor_fingerprint'] = 'b' * 64
        with self.assertRaises(ValueError): MODULE.validate(self.rows, cycles=True)

    def test_unintended_charge_is_rejected(self):
        self.rows[8]['quota'] = {'2026-09-16': 1}
        with self.assertRaises(ValueError): MODULE.validate(self.rows, cycles=True)

    def test_early_final_sample_is_rejected(self):
        self.rows[-2]['elapsed_ms'] -= 1
        with self.assertRaises(ValueError): MODULE.validate(self.rows, cycles=True)

    def test_uncleared_new_window_is_rejected(self):
        self.rows[2]['content_sizes'][0]['source_bytes'] = 3
        with self.assertRaises(ValueError): MODULE.validate(self.rows, cycles=True)

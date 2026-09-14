"""Reject incomparable or incomplete measurements before reporting percentages."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('compare', Path(__file__).resolve().parents[2] / 'scripts/compare-app-performance.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class Reports(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.before = Path(self.temp.name) / 'before'
        self.after = Path(self.temp.name) / 'after'
        self.metadata = {'hardware': 'fixed', 'os': 'fixed', 'xcode': 'fixed', 'conditions': ['fixed'],
                         'pins': {'pins': [{'identity': 'other', 'state': {'revision': 'same'}}]},
                         'source_hashes': {'Tests/Benchmarks/AppPerformanceAudit.swift': 'same'}}
        self.run = {'status': 'complete', 'rows': [
            {'name': f'configuration_{flag}', 'options': flag, 'model_completion_ms': 10.0,
             'input_sha256': 'input', 'output_sha256': 'output', 'export_matches_result': True,
             'memory': {'rss_bytes': 100, 'physical_footprint_bytes': 100, 'process_peak_rss_bytes': 100,
                        'task_info_status': 0, 'rusage_status': 0}}
            for flag in (2, 1, 1025, 33, 1057, 65, 1089)]}
        self.write(self.before)
        self.write(self.after)

    def write(self, directory, metadata=None, run=None):
        directory.mkdir(exist_ok=True)
        (directory / 'metadata.json').write_text(json.dumps(metadata or self.metadata))
        for n in range(3):
            (directory / f'run-{n}.json').write_text(json.dumps(run or self.run))

    def test_equal_samples_have_no_regression(self):
        result = MODULE.compare(self.before, self.after)
        self.assertFalse(result['stages'][0]['metrics']['model_completion_ms']['review'])

    def test_rejects_unrelated_dependency_drift(self):
        changed = copy.deepcopy(self.metadata)
        changed['pins']['pins'][0]['state']['revision'] = 'changed'
        self.write(self.after, metadata=changed)
        with self.assertRaisesRegex(ValueError, 'dependency drift'):
            MODULE.compare(self.before, self.after)

    def test_rejects_incomplete_coverage(self):
        changed = copy.deepcopy(self.run)
        changed['rows'].pop()
        self.write(self.after, run=changed)
        with self.assertRaisesRegex(ValueError, 'configuration coverage'):
            MODULE.compare(self.before, self.after)

    def test_rejects_different_input(self):
        changed = copy.deepcopy(self.run)
        changed['rows'][0]['input_sha256'] = 'different'
        self.write(self.after, run=changed)
        with self.assertRaisesRegex(ValueError, 'Input corpus differs'):
            MODULE.compare(self.before, self.after)

    def test_changed_output_is_explicit(self):
        changed = copy.deepcopy(self.run)
        changed['rows'][0]['output_sha256'] = 'dictionary-change'
        self.write(self.after, run=changed)
        self.assertTrue(MODULE.compare(self.before, self.after)['stages'][0]['output_changed'])

    def test_rejects_failed_run(self):
        changed = copy.deepcopy(self.run)
        changed['status'] = 'failed'
        self.write(self.after, run=changed)
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            MODULE.compare(self.before, self.after)


if __name__ == '__main__':
    unittest.main()

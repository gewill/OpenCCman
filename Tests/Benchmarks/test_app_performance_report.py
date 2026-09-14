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
        self.metadata = {'schema': 2, 'resolved_checkout_revisions': {'other': 'same'}, 'hardware': 'fixed', 'os': 'fixed', 'xcode': 'fixed', 'conditions': ['fixed'],
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
        run = copy.deepcopy(run or self.run)
        run['metadata_sha256'] = MODULE.sha256(directory / 'metadata.json')
        for n in range(3):
            (directory / f'run-{n}.json').write_text(json.dumps(run or self.run))

    def test_equal_samples_have_no_regression(self):
        result = MODULE.compare(self.before, self.after)
        self.assertFalse(result['stages'][0]['metrics']['model_completion_ms']['review'])

    def test_rejects_unrelated_dependency_drift(self):
        changed = copy.deepcopy(self.metadata)
        changed['pins']['pins'][0]['state']['revision'] = 'changed'
        changed['resolved_checkout_revisions']['other'] = 'changed'
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

    def test_rejects_environment_changes(self):
        for key in ('conditions', 'os', 'xcode', 'hardware'):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.metadata)
                changed[key] = 'changed'
                self.write(self.after, metadata=changed)
                with self.assertRaisesRegex(ValueError, 'Conditions differ'):
                    MODULE.compare(self.before, self.after)

    def test_rejects_harness_and_driver_changes(self):
        for key, error in [('Tests/Benchmarks/AppPerformanceAudit.swift', 'harness'),
                           ('scripts/benchmark-app.py', 'driver'), ('scripts/app_performance.py', 'driver')]:
            with self.subTest(key=key):
                changed = copy.deepcopy(self.metadata)
                changed['source_hashes'][key] = 'changed'
                self.write(self.after, metadata=changed)
                with self.assertRaisesRegex(ValueError, error):
                    MODULE.compare(self.before, self.after)

    def test_rejects_missing_or_wrong_checkout_proof(self):
        for revisions in (None, {}, {'other': 'wrong'}):
            with self.subTest(revisions=revisions):
                changed = copy.deepcopy(self.metadata)
                changed['resolved_checkout_revisions'] = revisions
                self.write(self.after, metadata=changed)
                with self.assertRaisesRegex(ValueError, '[Dd]ependency'):
                    MODULE.compare(self.before, self.after)

    def test_accepts_only_engine_revision_change(self):
        before = copy.deepcopy(self.metadata)
        before['pins']['pins'].append({'identity': 'swiftyopencc', 'state': {'revision': 'old'}})
        before['resolved_checkout_revisions']['swiftyopencc'] = 'old'
        after = copy.deepcopy(before)
        after['pins']['pins'][-1]['state']['revision'] = 'new'
        after['resolved_checkout_revisions']['swiftyopencc'] = 'new'
        self.write(self.before, metadata=before)
        self.write(self.after, metadata=after)
        MODULE.compare(self.before, self.after)

    def test_rejects_too_few_samples(self):
        (self.after / 'run-2.json').unlink()
        with self.assertRaisesRegex(ValueError, 'three'):
            MODULE.compare(self.before, self.after)

    def test_rejects_duplicate_stages(self):
        changed = copy.deepcopy(self.run)
        changed['rows'].append(changed['rows'][0])
        self.write(self.after, run=changed)
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            MODULE.compare(self.before, self.after)

    def test_rejects_bad_collection_and_validation(self):
        for key in ('task_info_status', 'rusage_status', 'export_matches_result', 'editors_match_model'):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.run)
                if key.endswith('status'):
                    changed['rows'][0]['memory'][key] = 1
                else:
                    changed['rows'][0][key] = False
                self.write(self.after, run=changed)
                with self.assertRaises(ValueError):
                    MODULE.compare(self.before, self.after)

    def test_rejects_missing_stage(self):
        before = copy.deepcopy(self.run)
        before['rows'].append(dict(before['rows'][0], name='extra_stage'))
        self.write(self.before, run=before)
        with self.assertRaisesRegex(ValueError, 'Missing stage'):
            MODULE.compare(self.before, self.after)

    def test_rejects_nondeterministic_output(self):
        file = self.after / 'run-1.json'
        changed = json.loads(file.read_text())
        changed['rows'][0]['output_sha256'] = 'different'
        file.write_text(json.dumps(changed))
        with self.assertRaisesRegex(ValueError, 'Nondeterministic'):
            MODULE.compare(self.before, self.after)

    def test_rejects_background_or_hidden_run(self):
        for active, visible in ((False, 1), (True, 0)):
            with self.subTest(active=active, visible=visible):
                changed = copy.deepcopy(self.run)
                changed['rows'].insert(0, dict(changed['rows'][0], name='root_layout_ready',
                                             app_active=active, visible_window_count=visible))
                self.write(self.after, run=changed)
                with self.assertRaisesRegex(ValueError, 'Foreground'):
                    MODULE.compare(self.before, self.after)

    def test_rejects_rewritten_metadata(self):
        file = self.after / 'metadata.json'
        file.write_text(file.read_text() + ' ')
        with self.assertRaisesRegex(ValueError, 'provenance'):
            MODULE.compare(self.before, self.after)

    def test_rejects_legacy_protocol(self):
        changed = dict(self.metadata, schema=1)
        self.write(self.after, metadata=changed)
        with self.assertRaisesRegex(ValueError, 'Legacy'):
            MODULE.compare(self.before, self.after)


if __name__ == '__main__':
    unittest.main()

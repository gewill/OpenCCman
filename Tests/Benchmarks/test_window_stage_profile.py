"""Synthetic sampler/clock tests, never evidence of actual application stacks."""
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('stage_profile', ROOT / 'scripts/window_stage_profile.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class StageProfileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.raw = self.root / 'lifecycle-123-test.jsonl'
        self.output = self.root / 'profiles'
        self.process = Mock(pid=123)
        self.process.poll.return_value = None
        self.rows = [self.row(MODULE.STAGES[0][1])]
        self.write()

    def row(self, event):
        return dict(pid=123, event=event, elapsed_ms=100)

    def write(self):
        self.raw.write_text(''.join(json.dumps(r) + '\n' for r in self.rows))

    def capture(self, **kwargs):
        with patch.object(MODULE.time, 'monotonic', return_value=10):
            return MODULE.profile_stages(self.process, self.root, self.output, **kwargs)

    def test_partial_append_is_ignored_until_newline(self):
        with self.raw.open('ab') as f:
            f.write(b'{"pid":')
        self.assertEqual(MODULE.complete_rows(self.raw), self.rows)

    def test_wrong_pid_and_missing_graph_rejected(self):
        for value in ('Process: OpenCCman [124]\nCall graph:', 'Process: OpenCCman [123]'):
            with self.assertRaises(ValueError): MODULE.check_sample(value, 123)

    def test_owned_process_already_exited(self):
        self.process.poll.return_value = 0
        with patch.object(MODULE.subprocess, 'run') as run:
            with self.assertRaises(ValueError): self.capture(deadline=40)
            run.assert_not_called()
        self.assertFalse(json.loads((self.output / 'capture.json').read_text())['valid_capture'])

    def test_expired_deadline(self):
        with patch.object(MODULE.subprocess, 'run') as run:
            with self.assertRaises(ValueError): self.capture(deadline=9)
            run.assert_not_called()

    def test_insufficient_sample_budget(self):
        with patch.object(MODULE.subprocess, 'run') as run:
            with self.assertRaises(ValueError): self.capture(deadline=14)
            run.assert_not_called()

    def test_stage_already_completed(self):
        self.rows.append(self.row(MODULE.STAGES[0][2]))
        self.write()
        with patch.object(MODULE.subprocess, 'run') as run:
            with self.assertRaises(ValueError): self.capture(deadline=40)
            run.assert_not_called()

    def test_mixed_process_or_malformed_log(self):
        for value in ({'pid': 124}, {'elapsed_ms': float('nan')}, {'event': None}):
            self.rows = [dict(self.row(MODULE.STAGES[0][1]), **value)]
            self.write()
            with self.assertRaises(ValueError): MODULE.owned_rows(self.raw, 123)

    def test_sampler_failure_preserves_report(self):
        with patch.object(MODULE.subprocess, 'run', return_value=Mock(returncode=1)):
            with self.assertRaises(ValueError): self.capture(deadline=40)
        report = json.loads((self.output / 'capture.json').read_text())
        self.assertFalse(report['valid_capture'])
        self.assertEqual(report['samples'][0]['exit_code'], 1)
        self.assertTrue((self.output / 'import-tool.log').exists())

    def test_both_owned_samples_preserve_straddling_fact(self):
        def fake_sample(command, **kwargs):
            self.assertEqual(command[:5], ['/usr/bin/sample', '123', '5', '10', '-mayDie'])
            self.assertEqual(kwargs['timeout'], 30)
            Path(command[-1]).write_text('Process: OpenCCman [123]\nCall graph:\nsynthetic test only\n')
            index = 0 if 'import-sample' in command[-1] else 1
            self.rows.append(self.row(MODULE.STAGES[index][2]))
            if index == 0: self.rows.append(self.row(MODULE.STAGES[1][1]))
            self.write()
            return Mock(returncode=0)
        with patch.object(MODULE.subprocess, 'run', side_effect=fake_sample) as run:
            report = self.capture(deadline=40)
        self.assertEqual(run.call_count, 2)
        self.assertTrue(report['valid_capture'])
        self.assertTrue(all(r['stage_end_seen_at_capture_return'] for r in report['samples']))
        self.assertTrue(all(len(r['sample_sha256']) == 64 for r in report['samples']))

    def test_raw_mode_cannot_launch_profiler(self):
        result = subprocess.run(['python3', str(ROOT / 'scripts/check-native-window-lifecycle.py'),
                                 '--raw', str(self.raw), '--documents', '--active-anchor',
                                 '--profile-stages', '--output', str(self.output)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('requires --app', result.stderr)
        self.assertFalse(self.output.exists())

    def test_sampling_failure_still_waits_with_original_deadline_and_keeps_raw(self):
        spec = importlib.util.spec_from_file_location('checker', ROOT / 'scripts/check-native-window-lifecycle.py')
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        bundle = checker.BUNDLE + 'DocumentsActiveAnchor'
        cache = self.root / 'Library/Caches' / bundle
        cache.mkdir(parents=True)
        self.raw.rename(cache / self.raw.name)
        app = self.root / 'OpenCCman.app'
        (app / 'Contents').mkdir(parents=True)
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': bundle, 'CFBundleExecutable': 'OpenCCman'}))
        def exited(**kwargs):
            self.process.poll.return_value = 0
            return 0
        self.process.wait.side_effect = exited
        arguments = ['checker', '--app', str(app), '--documents', '--active-anchor',
                     '--profile-stages', '--output', str(self.output)]
        # Single process lifetime: starts at 0, sampler ends at 15, wait at 20.
        with (patch.object(checker.sys, 'argv', arguments),
              patch.dict(checker.os.environ, GITHUB_ACTIONS='true', RUNNER_OS='macOS'),
              patch.object(Path, 'home', return_value=self.root),
              patch.object(checker.time, 'monotonic', side_effect=[0, 10, 10, 15, 20]),
              patch.object(checker.subprocess, 'Popen', return_value=self.process),
              patch.object(checker.subprocess, 'run', return_value=Mock(returncode=1)),
              contextlib.redirect_stdout(io.StringIO())):
            self.assertEqual(checker.main(), 4)
        self.process.wait.assert_called_once_with(timeout=640)
        report = json.loads((self.output / 'result.json').read_text())
        self.assertFalse(report['valid_profile'])
        self.assertTrue(report['process_exited'])
        self.assertEqual(report['exit_code'], 0)
        self.assertTrue((self.output / 'raw.jsonl').exists())
        self.assertTrue((self.output / 'process-raw-0.jsonl').exists())
        self.assertTrue((self.output / 'documents').exists())

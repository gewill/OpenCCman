"""Control/failure tests and re-reading existing evidence; no UI launches."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('editor_comparison', ROOT / 'scripts/compare-workspace-editor.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class EditorComparisonTests(unittest.TestCase):
    def test_local_launch_rejected_before_git_or_files(self):
        with (patch.dict(MODULE.os.environ, GITHUB_ACTIONS='false'),
              patch.object(MODULE.sys, 'argv', ['compare', '--baseline', 'a'*40, '--candidate', 'b'*40, '--output', '/unused']),
              patch.object(MODULE, 'git') as git,
              contextlib.redirect_stderr(io.StringIO())):
            with self.assertRaises(SystemExit) as raised: MODULE.main()
            self.assertEqual(raised.exception.code, 2)
            git.assert_not_called()

    def test_dependency_drift_rejected_before_preparation(self):
        a,b='a'*40,'b'*40
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)/'new'
            with (patch.dict(MODULE.os.environ, GITHUB_ACTIONS='true', RUNNER_OS='macOS'),
                  patch.object(MODULE.sys, 'argv', ['compare', '--baseline', a, '--candidate', b, '--output', str(output)]),
                  patch.object(MODULE, 'git', side_effect=[a.encode(), b.encode(), b.encode(), a.encode(), b'old lock', b'new lock']),
                  patch.object(MODULE, 'run') as run,
                  contextlib.redirect_stderr(io.StringIO())):
                with self.assertRaises(SystemExit) as raised: MODULE.main()
                self.assertEqual(raised.exception.code, 2)
                run.assert_not_called()
            self.assertFalse(output.exists())

    def test_timeout_closes_only_owned_process_group(self):
        process=Mock(pid=123)
        process.wait.side_effect=[subprocess.TimeoutExpired('test', 1), 0, 0]
        with tempfile.TemporaryDirectory() as tmp:
            with (patch.object(MODULE.subprocess, 'Popen', return_value=process) as launch,
                  patch.object(MODULE.os, 'killpg') as kill):
                with self.assertRaises(subprocess.TimeoutExpired):
                    MODULE.run(['test-command'], Path(tmp)/'log', 1)
            self.assertTrue(launch.call_args.kwargs['start_new_session'])
            self.assertEqual([c.args for c in kill.call_args_list], [(123,signal.SIGTERM),(123,signal.SIGKILL)])

    def test_nonzero_command_preserves_log_and_fails(self):
        process=Mock(pid=123)
        process.wait.return_value=7
        with tempfile.TemporaryDirectory() as tmp:
            log=Path(tmp)/'failure.log'
            with patch.object(MODULE.subprocess, 'Popen', return_value=process):
                with self.assertRaisesRegex(ValueError, 'exited 7'): MODULE.run(['test'], log, 1)
            self.assertTrue(log.exists())

    def test_existing_raw_metrics_are_recomputed_not_copied(self):
        root=ROOT/'docs/performance/document-stage-profiling/2026-09-16'
        values=MODULE.metrics(root)
        self.assertEqual(values['successful_exports'],5)
        self.assertEqual(values['final_live_models'],[])
        self.assertAlmostEqual(values['stages']['10mib-a']['native_conversion_ms'],448.89375)

    def test_failed_protocol_cannot_become_comparison(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/'result.json').write_text(json.dumps({'valid_protocol': False}))
            with self.assertRaisesRegex(ValueError, 'Incomplete'):MODULE.metrics(root)

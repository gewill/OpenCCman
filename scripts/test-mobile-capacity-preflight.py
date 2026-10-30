#!/usr/bin/env python3
"""Reject incomplete capacity evidence before building or creating output."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('capacity', Path(__file__).with_name('check-mobile-capacity-outputs.py'))
capacity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capacity)
MODES = {'simplified': 2, 'traditional': 1, 'traditional-taiwan-idiom': 1025,
         'taiwan': 33, 'taiwan-idiom': 1057, 'hong-kong': 65, 'hong-kong-taiwan-idiom': 1089}


class PreflightChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.wrapper = self.root / 'wrapper'
        subprocess.run(['git', 'init', '-q', str(self.wrapper)], check=True)
        subprocess.run(['git', '-C', str(self.wrapper), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit', '-q', '--allow-empty', '-m', 'fixture'], check=True)
        self.pin = subprocess.check_output(['git', '-C', str(self.wrapper), 'rev-parse', 'HEAD'], text=True).strip()
        lock = self.root / 'OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        lock.parent.mkdir(parents=True)
        lock.write_text(json.dumps({'pins': [{'identity': 'swiftyopencc', 'state': {'revision': self.pin}}]}))
        self.fixtures = self.root / 'fixtures'
        self.fixtures.mkdir()
        source = self.fixtures / 'fixture.txt'
        source.write_bytes(b'x')
        self.manifest = {'wrapper_sha': self.pin, 'fixtures': [
            {'file': source.name, 'bytes': 1, 'sha256': capacity.sha(source)}]}
        self.oracle = {'wrapper_sha': self.pin, 'rows': [
            {'fixture': source.name, 'mode': mode, 'options_raw': raw, 'input_bytes': 1,
             'input_sha256': capacity.sha(source), 'output_bytes': 1, 'output_sha256': capacity.sha(source)}
            for mode, raw in MODES.items()]}
        self.output = self.root / 'output'

    def invoke(self, expected_error=None):
        manifest = self.fixtures / 'manifest.json'
        manifest.write_text(json.dumps(self.manifest))
        self.oracle['fixture_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
        oracle = self.root / 'oracle.json'
        oracle.write_text(json.dumps(self.oracle))
        argv = ['check', '--fixtures', str(self.fixtures), '--oracle', str(oracle),
                '--opencc-path', str(self.wrapper), '--output', str(self.output)]
        real_run = subprocess.run
        builds = []

        def run(command, *args, **kwargs):
            if command[:2] == ['swift', 'build']:
                builds.append(command)
                raise RuntimeError('build boundary')
            return real_run(command, *args, **kwargs)

        with patch.object(capacity, 'ROOT', self.root), patch.object(sys, 'argv', argv), \
             patch.object(capacity.subprocess, 'run', side_effect=run):
            if expected_error:
                with contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as error:
                    capacity.main()
                self.assertEqual(error.exception.code, 2)
                self.assertIn(expected_error, stderr.getvalue())
                self.assertFalse(self.output.exists())
                self.assertEqual(builds, [])
            else:
                with self.assertRaisesRegex(RuntimeError, 'build boundary'):
                    capacity.main()
                self.assertEqual(len(builds), 1)

    def test_empty_matrix(self):
        self.manifest['fixtures'] = []
        self.oracle['rows'] = []
        self.invoke('nonempty unique fixture names')

    def test_duplicate_fixture_with_duplicate_rows(self):
        self.manifest['fixtures'] *= 2
        self.oracle['rows'] *= 2
        self.invoke('nonempty unique fixture names')

    def test_missing_mode(self):
        self.oracle['rows'].pop()
        self.invoke('exactly seven modes')

    def test_duplicate_mode(self):
        self.oracle['rows'][-1] = self.oracle['rows'][0].copy()
        self.invoke('exactly seven modes')

    def test_wrong_mode_options(self):
        self.oracle['rows'][0]['options_raw'] = 1
        self.invoke('Oracle input or mode mismatch')

    def test_fixture_changed(self):
        (self.fixtures / 'fixture.txt').write_bytes(b'y')
        self.invoke('Fixture integrity mismatch')

    def test_path_escape(self):
        self.manifest['fixtures'][0]['file'] = '../fixture.txt'
        for row in self.oracle['rows']:
            row['fixture'] = '../fixture.txt'
        self.invoke('direct regular file')

    def test_valid_matrix_reaches_build(self):
        # Stop before compilation; the real service run is a separate check.
        source_dir = self.root / 'OpenCCman/Services'
        source_dir.mkdir(parents=True)
        for name in capacity.SOURCES:
            source = self.root / name
            source.parent.mkdir(parents=True, exist_ok=True)
            source.touch()
        self.invoke()


if __name__ == '__main__':
    unittest.main()

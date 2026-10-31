#!/usr/bin/env python3
"""Exercise real CLI success, corrupted exports, provenance and safe reads."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('verify-mobile-export.py')


class ExportChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = ('繁體\x00\r\n😀e\u0301\ufeff' * 30000).encode()
        self.export = self.root / 'export.txt'
        self.export.write_bytes(self.payload)
        self.context = dict(device_model='synthetic-test', os='test', build='test', app_sha='test',
                            wrapper_sha='locked-test', provider='test', fixture='fixture.txt', mode='traditional')
        self.oracle = {'wrapper_sha': 'locked-test', 'rows': [dict(fixture='fixture.txt', mode='traditional',
                        options_raw=1, output_bytes=len(self.payload), output_sha256=hashlib.sha256(self.payload).hexdigest())]}

    def run_cli(self, expected):
        (self.root / 'context.json').write_text(json.dumps(self.context))
        (self.root / 'oracle.json').write_text(json.dumps(self.oracle))
        result = subprocess.run([sys.executable, str(SCRIPT), '--export', str(self.export),
            '--context', str(self.root / 'context.json'), '--oracle', str(self.root / 'oracle.json'),
            '--report', str(self.root / 'report.json')], capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return self.root / 'report.json'

    def test_unicode_nul_full_bytes_and_no_overwrite(self):
        report = self.run_cli(0)
        before = report.read_bytes()
        self.assertTrue(json.loads(before)['passed'])
        self.run_cli(2)
        self.assertEqual(report.read_bytes(), before)
        self.assertEqual(self.export.read_bytes(), self.payload)

    def test_truncation_and_same_size_corruption(self):
        for payload in (self.payload[:-1], b'x' + self.payload[1:]):
            self.export.write_bytes(payload)
            report = self.run_cli(1)
            self.assertFalse(json.loads(report.read_bytes())['passed'])
            report.unlink()

    def test_wrong_wrapper_mode_and_duplicate(self):
        self.context['wrapper_sha'] = 'wrong'
        self.assertFalse(self.run_cli(2).exists())
        self.context['wrapper_sha'] = 'locked-test'
        self.oracle['rows'][0]['options_raw'] = 2
        self.assertFalse(self.run_cli(2).exists())
        self.oracle['rows'][0]['options_raw'] = 1
        self.oracle['rows'] *= 2
        self.assertFalse(self.run_cli(2).exists())

    def test_link_and_fifo_rejected_without_modification(self):
        import os
        self.export.unlink()
        target = self.root / 'target.txt'
        target.write_bytes(self.payload)
        self.export.symlink_to(target)
        self.assertFalse(self.run_cli(2).exists())
        self.export.unlink()
        os.mkfifo(self.export)
        self.assertFalse(self.run_cli(2).exists())
        self.assertEqual(target.read_bytes(), self.payload)


if __name__ == '__main__':
    unittest.main()

"""A failed build or changed artifact must never become a benchmark sample."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
SPEC = importlib.util.spec_from_file_location('driver', ROOT / 'scripts/benchmark-app.py')
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)


class BuildVerification(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name)
        self.source = self.output / 'source'
        (self.source / DRIVER.LOCK).parent.mkdir(parents=True)
        self.lock = {'pins': [{'identity': 'engine', 'state': {'revision': 'verified'}}]}
        (self.source / DRIVER.LOCK).write_text(json.dumps(self.lock))
        (self.source / 'test.swift').write_text('let value = 1')
        self.app = self.output / 'derived/Build/Products/Release/OpenCCman.app'
        self.app.mkdir(parents=True)
        (self.app / 'binary').write_bytes(b'built')
        self.metadata = {'schema': 2, 'pins': self.lock, 'resolved_checkout_revisions': {'engine': 'verified'},
                         'source_hashes': DRIVER.source_hashes(self.source)}
        for name in ('benchmark-app.py', 'app_performance.py'):
            target = self.source / 'scripts' / name
            target.parent.mkdir(exist_ok=True)
            target.write_bytes((ROOT / 'scripts' / name).read_bytes())
        self.metadata['source_hashes'] = DRIVER.source_hashes(self.source)
        (self.output / 'metadata.json').write_text(json.dumps(self.metadata))
        self.marker = {'metadata_sha256': DRIVER.sha256(self.output / 'metadata.json'),
                       'app_hashes': DRIVER.artifact_hashes(self.app)}
        (self.output / 'build-complete.json').write_text(json.dumps(self.marker))
        self.addCleanup(patch.stopall)
        self.checkouts = patch.object(DRIVER, 'checkout_revisions', return_value={'engine': 'verified'}).start()
        patch.object(DRIVER, 'environment', return_value={}).start()

    def test_accepts_verified_unchanged_build(self):
        DRIVER.verify_build(self.output)

    def test_rejects_build_without_success_marker(self):
        (self.output / 'build-complete.json').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing successful'):
            DRIVER.verify_build(self.output)

    def test_rejects_changed_source(self):
        (self.source / 'test.swift').write_text('let value = 2')
        with self.assertRaisesRegex(ValueError, 'source changed'):
            DRIVER.verify_build(self.output)

    def test_rejects_changed_app(self):
        (self.app / 'binary').write_bytes(b'different build')
        with self.assertRaisesRegex(ValueError, 'app changed'):
            DRIVER.verify_build(self.output)

    def test_rejects_changed_metadata(self):
        (self.output / 'metadata.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'metadata changed'):
            DRIVER.verify_build(self.output)

    def test_rejects_changed_lock(self):
        (self.source / DRIVER.LOCK).write_text('{}')
        with self.assertRaisesRegex(ValueError, 'lock changed'):
            DRIVER.verify_build(self.output)

    def test_rejects_changed_checkout(self):
        self.checkouts.return_value = {'engine': 'wrong'}
        with self.assertRaisesRegex(ValueError, 'checkout changed'):
            DRIVER.verify_build(self.output)


if __name__ == '__main__':
    unittest.main()

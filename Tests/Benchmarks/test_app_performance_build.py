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

    def test_variant_anchor_changes_only_attachment(self):
        path = self.source / 'Keeper.swift'
        path.write_bytes((ROOT / 'OpenCCman/View/WorkspaceScrollKeeper.swift').read_bytes())
        before = path.read_text().count('backgroundLayoutEnabled = false')
        DRIVER.replace_once(path, '      self.clip = clip\n      size = clip.bounds.size',
                            '      self.clip = clip\n      size = clip.bounds.size\n      editor.layoutManager?.backgroundLayoutEnabled = false')
        self.assertEqual(path.read_text().count('backgroundLayoutEnabled = false'), before + 1)

    def test_textkit1_no_anchor_keeps_native_editor_construction(self):
        editor = self.source / 'OpenCCman/View/WorkspaceTextEditor.swift'
        editor.parent.mkdir(parents=True)
        original = (ROOT / 'OpenCCman/View/WorkspaceTextEditor.swift').read_text()
        editor.write_text(original)
        DRIVER.prepare_textkit1_no_anchor(self.source)
        updated = editor.read_text()
        self.assertEqual(updated.count('scrollKeeper.attach(editor)'), 0)
        self.assertEqual(updated.count('let layout = NSLayoutManager()'), 1)
        self.assertEqual(updated.count('let editor = WorkspaceDiffTextView('), 1)
        self.assertIn('final class WorkspaceDiffTextView: NSTextView', updated)
        self.assertEqual(updated.replace('      // Private benchmark: omit the viewport observer.\n',
                                         '      scrollKeeper.attach(editor)\n'), original)

    def test_accepts_verified_unchanged_build(self):
        DRIVER.verify_build(self.output)

    def test_textkit2_variants_preserve_editor_and_expected_keeper(self):
        for name in ('no_anchor', 'modern_anchor', 'single_target'):
            with self.subTest(variant=name):
                source = self.output / name
                for relative in ('OpenCCman/View/WorkspaceTextEditor.swift',
                                 'OpenCCman/View/WorkspaceScrollKeeper.swift',
                                 'Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift'):
                    target = source / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes((ROOT / relative).read_bytes())
                getattr(DRIVER, f'prepare_textkit2_{name}')(source)
                editor = (source / 'OpenCCman/View/WorkspaceTextEditor.swift').read_text()
                self.assertEqual(editor.count('let editor = WorkspaceDiffTextView(usingTextLayoutManager: true)'), 1)
                self.assertNotIn('let layout = NSLayoutManager()', editor)
                self.assertIn('final class WorkspaceDiffTextView: NSTextView', editor)
                self.assertEqual(editor.count('scrollKeeper.attach(editor)'), 0 if name == 'no_anchor' else 1)
                keeper = (source / 'OpenCCman/View/WorkspaceScrollKeeper.swift').read_text()
                if name == 'no_anchor':
                    self.assertEqual(keeper, (ROOT / 'OpenCCman/View/WorkspaceScrollKeeper.swift').read_text())
                else:
                    self.assertIn('private let scrollKeeper = ModernWorkspaceScrollKeeper()', editor)
                    expected = (ROOT / ('docs/performance/2026-09-24-textkit-scroll-ablation/raw/'
                                        'firstrect-single-target-scroll/ModernWorkspaceScrollKeeper.swift.txt'
                                        if name == 'single_target' else
                                        'Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift')).read_text()
                    self.assertIn(expected, keeper)

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

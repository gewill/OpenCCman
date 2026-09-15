"""Negative protocol tests. Synthetic rows are never presented as app evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('document_check', ROOT / 'scripts/check-native-window-lifecycle.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
MANIFEST = json.loads((ROOT / 'docs/performance/native-window-lifecycle/2026-09-15-documents/preparation.json').read_text())


class WindowDocumentTests(unittest.TestCase):
    def setUp(self):
        self.rows = []
        self.time = 0
        self.writes = ['anchor']
        def row(event, count=1, visible=1, used=1, pending=0, label='1mib-a', source=0, result=0,
                importing=False, converting=False, **extra):
            item = dict(event=event, elapsed_ms=self.time, created_total=count, pid=42,
                        visible_main_capable_windows=visible, live_model_numbers=list(range(1, count + 1)),
                        anchor_fingerprint='a' * 64, quota={'2026-09-16': used}, pending_reservations=pending,
                        label=label, result_writebacks=self.writes[:],
                        model_states=[dict(number=1, importing=False, converting=False)],
                        content_sizes=[dict(number=1, source_bytes=75, result_bytes=75, has_export=True)],
                        native_call=dict(begin_ns=100, will_close_ns=150, end_ns=200))
            if count > 1:
                item['model_states'].append(dict(number=count, importing=importing, converting=converting))
                item['content_sizes'].append(dict(number=count, source_bytes=source, result_bytes=result, has_export=result > 0))
            item.update(extra)
            self.rows.append(item)
            self.time += 100
            return item
        for fixture in MANIFEST['fixtures']:
            row(f"documents_fixture_{fixture['mib']}", **{k: fixture[k] for k in ('input_bytes', 'expected_bytes', 'input_sha256', 'expected_sha256')})
        row('documents_started')
        self.time += 10000
        row('documents_anchor_ready')
        for index, label in enumerate(('1mib-a', '1mib-b', '10mib-a', '10mib-b', 'active-10mib'), 1):
            fixture = MANIFEST['fixtures'][0 if index <= 2 else 1]
            length = fixture['expected_bytes']
            args = dict(count=index + 1, visible=2, used=index, label=label)
            row(f'document_{label}_import_started', importing=True, **args)
            row(f'document_{label}_imported', source=length, **args)
            row(f'document_{label}_conversion_started', source=length, pending=1, converting=True, **args)
            if index < 5:
                self.writes.append(label)
                args['used'] += 1
                row(f'document_{label}_exported', source=length, result=length, actual_bytes=length,
                    actual_sha256=fixture['expected_sha256'], byte_equal=True, nul_count=fixture['unit_repeats'],
                    export_filename=f"input-{fixture['mib']}mib-converted.txt", **args)
                self.time += 10000
                row(f'document_{label}_before_close', source=length, result=length, **args)
            else:
                row(f'document_{label}_before_close', source=length, pending=1, converting=True, **args)
            args.update(visible=1, source=length, result=length if index < 5 else 0)
            closed = row(f'document_{label}_closed', **args)
            self.time = closed['elapsed_ms'] + 5000
            row(f'document_{label}_plus_5', **args)
            self.time = closed['elapsed_ms'] + 20000
            row(f'document_{label}_plus_20', **args)
        final_args = dict(count=6, visible=0, used=5)
        closed = row('documents_final_closed', **final_args)
        self.time = closed['elapsed_ms'] + 5000
        row('documents_final_plus_5', **final_args)
        self.time = closed['elapsed_ms'] + 20000
        row('documents_final_plus_20', **final_args)
        row('documents_finished', **final_args)

    def event(self, name):
        return next(r for r in self.rows if r['event'] == name)

    def rejects(self):
        with self.assertRaises(ValueError): MODULE.validate(self.rows, documents=True)

    def test_retained_models_are_reported(self):
        result = MODULE.validate(self.rows, documents=True)
        self.assertEqual(result['documents_final_plus_20']['live_model_numbers'], [1, 2, 3, 4, 5, 6])

    def test_unchanged_byte_length_with_corruption_is_rejected(self):
        self.event('document_10mib-a_exported')['actual_sha256'] = '0' * 64
        self.rejects()

    def test_changed_fixture_is_rejected(self):
        self.event('documents_fixture_10')['input_sha256'] = '0' * 64
        self.rejects()

    def test_loading_label_without_native_overlap_is_rejected(self):
        for suffix in ('plus_5', 'plus_20'):
            self.event(f'document_active-10mib_{suffix}')['native_call']['will_close_ns'] = 201
        self.rejects()

    def test_missing_native_completion_is_rejected(self):
        del self.event('document_active-10mib_plus_20')['native_call']['end_ns']
        self.rejects()

    def test_leaked_quota_reservation_is_rejected(self):
        self.event('document_active-10mib_plus_20')['pending_reservations'] = 1
        self.rejects()

    def test_cancelled_conversion_charged_is_rejected(self):
        self.event('document_active-10mib_plus_5')['quota'] = {'2026-09-16': 6}
        self.rejects()

    def test_late_writeback_is_rejected(self):
        self.event('documents_final_plus_20')['result_writebacks'].append('active-10mib')
        self.rejects()

    def test_anchor_result_changed_is_rejected(self):
        self.event('document_10mib-b_closed')['anchor_fingerprint'] = 'b' * 64
        self.rejects()

    def test_missing_large_document_repeat_is_rejected(self):
        self.rows.remove(self.event('document_10mib-b_exported'))
        self.rejects()

    def test_early_observation_is_rejected(self):
        self.event('document_1mib-a_plus_20')['elapsed_ms'] -= 1
        self.rejects()


class SavedDocumentTests(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        spec = importlib.util.spec_from_file_location('saved_documents', ROOT / 'scripts/window_document_protocol.py')
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        for fixture in MANIFEST['fixtures']:
            pad = 'x' * fixture['ascii_padding_bytes']
            source = b'\xef\xbb\xbf' + (MANIFEST['fixture_source'] * fixture['unit_repeats'] + pad).encode()
            expected = (MANIFEST['fixture_expected'] * fixture['unit_repeats'] + pad).encode()
            (self.directory / fixture['input']).write_bytes(source)
            (self.directory / fixture['expected']).write_bytes(expected)
            for repeat in ('a', 'b'):
                (self.directory / f"actual-{fixture['mib']}mib-{repeat}.txt").write_bytes(expected)

    def tearDown(self):
        self.temp.cleanup()

    def test_fixed_oracle_exports_pass(self):
        self.assertEqual(len(self.module.verify_files(self.directory)), 4)

    def test_same_length_corruption_fails(self):
        path = self.directory / 'actual-10mib-b.txt'
        data = path.read_bytes()
        path.write_bytes(data[:-1] + b'y')
        with self.assertRaises(ValueError): self.module.verify_files(self.directory)

    def test_nul_truncation_fails(self):
        path = self.directory / 'actual-1mib-a.txt'
        path.write_bytes(path.read_bytes().split(b'\0', 1)[0])
        with self.assertRaises(ValueError): self.module.verify_files(self.directory)

"""Reject false retained-window success; synthetic protocol fixtures only."""
import copy
import unittest
import test_window_documents as base

MODULE, MANIFEST = base.MODULE, base.MANIFEST


class RetainedActiveWindowTests(unittest.TestCase):
    def setUp(self):
        fixture = base.WindowDocumentTests()
        fixture.setUp()
        self.rows = fixture.rows
        final = [r for r in self.rows if r['event'].startswith('documents_final_') or r['event'] == 'documents_finished']
        self.rows = [r for r in self.rows if r not in final]
        template = self.rows[-1]
        t = template['elapsed_ms'] + 100
        writes = template['result_writebacks'][:]
        length = MANIFEST['fixtures'][1]['expected_bytes']
        for index, name in enumerate(('import_started', 'imported', 'before_other_close', 'exported', 'plus_5', 'plus_20')):
            r = copy.deepcopy(template)
            r.update(event='retained_' + name, created_total=7, live_model_numbers=list(range(1, 8)),
                     visible_main_capable_windows=2 if index < 3 else 1,
                     elapsed_ms=t, anchor_fingerprint='b' * 64,
                     pending_reservations=1 if index == 2 else 0,
                     quota={'2026-09-16': 5 if index < 3 else 6},
                     result_writebacks=writes + (['retained-active-10mib'] if index >= 3 else []),
                     content_sizes=[dict(number=1, source_bytes=length, result_bytes=length if index >= 3 else 0, has_export=index >= 3)],
                     model_states=[dict(number=1, importing=index == 0, converting=index == 2)])
            if index == 2:
                r.update(retained_model_number=1, closed_model_number=7, retained_converting=True,
                         other_converting=False, other_importing=False, native_call={'begin_ns':100})
            if index >= 3:
                r.update(actual_bytes=length, actual_sha256=MANIFEST['fixtures'][1]['expected_sha256'],
                         byte_equal=True, export_filename='input-10mib-converted.txt',
                         source_sha256='c'*64, expected_source_sha256='c'*64)
            self.rows.append(r)
            t += 5000 if index == 3 else 15000 if index == 4 else 100
        for i, r in enumerate(final):
            r.update(created_total=7, live_model_numbers=list(range(1,8)), quota={'2026-09-16':6},
                     result_writebacks=writes+['retained-active-10mib'], elapsed_ms=t+[0,5000,20000,20100][i])
        self.rows.extend(final)

    def event(self, name):
        return next(r for r in self.rows if r['event'] == name)

    def rejects(self):
        with self.assertRaises(ValueError): MODULE.validate(self.rows, documents=True, active_anchor=True)

    def test_complete_case_preserves_retention_as_outcome(self):
        result = MODULE.validate(self.rows, documents=True, active_anchor=True)
        self.assertEqual(result['retained_plus_20']['live_model_numbers'], list(range(1,8)))

    def test_original_protocol_is_not_enough(self):
        self.rows = [r for r in self.rows if not r['event'].startswith('retained_')]
        self.rejects()

    def test_closing_active_anchor_instead_of_other_window_fails(self):
        self.event('retained_before_other_close')['closed_model_number'] = 1
        self.rejects()

    def test_loading_without_actual_overlap_fails(self):
        self.event('retained_exported')['native_call']['will_close_ns'] = 201
        self.rejects()

    def test_finishing_before_close_fails(self):
        self.event('retained_before_other_close')['native_call']['end_ns'] = 99
        self.rejects()

    def test_accidental_cancellation_or_missing_success_fails(self):
        self.event('retained_exported')['result_writebacks'].pop()
        self.rejects()

    def test_unchanged_length_wrong_output_fails(self):
        self.event('retained_exported')['actual_sha256'] = '0'*64
        self.rejects()

    def test_pending_reservation_after_success_fails(self):
        self.event('retained_plus_20')['pending_reservations'] = 1
        self.rejects()

    def test_extra_quota_charge_fails(self):
        self.event('retained_plus_5')['quota'] = {'2026-09-16':7}
        self.rejects()

    def test_changed_retained_configuration_fails(self):
        self.event('retained_plus_20')['anchor_fingerprint'] = 'd'*64
        self.rejects()

    def test_short_observation_fails(self):
        self.event('retained_plus_5')['elapsed_ms'] -= 1
        self.rejects()


class RetainedSavedFileTests(unittest.TestCase):
    def setUp(self):
        self.fixture = base.SavedDocumentTests()
        self.fixture.setUp()
        self.path = self.fixture.directory / 'actual-retained-active-10mib.txt'
        self.path.write_bytes((self.fixture.directory / 'expected-10mib.txt').read_bytes())

    def tearDown(self):
        self.fixture.tearDown()

    def test_fifth_export_is_independently_checked(self):
        exports = self.fixture.module.verify_files(self.fixture.directory, active_anchor=True)
        self.assertEqual(len(exports), 5)
        self.assertEqual(exports[-1]['file'], self.path.name)

    def test_missing_retained_export_fails(self):
        self.path.unlink()
        with self.assertRaises(FileNotFoundError):
            self.fixture.module.verify_files(self.fixture.directory, active_anchor=True)

    def test_same_length_retained_corruption_fails(self):
        data = self.path.read_bytes()
        self.path.write_bytes(data[:-1] + b'y')
        with self.assertRaises(ValueError):
            self.fixture.module.verify_files(self.fixture.directory, active_anchor=True)


class ArchivedRetainedWindowTests(unittest.TestCase):
    conditions = ('ci-macos15', 'no-extra-observation', 'partial-recording', 'recorded-final-case')

    def test_actual_protocols_revalidate(self):
        for condition in self.conditions:
            with self.subTest(condition=condition):
                path = base.ROOT / 'docs/performance/retained-active-window/2026-09-16' / condition
                rows = [base.json.loads(line) for line in (path / 'raw.jsonl').read_text().splitlines()]
                result = MODULE.validate(rows, documents=True, active_anchor=True)
                recorded = base.json.loads((path / 'result.json').read_text())
                self.assertEqual(result, recorded['observations'])
                self.assertTrue(all(r['task_info_status'] == 0 and r['rusage_status'] == 0 for r in rows))

    def test_actual_archives_contain_five_valid_outputs_each(self):
        import tempfile
        import zipfile
        import importlib.util
        spec = importlib.util.spec_from_file_location('retained_saved', base.ROOT / 'scripts/window_document_protocol.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        names = ['input-1mib.txt', 'expected-1mib.txt', 'input-10mib.txt', 'expected-10mib.txt']
        names += [f'actual-{name}.txt' for name in ('1mib-a','1mib-b','10mib-a','10mib-b','retained-active-10mib')]
        for condition in self.conditions:
            with self.subTest(condition=condition):
                path = base.ROOT / 'docs/performance/retained-active-window/2026-09-16' / condition
                with tempfile.TemporaryDirectory() as temporary, zipfile.ZipFile(path / 'generated-files.zip') as archive:
                    self.assertCountEqual(archive.namelist(), names)
                    for name in names:
                        (base.Path(temporary) / name).write_bytes(archive.read(name))
                    exports = module.verify_files(base.Path(temporary), active_anchor=True)
                self.assertEqual(exports, base.json.loads((path / 'result.json').read_text())['saved_exports'])

    def test_failed_capture_is_not_a_successful_demo(self):
        path = base.ROOT / 'docs/performance/retained-active-window/2026-09-16/partial-recording/capture-status.json'
        status = base.json.loads(path.read_text())
        self.assertTrue(status['functional_protocol_passed'])
        self.assertFalse(status['recording_completed_successfully'])
        self.assertFalse(status['covers_retained_active_case'])
        self.assertNotEqual(status['recorder_exit_code'], 0)

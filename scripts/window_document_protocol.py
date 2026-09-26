"""Validate document evidence, including fixed oracle hashes and native-call overlap.

Protocol correctness and retention outcomes are separate. Never turn a valid
record of retained models into a claimed release, or accept a UI loading flag
as evidence that the native call actually overlapped the close notification.
"""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'docs/performance/native-window-lifecycle/2026-09-15-documents/preparation.json'
LABELS = ('1mib-a', '1mib-b', '10mib-a', '10mib-b', 'active-10mib')


def validate_documents(rows, active_anchor=False):
    if any(row['event'].startswith('documents_failed:') for row in rows):
        raise ValueError('Document driver failed')
    observations = {}

    def event(name, created, visible):
        matches = [r for r in rows if r['event'] == name]
        if (len(matches) != 1 or matches[0]['created_total'] != created
                or matches[0]['visible_main_capable_windows'] != visible):
            raise ValueError(f'Missing/invalid document event: {name}')
        observations[name] = matches[0]
        return matches[0]

    def quota(row, used, pending):
        value = row.get('quota')
        if (not isinstance(value, dict) or len(value) != 1 or list(value.values()) != [used]
                or type(row.get('pending_reservations')) is not int or row['pending_reservations'] != pending):
            raise ValueError('Wrong success count or unreleased reservation')
        if list(value) != list(baseline['quota']):
            raise ValueError('Date changed during single-day protocol; repeat separately')

    def sizes(row, number, source, result, has_export):
        values = [s for s in row.get('content_sizes', []) if s.get('number') == number]
        if len(values) != 1 or (values[0].get('source_bytes'), values[0].get('result_bytes'),
                               values[0].get('has_export')) != (source, result, has_export):
            raise ValueError('Unexpected source/result/export state')

    def task(row, number, importing=False, converting=False):
        values = [s for s in row.get('model_states', []) if s.get('number') == number]
        if len(values) != 1 or values[0].get('importing') is not importing or values[0].get('converting') is not converting:
            raise ValueError('Unexpected import/conversion state')

    fixtures = {f['mib']: f for f in json.loads(MANIFEST.read_text())['fixtures']}
    started = event('documents_started', 1, 1)
    for mib, fixture in fixtures.items():
        raw = event(f'documents_fixture_{mib}', 1, 1)
        for key in ('input_bytes', 'input_sha256', 'expected_bytes', 'expected_sha256'):
            if raw.get(key) != fixture[key]:
                raise ValueError('Fixture differs from pinned historical oracle')
        if raw['elapsed_ms'] > started['elapsed_ms']:
            raise ValueError('Fixture generated after startup')
    baseline = event('documents_anchor_ready', 1, 1)
    fingerprint = baseline.get('anchor_fingerprint')
    if not isinstance(fingerprint, str) or not re.fullmatch('[0-9a-f]{64}', fingerprint):
        raise ValueError('Missing anchor fingerprint')
    if baseline['elapsed_ms'] - started['elapsed_ms'] < 10000:
        raise ValueError('Anchor settled for less than ten seconds')
    quota(baseline, 1, 0)
    sizes(baseline, 1, 75, 75, True)
    task(baseline, 1)
    expected_writes = ['anchor']
    if baseline.get('result_writebacks') != expected_writes:
        raise ValueError('Anchor did not complete exactly once')
    previous = baseline['elapsed_ms']

    for index, label in enumerate(LABELS, 1):
        active = index == 5
        fixture = fixtures[1 if index <= 2 else 10]
        length = fixture['expected_bytes']
        count = index + 1
        suffixes = ['import_started', 'imported', 'conversion_started']
        if not active:
            suffixes.append('exported')
        suffixes += ['before_close', 'closed', 'plus_5', 'plus_20']
        stages = {suffix: event(f'document_{label}_{suffix}', count,
                  1 if suffix in ('closed', 'plus_5', 'plus_20') else 2) for suffix in suffixes}
        times = [r['elapsed_ms'] for r in stages.values()]
        if times != sorted(times) or times[0] < previous:
            raise ValueError('Document cycles overlapped or reordered')
        for suffix, row in stages.items():
            if row.get('anchor_fingerprint') != fingerprint or row.get('label') != label:
                raise ValueError('Anchor or document label changed')
            sizes(row, 1, 75, 75, True)
            task(row, 1)
        for suffix in ('import_started', 'imported'):
            quota(stages[suffix], index, 0)
            if stages[suffix].get('result_writebacks') != expected_writes:
                raise ValueError('Import unexpectedly wrote a result')
        task(stages['import_started'], count, importing=True)
        sizes(stages['imported'], count, length, 0, False)
        task(stages['imported'], count)
        quota(stages['conversion_started'], index, 1)
        task(stages['conversion_started'], count, converting=True)
        if not active:
            exported = stages['exported']
            expected_writes = expected_writes + [label]
            for key, value in [('actual_bytes', length), ('actual_sha256', fixture['expected_sha256']),
                               ('byte_equal', True), ('nul_count', fixture['unit_repeats']),
                               ('export_filename', f"input-{fixture['mib']}mib-converted.txt")]:
                if exported.get(key) != value:
                    raise ValueError(f'Export mismatch: {key}')
            if stages['before_close']['elapsed_ms'] - exported['elapsed_ms'] < 10000:
                raise ValueError('Completed document hold shorter than ten seconds')
            for suffix in ('exported', 'before_close'):
                quota(stages[suffix], index + 1, 0)
                sizes(stages[suffix], count, length, length, True)
                task(stages[suffix], count)
        else:
            quota(stages['before_close'], 5, 1)
            task(stages['before_close'], count, converting=True)
            sizes(stages['before_close'], count, length, 0, False)
        for delay in (5, 20):
            row = stages[f'plus_{delay}']
            if row['elapsed_ms'] - stages['closed']['elapsed_ms'] < delay * 1000:
                raise ValueError('Short document close observation')
            quota(row, min(index + 1, 5), 0)
            if active and count in row['live_model_numbers']:
                task(row, count)
                sizes(row, count, length, 0, False)
            if row.get('result_writebacks') != expected_writes:
                raise ValueError('Missing success or late cancelled-result writeback')
            call = row.get('native_call', {})
            if any(type(call.get(key)) is not int for key in ('begin_ns', 'end_ns')) or not 0 < call['begin_ns'] < call['end_ns']:
                raise ValueError('Missing native call interval')
            if active and (type(call.get('will_close_ns')) is not int or
                           not call['begin_ns'] < call['will_close_ns'] < call['end_ns']):
                raise ValueError('Close did not overlap actual native call interval')
        previous = times[-1]

    if active_anchor:
        names = ('import_started', 'imported', 'before_other_close', 'exported', 'plus_5', 'plus_20')
        stages = {name: event(f'retained_{name}', 7,
                  2 if name in names[:3] else 1) for name in names}
        times = [row['elapsed_ms'] for row in stages.values()]
        if times != sorted(times) or times[0] < previous:
            raise ValueError('Retained-anchor cycle overlapped or reordered')
        length = fixtures[10]['expected_bytes']
        task(stages['import_started'], 1, importing=True)
        task(stages['imported'], 1)
        sizes(stages['imported'], 1, length, 0, False)
        for name in names[:2]:
            quota(stages[name], 5, 0)
            if stages[name].get('result_writebacks') != expected_writes:
                raise ValueError('Retained import wrote a result')
        before = stages['before_other_close']
        quota(before, 5, 1)
        if (before.get('retained_model_number') != 1 or before.get('closed_model_number') != 7
                or before.get('retained_converting') is not True
                or before.get('other_converting') is not False or before.get('other_importing') is not False):
            raise ValueError('Wrong active/closed window identity or task state')
        begun = before.get('native_call', {})
        if type(begun.get('begin_ns')) is not int or begun['begin_ns'] <= 0 or 'end_ns' in begun:
            raise ValueError('Retained call was not active before close')
        exported = stages['exported']
        for key, value in [('actual_bytes', length), ('actual_sha256', fixtures[10]['expected_sha256']),
                           ('byte_equal', True), ('export_filename', 'input-10mib-converted.txt')]:
            if exported.get(key) != value:
                raise ValueError('Retained output differs from oracle')
        if (not re.fullmatch('[0-9a-f]{64}', exported.get('source_sha256', '')) or
                exported['source_sha256'] != exported.get('expected_source_sha256')):
            raise ValueError('Retained source changed')
        fingerprint = exported.get('anchor_fingerprint')
        if not isinstance(fingerprint, str) or not re.fullmatch('[0-9a-f]{64}', fingerprint):
            raise ValueError('Missing retained content/configuration fingerprint')
        expected_writes = expected_writes + ['retained-active-10mib']
        for name in names[3:]:
            row = stages[name]
            quota(row, 6, 0)
            sizes(row, 1, length, length, True)
            task(row, 1)
            if row.get('anchor_fingerprint') != fingerprint or row.get('result_writebacks') != expected_writes:
                raise ValueError('Retained result/configuration changed or wrong writebacks')
            call = row.get('native_call', {})
            if (any(type(call.get(k)) is not int for k in ('begin_ns', 'will_close_ns', 'end_ns'))
                    or call['begin_ns'] != begun['begin_ns']
                    or not 0 < call['begin_ns'] < call['will_close_ns'] < call['end_ns']):
                raise ValueError('Other close did not overlap retained native conversion')
        for delay in (5, 20):
            if stages[f'plus_{delay}']['elapsed_ms'] - exported['elapsed_ms'] < delay * 1000:
                raise ValueError('Short retained success observation')
        previous = times[-1]

    final_count, final_quota = (7, 6) if active_anchor else (6, 5)
    final = {suffix: event(f'documents_final_{suffix}', final_count, 0) for suffix in ('closed', 'plus_5', 'plus_20')}
    if final['closed']['elapsed_ms'] < previous:
        raise ValueError('Final close preceded document completion')
    for suffix, row in final.items():
        quota(row, final_quota, 0)
        if row.get('result_writebacks') != expected_writes:
            raise ValueError('Late writeback after final close')
    for delay in (5, 20):
        if final[f'plus_{delay}']['elapsed_ms'] - final['closed']['elapsed_ms'] < delay * 1000:
            raise ValueError('Short final observation')
    finished = event('documents_finished', final_count, 0)
    if finished['elapsed_ms'] < final['plus_20']['elapsed_ms']:
        raise ValueError('Premature finish')
    return observations


def verify_files(directory, active_anchor=False):
    """Independent post-exit byte comparison; never uses the tested converter."""
    import hashlib
    fixtures = json.loads(MANIFEST.read_text())['fixtures']
    exports = []
    for fixture in fixtures:
        source = (directory / fixture['input']).read_bytes()
        expected = (directory / fixture['expected']).read_bytes()
        for kind, data in [('input', source), ('expected', expected)]:
            if len(data) != fixture[f'{kind}_bytes'] or hashlib.sha256(data).hexdigest() != fixture[f'{kind}_sha256']:
                raise ValueError('Saved fixture differs from pinned oracle')
        for repeat in ('a', 'b'):
            name = f"actual-{fixture['mib']}mib-{repeat}.txt"
            data = (directory / name).read_bytes()
            if data != expected:
                raise ValueError(f'Saved export is not byte equal: {name}')
            exports.append(dict(file=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                                byte_equal=True, nul_count=data.count(b'\0'), crlf_count=data.count(b'\r\n'),
                                has_bom=data.startswith(b'\xef\xbb\xbf')))
    if (directory / 'actual-active-10mib.txt').exists():
        raise ValueError('Cancelled window unexpectedly exported')
    if active_anchor:
        expected = (directory / 'expected-10mib.txt').read_bytes()
        name = 'actual-retained-active-10mib.txt'
        data = (directory / name).read_bytes()
        if data != expected:
            raise ValueError('Retained-window saved export is not byte equal')
        exports.append(dict(file=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                            byte_equal=True, nul_count=data.count(b'\0'), crlf_count=data.count(b'\r\n'),
                            has_bom=data.startswith(b'\xef\xbb\xbf')))
    return exports

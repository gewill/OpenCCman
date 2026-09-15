#!/usr/bin/env python3
"""Validate native model lifecycle evidence; optionally run the private app on CI.

Retained models are reported, not treated as a protocol failure or a proven leak.
Local mode reads an existing log only. It never launches or controls an app.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'org.gewill.OpenCCman.NativeWindowLifecycleAuditAuto'
SPEC = importlib.util.spec_from_file_location('lifetime_protocol', ROOT / 'scripts/diagnose-window-lifetime.py')
PROTOCOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROTOCOL)


def validate(rows, cycles=False, documents=False):
    normalized = []
    pids = set()
    for row in rows:
        live = row.get('live_model_numbers')
        created = row.get('created_total')
        if (not isinstance(row.get('event'), str) or type(created) is not int or not isinstance(live, list)
                or any(type(number) is not int or not 1 <= number <= created for number in live)
                or len(set(live)) != len(live)
                or type(row.get('pid')) is not int
                or not isinstance(row.get('elapsed_ms'), (int, float))
                or not math.isfinite(row['elapsed_ms'])
                or type(row.get('visible_main_capable_windows')) is not int
                or not 0 <= created <= (6 if documents else 7 if cycles else 2)):
            raise ValueError('Malformed real-model record')
        pids.add(row['pid'])
        normalized.append({
            'event': row.get('event'), 'elapsed': row['elapsed_ms'] / 1000,
            'created': created, 'alive': len(live),
            'visible': row.get('visible_main_capable_windows'),
        })
    if len(pids) != 1:
        raise ValueError('Log must contain exactly one process')
    for key in ('elapsed', 'created'):
        values = [row[key] for row in normalized]
        if values != sorted(values):
            raise ValueError('Records are out of order')
    if documents:
        spec = importlib.util.spec_from_file_location('document_protocol', ROOT / 'scripts/window_document_protocol.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.validate_documents(rows)
    if cycles:
        return validate_cycles(rows)
    stages = PROTOCOL.validate(normalized)
    return {event: next(row for row in rows if row['event'] == event) for event in stages}


def validate_cycles(rows):
    def event(name, created, visible):
        matches = [row for row in rows if row['event'] == name]
        if (len(matches) != 1 or matches[0]['created_total'] != created
                or matches[0]['visible_main_capable_windows'] != visible):
            raise ValueError(f'Missing/invalid cycle event: {name}')
        return matches[0]

    starts = [r for r in rows if r['event'] == 'cycles_started']
    if len(starts) != 1 or starts[0]['created_total'] != 1:
        raise ValueError('Invalid cycle startup')
    if any(r['event'].startswith('cycles_failed') for r in rows):
        raise ValueError('Cycle driver failed')
    baseline = event('cycles_anchor_ready', 1, 1)
    fingerprint = baseline.get('anchor_fingerprint')
    if not isinstance(fingerprint, str) or len(fingerprint) != 64 or baseline.get('quota') != {}:
        raise ValueError('Invalid initial business state')
    if baseline['elapsed_ms'] - starts[0]['elapsed_ms'] < 10_000:
        raise ValueError('Initial observation too short')
    observations = {'cycles_anchor_ready': baseline}
    previous = baseline['elapsed_ms']
    for cycle in range(1, 4):
        count = 1 + 2 * cycle
        stages = {suffix: event(f'cycle_{cycle}_{suffix}', count, visible)
                  for suffix, visible in [('ready', 3), ('before_close', 3), ('closed', 1),
                                          ('plus_5', 1), ('plus_20', 1)]}
        times = [r['elapsed_ms'] for r in stages.values()]
        if times != sorted(times) or times[0] < previous:
            raise ValueError('Cycles overlapped or reordered')
        if times[1] - times[0] < 10_000:
            raise ValueError('New-window hold too short')
        for delay in (5, 20):
            if stages[f'plus_{delay}']['elapsed_ms'] - stages['closed']['elapsed_ms'] < delay * 1000:
                raise ValueError('Cycle observation shorter than declared')
        sizes = {r['number']: r for r in stages['ready'].get('content_sizes', [])}
        for number in (2 * cycle, 2 * cycle + 1):
            if number not in sizes or sizes[number]['source_bytes'] != 0 or sizes[number]['result_bytes'] != 0:
                raise ValueError('New source was not cleared')
        for suffix, row in stages.items():
            if row.get('anchor_fingerprint') != fingerprint or row.get('quota') != {}:
                raise ValueError('Anchor content/configuration/task or quota changed')
            observations[f'cycle_{cycle}_{suffix}'] = row
        previous = times[-1]
    final = {suffix: event(f'cycles_final_{suffix}', 7, 0) for suffix in ('closed', 'plus_5', 'plus_20')}
    if final['closed']['elapsed_ms'] < previous:
        raise ValueError('Final close preceded cycle completion')
    for delay in (5, 20):
        if final[f'plus_{delay}']['elapsed_ms'] - final['closed']['elapsed_ms'] < delay * 1000:
            raise ValueError('Final observation too short')
    finished = event('cycles_finished', 7, 0)
    if finished['elapsed_ms'] < final['plus_20']['elapsed_ms']:
        raise ValueError('Premature finish')
    observations.update({f'cycles_final_{key}': row for key, row in final.items()})
    observations['cycles_finished'] = finished
    return observations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--raw', type=Path, help='Read-only validation of an existing per-process JSONL')
    mode.add_argument('--app', type=Path, help='CI only: launch the isolated automatic app')
    parser.add_argument('--output', required=True, type=Path, help='New report directory')
    protocol = parser.add_mutually_exclusive_group()
    protocol.add_argument('--documents', action='store_true', help='Validate fixed document cycles and native-call close overlap')
    protocol.add_argument('--cycles', action='store_true', help='Validate three cycles with distinct new model identities')
    args = parser.parse_args()
    bundle = BUNDLE + ('Documents' if args.documents else 'Cycles' if args.cycles else '')
    if args.app and (os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'macOS'):
        parser.error('Local mode only reads --raw; launch the private app through the normal UI')
    if args.app:
        info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != bundle:
            parser.error('Refuse any app other than the isolated automatic diagnostic')
    args.output.mkdir(parents=True, exist_ok=False)
    process = None
    raw = args.raw
    result = {'valid_protocol': False, 'mode': 'ci-automatic' if args.app else 'existing-log'}
    try:
        if args.app:
            executable = args.app / 'Contents/MacOS' / info['CFBundleExecutable']
            with (args.output / 'process.log').open('w') as log:
                process = subprocess.Popen([str(executable)], stdout=log, stderr=subprocess.STDOUT)
                result['pid'] = process.pid
                result['exit_code'] = process.wait(timeout=270 if args.documents else 180 if args.cycles else 100)
            if result['exit_code'] != 0:
                raise ValueError('Diagnostic app exited unsuccessfully')
            candidates = list((Path.home() / 'Library/Caches' / bundle).glob(f'lifecycle-{process.pid}-*.jsonl'))
            if len(candidates) != 1:
                raise ValueError('Expected exactly one log for the launched process')
            raw = candidates[0]
        data = raw.read_bytes()
        (args.output / 'raw.jsonl').write_bytes(data)
        result['raw_sha256'] = hashlib.sha256(data).hexdigest()
        result['observations'] = validate([json.loads(line) for line in data.splitlines()], args.cycles, args.documents)
        result['valid_protocol'] = True
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result['error'] = str(error)
    finally:
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            result['process_exited'] = process.poll() is not None
            # Preserve incomplete evidence on failures too, without choosing a
            # different PID or treating a partial run as successful.
            candidates = list((Path.home() / 'Library/Caches' / bundle).glob(f'lifecycle-{process.pid}-*.jsonl'))
            for index, path in enumerate(candidates):
                (args.output / f'process-raw-{index}.jsonl').write_bytes(path.read_bytes())
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['valid_protocol'] else 4


if __name__ == '__main__':
    sys.exit(main())

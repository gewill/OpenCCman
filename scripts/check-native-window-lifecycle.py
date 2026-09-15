#!/usr/bin/env python3
"""Validate native model lifecycle evidence; optionally run the private app on CI.

Retained models are reported, not treated as a protocol failure or a proven leak.
Local mode reads an existing log only. It never launches or controls an app.
"""
import argparse
import hashlib
import importlib.util
import json
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


def validate(rows):
    normalized = []
    pids = set()
    for row in rows:
        live = row.get('live_model_numbers')
        created = row.get('created_total')
        if (type(created) is not int or not isinstance(live, list)
                or any(type(number) is not int or not 1 <= number <= created for number in live)
                or len(set(live)) != len(live)
                or type(row.get('pid')) is not int
                or not isinstance(row.get('elapsed_ms'), (int, float))):
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
    stages = PROTOCOL.validate(normalized)
    return {event: next(row for row in rows if row['event'] == event) for event in stages}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--raw', type=Path, help='Read-only validation of an existing per-process JSONL')
    mode.add_argument('--app', type=Path, help='CI only: launch the isolated automatic app')
    parser.add_argument('--output', required=True, type=Path, help='New report directory')
    args = parser.parse_args()
    if args.app and (os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'macOS'):
        parser.error('Local mode only reads --raw; launch the private app through the normal UI')
    if args.app:
        info = plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != BUNDLE:
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
                result['exit_code'] = process.wait(timeout=100)
            if result['exit_code'] != 0:
                raise ValueError('Diagnostic app exited unsuccessfully')
            candidates = list((Path.home() / 'Library/Caches' / BUNDLE).glob(f'lifecycle-{process.pid}-*.jsonl'))
            if len(candidates) != 1:
                raise ValueError('Expected exactly one log for the launched process')
            raw = candidates[0]
        data = raw.read_bytes()
        (args.output / 'raw.jsonl').write_bytes(data)
        result['raw_sha256'] = hashlib.sha256(data).hexdigest()
        result['observations'] = validate([json.loads(line) for line in data.splitlines()])
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
            candidates = list((Path.home() / 'Library/Caches' / BUNDLE).glob(f'lifecycle-{process.pid}-*.jsonl'))
            for index, path in enumerate(candidates):
                (args.output / f'process-raw-{index}.jsonl').write_bytes(path.read_bytes())
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['valid_protocol'] else 4


if __name__ == '__main__':
    sys.exit(main())

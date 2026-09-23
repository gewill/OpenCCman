#!/usr/bin/env python3
"""Profile a private app editor variant at the final 10 MiB width change."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import importlib.util
SPEC = importlib.util.spec_from_file_location('benchmark_app', Path(__file__).with_name('benchmark-app.py'))
BENCHMARK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BENCHMARK)


def wait_for(path, process, predicate, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if path.exists():
            try:
                report = json.loads(path.read_text())
            except (OSError, ValueError):
                report = None
            if report and predicate(report):
                return report
        if process.poll() is not None:
            raise RuntimeError(f'Diagnostic app exited before marker: {process.returncode}')
        time.sleep(0.05)
    raise TimeoutError(f'Diagnostic marker not reached within {seconds}s: {path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True, type=Path, help='Verified private benchmark build')
    parser.add_argument('--variant', choices=('unchanged', 'textkit2-no-anchor'), required=True)
    parser.add_argument('--skip-xctrace', action='store_true', help='Collect VM and heap after a matching 15-second hold')
    parser.add_argument('--malloc-stack-logging', action='store_true', help='Enable allocation backtraces in this private process')
    parser.add_argument('--capture-before', action='store_true', help='Capture VM and heap during the pre-layout pause')
    parser.add_argument('--profile-name', default='profile', help='New output directory name within private build')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', args.profile_name):
        parser.error('Profile directory name must be a single simple path segment')
    build = args.build.resolve()
    metadata = BENCHMARK.verify_build(build)
    if metadata['application_variant'] != args.variant or metadata['conditions']['suite'] != 'reflow':
        parser.error('Requires the requested private reflow build variant')
    output = build / args.profile_name
    if output.exists():
        parser.error('Profile output exists; use a fresh private build')
    output.mkdir()
    report_path = output / 'run.json'
    app = build / 'derived/Build/Products/Release/OpenCCman.app'
    command = ['open', '-n', '-W', '-a', str(app)]
    if args.malloc_stack_logging:
        command += ['--env', 'MallocStackLogging=1']
    command += ['--args', '-performance-output', str(report_path),
               '-skip-whats-new', '-AppleLanguages', '(en)', '-AppleInterfaceStyle', 'Light',
               '-performance-reflow', '-performance-reflow-profile-pause', '-performance-reflow-profile-hold']
    if args.variant == 'textkit2-no-anchor':
        command.append('-performance-require-textkit2')
    process = subprocess.Popen(command)
    owned_pid = None
    manifest = {'build_metadata_sha256': BENCHMARK.sha256(build / 'metadata.json'),
                'source_commit': metadata['source_commit'], 'variant': metadata['application_variant'],
                'profile_driver_sha256': BENCHMARK.sha256(Path(__file__)),
                'malloc_stack_logging': args.malloc_stack_logging,
                'command': ['open', '-n', '-W', '-a', '<private app>'] +
                           (['--env', 'MallocStackLogging=1'] if args.malloc_stack_logging else []) +
                           ['--args', '-performance-output', '<profile>/run.json'] + command[command.index('--args') + 3:],
                'instruments': ['Allocations', 'VM Tracker']}
    try:
        started = wait_for(report_path, process, lambda _: True, 30)
        owned_pid = started['pid']
        subprocess.run(['open', '-a', str(app)], check=True)
        paused = wait_for(report_path, process,
                          lambda r: any(x['name'] == 'profile_before_final_layout' for x in r['rows']), 120)
        if paused['pid'] != owned_pid:
            raise RuntimeError('Diagnostic PID changed')
        if args.capture_before:
            for name, capture in [('before-vmmap-summary.txt', ['vmmap', '-summary', str(owned_pid)]),
                                  ('before-heap.txt', ['heap', '-s', str(owned_pid)])]:
                with (output / name).open('w') as file:
                    result = subprocess.run(capture, stdout=file, stderr=subprocess.STDOUT, timeout=30)
                manifest[name + '_exit_code'] = result.returncode
            current = json.loads(report_path.read_text())
            manifest['before_capture_still_paused'] = current['rows'][-1]['name'] == 'profile_before_final_layout'
        if not args.skip_xctrace:
            trace = output / 'final-layout.trace'
            trace_command = ['xcrun', 'xctrace', 'record', '--instrument', 'Allocations', '--instrument', 'VM Tracker',
                             '--attach', str(owned_pid), '--time-limit', '45s', '--no-prompt', '--output', str(trace)]
            with (output / 'xctrace.log').open('w') as log:
                result = subprocess.run(trace_command, stdout=log, stderr=subprocess.STDOUT, timeout=90)
            manifest['xctrace_exit_code'] = result.returncode
            manifest['trace_exists'] = trace.exists()
        else:
            manifest['xctrace_skipped'] = True
        held = wait_for(report_path, process, lambda r: r.get('status') == 'profiling_hold', 60)
        if args.skip_xctrace:
            time.sleep(15)
        manifest['held_stages'] = [row['name'] for row in held['rows'][-5:]]
        for name, capture in [('vmmap-summary.txt', ['vmmap', '-summary', str(owned_pid)]),
                              ('vmmap-regions.txt', ['vmmap', str(owned_pid)]),
                              ('heap.txt', ['heap', '-s', str(owned_pid)])]:
            with (output / name).open('w') as file:
                result = subprocess.run(capture, stdout=file, stderr=subprocess.STDOUT, timeout=60)
            manifest[name + '_exit_code'] = result.returncode
        if args.malloc_stack_logging:
            for kind in ('NSTextParagraph', 'NSCountableTextRange', 'NSCountableTextLocation'):
                name = f'malloc-history-{kind}.txt'
                with (output / name).open('w') as file:
                    result = subprocess.run(['malloc_history', str(owned_pid), '-callTree',
                                             '-chargeSystemLibraries', kind],
                                            stdout=file, stderr=subprocess.STDOUT, timeout=120)
                manifest[name + '_exit_code'] = result.returncode
    finally:
        if owned_pid is not None:
            subprocess.run(['kill', '-TERM', str(owned_pid)], check=False)
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.terminate()
        (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if manifest.get('xctrace_exit_code') or args.capture_before and not manifest.get('before_capture_still_paused') or any(
            manifest.get(name + '_exit_code') for name in
            ('before-vmmap-summary.txt', 'before-heap.txt', 'vmmap-summary.txt', 'vmmap-regions.txt', 'heap.txt')):
        raise SystemExit(4)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Build and measure isolated native TextKit 1/2 views; never edits the app target."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Tests/Benchmarks/NativeTextKitMemory.swift'
SHORT_LINE = '汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301\r\n\r\n'
LONG_LINE = ('汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301 ' * 180) + '\r\n\r\n'
SINGLE_LINE = '汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301 '
LINES = {'short': SHORT_LINE, 'long': LONG_LINE, 'single': SINGLE_LINE}


def command(args):
    return subprocess.check_output(args, text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(size, pattern):
    line = LINES[pattern].encode('utf-8')
    return line * (size // len(line)) + b'a' * (size % len(line))


def validate(run, mode, size, width_switch=False, no_rescroll=False):
    if run.get('status') != 'complete' or run.get('mode') != mode or run.get('source_utf8_bytes') != size:
        raise ValueError('Incomplete or wrong native benchmark run')
    expected_names = ['empty_ready', 'first_display', 'scroll_start', 'scroll_middle', 'scroll_end']
    if width_switch:
        expected_names += ['width_narrow', 'width_wide']
    if [row['name'] for row in run['rows']] != expected_names:
        raise ValueError('Native benchmark stages differ')
    for row in run['rows']:
        if row['textkit2'] != (mode == 'tk2') or row['fallback_events'] or not row['visible']:
            raise ValueError('Text system changed or window not visible')
        if row['editor_utf16'] != (0 if row['name'] == 'empty_ready' else run['source_utf16']):
            raise ValueError('Editor did not retain the complete source')
        if (row['name'].startswith('scroll') or row['name'].startswith('width_') and not no_rescroll) and (not row['target_visible'] or row['scroll_attempts'] < 1):
            raise ValueError('Target character did not become visible')
        if row['rss_bytes'] <= 0 or row['physical_footprint_bytes'] <= 0:
            raise ValueError('Memory collection failed')


def partial_stages(path):
    if not path.exists():
        return None, []
    try:
        partial = json.loads(path.read_text())
    except (OSError, ValueError):
        return 'unreadable', []
    return partial.get('status'), [row.get('name') for row in partial.get('rows', [])]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='New directory outside the repository')
    parser.add_argument('--pattern', choices=LINES, default='short')
    parser.add_argument('--sizes', nargs='+', type=int, default=[1, 5, 10], help='MiB, default 1 5 10')
    parser.add_argument('--samples', type=int, default=3)
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--modes', nargs='+', choices=('tk1', 'tk2'), default=['tk1', 'tk2'])
    parser.add_argument('--width-switch', action='store_true', help='Resize 1200→800→1200 pt at the end-of-document caret')
    parser.add_argument('--narrow-width', type=int, default=800, help='First resize width in points, default 800')
    parser.add_argument('--no-rescroll', action='store_true', help='Do not restore the end caret after resizing')
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents or output.exists() or args.samples < 1 or args.timeout < 1 or any(s < 1 or s > 10 for s in args.sizes) or not 300 <= args.narrow_width < 1200 or args.no_rescroll and not args.width_switch:
        parser.error('Use a new directory outside the repository; sizes must be 1–10 MiB')
    output.mkdir(parents=True)
    binary = output / 'native-textkit-memory'
    build = ['xcrun', 'swiftc', '-O', '-g', '-target', 'arm64-apple-macos12.0', '-framework', 'AppKit', str(SOURCE), '-o', str(binary)]
    with (output / 'build.log').open('w') as log:
        subprocess.run(build, stdout=log, stderr=subprocess.STDOUT, check=True)
    metadata = {
        'schema': 1, 'source_commit': command(['git', 'rev-parse', 'HEAD']),
        'source_status': command(['git', 'status', '--short']),
        'source_sha256': sha(SOURCE), 'driver_sha256': sha(Path(__file__)), 'binary_sha256': sha(binary),
        'build_command': build[:-3] + ['Tests/Benchmarks/NativeTextKitMemory.swift', '-o', '<output>/native-textkit-memory'],
        'pattern': args.pattern, 'samples': args.samples, 'modes': args.modes,
        'width_switch': args.width_switch,
        'narrow_width_points': args.narrow_width,
        'no_rescroll': args.no_rescroll,
        'sizes_mib': args.sizes, 'window_content_points': [1200, 800],
        'target': 'arm64-apple-macos12.0', 'arch': platform.machine(),
        'macos': command(['sw_vers', '-productVersion']),
        'macos_build': command(['sw_vers', '-buildVersion']),
        'xcode': command(['xcodebuild', '-version']),
        'fixture_sha256': {}, 'run_order': 'size, sample, requested modes',
        'limit_seconds_per_process': args.timeout,
    }
    for mib in args.sizes:
        path = output / f'{args.pattern}-{mib}MiB.txt'
        path.write_bytes(fixture(mib * 1024 * 1024, args.pattern))
        metadata['fixture_sha256'][str(mib)] = sha(path)
    (output / 'metadata.json').write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n')
    runs = {}
    incomplete = []
    for mib in args.sizes:
        for sample in range(1, args.samples + 1):
            for mode in args.modes:
                name = f'{mode}-{args.pattern}-{mib}MiB-{sample:02}.json'
                path = output / name
                command_line = [str(binary), '--mode', mode, '--input', str(output / f'{args.pattern}-{mib}MiB.txt'), '--output', str(path)]
                if args.width_switch:
                    command_line += ['--width-switch', '--narrow-width', str(args.narrow_width)]
                    if args.no_rescroll:
                        command_line.append('--no-rescroll')
                try:
                    result = subprocess.run(command_line, timeout=args.timeout, capture_output=True, text=True)
                    (output / (name + '.stderr')).write_text(result.stderr)
                    if result.returncode != 0 or not path.exists():
                        raise RuntimeError(f'exit {result.returncode}; output exists: {path.exists()}')
                    run = json.loads(path.read_text())
                    validate(run, mode, mib * 1024 * 1024, args.width_switch, args.no_rescroll)
                except (subprocess.TimeoutExpired, RuntimeError, ValueError, json.JSONDecodeError) as error:
                    partial_status, completed_stages = partial_stages(path)
                    failure = {
                        'run': name, 'reason': 'timeout' if isinstance(error, subprocess.TimeoutExpired) else 'failed',
                        'detail': str(error), 'limit_seconds': args.timeout,
                        'partial_status': partial_status, 'completed_stages': completed_stages,
                    }
                    incomplete.append(failure)
                    (output / (name + '.incomplete.json')).write_text(json.dumps(failure, indent=2) + '\n')
                    print(f'{name}: {failure["reason"]}', flush=True)
                    continue
                run['metadata_sha256'] = sha(output / 'metadata.json')
                run['command'] = ['<output>/native-textkit-memory', '--mode', mode, '--input', f'<output>/{args.pattern}-{mib}MiB.txt', '--output', f'<output>/{name}']
                if args.width_switch:
                    run['command'] += ['--width-switch', '--narrow-width', str(args.narrow_width)]
                    if args.no_rescroll:
                        run['command'].append('--no-rescroll')
                path.write_text(json.dumps(run, indent=2, ensure_ascii=False) + '\n')
                runs.setdefault((mib, mode), []).append(run)
                print(f'{name}: complete', flush=True)
    summary = {}
    for (mib, mode), group in runs.items():
        key = f'{mode}-{args.pattern}-{mib}MiB'
        summary[key] = {'complete_samples': len(group), 'expected_samples': args.samples}
        for stage in (['first_display', 'scroll_middle', 'scroll_end'] +
                      (['width_narrow', 'width_wide'] if args.width_switch else [])):
            rows = [next(row for row in run['rows'] if row['name'] == stage) for run in group]
            summary[key][stage] = {}
            for metric in ('action_ms', 'rss_bytes', 'physical_footprint_bytes'):
                values = [row[metric] for row in rows]
                summary[key][stage][metric] = {'median': statistics.median(values), 'range': [min(values), max(values)]}
    (output / 'summary.json').write_text(json.dumps({'complete': summary, 'incomplete': incomplete}, indent=2) + '\n')
    if incomplete:
        raise SystemExit(4)


if __name__ == '__main__':
    main()

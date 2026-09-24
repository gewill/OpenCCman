#!/usr/bin/env python3
"""Build and measure isolated native TextKit 1/2 views; never edits the app target."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import signal
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Tests/Benchmarks/NativeTextKitMemory.swift'
SHORT_LINE = '汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301\r\n\r\n'
LONG_LINE = ('汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301 ' * 180) + '\r\n\r\n'
SINGLE_LINE = '汉语转换，软件与网络。繁體中文 👨‍👩‍👧‍👦 e\u0301 '
APP_PREFIX = '汉语转换，软件与网络。繁體中文'
LINES = {
    'short': SHORT_LINE, 'long': LONG_LINE, 'single': SINGLE_LINE,
    'app-mixed': APP_PREFIX + '👨‍👩‍👧‍👦e\u0301',
    'app-plain': APP_PREFIX,
    'app-emoji': APP_PREFIX + '👨‍👩‍👧‍👦',
    'app-combining': APP_PREFIX + 'e\u0301',
}


def command(args):
    return subprocess.check_output(args, text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(size, pattern):
    line = LINES[pattern].encode('utf-8')
    return line * (size // len(line)) + b'a' * (size % len(line))


def validate(run, mode, size, width_switch=False, no_rescroll=False, recovery=False):
    if run.get('status') != 'complete' or run.get('mode') != mode or run.get('source_utf8_bytes') != size:
        raise ValueError('Incomplete or wrong native benchmark run')
    expected_names = ['empty_ready', 'first_display', 'scroll_start', 'scroll_middle', 'scroll_end']
    if width_switch:
        expected_names += ['width_narrow', 'width_wide']
    if recovery:
        expected_names += ['recovery_before_clear', 'recovery_clear_ack',
                           'recovery_after_5s', 'recovery_after_30s']
    if [row['name'] for row in run['rows']] != expected_names:
        raise ValueError('Native benchmark stages differ')
    for row in run['rows']:
        if row['textkit2'] != (mode == 'tk2') or row['fallback_events'] or not row['visible']:
            raise ValueError('Text system changed or window not visible')
        if row.get('app_active') is False:
            raise ValueError('Native benchmark lost foreground focus')
        expected_length = 0 if row['name'] == 'empty_ready' or row['name'].startswith('recovery_after_') or row['name'] == 'recovery_clear_ack' else run['source_utf16']
        if row['editor_utf16'] != expected_length or row['storage_utf16'] != expected_length:
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


def terminate_owned_app(path, binary):
    """A timed-out `open -W` can leave its launched app running."""
    if not path.exists():
        return False
    try:
        pid = json.loads(path.read_text()).get('pid')
        if not isinstance(pid, int) or pid <= 0:
            return False
        def owns_pid():
            try:
                return str(binary) in command(['ps', '-p', str(pid), '-o', 'command='])
            except subprocess.CalledProcessError:
                return False
        if not owns_pid():
            return False
        os.kill(pid, signal.SIGTERM)
        for _ in range(25):
            if not owns_pid():
                return True
            time.sleep(0.1)
        if owns_pid():
            os.kill(pid, signal.SIGKILL)
        return True
    except (OSError, ValueError, subprocess.CalledProcessError):
        return False


def owned_pids(binary):
    """Find only running processes whose executable path is this private bundle."""
    pids = set()
    for line in command(['ps', '-axo', 'pid=,command=']).splitlines():
        fields = line.strip().split(maxsplit=1)
        if len(fields) == 2 and (fields[1] == str(binary) or fields[1].startswith(str(binary) + ' ')):
            pids.add(int(fields[0]))
    return pids


def activate_owned_app(binary, prior):
    """The AppKit process name differs from its bundle name; target its exact PID."""
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        current = owned_pids(binary) - prior
        if len(current) == 1:
            pid = current.pop()
            script = ('tell application "System Events" to set frontmost of first '
                      f'application process whose unix id is {pid} to true')
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True,
                           text=True, timeout=10)
            return pid
        if len(current) > 1:
            raise RuntimeError('Multiple new private TextKit app processes')
        time.sleep(0.05)
    raise RuntimeError('Private TextKit app did not start for foreground activation')


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
    parser.add_argument('--content-width', type=int, default=1200,
                        help='Initial native editor window width in points, default 1200')
    parser.add_argument('--no-rescroll', action='store_true', help='Do not restore the end caret after resizing')
    parser.add_argument('--recovery', action='store_true', help='Clear the native editor and measure recovery through 30 seconds')
    parser.add_argument('--activate-process', action='store_true',
                        help='Bring only the launched diagnostic PID to the foreground via System Events')
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents or output.exists() or args.samples < 1 or args.timeout < 1 or any(s < 1 or s > 10 for s in args.sizes) or not 300 <= args.narrow_width < 1200 or not 300 <= args.content_width <= 1200 or args.no_rescroll and not args.width_switch:
        parser.error('Use a new directory outside the repository; sizes must be 1–10 MiB')
    output.mkdir(parents=True)
    app = output / 'NativeTextKitMemory.app'
    binary = app / 'Contents/MacOS/native-textkit-memory'
    binary.parent.mkdir(parents=True)
    build = ['xcrun', 'swiftc', '-O', '-g', '-target', 'arm64-apple-macos12.0', '-framework', 'AppKit', str(SOURCE), '-o', str(binary)]
    with (output / 'build.log').open('w') as log:
        subprocess.run(build, stdout=log, stderr=subprocess.STDOUT, check=True)
    info = app / 'Contents/Info.plist'
    info.write_bytes(plistlib.dumps({
        'CFBundleExecutable': binary.name,
        'CFBundleIdentifier': 'org.gewill.OpenCCman.NativeTextKitMemory',
        'CFBundleName': 'NativeTextKitMemory',
        'CFBundlePackageType': 'APPL',
        'LSMinimumSystemVersion': '12.0',
    }))
    subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    metadata = {
        'schema': 1, 'source_commit': command(['git', 'rev-parse', 'HEAD']),
        'source_status': command(['git', 'status', '--short']),
        'source_sha256': sha(SOURCE), 'driver_sha256': sha(Path(__file__)),
        'binary_sha256': sha(binary), 'bundle_info_sha256': sha(info),
        'signature': 'ad hoc, verified; private diagnostic bundle only',
        'build_command': build[:-3] + ['Tests/Benchmarks/NativeTextKitMemory.swift', '-o', '<output>/NativeTextKitMemory.app/Contents/MacOS/native-textkit-memory'],
        'pattern': args.pattern, 'samples': args.samples, 'modes': args.modes,
        'width_switch': args.width_switch,
        'narrow_width_points': args.narrow_width,
        'content_width_points': args.content_width,
        'no_rescroll': args.no_rescroll,
        'recovery': args.recovery,
        'activate_process': args.activate_process,
        'sizes_mib': args.sizes, 'window_content_points': [args.content_width, 800],
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
                command_line = ['open', '-n', '-W', '-a', str(app), '--args', '--mode', mode,
                                '--input', str(output / f'{args.pattern}-{mib}MiB.txt'), '--output', str(path),
                                '--content-width', str(args.content_width)]
                if args.width_switch:
                    command_line += ['--width-switch', '--narrow-width', str(args.narrow_width)]
                    if args.no_rescroll:
                        command_line.append('--no-rescroll')
                if args.recovery:
                    command_line.append('--recovery')
                try:
                    if args.activate_process:
                        prior = owned_pids(binary)
                        process = subprocess.Popen(command_line, stdout=subprocess.PIPE,
                                                   stderr=subprocess.PIPE, text=True)
                        try:
                            activated_pid = activate_owned_app(binary, prior)
                            stdout, stderr = process.communicate(timeout=args.timeout)
                        except BaseException:
                            if process.poll() is None:
                                process.terminate()
                                process.communicate(timeout=5)
                            raise
                        result = subprocess.CompletedProcess(command_line, process.returncode, stdout, stderr)
                    else:
                        activated_pid = None
                        result = subprocess.run(command_line, timeout=args.timeout, capture_output=True, text=True)
                    (output / (name + '.stderr')).write_text(result.stderr)
                    if result.returncode != 0 or not path.exists():
                        raise RuntimeError(f'exit {result.returncode}; output exists: {path.exists()}')
                    run = json.loads(path.read_text())
                    validate(run, mode, mib * 1024 * 1024, args.width_switch, args.no_rescroll, args.recovery)
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError, RuntimeError,
                        ValueError, json.JSONDecodeError) as error:
                    terminated = terminate_owned_app(path, binary)
                    partial_status, completed_stages = partial_stages(path)
                    failure = {
                        'run': name, 'reason': 'timeout' if isinstance(error, subprocess.TimeoutExpired) else 'failed',
                        'detail': str(error), 'limit_seconds': args.timeout,
                        'partial_status': partial_status, 'completed_stages': completed_stages,
                        'owned_app_termination_requested': terminated,
                    }
                    incomplete.append(failure)
                    (output / (name + '.incomplete.json')).write_text(json.dumps(failure, indent=2) + '\n')
                    print(f'{name}: {failure["reason"]}', flush=True)
                    continue
                run['metadata_sha256'] = sha(output / 'metadata.json')
                if activated_pid is not None:
                    if run['pid'] != activated_pid:
                        raise RuntimeError('Foreground activation targeted the wrong process')
                    run['activated_pid'] = activated_pid
                run['command'] = ['open', '-n', '-W', '-a', '<output>/NativeTextKitMemory.app', '--args',
                                  '--mode', mode, '--input', f'<output>/{args.pattern}-{mib}MiB.txt', '--output',
                                  f'<output>/{name}', '--content-width', str(args.content_width)]
                if args.width_switch:
                    run['command'] += ['--width-switch', '--narrow-width', str(args.narrow_width)]
                    if args.no_rescroll:
                        run['command'].append('--no-rescroll')
                if args.recovery:
                    run['command'].append('--recovery')
                path.write_text(json.dumps(run, indent=2, ensure_ascii=False) + '\n')
                runs.setdefault((mib, mode), []).append(run)
                print(f'{name}: complete', flush=True)
    summary = {}
    for (mib, mode), group in runs.items():
        key = f'{mode}-{args.pattern}-{mib}MiB'
        summary[key] = {'complete_samples': len(group), 'expected_samples': args.samples}
        for stage in (['first_display', 'scroll_middle', 'scroll_end'] +
                      (['width_narrow', 'width_wide'] if args.width_switch else []) +
                      (['recovery_before_clear', 'recovery_clear_ack',
                        'recovery_after_5s', 'recovery_after_30s'] if args.recovery else [])):
            rows = [next(row for row in run['rows'] if row['name'] == stage) for run in group]
            summary[key][stage] = {}
            for metric in ('action_ms', 'rss_bytes', 'physical_footprint_bytes'):
                if not all(metric in row for row in rows):
                    continue
                values = [row[metric] for row in rows]
                summary[key][stage][metric] = {'median': statistics.median(values), 'range': [min(values), max(values)]}
    (output / 'summary.json').write_text(json.dumps({'complete': summary, 'incomplete': incomplete}, indent=2) + '\n')
    if incomplete:
        raise SystemExit(4)


if __name__ == '__main__':
    main()

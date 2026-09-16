#!/usr/bin/env python3
"""CI-only, sequential Release document runs of two exact commits on one host."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
LOCK = 'OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], timeout=30)


def run(args, log, timeout):
    """Bound an owned process group, including the diagnostic app on failure."""
    with log.open('w') as stream:
        process = subprocess.Popen([str(a) for a in args], stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            # The parent may exit before its children; close the owned group too.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
            raise
    if code:
        raise ValueError(f'Command exited {code}; see {log.name}')


def metrics(report):
    result = json.loads((report / 'result.json').read_text())
    if not result.get('valid_protocol') or not result.get('process_exited') or result.get('exit_code') != 0:
        raise ValueError('Incomplete document protocol')
    rows = [json.loads(line) for line in (report / 'raw.jsonl').read_text().splitlines()]
    if any(r.get('task_info_status') != 0 or r.get('rusage_status') != 0 for r in rows):
        raise ValueError('Invalid native memory measurement')
    events = {r['event']: r for r in rows}
    values = {}
    for label in ('1mib-a', '1mib-b', '10mib-a', '10mib-b'):
        start, imported, converting, exported = [events[f'document_{label}_{s}']
            for s in ('import_started', 'imported', 'conversion_started', 'exported')]
        call = exported['native_call']
        values[label] = {
            'import_to_driver_ready_ms': imported['elapsed_ms'] - start['elapsed_ms'],
            'conversion_to_verified_export_ms': exported['elapsed_ms'] - converting['elapsed_ms'],
            'native_conversion_ms': (call['end_ns'] - call['begin_ns']) / 1e6,
        }
    return {'stages': values, 'pid': result['pid'],
            'sampled_peak_footprint_bytes': max(r['physical_footprint_bytes'] for r in rows),
            'kernel_peak_rss_bytes': max(r['process_peak_rss_bytes'] for r in rows),
            'final_live_models': events['documents_final_plus_20']['live_model_numbers'],
            'successful_exports': len(result['saved_exports']),
            'raw_sha256': hashlib.sha256((report / 'raw.jsonl').read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', required=True)
    parser.add_argument('--candidate', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'macOS':
        parser.error('Execution is restricted to the isolated macOS CI runner')
    for ref in (args.baseline, args.candidate):
        if not re.fullmatch('[0-9a-f]{40}', ref) or git('rev-parse', ref + '^{commit}').decode().strip() != ref:
            parser.error('Both revisions must be complete commit SHAs')
    if args.baseline == args.candidate or git('rev-parse', 'HEAD').decode().strip() != args.candidate:
        parser.error('Candidate must be current HEAD and differ from baseline')
    if git('merge-base', args.baseline, args.candidate).decode().strip() != args.baseline:
        parser.error('Baseline must be an ancestor of candidate')
    if git('show', args.baseline + ':' + LOCK) != git('show', args.candidate + ':' + LOCK):
        parser.error('Dependency lock changed; comparison would mix editor and dependency changes')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    result = {'valid_comparison': False, 'order': ['baseline', 'candidate'],
              'baseline_sha': args.baseline, 'candidate_sha': args.candidate,
              'platform': platform.platform(), 'machine': platform.machine(),
              'scope': 'One sequential pair on the same runner. Stage times include UI/validation; not cold-start or pixel-presentation timings.',
              'cases': {}}
    worktrees = []
    began = time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix='openccman-editor-comparison-') as temporary:
            temp = Path(temporary)
            try:
                apps = {}
                for name, ref in (('baseline', args.baseline), ('candidate', args.candidate)):
                    checkout = temp / name
                    git('worktree', 'add', '--detach', str(checkout), ref)
                    worktrees.append(checkout)
                    case = output / name
                    case.mkdir()
                    prepared = temp / (name + '-prepared')
                    run(['python3', checkout / 'scripts/prepare-window-lifecycle.py',
                         '--documents', '--active-anchor', '--output', prepared], case / 'prepare.log', 60)
                    shutil.copyfile(prepared / 'preparation.json', case / 'preparation.json')
                    shutil.copyfile(checkout / LOCK, case / 'Package.resolved')
                    derived = temp / (name + '-derived')
                    # Identical settings; all dependency pins are enforced. No
                    # source or dependency cache is patched during preparation.
                    run(['xcodebuild', '-project', prepared / 'source/OpenCCman.xcodeproj',
                         '-scheme', 'OpenCCman', '-configuration', 'Release',
                         '-destination', 'platform=macOS', '-derivedDataPath', derived,
                         '-clonedSourcePackagesDirPath', temp / 'packages',
                         '-disableAutomaticPackageResolution', '-onlyUsePackageVersionsFromResolvedFile',
                         'CODE_SIGNING_ALLOWED=NO', 'ARCHS=arm64 x86_64', 'ONLY_ACTIVE_ARCH=NO',
                         'PRODUCT_BUNDLE_IDENTIFIER=org.gewill.OpenCCman.NativeWindowLifecycleAuditAutoDocumentsActiveAnchor',
                         'build'], case / 'build.log', 1200)
                    if (prepared / 'source' / LOCK).read_bytes() != (checkout / LOCK).read_bytes():
                        raise ValueError('Prepared dependency lock drifted')
                    app = derived / 'Build/Products/Release/OpenCCman.app'
                    binary = app / 'Contents/MacOS/OpenCCman'
                    (case / 'binary-sha256.txt').write_text(hashlib.sha256(binary.read_bytes()).hexdigest() + '\n')
                    run(['ditto', '-c', '-k', '--keepParent', app, case / 'OpenCCman.zip'], case / 'archive.log', 120)
                    apps[name] = (checkout, app)
                # Build both before timing either. No sample/CUA/recording.
                for name in result['order']:
                    checkout, app = apps[name]
                    case = output / name
                    run(['python3', checkout / 'scripts/check-native-window-lifecycle.py',
                         '--app', app, '--documents', '--active-anchor', '--output', case / 'run'],
                        case / 'checker.log', 730)
                    result['cases'][name] = metrics(case / 'run')
                result['valid_comparison'] = True
            finally:
                for checkout in reversed(worktrees):
                    git('worktree', 'remove', str(checkout))
                result['temporary_checkouts_removed'] = True
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result['error'] = str(error)
        result['valid_comparison'] = False
    finally:
        result['total_wall_seconds'] = time.monotonic() - began
        (output / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['valid_comparison'] else 4


if __name__ == '__main__':
    sys.exit(main())

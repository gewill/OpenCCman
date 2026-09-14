#!/usr/bin/env python3
"""Measure an isolated Release app. Never edits the developer checkout or package cache."""
import argparse
import hashlib
import json
import pathlib
import platform
import re
import shutil
import statistics
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUNDLE = 'org.gewill.OpenCCman.PerformanceAudit'
LOCK = pathlib.Path('OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved')


def command(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def replace_once(path, before, after):
    text = path.read_text()
    if text.count(before) != 1:
        raise RuntimeError(f'Injection anchor changed in {path}: {before[:80]}')
    path.write_text(text.replace(before, after, 1))


def prepare(destination):
    destination.mkdir(parents=True)
    source = destination / 'source'
    shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns('.git', '.build', '__pycache__', '*.xcuserstate', 'xcuserdata'))
    app = source / 'OpenCCman/OpenCCmanApp.swift'
    replace_once(app, '    IAPManager.shared.configure()', '    AppPerformanceAudit.prepare()\n    IAPManager.shared.configure()')
    replace_once(source / 'OpenCCman/Scene/RootView.swift', '      AppDelegate.registerReadyWindow(window)',
                 '      AppDelegate.registerReadyWindow(window)\n      AppPerformanceAudit.shared.register(viewModel, window: window)')
    replace_once(source / 'OpenCCman/IAPManager.swift', '    Purchases.shared.delegate = self',
                 '    // Benchmark: do not overwrite isolated synthetic entitlement preferences.')
    replace_once(source / 'OpenCCman/AppDelegate.swift',
                 '    func applicationDidFinishLaunching(_ notification: Notification) {',
                 '    func applicationDidFinishLaunching(_ notification: Notification) {\n      DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }')
    project = source / 'OpenCCman.xcodeproj/project.pbxproj'
    replace_once(project, '/* Begin PBXBuildFile section */', '''/* Begin PBXBuildFile section */
        A01800000000000000000001 = {isa = PBXBuildFile; fileRef = A01800000000000000000002; };''')
    replace_once(project, '/* Begin PBXFileReference section */', '''/* Begin PBXFileReference section */
        A01800000000000000000002 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/Benchmarks/AppPerformanceAudit.swift; sourceTree = SOURCE_ROOT; };''')
    replace_once(project, '3863CECBA90A40108CB62210 /* ControlSizingGallery.swift in Sources */,',
                 '3863CECBA90A40108CB62210 /* ControlSizingGallery.swift in Sources */,\n                A01800000000000000000001,')
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True, help='New directory outside the repository')
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--start-index', type=int, default=1)
    parser.add_argument('--packages', type=pathlib.Path, help='Existing SourcePackages copied privately with APFS clones')
    parser.add_argument('--build-only', action='store_true', help='Build now, measure later without competing compiler load')
    parser.add_argument('--engine-revision', help='Comparison only: full wrapper SHA in the private snapshot')
    parser.add_argument('--reuse-build', action='store_true', help='Rerun the already built, recorded source snapshot')
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.samples < 1 or args.start_index < 1 or args.output == ROOT or ROOT in args.output.parents:
        parser.error('Use positive samples and an output directory outside this repository')
    if args.engine_revision and not re.fullmatch(r'[0-9a-f]{40}', args.engine_revision):
        parser.error('Engine comparison revision must be a full lowercase SHA')
    source = args.output / 'source'
    if not args.reuse_build:
        source = prepare(args.output)
        packages = args.output / 'packages'
        if args.packages:
            subprocess.run(['cp', '-cR', str(args.packages.resolve()), str(packages)], check=True)
        if args.engine_revision:
            lock = json.loads((source / LOCK).read_text())
            pin = next(p for p in lock['pins'] if p['identity'] == 'swiftyopencc')
            original = pin['state']['revision']
            pin['state'] = {'revision': args.engine_revision}
            (source / LOCK).write_text(json.dumps(lock, indent=2) + '\n')
            replace_once(source / 'OpenCCman.xcodeproj/project.pbxproj',
                         'revision = ' + original, 'revision = ' + args.engine_revision)
        expected_lock = (source / LOCK).read_bytes()
        metadata = {'schema': 1, 'source_commit': command(['git', 'rev-parse', 'HEAD'], cwd=ROOT),
                    'comparison_engine_override': args.engine_revision,
                    'source_status': command(['git', 'status', '--short'], cwd=ROOT),
                    'pins': json.loads((source / LOCK).read_text()), 'os': platform.platform(),
                    'hardware': command(['sysctl', '-n', 'hw.model', 'hw.memsize', 'machdep.cpu.brand_string']),
                    'xcode': command(['xcodebuild', '-version']), 'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    'source_hashes': {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                                      for p in sorted(source.rglob('*')) if p.is_file() and p.suffix in ('.swift', '.pbxproj', '.py')},
                    'conditions': ['Release -O; isolated bundle/preferences; ad-hoc signed; sandbox disabled for harness output',
                                   'RevenueCat configure retained; entitlement refresh/delegate/review/WhatsNew suppressed; synthetic Pro preferences',
                                   '1200x800 content points; en locale/light theme via launch arguments',
                                   'fresh process; one reopen event after initialization; handshake included; OS/file caches NOT purged; not cold boot or first photon',
                                   'userInitiated activity prevents App Nap for the measured protocol; app foreground state recorded at each stage',
                                   'two additional fixed-size NSHostingView windows use explicit /home route; not native WindowGroup lifecycle evidence',
                                   'layout flush waits for both native editors to acknowledge exact model text, then displayIfNeeded; not presentation timestamp',
                                   '20ms main timer gap includes harness work and scheduling; not frame rate',
                                   'RSS high water includes earlier stages; footprint and RSS are different metrics']}
        (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
        build = ['xcodebuild', '-project', str(source / 'OpenCCman.xcodeproj'), '-scheme', 'OpenCCman',
                 '-configuration', 'Release', '-destination', 'platform=macOS', '-derivedDataPath', str(args.output / 'derived'),
                 '-clonedSourcePackagesDirPath', str(packages), '-disableAutomaticPackageResolution', '-onlyUsePackageVersionsFromResolvedFile',
                 'PRODUCT_BUNDLE_IDENTIFIER=' + BUNDLE, 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGN_ENTITLEMENTS=', 'ENABLE_APP_SANDBOX=NO', 'build']
        with (args.output / 'build.log').open('w') as log:
            subprocess.run(build, stdout=log, stderr=subprocess.STDOUT, check=True)
        if (source / LOCK).read_bytes() != expected_lock:
            raise RuntimeError('Dependency drift during build')
        app = args.output / 'derived/Build/Products/Release/OpenCCman.app'
        subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
        revisions = {}
        for checkout in (packages / 'checkouts').iterdir():
            if checkout.is_dir():
                if command(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=checkout):
                    raise RuntimeError(f'Modified dependency checkout: {checkout.name}')
                revisions[checkout.name.lower()] = command(['git', 'rev-parse', 'HEAD'], cwd=checkout)
        for pin in metadata['pins']['pins']:
            if revisions.get(pin['identity']) != pin['state']['revision']:
                raise RuntimeError(f'Dependency checkout does not match pin: {pin["identity"]}')
        metadata['resolved_checkout_revisions'] = revisions
        (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    app = args.output / 'derived/Build/Products/Release/OpenCCman.app'
    if args.build_only:
        return
    for index in range(args.start_index, args.start_index + args.samples):
        output = args.output / f'run-{index:02}.json'
        if output.exists():
            raise RuntimeError(f'Refusing to overwrite existing sample {output}')
        launch = time.monotonic()
        process = subprocess.Popen(['open', '-n', '-W', '-a', str(app), '--args', '-performance-output', str(output),
                                    '-skip-whats-new', '-AppleLanguages', '(en)', '-AppleInterfaceStyle', 'Light'])
        # LaunchServices can create this SwiftUI process without an untitled window.
        # Send one reopen event after initialization; include this handshake in the
        # process-start metric instead of waiting for a human activation.
        handshake_deadline = time.monotonic() + 30
        while not output.exists() and process.poll() is None and time.monotonic() < handshake_deadline:
            time.sleep(0.02)
        if output.exists():
            subprocess.run(['open', '-a', str(app)], check=True)
        try:
            process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            # Kill only the PID written by this owned harness, leaving other apps alone.
            if output.exists():
                pid = json.loads(output.read_text()).get('pid')
                if pid:
                    subprocess.run(['kill', '-TERM', str(pid)], check=False)
            process.terminate()
            raise
        result = json.loads(output.read_text())
        result['launch_to_exit_seconds'] = time.monotonic() - launch
        output.write_text(json.dumps(result, indent=2) + '\n')
        if result['status'] != 'complete':
            raise RuntimeError(result)
        print(f'Sample {index}: complete', flush=True)
        time.sleep(1)
    runs = [json.loads(p.read_text()) for p in sorted(args.output.glob('run-*.json'))]
    summary = {}
    for name in [r['name'] for r in runs[0]['rows']]:
        rows = [next(r for r in run['rows'] if r['name'] == name) for run in runs]
        keys = ['process_cpu_ms', 'process_start_to_root_layout_ms', 'app_init_to_root_layout_ms', 'model_completion_ms', 'result_layout_flush_ms', 'read_decode_ms', 'source_layout_flush_ms']
        summary[name] = {key: statistics.median(r[key] for r in rows) for key in keys if key in rows[0]}
        summary[name]['median_memory'] = {key: statistics.median(r['memory'][key] for r in rows) for key in rows[0]['memory']}
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()

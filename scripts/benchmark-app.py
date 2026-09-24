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

from app_performance import TIMINGS, PROTOCOL, sha256, source_hashes, artifact_hashes, validate_pins

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


def prepare_textkit2_no_anchor(source):
    """Replace the native editor only in the private benchmark snapshot.

    The legacy glyph-based scroll keeper is intentionally excluded so this
    first app-bridge comparison can isolate it as a separate integration axis.
    """
    editor = source / 'OpenCCman/View/WorkspaceTextEditor.swift'
    replace_once(editor, '''      let storage = NSTextStorage()
      let layout = NSLayoutManager()
      layout.allowsNonContiguousLayout = true
      layout.backgroundLayoutEnabled = false
      storage.addLayoutManager(layout)
      let container = NSTextContainer(containerSize: NSSize(width: 1, height: CGFloat.greatestFiniteMagnitude))
      container.widthTracksTextView = true
      container.lineFragmentPadding = 0
      layout.addTextContainer(container)
      let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), textContainer: container)''',
                 '''      let editor = NSTextView(usingTextLayoutManager: true)
      editor.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
      editor.textContainer?.widthTracksTextView = true
      editor.textContainer?.lineFragmentPadding = 0''')
    replace_once(editor, '      scrollKeeper.attach(editor)\n      return viewport',
                 '      // Private TextKit 2 benchmark: exclude the legacy glyph-based scroll keeper.\n      return viewport')


def prepare_textkit2_modern_anchor(source):
    prepare_textkit2_no_anchor(source)
    editor = source / 'OpenCCman/View/WorkspaceTextEditor.swift'
    replace_once(editor, '    private let scrollKeeper = WorkspaceScrollKeeper()',
                 '    private let scrollKeeper = ModernWorkspaceScrollKeeper()')
    replace_once(editor,
                 '      // Private TextKit 2 benchmark: exclude the legacy glyph-based scroll keeper.\n      return viewport',
                 '      scrollKeeper.attach(editor)\n      return viewport')
    keeper = source / 'OpenCCman/View/WorkspaceScrollKeeper.swift'
    modern = (source / 'Tests/Benchmarks/ModernWorkspaceScrollKeeper.swift').read_text()
    replace_once(keeper, '  }\n\n#endif', '  }\n\n' + modern + '\n#endif')


def environment():
    return {'os': {'version': command(['sw_vers', '-productVersion']),
                   'build': command(['sw_vers', '-buildVersion']), 'arch': platform.machine()},
            'hardware': command(['sysctl', '-n', 'hw.model', 'hw.memsize', 'machdep.cpu.brand_string']),
            'xcode': command(['xcodebuild', '-version'])}


def checkout_revisions(packages):
    revisions = {}
    for checkout in (packages / 'checkouts').iterdir():
        if checkout.is_dir():
            if command(['git', 'status', '--porcelain', '--untracked-files=all'], cwd=checkout):
                raise ValueError(f'Modified dependency checkout: {checkout.name}')
            revisions[checkout.name.lower()] = command(['git', 'rev-parse', 'HEAD'], cwd=checkout)
    return revisions


def verify_build(output):
    marker_path = output / 'build-complete.json'
    if not marker_path.exists():
        raise ValueError('Missing successful build verification; rebuild in a new directory')
    marker = json.loads(marker_path.read_text())
    if marker['metadata_sha256'] != sha256(output / 'metadata.json'):
        raise ValueError('Build metadata changed')
    metadata = json.loads((output / 'metadata.json').read_text())
    validate_pins(metadata)
    if metadata['schema'] != PROTOCOL:
        raise ValueError('Measurement protocol changed; rebuild')
    if json.loads((output / 'source' / LOCK).read_text()) != metadata['pins']:
        raise ValueError('Dependency lock changed')
    if source_hashes(output / 'source') != metadata['source_hashes']:
        raise ValueError('Built source changed')
    if checkout_revisions(output / 'packages') != metadata['resolved_checkout_revisions']:
        raise ValueError('Dependency checkout changed')
    if artifact_hashes(output / 'derived/Build/Products/Release/OpenCCman.app') != marker['app_hashes']:
        raise ValueError('Built app changed')
    for key, value in environment().items():
        if metadata[key] != value:
            raise ValueError('Build environment changed: ' + key)
    for name in ('benchmark-app.py', 'app_performance.py'):
        if sha256(ROOT / 'scripts' / name) != metadata['source_hashes']['scripts/' + name]:
            raise ValueError('Measurement driver changed; rebuild')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True, help='New directory outside the repository')
    parser.add_argument('--reflow', action='store_true', help='Measure native scrolling and layout commands instead of conversion suite')
    parser.add_argument('--timeout', type=int, default=600, help='Per-process deadline in seconds, preserving partial output')
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--start-index', type=int, default=1)
    parser.add_argument('--packages', type=pathlib.Path, help='Existing SourcePackages copied privately with APFS clones')
    parser.add_argument('--build-only', action='store_true', help='Build now, measure later without competing compiler load')
    parser.add_argument('--disable-background-layout', action='store_true', help='Explicit isolated TextKit 1 experiment')
    parser.add_argument('--textkit2-no-anchor', action='store_true', help='Private TextKit 2 app bridge without the legacy glyph-based anchor keeper')
    parser.add_argument('--textkit2-modern-anchor', action='store_true', help='Private TextKit 2 app bridge with a diagnostic visible-character anchor')
    parser.add_argument('--middle-composed', action='store_true', help='Use the midpoint composed character and its full range for visibility geometry')
    parser.add_argument('--single-paragraph', action='store_true', help='Use one unbroken 1/5/10 MiB paragraph in the reflow suite')
    parser.add_argument('--engine-revision', help='Comparison only: full wrapper SHA in the private snapshot')
    parser.add_argument('--comparison-no-nul', action='store_true', help='Use the common-input comparison fixture without U+0000; default correctness fixture remains unchanged')
    parser.add_argument('--reuse-build', action='store_true', help='Rerun the already built, recorded source snapshot')
    args = parser.parse_args()
    args.output = args.output.resolve()
    if args.samples < 1 or args.start_index < 1 or args.timeout < 1 or args.output == ROOT or ROOT in args.output.parents:
        parser.error('Use positive samples and an output directory outside this repository')
    if args.engine_revision and not re.fullmatch(r'[0-9a-f]{40}', args.engine_revision):
        parser.error('Engine comparison revision must be a full lowercase SHA')
    if (args.textkit2_no_anchor or args.textkit2_modern_anchor) and (not args.reflow or args.disable_background_layout):
        parser.error('The TextKit 2 bridge variant requires --reflow and excludes TextKit 1 layout overrides')
    if args.textkit2_no_anchor and args.textkit2_modern_anchor:
        parser.error('Select one private TextKit 2 variant')
    if args.single_paragraph and not args.reflow:
        parser.error('The single-paragraph fixture requires --reflow')
    if args.single_paragraph and args.comparison_no_nul:
        parser.error('Select one input profile')
    if args.reuse_build and (args.engine_revision or args.disable_background_layout or args.textkit2_no_anchor or args.textkit2_modern_anchor or args.middle_composed or args.single_paragraph or args.packages or args.comparison_no_nul):
        parser.error('Reuse the recorded build without source/dependency overrides')
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
        if args.disable_background_layout:
            replace_once(source / 'OpenCCman/View/WorkspaceScrollKeeper.swift',
                         '      self.clip = clip\n      size = clip.bounds.size',
                         '      self.clip = clip\n      size = clip.bounds.size\n      editor.layoutManager?.backgroundLayoutEnabled = false')
        if args.textkit2_modern_anchor:
            prepare_textkit2_modern_anchor(source)
        elif args.textkit2_no_anchor:
            prepare_textkit2_no_anchor(source)
        expected_lock = (source / LOCK).read_bytes()
        commit = command(['git', 'rev-parse', 'HEAD'], cwd=ROOT)
        metadata = {'schema': PROTOCOL, 'source_commit': commit, 'measurement_harness_commit': commit,
                    'comparison_engine_override': args.engine_revision,
                    'application_variant': ('textkit2-modern-anchor' if args.textkit2_modern_anchor else
                                            'textkit2-no-anchor' if args.textkit2_no_anchor else
                                            'background-layout-off' if args.disable_background_layout else 'unchanged'),
                    'source_status': command(['git', 'status', '--short'], cwd=ROOT),
                    'pins': json.loads((source / LOCK).read_text()), **environment(),
                    'started_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    'source_hashes': source_hashes(source),
                    'conditions': {'protocol': PROTOCOL, 'suite': 'reflow' if args.reflow else 'conversion', 'configuration': 'Release -O',
                        'input_profile': ('single-paragraph' if args.single_paragraph else
                                          'comparison-without-nul' if args.comparison_no_nul else 'default'),
                        'isolation': 'ad-hoc signature; diagnostic bundle/preferences; sandbox disabled',
                        'sdk': 'RevenueCat configure retained; synthetic Pro; refresh/delegate/review/WhatsNew suppressed',
                        'window_content_points': [1200, 800], 'locale': 'en', 'theme': 'Light',
                        'launch': 'fresh process; one reopen event after initialization; OS/file caches not purged',
                        'activity': 'userInitiatedAllowingIdleSystemSleep; foreground required after root ready',
                        'extra_windows': 'two fixed-size hosting windows at /home; not native WindowGroup lifecycle',
                        'layout': 'role + precomputed UTF16 length acknowledgement and display flush; exact UTF8 validation after timer; not presentation',
                        'navigation_target': ('middle composed character with full composed-range geometry' if args.middle_composed else
                                              'middle next ordinary Han glyph within 128 UTF16 units; start/end composed-character boundary'),
                        'timer': '20ms main timer gap includes harness work and scheduling; not FPS',
                        'memory': 'RSS high water includes all previous work, fixtures and validation'}}
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
        metadata['resolved_checkout_revisions'] = checkout_revisions(packages)
        validate_pins(metadata)
        (args.output / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
        marker = {'metadata_sha256': sha256(args.output / 'metadata.json'), 'app_hashes': artifact_hashes(app)}
        (args.output / 'build-complete.json').write_text(json.dumps(marker, indent=2) + '\n')
    metadata = verify_build(args.output)
    if metadata['conditions']['suite'] != ('reflow' if args.reflow else 'conversion'):
        raise ValueError('Measurement suite differs from the recorded build')
    app = args.output / 'derived/Build/Products/Release/OpenCCman.app'
    if args.build_only:
        return
    for index in range(args.start_index, args.start_index + args.samples):
        output = args.output / f'run-{index:02}.json'
        if output.exists():
            raise RuntimeError(f'Refusing to overwrite existing sample {output}')
        launch = time.monotonic()
        profile_args = ['-performance-comparison-no-nul'] if metadata['conditions']['input_profile'] == 'comparison-without-nul' else []
        if metadata['conditions']['input_profile'] == 'single-paragraph':
            profile_args.append('-performance-single-paragraph')
        if metadata['application_variant'] in ('textkit2-no-anchor', 'textkit2-modern-anchor'):
            profile_args.append('-performance-require-textkit2')
        if metadata['conditions']['navigation_target'].startswith('middle composed character'):
            profile_args.append('-performance-middle-composed')
        process = subprocess.Popen(['open', '-n', '-W', '-a', str(app), '--args', '-performance-output', str(output),
                                    '-skip-whats-new', '-AppleLanguages', '(en)', '-AppleInterfaceStyle', 'Light']
                                   + (['-performance-reflow'] if args.reflow else []) + profile_args)
        # LaunchServices can create this SwiftUI process without an untitled window.
        # Send one reopen event after initialization; include this handshake in the
        # process-start metric instead of waiting for a human activation.
        handshake_deadline = time.monotonic() + 30
        while not output.exists() and process.poll() is None and time.monotonic() < handshake_deadline:
            time.sleep(0.02)
        if output.exists():
            subprocess.run(['open', '-a', str(app)], check=True)
        try:
            process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            # Kill only the PID written by this owned harness, leaving other apps alone.
            if output.exists():
                pid = json.loads(output.read_text()).get('pid')
                if pid:
                    subprocess.run(['kill', '-TERM', str(pid)], check=False)
            process.terminate()
            raise
        result = json.loads(output.read_text())
        result['metadata_sha256'] = sha256(args.output / 'metadata.json')
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
        keys = (*TIMINGS, 'action_ms')
        summary[name] = {key: statistics.median(r[key] for r in rows) for key in keys if key in rows[0]}
        summary[name]['median_memory'] = {key: statistics.median(r['memory'][key] for r in rows) for key in rows[0]['memory']}
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Prepare, but never launch, an isolated native WindowGroup diagnostic source copy."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUNDLE = 'org.gewill.OpenCCman.NativeWindowLifecycleAudit'
LOCK = pathlib.Path('OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved')


def replace_once(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise ValueError(f'Injection anchor not unique in {path.name}: {old!r}')
    path.write_text(text.replace(old, new, 1))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(output, automatic=False):
    output = output.resolve()
    if output == ROOT or ROOT.is_relative_to(output):
        raise ValueError('Output must not contain the checkout')
    output.mkdir(parents=True, exist_ok=False)
    source = output / 'source'
    source.mkdir()
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    for name in filter(None, tracked):
        path = ROOT / name
        if path.is_file():
            destination = source / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
    harness = pathlib.Path('Tests/Benchmarks/NativeWindowLifecycleAudit.swift')
    (source / harness).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / harness, source / harness)
    bundle = BUNDLE + ('Auto' if automatic else '')
    modified = [pathlib.Path(x) for x in [
        'OpenCCman/OpenCCmanApp.swift', 'OpenCCman/Scene/HomeViewModel.swift',
        'OpenCCman/AppDelegate.swift', 'OpenCCman/Info.plist', 'OpenCCman.xcodeproj/project.pbxproj',
        'OpenCCman/Services/GlobalShortcutService.swift',
    ]]
    before = {str(p): digest(ROOT / p) for p in modified}
    replace_once(source / modified[0], '    IAPManager.shared.configure()', '    NativeWindowLifecycleAudit.prepare()')
    replace_once(source / modified[0], '            checkPro()', '            // Diagnostic isolation: no purchase status refresh.')
    if automatic:
        replace_once(source / modified[0], '    WindowGroup {', '    WindowGroup(id: "lifetime") {')
        replace_once(source / modified[0], '      appContent\n',
                     '      appContent\n      .background(LifetimeDriverView())\n')
        replace_once(source / modified[0],
                     'skipAutomatic: ProcessInfo.processInfo.arguments.contains("-skip-whats-new")',
                     'skipAutomatic: true')
        # Share the tested fixed-timing driver; only adapt its logging sink.
        driver = (ROOT / 'Tests/Benchmarks/WindowLifetimeDriver.swift').read_text()
        driver = driver.replace('ProbeLog.shared.record', 'NativeWindowLifecycleAudit.stage')
        with (source / harness).open('a') as file:
            file.write('\nimport SwiftUI\n' + driver + '''
extension NativeWindowLifecycleAudit {
  static func stage(_ event: String) { shared.record(event) }
}
''')
        replace_once(source / harness, BUNDLE, bundle)
    replace_once(source / modified[1], '  init() {', '  private var lifecycleAuditNumber = 0\n\n  init() {\n    lifecycleAuditNumber = NativeWindowLifecycleAudit.created(self)')
    replace_once(source / modified[1], '  deinit {', '  deinit {\n    NativeWindowLifecycleAudit.released(ObjectIdentifier(self), number: lifecycleAuditNumber)')
    replace_once(source / modified[2], '      NSApp.servicesProvider = TextConversionService.shared',
                 '      // Diagnostic isolation: do not register a competing Services provider.')
    replace_once(source / modified[2], '      _ = GlobalShortcutService.shared',
                 '      // Diagnostic isolation: do not register competing global shortcuts.')
    # Activation/menu callbacks can lazily instantiate this singleton too.
    replace_once(source / modified[5], '        setupKeyboardShortcuts()',
                 '        // Diagnostic isolation: no global key registration.')
    info = plistlib.loads((source / modified[3]).read_bytes())
    info.pop('NSServices')
    (source / modified[3]).write_bytes(plistlib.dumps(info))
    project = source / modified[4]
    replace_once(project, '/* Begin PBXBuildFile section */', '''/* Begin PBXBuildFile section */
        A01810000000000000000001 = {isa = PBXBuildFile; fileRef = A01810000000000000000002; };''')
    replace_once(project, '/* Begin PBXFileReference section */', '''/* Begin PBXFileReference section */
        A01810000000000000000002 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Tests/Benchmarks/NativeWindowLifecycleAudit.swift; sourceTree = SOURCE_ROOT; };''')
    replace_once(project, '3863CECBA90A40108CB62210 /* ControlSizingGallery.swift in Sources */,',
                 '3863CECBA90A40108CB62210 /* ControlSizingGallery.swift in Sources */,\n                A01810000000000000000001,')
    # RootView/model ownership and dependencies remain identical in both modes.
    unchanged = [LOCK, pathlib.Path('OpenCCman/Scene/RootView.swift')]
    for p in unchanged:
        if (ROOT / p).read_bytes() != (source / p).read_bytes():
            raise ValueError(f'Unexpected mutation: {p}')
    metadata = {
        'protocol': 'native-window-lifecycle-automatic-1' if automatic else 'native-window-lifecycle-1',
        'bundle_id': bundle, 'automatic': automatic,
        'diagnostic_minimum_macos': '13.0' if automatic else '11.0',
        'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True),
        'harness_sha256': digest(ROOT / harness), 'preparer_sha256': digest(pathlib.Path(__file__)),
        'prepared_harness_sha256': digest(source / harness),
        'modified_source_sha256': {str(p): {'before': before[str(p)], 'after': digest(source / p)} for p in modified},
        'unchanged_source_sha256': {str(p): digest(source / p) for p in unchanged},
        'variant': 'Real WindowGroup/Router/RootView; weak model logging; isolated free preferences; no purchase setup or Services/global shortcut registration',
        'run': ('Not launched. Automatic diagnostic requires macOS 13+: native openWindow/performClose; first/pair hold 10 seconds, then +5/+20 observations after each close. No AX queries required.'
                if automatic else 'Not launched. Open/close windows only through the actual app UI; collect per-process JSONL from the diagnostic bundle cache.'),
    }
    if automatic:
        metadata['driver_sha256'] = digest(ROOT / 'Tests/Benchmarks/WindowLifetimeDriver.swift')
    (output / 'preparation.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True, help='New directory, never overwritten')
    parser.add_argument('--automatic', action='store_true', help='Append the fixed native WindowGroup driver; build this private copy with MACOSX_DEPLOYMENT_TARGET=13.0')
    args = parser.parse_args()
    prepare(args.output, args.automatic)

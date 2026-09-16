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


def prepare(output):
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
    modified = [pathlib.Path(x) for x in [
        'OpenCCman/OpenCCmanApp.swift', 'OpenCCman/Scene/HomeViewModel.swift',
        'OpenCCman/AppDelegate.swift', 'OpenCCman/Info.plist', 'OpenCCman.xcodeproj/project.pbxproj',
        'OpenCCman/Services/GlobalShortcutService.swift',
    ]]
    before = {str(p): digest(ROOT / p) for p in modified}
    replace_once(source / modified[0], '    IAPManager.shared.configure()', '    NativeWindowLifecycleAudit.prepare()')
    replace_once(source / modified[0], '            checkPro()', '            // Diagnostic isolation: no purchase status refresh.')
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
    # No private dependency lock/cache changes and no RootView/WindowGroup rewrite.
    unchanged = [LOCK, pathlib.Path('OpenCCman/Scene/RootView.swift')]
    for p in unchanged:
        if (ROOT / p).read_bytes() != (source / p).read_bytes():
            raise ValueError(f'Unexpected mutation: {p}')
    metadata = {
        'protocol': 'native-window-lifecycle-1', 'bundle_id': BUNDLE,
        'source_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True),
        'harness_sha256': digest(ROOT / harness), 'preparer_sha256': digest(pathlib.Path(__file__)),
        'modified_source_sha256': {str(p): {'before': before[str(p)], 'after': digest(source / p)} for p in modified},
        'unchanged_source_sha256': {str(p): digest(source / p) for p in unchanged},
        'variant': 'Real WindowGroup/Router/RootView; weak model logging; isolated free preferences; no purchase setup or Services/global shortcut registration',
        'run': 'Not launched. Open/close windows only through the actual app UI; collect per-process JSONL from the diagnostic bundle cache.',
    }
    (output / 'preparation.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True, help='New directory, never overwritten')
    prepare(parser.parse_args().output)

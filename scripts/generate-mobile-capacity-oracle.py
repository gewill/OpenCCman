#!/usr/bin/env python3
"""Build a pinned Mac whole-text reference, then hash each fixture in seven modes.

This intentionally uses whole-file memory on Mac, never on the mobile App.
No streaming implementation is linked. Outputs are reference hashes, not a
capacity/performance pass; each pair runs in a fresh subprocess.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MODES = ['simplified', 'traditional', 'traditional-taiwan-idiom', 'taiwan',
         'taiwan-idiom', 'hong-kong', 'hong-kong-taiwan-idiom']


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        while block := stream.read(256 * 1024):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixtures', required=True, type=Path)
    p.add_argument('--opencc-path', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    fixtures = a.fixtures.resolve()
    wrapper = a.opencc_path.resolve()
    manifest = json.loads((fixtures / 'manifest.json').read_text())
    lock = json.loads((ROOT / 'OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())
    pin = next(x['state']['revision'] for x in lock['pins'] if x['identity'] == 'swiftyopencc')
    revision = subprocess.check_output(['git', '-C', str(wrapper), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(['git', '-C', str(wrapper), 'status', '--porcelain'], text=True).strip()
    if dirty or revision != pin or manifest['wrapper_sha'] != pin:
        p.error('Require a clean wrapper at app and fixture locked revision')
    rows = manifest['fixtures']
    names = [r['file'] for r in rows]
    if not names or len(set(names)) != len(names):
        p.error('Require nonempty unique fixture names')
    for row in rows:
        file = fixtures / row['file']
        if Path(row['file']).name != row['file'] or file.is_symlink():
            p.error('Fixture must be a direct regular file')
        if not file.is_file() or file.stat().st_size != row['bytes'] or sha(file) != row['sha256']:
            p.error(f'Fixture integrity mismatch: {row["file"]}')
    a.output.mkdir(parents=True, exist_ok=False)
    package = a.output.resolve() / 'package'
    sources = package / 'Sources/Oracle'
    sources.mkdir(parents=True)
    source = ROOT / 'Tests/Benchmarks/MobileCapacityOracle.swift'
    shutil.copy2(source, sources / 'Main.swift')
    (package / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Oracle", platforms: [.macOS(.v12)],
 dependencies: [.package(name: "swiftyopencc", path: WRAPPER)],
 targets: [.executableTarget(name: "Oracle", dependencies: [.product(name: "OpenCC", package: "swiftyopencc")])])
'''.replace('WRAPPER', json.dumps(str(wrapper))))
    with (a.output / 'build.log').open('w') as log:
        subprocess.run(['swift', 'build', '-c', 'release', '--package-path', str(package)],
                       stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    binary = package / '.build/release/Oracle'
    report = {'schema': 1, 'purpose': 'independent reference only; not device acceptance',
              'wrapper_sha': pin, 'oracle_source_sha256': sha(source), 'binary_sha256': sha(binary),
              'fixture_manifest_sha256': sha(fixtures / 'manifest.json'), 'rows': []}
    results = a.output / 'results'
    results.mkdir()
    for row in rows:
        for mode in MODES:
            result = results / f'{row["file"]}.{mode}.json'
            subprocess.run([str(binary), str(fixtures / row['file']), mode, str(result)],
                           check=True, timeout=600)
            measured = json.loads(result.read_text())
            if measured['input_sha256'] != row['sha256'] or measured['input_bytes'] != row['bytes']:
                raise RuntimeError('Input changed during reference generation')
            report['rows'].append({'fixture': row['file'], **measured})
            print(f'Reference: {row["file"]} / {mode}', flush=True)
    (a.output / 'oracle.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {len(report["rows"])} independent whole-text references; device tests NOT run')


if __name__ == '__main__':
    main()

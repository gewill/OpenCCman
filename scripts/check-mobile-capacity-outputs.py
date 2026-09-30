#!/usr/bin/env python3
"""Compare the actual mobile file service on Mac with independent oracle hashes.

No UI or physical-device capacity claim is made by this check.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [f'OpenCCman/Services/{s}.swift' for s in (
    'ChineseConversionService', 'TextFileService', 'StreamingConversionPump',
    'FileConversionPolicy', 'MobileLargeFileService')]
SOURCES.append('Tests/Benchmarks/MobileCapacityServiceProbe.swift')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        while b := f.read(256 * 1024):
            h.update(b)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixtures', required=True, type=Path)
    p.add_argument('--oracle', required=True, type=Path)
    p.add_argument('--opencc-path', required=True, type=Path)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    fixture_root = a.fixtures.resolve()
    oracle = json.loads(a.oracle.read_text())
    manifest = json.loads((fixture_root / 'manifest.json').read_text())
    wrapper = a.opencc_path.resolve()
    lock = json.loads((ROOT / 'OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())
    pin = next(x['state']['revision'] for x in lock['pins'] if x['identity'] == 'swiftyopencc')
    revision = subprocess.check_output(['git', '-C', str(wrapper), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(['git', '-C', str(wrapper), 'status', '--porcelain'], text=True).strip()
    if dirty or revision != pin or oracle['wrapper_sha'] != pin or manifest['wrapper_sha'] != pin:
        p.error('Require clean, identically pinned wrapper and evidence')
    if sha(fixture_root / 'manifest.json') != oracle['fixture_manifest_sha256']:
        p.error('Oracle belongs to another fixture manifest')
    names = [r['file'] for r in manifest['fixtures']]
    modes = {'simplified': 2, 'traditional': 1, 'traditional-taiwan-idiom': 1025,
             'taiwan': 33, 'taiwan-idiom': 1057, 'hong-kong': 65, 'hong-kong-taiwan-idiom': 1089}
    rows = oracle['rows']
    if len(rows) != len(names) * 7 or {(r['fixture'], r['mode']) for r in rows} != {(f, m) for f in names for m in modes}:
        p.error('Require exactly seven modes for every fixture')
    for f in manifest['fixtures']:
        path = fixture_root / f['file']
        if Path(f['file']).name != f['file'] or path.is_symlink() or not path.is_file():
            p.error('Fixture must be a direct regular file')
        if sha(path) != f['sha256'] or path.stat().st_size != f['bytes']:
            p.error('Fixture integrity mismatch')
    for r in rows:
        f = next(f for f in manifest['fixtures'] if f['file'] == r['fixture'])
        if r['options_raw'] != modes[r['mode']] or r['input_sha256'] != f['sha256'] or r['input_bytes'] != f['bytes']:
            p.error('Oracle input or mode mismatch')
    a.output.mkdir(parents=True, exist_ok=False)
    output = a.output.resolve()
    package = output / 'package'
    source_dir = package / 'Sources/Probe'
    source_dir.mkdir(parents=True)
    for s in SOURCES:
        shutil.copy2(ROOT / s, source_dir / Path(s).name)
    (package / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Probe", platforms: [.macOS(.v12)],
 dependencies: [.package(name: "swiftyopencc", path: WRAPPER)],
 targets: [.executableTarget(name: "Probe", dependencies: [.product(name: "OpenCC", package: "swiftyopencc")])])
'''.replace('WRAPPER', json.dumps(str(wrapper))))
    with (output / 'build.log').open('w') as log:
        subprocess.run(['swift', 'build', '-c', 'release', '--package-path', str(package)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    binary = package / '.build/release/Probe'
    report = {'host': 'macOS service-only, NOT signed iOS acceptance', 'wrapper_sha': pin,
              'app_sha': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
              'source_sha256': {s: sha(ROOT / s) for s in SOURCES}, 'oracle_sha256': sha(a.oracle),
              'binary_sha256': sha(binary), 'rows': []}
    results = output / 'results'
    results.mkdir()
    for i, row in enumerate(rows):
        result = results / f'{i:03d}.json'
        with tempfile.TemporaryDirectory(prefix='owned-job-', dir=output) as job:
            subprocess.run([str(binary), str(fixture_root / row['fixture']), str(row['options_raw']),
                            row['output_sha256'], str(row['output_bytes']), str(Path(job) / 'store'), str(result)],
                           check=True, timeout=600)
        actual = json.loads(result.read_text())
        if actual['input_bytes'] != row['input_bytes']:
            raise RuntimeError('Wrong consumed input size')
        report['rows'].append({'fixture': row['fixture'], 'mode': row['mode'], **actual})
        print(f'PASS {i + 1}/{len(rows)}: {row["fixture"]} / {row["mode"]}', flush=True)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: complete service output/recovery/cleanup matrix; device acceptance NOT run')


if __name__ == '__main__':
    main()

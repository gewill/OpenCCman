#!/usr/bin/env python3
"""Typecheck isolated initializer fixtures and unmodified upstream source files.

No package resolution, cache cleanup, application build, or product edits.
Run via DEVELOPER_DIR to choose a toolchain without changing xcode-select.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'Tests/Toolchain/RevenueCatInitializer'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory')
    parser.add_argument('--expect-legacy', choices=['pass', 'fail'], required=True)
    parser.add_argument('--upstream-legacy', type=Path)
    parser.add_argument('--upstream-fixed', type=Path)
    args = parser.parse_args()
    if bool(args.upstream_legacy) != bool(args.upstream_fixed):
        parser.error('Supply both upstream files or neither')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    cases = [('reduced-legacy', FIXTURES / 'ExtensionInitializer.swift', args.expect_legacy),
             ('reduced-fixed', FIXTURES / 'PrimaryInitializer.swift', 'pass')]
    if args.upstream_legacy:
        cases += [('upstream-legacy', args.upstream_legacy.resolve(), args.expect_legacy),
                  ('upstream-fixed', args.upstream_fixed.resolve(), 'pass')]
    report = {'schemaVersion': 1, 'createdAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'scope': 'isolated macOS source typechecking, not whole-SDK or application validation',
              'developerDir': os.environ.get('DEVELOPER_DIR'), 'cases': []}
    for name, command in [('xcode', ['xcodebuild', '-version']),
                          ('swift', ['xcrun', 'swiftc', '-version'])]:
        report[name] = subprocess.check_output(command, text=True, stderr=subprocess.STDOUT, timeout=60).strip()
    sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True, stderr=subprocess.STDOUT, timeout=60).strip()
    settings = json.loads((Path(sdk) / 'SDKSettings.json').read_text())['SupportedTargets']['macosx']
    report['sdk'] = {'path': sdk, 'minimumDeploymentTarget': settings['MinimumDeploymentTarget'],
                     'validDeploymentTargets': settings['ValidDeploymentTargets']}
    ios_sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True, timeout=60).strip()
    ios_settings = json.loads((Path(ios_sdk) / 'SDKSettings.json').read_text())['SupportedTargets']['iphoneos']
    report['iosSDK'] = {'path': ios_sdk, 'minimumDeploymentTarget': ios_settings['MinimumDeploymentTarget'],
                        'validDeploymentTargets': ios_settings['ValidDeploymentTargets']}
    report['sources'] = {label: hashlib.sha256(source.read_bytes()).hexdigest() for label, source, _ in cases}
    if args.upstream_legacy:
        upstream = json.loads((FIXTURES / 'upstream-sources.json').read_text())
        report['upstreamSources'] = upstream
        for label in ['upstream-legacy', 'upstream-fixed']:
            if report['sources'][label] != upstream[label]['sha256']:
                parser.error(f'{label} does not match the pinned upstream source checksum')
    with tempfile.TemporaryDirectory(prefix='openccman-initializer-') as temp:
        for label, source, expected in cases:
            # Stable diagnostic paths; original sources and dependency caches stay untouched.
            copy = output / f'{label}.swift'
            copy.write_bytes(source.read_bytes())
            command = ['xcrun', 'swiftc', '-typecheck', '-swift-version', '5',
                       '-module-name', 'InitializerProbe', '-sdk', sdk,
                       '-target', 'arm64-apple-macosx12.0',
                       '-module-cache-path', str(Path(temp) / 'module-cache'), copy.name]
            timed_out = False
            try:
                proc = subprocess.run(command, cwd=output, text=True, capture_output=True, timeout=120)
                code, log = proc.returncode, proc.stdout + proc.stderr
            except subprocess.TimeoutExpired as error:
                timed_out = True
                code = None
                log = 'Typecheck timed out after 120 seconds\n'
                for part in [error.stdout, error.stderr]:
                    if part:
                        log += part.decode(errors='replace') if isinstance(part, bytes) else part
            (output / f'{label}.log').write_text(log)
            signature = "invalid redeclaration of synthesized memberwise 'init(stringRepresentation:)'" in log
            matched = not timed_out and (code == 0 if expected == 'pass' else code != 0 and signature)
            report['cases'].append({'name': label, 'expected': expected, 'exitCode': code,
                                    'timedOut': timed_out, 'initializerCollision': signature,
                                    'expectationMatched': matched,
                                    'command': ['<temporary-module-cache>' if arg == str(Path(temp) / 'module-cache') else arg for arg in command]})
    report['expectationsMatched'] = all(case['expectationMatched'] for case in report['cases'])
    (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'output': str(output), 'expectationsMatched': report['expectationsMatched'],
                      'cases': [{k: case[k] for k in ['name', 'exitCode', 'expectationMatched']} for case in report['cases']]}))
    return 0 if report['expectationsMatched'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

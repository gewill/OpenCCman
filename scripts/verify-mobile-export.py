#!/usr/bin/env python3
"""Read one explicitly supplied exported TXT and compare its full bytes to an oracle.

Context is operator-supplied provenance, not proof of a device run. This command
does not connect to devices, inspect user files, or establish memory acceptance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat

MODES = {'simplified': 2, 'traditional': 1, 'traditional-taiwan-idiom': 1025,
         'taiwan': 33, 'taiwan-idiom': 1057, 'hong-kong': 65, 'hong-kong-taiwan-idiom': 1089}


def fingerprint(value):
    return (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns)


def verify(export, oracle_path, context_path):
    oracle_bytes = oracle_path.read_bytes()
    oracle = json.loads(oracle_bytes)
    context = json.loads(context_path.read_bytes())
    for key in ('device_model', 'os', 'build', 'app_sha', 'wrapper_sha', 'provider', 'fixture', 'mode'):
        if not isinstance(context.get(key), str) or not context[key].strip():
            raise ValueError(f'Missing context: {key}')
    if context['wrapper_sha'] != oracle['wrapper_sha']:
        raise ValueError('Context wrapper differs from reference')
    if context['mode'] not in MODES:
        raise ValueError('Unknown conversion mode')
    rows = [r for r in oracle['rows'] if (r['fixture'], r['mode']) == (context['fixture'], context['mode'])]
    if len(rows) != 1 or rows[0]['options_raw'] != MODES[context['mode']]:
        raise ValueError('Missing, duplicate or inconsistent reference')
    reference = rows[0]
    # O_NONBLOCK avoids hanging on a FIFO before the regular-file check.
    fd = os.open(export, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise ValueError('Export must be a regular file, not a link or device')
        digest = hashlib.sha256()
        count = 0
        while block := stream.read(256 * 1024):
            count += len(block)
            digest.update(block)
        after = os.fstat(stream.fileno())
        current = os.stat(export, follow_symlinks=False)
        if fingerprint(before) != fingerprint(after) or fingerprint(after) != fingerprint(current):
            raise ValueError('Export changed during verification')
    actual = digest.hexdigest()
    passed = count == reference['output_bytes'] and actual == reference['output_sha256']
    return {'schema': 1, 'passed': passed,
            'scope': 'Full exported-byte comparison only; device context is operator supplied, not independently verified',
            'context': context, 'oracle_sha256': hashlib.sha256(oracle_bytes).hexdigest(),
            'reference': reference, 'actual': {'bytes': count, 'sha256': actual}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('export', 'oracle', 'context', 'report'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.export, args.oracle, args.context)
        # Exclusive creation also protects inputs if a report path aliases one.
        with args.report.open('x') as report:
            json.dump(result, report, ensure_ascii=False, indent=2)
            report.write('\n')
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(2, f'ERROR: {error}\n')
    print('PASS: full exported bytes match reference' if result['passed'] else 'FAIL: exported bytes differ from reference')
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()

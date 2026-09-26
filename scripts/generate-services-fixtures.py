#!/usr/bin/env python3
"""Generate byte-sized synthetic inputs and same-version OpenCC CLI expectations."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MODES = ['s2t', 's2tw', 's2twp', 's2hk', 't2s',
         'legacy-s2t-tw-idiom', 'legacy-s2hk-tw-idiom']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', type=Path, required=True)
    parser.add_argument('--resources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sizes', type=int, nargs='+', default=[1024, 1048576, 5242880, 10485760])
    parser.add_argument('--modes', nargs='+', choices=MODES, default=MODES,
                        help='Generate a focused subset; the default remains all seven modes.')
    args = parser.parse_args()
    if any(size < 1024 or size > 104857600 for size in args.sizes):
        parser.error('Use byte sizes between 1 KiB and 100 MiB; larger cases need a separate protocol.')
    if len(set(args.modes)) != len(args.modes):
        parser.error('Modes must be unique.')
    cli, resources, output = args.cli.resolve(), args.resources.resolve(), args.output.resolve()
    # Never replace an existing corpus or silently rewrite expected output.
    if output.exists():
        parser.error('Output directory already exists; choose a new directory.')
    manifest_data = (resources / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_data)
    version = subprocess.check_output([str(cli), '--version'], text=True).strip()
    expected_version = manifest['opencc']['tag'].removeprefix('ver.')
    if f'Version: {expected_version}' not in version.splitlines():
        raise ValueError('CLI version must exactly match the resource release.')
    for name, expected in manifest['files'].items():
        path = (resources / name).resolve()
        if not path.is_relative_to(resources) or digest(path.read_bytes()) != expected:
            raise ValueError(f'Resource checksum mismatch: {name}')
    output.mkdir(parents=True)
    sentence = '简体中文 軟體 软件 鼠标 滑鼠 網路 网络 内存 記憶體 里面 香港 台湾 😀 é '
    short = (sentence + '\r\n\r\n').encode('utf-8')
    long = (sentence * 100 + '\r\n').encode('utf-8')
    result = {'schemaVersion': 1, 'generatorSHA256': digest(Path(__file__).read_bytes()),
              'cliVersion': version, 'cliSHA256': digest(cli.read_bytes()),
              'resourceManifestSHA256': digest(manifest_data), 'opencc': manifest['opencc'],
              'cases': []}
    for shape, block in [('short-paragraphs', short), ('long-paragraphs', long)]:
        for size in args.sizes:
            data = block * (size // len(block))
            # Include whole Unicode sentences, then ASCII fill; never cut a scalar.
            tail = sentence.encode('utf-8')
            data += tail * ((size - len(data)) // len(tail))
            data += b' ' * (size - len(data))
            data.decode('utf-8')
            name = f'{shape}-{size}'
            source = output / (name + '.txt')
            source.write_bytes(data)
            for mode in args.modes:
                folder = 'Compatibility' if mode.startswith('legacy-') else 'Official'
                expected_path = output / f'{name}-{mode}.txt'
                subprocess.run([str(cli), '-c', str(resources / folder / (mode + '.json')),
                                '-i', str(source), '-o', str(expected_path)],
                               cwd=resources / 'Official', check=True)
                expected = expected_path.read_bytes()
                result['cases'].append({'shape': shape, 'mode': mode, 'input': source.name,
                                        'inputBytes': len(data), 'inputSHA256': digest(data),
                                        'expected': expected_path.name, 'expectedBytes': len(expected),
                                        'expectedSHA256': digest(expected)})
    # An interrupted generation has no completed manifest and is not a valid corpus.
    (output / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'Generated {len(result["cases"])} cases; no Services calls performed.')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Exercise the compiled whole-text reference, including NUL and BOM semantics."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', required=True, type=Path)
a = p.parse_args()
binary = a.binary.resolve()
modes = ['simplified', 'traditional', 'traditional-taiwan-idiom', 'taiwan',
         'taiwan-idiom', 'hong-kong', 'hong-kong-taiwan-idiom']
with tempfile.TemporaryDirectory(prefix='openccman-oracle-check-') as folder:
    root = Path(folder)
    source = root / 'source.txt'
    payload = 'A\0B\r\n\r\n🙂e\u0301\ufeffZ'.encode()
    source.write_bytes(b'\xef\xbb\xbf' + payload)
    for mode in modes:
        result = root / (mode + '.json')
        subprocess.run([str(binary), str(source), mode, str(result)], check=True)
        row = json.loads(result.read_text())
        assert row['output_bytes'] == len(payload), mode
        assert row['output_sha256'] == hashlib.sha256(payload).hexdigest(), mode
        assert row['input_sha256'] == hashlib.sha256(source.read_bytes()).hexdigest(), mode
    source.write_bytes(b'\xffinvalid')
    result = root / 'invalid.json'
    failed = subprocess.run([str(binary), str(source), 'traditional', str(result)], capture_output=True)
    assert failed.returncode != 0 and not result.exists(), 'Invalid UTF-8 must fail closed'
print('PASS: seven modes preserve NUL/CRLF/emoji/combining/interior BOM; initial BOM stripped; invalid UTF-8 rejected')

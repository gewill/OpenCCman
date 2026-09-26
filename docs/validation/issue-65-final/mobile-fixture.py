#!/usr/bin/env python3
"""Recreate this audit's synthetic paste corpus and optionally verify copied output."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--mib", type=int, choices=(1, 10), default=1)
parser.add_argument("--write", type=Path)
parser.add_argument("--verify-copy", type=Path)
args = parser.parse_args()
data = bytearray()
index = 0
while True:
    line = f"Paragraph {index:05d} 鼠标里面的软件与网络。 Emoji 👩🏽‍💻 e\u0301\r\n\r\n".encode()
    if len(data) + len(line) > 1048576:
        break
    data.extend(line)
    index += 1
data.extend(b"x" * (1048576 - len(data)))
data = bytes(data) * args.mib
# This expected output is specific to this fixed sentence and Traditional/OpenCC
# configuration. It is not a general-purpose Chinese converter.
expected = data.decode().translate(str.maketrans("标里软与络网", "標裏軟與絡網")).encode()
result = {"input_bytes": len(data), "input_sha256": hashlib.sha256(data).hexdigest(),
          "expected_sha256": hashlib.sha256(expected).hexdigest()}
if args.write:
    args.write.write_bytes(data)
if args.verify_copy:
    copied = args.verify_copy.read_bytes()
    result.update(output_bytes=len(copied), exact_expected_output=copied == expected,
                  output_sha256=hashlib.sha256(copied).hexdigest())
    if copied != expected:
        raise SystemExit(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))

#!/usr/bin/env python3
"""Reproduce the fixed 2 GiB native QA fixture or verify its known s2t output.

This literal oracle is only for this fixture, not a general Chinese converter.
"""
import argparse
import hashlib
from pathlib import Path

SOURCE = '头发与鼠标数据库服务器 😀é\0\r\n\n'.encode()
EXPECTED = '頭髮與鼠標數據庫服務器 😀é\0\r\n\n'.encode()
SIZE = 2 * 1024**3

def parts():
    block = SOURCE * 8192
    count, remainder = divmod(SIZE, len(block))
    tail = block[:remainder]
    while True:
        try:
            tail.decode('utf-8')
            break
        except UnicodeDecodeError:
            tail = tail[:-1]
    padding = b'a' * (remainder - len(tail))
    return count, block, tail, padding

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['create', 'verify'])
    parser.add_argument('file', type=Path)
    args = parser.parse_args()
    count, block, tail, padding = parts()
    if args.action == 'create':
        with args.file.open('xb') as target:
            for _ in range(count):
                target.write(block)
            target.write(tail + padding)
        assert args.file.stat().st_size == SIZE
    else:
        expected = hashlib.sha256()
        for _ in range(count):
            expected.update(EXPECTED * 8192)
        fixed_mapping = str.maketrans(dict(zip('头发与鼠标数据库服务器', '頭髮與鼠標數據庫服務器')))
        expected.update(tail.decode().translate(fixed_mapping).encode() + padding)
        actual = hashlib.sha256()
        with args.file.open('rb') as source:
            while chunk := source.read(1024 * 1024):
                actual.update(chunk)
        assert args.file.stat().st_size == SIZE
        assert actual.hexdigest() == expected.hexdigest()
        print('PASS: complete native output SHA-256', actual.hexdigest())

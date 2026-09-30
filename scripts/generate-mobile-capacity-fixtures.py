#!/usr/bin/env python3
"""Create deterministic UTF-8 inputs for #260, never a capacity-pass report."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MIB = 1024 * 1024
# Exact bytes, including CRLF, NUL and decomposed accents, are intentional.
CORPORA = {
    "no-newline": "鼠标里面的硅二极管坏了，软件与硬件需要检查。",
    "ascii": "OpenCCman ASCII 0123456789 !? <> [] {}\r\n",
    "unicode": "\ufeff汉字臺灣香港🙂👩🏽‍💻e\u0301\x00甲\r\n\r\n乙\n丙\r丁\u2028戊\u2029",
    "phrases": "软件鼠标内存硬盘打印机出租车自行车数据库互联网服务器视频\r\n",
}


def generate(path, size, corpus):
    """Bounded writer; ASCII tail preserves exact size and valid UTF-8."""
    if size < 1 or corpus not in CORPORA:
        raise ValueError("Require a positive byte count and known corpus")
    seed = CORPORA[corpus].encode("utf-8")
    block = seed * max(1, (64 * 1024) // len(seed))
    digest = hashlib.sha256()
    remaining = size
    with path.open("xb") as out:
        while remaining >= len(block):
            out.write(block)
            digest.update(block)
            remaining -= len(block)
        repeats, tail = divmod(remaining, len(seed))
        data = seed * repeats + b"x" * tail
        out.write(data)
        digest.update(data)
    return {"file": path.name, "bytes": size, "sha256": digest.hexdigest(),
            "corpus": corpus, "seed_utf8_hex": seed.hex(),
            "tail": "ASCII x padding, never a split UTF-8 sequence"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--sizes-mib", type=int, nargs="+", default=[20, 50, 100])
    parser.add_argument("--corpora", choices=CORPORA, nargs="+", default=list(CORPORA))
    args = parser.parse_args()
    if any(s < 1 or s > 100 for s in args.sizes_mib):
        parser.error("Sizes must be 1...100 MiB; release matrix requires 20, 50, 100")
    if len(set(args.sizes_mib)) != len(args.sizes_mib) or len(set(args.corpora)) != len(args.corpora):
        parser.error("Duplicate sizes/corpora are not allowed")
    lock = ROOT / "OpenCCman.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    pin = next(p["state"]["revision"] for p in json.loads(lock.read_bytes())["pins"]
               if p["identity"] == "swiftyopencc")
    # Fail on an existing directory: never replace a user's fixtures/results.
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = {"schema": 1, "purpose": "input fixtures only; no device acceptance",
                "wrapper_sha": pin,
                "app_sha": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
                "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                "fixtures": []}
    for size in args.sizes_mib:
        for corpus in args.corpora:
            path = args.output / f"{size:03d}MiB-{corpus}.txt"
            manifest["fixtures"].append(generate(path, size * MIB, corpus))
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"PASS: generated {len(manifest['fixtures'])} UTF-8 fixtures; device tests NOT run")


if __name__ == "__main__":
    main()

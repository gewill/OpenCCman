#!/usr/bin/env python3
"""Measure the Mac batch coordinator on 100 generated UTF-8 files.

Default mix: four files just under the 1 GiB limit plus 96 small and medium
files. Fixtures and outputs live in a new work directory that is removed
afterwards; only the JSON report is kept. This is a headless measurement of the
coordinator and file service, not a UI or signed-build acceptance.
"""
import argparse
import json
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MIB = 1024 * 1024
SEED = "软件鼠标内存硬盘打印机出租车自行车数据库互联网服务器视频\r\n头发里面的硅二极管坏了，导致光标分辨率降低。\n".encode()
SMALL_SIZES = [4 * 1024, 64 * 1024, 512 * 1024, 2 * MIB, 8 * MIB]


def write_fixture(path, size):
    block = SEED * max(1, MIB // len(SEED))
    remaining = size
    with path.open("xb") as out:
        while remaining >= len(block):
            out.write(block)
            remaining -= len(block)
        repeats, tail = divmod(remaining, len(SEED))
        out.write(SEED * repeats + b"x" * tail)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work", required=True, type=Path, help="New directory for fixtures and outputs")
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--large-count", type=int, default=4)
    parser.add_argument("--large-mib", type=int, default=1023)
    parser.add_argument("--files", type=int, default=100)
    args = parser.parse_args()
    if not 0 <= args.large_count <= args.files <= 100 or not 1 <= args.large_mib <= 1024:
        parser.error("Require at most 100 files, large files within 1 GiB")
    args.work.mkdir(parents=True, exist_ok=False)
    try:
        source, output = args.work / "input", args.work / "output"
        source.mkdir()
        output.mkdir()
        sizes = [args.large_mib * MIB] * args.large_count
        sizes += [SMALL_SIZES[i % len(SMALL_SIZES)] for i in range(args.files - args.large_count)]
        for index, size in enumerate(sizes):
            write_fixture(source / f"{index:03d}.txt", size)
        report = args.work / "report.json"
        subprocess.run(["python3", str(ROOT / "scripts/check-core.py"), "--batch-benchmark",
                        str(source), str(output), str(report)], check=True)
        result = json.loads(report.read_text())
        produced = sorted(p.name for p in output.iterdir())
        expected = sorted(f"{index:03d}-converted.txt" for index in range(len(sizes)))
        if produced != expected:
            raise SystemExit("Outputs do not match the input set exactly")
        result.update({
            "fixture_sizes": sizes,
            "app_sha": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
            "app_worktree_status": subprocess.check_output(["git", "-C", str(ROOT), "status", "--short"], text=True),
            "machine": subprocess.check_output(["sysctl", "-n", "hw.model"], text=True).strip(),
            "cpu": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
            "memory_bytes": int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True)),
            "os": platform.mac_ver()[0],
            "build": "SwiftPM release (swift run -c release)",
        })
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
        print(f"PASS: {result['succeeded']}/{result['files']} files in {result['elapsed_seconds']:.1f} s; "
              f"peak footprint {result['footprint_peak_mib']:.1f} MiB; "
              f"worst main-actor delay {result['main_actor_worst_delay_ms']:.1f} ms")
    finally:
        shutil.rmtree(args.work, ignore_errors=True)


if __name__ == "__main__":
    main()
